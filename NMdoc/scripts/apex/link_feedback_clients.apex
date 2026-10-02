List<Feedback__c> feedbackToUpdate = [
    SELECT Id, Event__r.Client__c
    FROM Feedback__c
    WHERE Client__c = null AND Event__c != null AND Event__r.Client__c != null
];

for (Feedback__c feedback : feedbackToUpdate) {
    feedback.Client__c = feedback.Event__r.Client__c;
}

if (!feedbackToUpdate.isEmpty()) {
    update feedbackToUpdate;
}

System.debug('Linked Feedback records to their Event clients: ' + feedbackToUpdate.size());