public class BatchCompleteEvents implements Database.Batchable<sObject> {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date todayDate = Date.today();
        return Database.getQueryLocator([
            SELECT Id, Event_Status__c 
            FROM Event__c 
            WHERE Event_Date__c < :todayDate 
              AND Event_Status__c = 'Scheduled'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Event__c> scope) {
        for (Event__c evt : scope) {
            evt.Event_Status__c = 'Completed';
        }
        update scope;
    }

    public void finish(Database.BatchableContext bc) {
    }
}