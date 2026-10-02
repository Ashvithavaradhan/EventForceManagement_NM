trigger EventTrigger13 on Event__c (after insert, after update) {
    if (Trigger.isAfter) {
        VenueStatusHelper.updateVenueStatus(Trigger.new, Trigger.oldMap);
    }
}