trigger PreventDoubleBooking on Event__c (before insert, before update) {
    Set<Id> venueIds = new Set<Id>();
    Set<Date> eventDates = new Set<Date>();
    Set<Id> incomingIds = new Set<Id>();
    Set<String> incomingBookings = new Set<String>();

    for (Event__c evt : Trigger.new) {
        if (evt.Id != null) incomingIds.add(evt.Id);
        if (evt.Venue__c != null && evt.Event_Date__c != null && VenueStatusHelper.isBookableStatus(evt.Event_Status__c)) {
            venueIds.add(evt.Venue__c);
            eventDates.add(evt.Event_Date__c);
            String key = evt.Venue__c + '_' + String.valueOf(evt.Event_Date__c);
            if (!incomingBookings.add(key)) {
                evt.addError('This venue is already booked for the selected date.');
            }
        }
    }

    if (venueIds.isEmpty()) return;

    List<Event__c> existingEvents = [
        SELECT Id, Venue__c, Event_Date__c 
        FROM Event__c 
        WHERE Venue__c IN :venueIds 
          AND Event_Date__c IN :eventDates 
          AND Event_Status__c IN ('Scheduled', 'Confirmed')
    ];

    Set<String> bookedSlots = new Set<String>();
    for (Event__c ex : existingEvents) {
        if (incomingIds.contains(ex.Id)) continue;
        String key = ex.Venue__c + '_' + String.valueOf(ex.Event_Date__c);
        bookedSlots.add(key);
    }

    for (Event__c evt : Trigger.new) {
        if (evt.Venue__c != null && evt.Event_Date__c != null && VenueStatusHelper.isBookableStatus(evt.Event_Status__c)) {
            String key = evt.Venue__c + '_' + String.valueOf(evt.Event_Date__c);
            if (bookedSlots.contains(key)) {
                evt.addError('This venue is already booked for the selected date.');
            }
        }
    }
}