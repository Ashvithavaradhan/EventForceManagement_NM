@IsTest
private class EventForceTest {
    @IsTest
    static void testEventFlow() {
        Client__c client = new Client__c(Name = 'Test Client', Email__c = 'test@example.com');
        insert client;

        Venue__c venue = new Venue__c(Name = 'Test Venue', Capacity__c = 100, Availability_Status__c = 'Available');
        insert venue;

        Event__c evt = new Event__c(
            Name = 'Test Event',
            Client__c = client.Id,
            Venue__c = venue.Id,
            Event_Date__c = Date.today().addDays(5),
            Event_Status__c = 'Scheduled'
        );
        insert evt;

        Venue__c updatedVenue = [SELECT Availability_Status__c FROM Venue__c WHERE Id = :venue.Id];
        assertVenueBooked(updatedVenue.Availability_Status__c);

        evt.Event_Status__c = 'Completed';
        update evt;

        Venue__c freedVenue = [SELECT Availability_Status__c FROM Venue__c WHERE Id = :venue.Id];
        System.assertEquals('Available', freedVenue.Availability_Status__c, 'Completing the event should release its venue.');
    }

    @IsTest
    static void testBatchJob() {
        Venue__c venue = new Venue__c(Name = 'Batch Venue', Availability_Status__c = 'Available');
        insert venue;

        Event__c pastEvent = new Event__c(
            Name = 'Past Event',
            Venue__c = venue.Id,
            Event_Date__c = Date.today().addDays(-2),
            Event_Status__c = 'Scheduled'
        );
        insert pastEvent;

        Test.startTest();
        BatchCompleteEvents b = new BatchCompleteEvents();
        Database.executeBatch(b);
        Test.stopTest();

        Event__c res = [SELECT Event_Status__c FROM Event__c WHERE Id = :pastEvent.Id];
        System.assertEquals('Completed', res.Event_Status__c, 'The batch should complete past Events.');
    }

    @IsTest
    static void testScheduleCompleteEventsRunsBatch() {
        Event__c pastEvent = new Event__c(
            Name = 'Scheduled Batch Event',
            Event_Date__c = Date.today().addDays(-1),
            Event_Status__c = 'Scheduled'
        );
        insert pastEvent;

        Test.startTest();
        new ScheduleCompleteEvents().execute(null);
        Test.stopTest();

        Event__c completedEvent = [SELECT Event_Status__c FROM Event__c WHERE Id = :pastEvent.Id];
        System.assertEquals('Completed', completedEvent.Event_Status__c, 'The scheduler should run the batch completion job.');
    }

