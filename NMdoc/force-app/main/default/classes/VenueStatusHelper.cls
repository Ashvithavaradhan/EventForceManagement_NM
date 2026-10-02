public with sharing class VenueStatusHelper {
    public static void updateVenueStatus(List<Event__c> events, Map<Id, Event__c> oldMap) {
        Set<Id> venueIdsToBook = new Set<Id>();
        Set<Id> venueIdsToFree = new Set<Id>();

        for (Event__c evt : events) {
            Event__c oldEvt = (oldMap != null) ? oldMap.get(evt.Id) : null;
            Boolean wasBookable = oldEvt != null && isBookableStatus(oldEvt.Event_Status__c);
            Boolean isBookableNow = isBookableStatus(evt.Event_Status__c);

            if (wasBookable && oldEvt.Venue__c != null &&
                (!isBookableNow || oldEvt.Venue__c != evt.Venue__c)) {
                venueIdsToFree.add(oldEvt.Venue__c);
            }
            if (isBookableNow && evt.Venue__c != null) {
                venueIdsToBook.add(evt.Venue__c);
            }
        }

        venueIdsToFree.removeAll(venueIdsToBook);
        List<Venue__c> venuesToUpdate = new List<Venue__c>();

        if (!venueIdsToBook.isEmpty()) {
            for (Id vId : venueIdsToBook) {
                venuesToUpdate.add(new Venue__c(Id = vId, Availability_Status__c = 'Booked'));
            }
        }

        if (!venueIdsToFree.isEmpty()) {
            for (Id vId : venueIdsToFree) {
                venuesToUpdate.add(new Venue__c(Id = vId, Availability_Status__c = 'Available'));
            }
        }

        if (!venuesToUpdate.isEmpty()) {
            update venuesToUpdate;
        }
    }

    public static Boolean isBookableStatus(String status) {
        return status == 'Confirmed' || status == 'Scheduled' || status == 'Pending Cancellation';
    }
}