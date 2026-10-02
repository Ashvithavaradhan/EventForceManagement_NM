/** Read-only Event summary data for the EventForce operations dashboard. */
public with sharing class EventForceDashboardController {
    /**
     * Returns upcoming Event totals and the next ten visible Event records.
     * @return Dashboard metrics and Event rows.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboard() {
        DashboardData data = new DashboardData();
        data.upcomingCount = [
            SELECT COUNT()
            FROM Event__c
            WHERE Event_Date__c >= TODAY
                AND Event_Status__c NOT IN ('Canceled', 'Cancelled', 'Completed')
            WITH USER_MODE
        ];

        AggregateResult budgetResult = [
            SELECT SUM(Event_Budget__c) totalBudget
            FROM Event__c
            WHERE Event_Date__c >= TODAY
                AND Event_Status__c NOT IN ('Canceled', 'Cancelled', 'Completed')
            WITH USER_MODE
        ];
        data.upcomingBudget = (Decimal) budgetResult.get('totalBudget');
        if (data.upcomingBudget == null) {
            data.upcomingBudget = 0;
        }

        data.upcomingEvents = new List<EventRow>();
        for (Event__c eventRecord : [
            SELECT Id, Name, Event_Date__c, Event_Type__c, Event_Status__c,
                Event_Budget__c, Client__r.Name, Venue__r.Name
            FROM Event__c
            WHERE Event_Date__c >= TODAY
                AND Event_Status__c NOT IN ('Canceled', 'Cancelled', 'Completed')
            WITH USER_MODE
            ORDER BY Event_Date__c ASC
            LIMIT 10
        ]) {
            data.upcomingEvents.add(new EventRow(eventRecord));
        }
        return data;
    }

    /** Summary metrics and rows displayed by the dashboard. */
    public class DashboardData {
        /** Number of non-canceled, non-completed Events dated today or later. */
        @AuraEnabled public Integer upcomingCount { get; set; }
        /** Sum of the formula budget for upcoming Events. */
        @AuraEnabled public Decimal upcomingBudget { get; set; }
        /** Upcoming Event rows, ordered by Event date. */
        @AuraEnabled public List<EventRow> upcomingEvents { get; set; }
    }

    /** Event fields formatted for the dashboard table. */
    public class EventRow {
        /** Salesforce Event record ID. */
        @AuraEnabled public Id id { get; set; }
        /** Event name. */
        @AuraEnabled public String name { get; set; }
        /** Scheduled Event date. */
        @AuraEnabled public Date eventDate { get; set; }
        /** Event category. */
        @AuraEnabled public String eventType { get; set; }
        /** Current Event status. */
        @AuraEnabled public String eventStatus { get; set; }
        /** Calculated Event budget. */
        @AuraEnabled public Decimal eventBudget { get; set; }
        /** Related Client name, when present. */
        @AuraEnabled public String clientName { get; set; }
        /** Related Venue name, when present. */
        @AuraEnabled public String venueName { get; set; }

        /**
         * Maps an Event record and its relationship names to a display row.
         * @param eventRecord Event record with loaded Client and Venue relationships.
         */
        public EventRow(Event__c eventRecord) {
            id = eventRecord.Id;
            name = eventRecord.Name;
            eventDate = eventRecord.Event_Date__c;
            eventType = eventRecord.Event_Type__c;
            eventStatus = eventRecord.Event_Status__c;
            eventBudget = eventRecord.Event_Budget__c;
            clientName = eventRecord.Client__r == null ? null : eventRecord.Client__r.Name;
            venueName = eventRecord.Venue__r == null ? null : eventRecord.Venue__r.Name;
        }
    }
}