    @IsTest
    static void testDoubleBookingRejectedWithinBulkInsert() {
        Venue__c venue = new Venue__c(Name = 'Bulk Venue', Availability_Status__c = 'Available');
        insert venue;
        Date eventDate = Date.today().addDays(20);
        List<Event__c> events = new List<Event__c>{
            new Event__c(Name = 'Bulk Event A', Venue__c = venue.Id, Event_Date__c = eventDate, Event_Status__c = 'Confirmed'),
            new Event__c(Name = 'Bulk Event B', Venue__c = venue.Id, Event_Date__c = eventDate, Event_Status__c = 'Confirmed')
        };

        Test.startTest();
        Database.SaveResult[] results = Database.insert(events, false);
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess(), 'The first booking should be accepted.');
        System.assertEquals(false, results[1].isSuccess(), 'The duplicate booking should be rejected.');
    }

    @IsTest
    static void testMovingEventReleasesPreviousVenue() {
        Venue__c originalVenue = new Venue__c(Name = 'Original Venue', Availability_Status__c = 'Available');
        Venue__c newVenue = new Venue__c(Name = 'New Venue', Availability_Status__c = 'Available');
        insert new List<Venue__c>{ originalVenue, newVenue };
        Event__c evt = new Event__c(
            Name = 'Moved Event', Venue__c = originalVenue.Id,
            Event_Date__c = Date.today().addDays(10), Event_Status__c = 'Confirmed'
        );
        insert evt;

        evt.Venue__c = newVenue.Id;
        update evt;

        Map<Id, Venue__c> updatedVenues = new Map<Id, Venue__c>([
            SELECT Id, Availability_Status__c FROM Venue__c WHERE Id IN :new Set<Id>{ originalVenue.Id, newVenue.Id }
        ]);
        System.assertEquals('Available', updatedVenues.get(originalVenue.Id).Availability_Status__c, 'Moving an event should free its previous venue.');
        assertVenueBooked(updatedVenues.get(newVenue.Id).Availability_Status__c);
    }

    @IsTest
    static void testPendingCancellationKeepsVenueReservedUntilApproved() {
        Client__c client = new Client__c(Name = 'Cancellation Client', Email__c = 'cancel@example.com');
        insert client;
        Venue__c venue = new Venue__c(Name = 'Cancellation Venue', Availability_Status__c = 'Available');
        insert venue;
        Event__c evt = new Event__c(
            Name = 'Cancellation Event', Client__c = client.Id, Venue__c = venue.Id,
            Event_Date__c = Date.today().addDays(15), Event_Status__c = 'Confirmed'
        );
        insert evt;

        evt.Event_Status__c = 'Pending Cancellation';
        update evt;

        Venue__c pendingVenue = [SELECT Availability_Status__c FROM Venue__c WHERE Id = :venue.Id];
        assertVenueBooked(pendingVenue.Availability_Status__c);

        evt.Event_Status__c = 'Canceled';
        update evt;

        Venue__c canceledVenue = [SELECT Availability_Status__c FROM Venue__c WHERE Id = :venue.Id];
        System.assertEquals('Available', canceledVenue.Availability_Status__c, 'Approval should release the venue after cancellation.');
    }

    @IsTest
    static void testDashboardReturnsUpcomingEventMetrics() {
        Event__c upcomingEvent = new Event__c(
            Name = 'Dashboard Wedding',
            Event_Date__c = Date.today().addDays(12),
            Event_Type__c = 'Wedding',
            Event_Status__c = 'Confirmed'
        );
        Event__c canceledEvent = new Event__c(
            Name = 'Dashboard Canceled Event',
            Event_Date__c = Date.today().addDays(8),
            Event_Type__c = 'Birthday',
            Event_Status__c = 'Canceled'
        );
        insert new List<Event__c>{ upcomingEvent, canceledEvent };

        EventForceDashboardController.DashboardData result = EventForceDashboardController.getDashboard();

        System.assertEquals(1, result.upcomingCount, 'Only active upcoming Events should be counted.');
        System.assertEquals(50000, result.upcomingBudget, 'The summary should use the Event budget formula.');
        System.assertEquals(1, result.upcomingEvents.size(), 'The dashboard should return the upcoming Event row.');
        System.assertEquals('Dashboard Wedding', result.upcomingEvents[0].name, 'The dashboard should return the next active Event.');
    }

    @IsTest
    static void testCancellationApprovalRoutesToManager() {
        User eventOwner = [SELECT ManagerId FROM User WHERE Id = :UserInfo.getUserId()];
        System.assertNotEquals(null, eventOwner.ManagerId, 'The Event owner needs a manager for approval routing.');

        Event__c evt = new Event__c(
            Name = 'Approval Routing Event',
            Event_Date__c = Date.today().addDays(18),
            Event_Status__c = 'Pending Cancellation'
        );
        insert evt;

        Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
        request.setObjectId(evt.Id);
        request.setComments('Automated test of manager approval routing.');

        Test.startTest();
        Approval.ProcessResult result = Approval.process(request);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess(), 'The cancellation request should enter the active approval process.');
        ProcessInstanceWorkitem workItem = [
            SELECT ActorId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :evt.Id
            LIMIT 1
        ];
        System.assertEquals(eventOwner.ManagerId, workItem.ActorId, 'The request should be assigned to the Event owner manager.');
    }

    private static void assertVenueBooked(String availabilityStatus) {
        System.assert(
            availabilityStatus == 'Reserved' || availabilityStatus == 'Booked',
            'Expected a booking status, received ' + availabilityStatus
        );
    }
}