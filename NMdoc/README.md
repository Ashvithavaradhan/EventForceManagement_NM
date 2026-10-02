# EventForce Management System

Salesforce DX implementation for managing event bookings, clients, venues, vendor assignments, feedback, and cancellation approvals.

## Data Model

- `Event__c` looks up to `Client__c` and `Venue__c`.
- `Feedback__c` looks up to `Event__c` and `Client__c`.
- `EventVendor__c` is the Event-to-Vendor junction object.
- Event budget is calculated from Event Type. Existing records and legacy picklist values were preserved while required values were activated.

The connected development org already contains 12 Events, 12 Clients, 12 Vendors, 12 Venues, and 10 Feedback records. The Feedback Client lookups were populated from their linked Events where blank.

## Automation

- `Client_Reminder_3_Days_Before` emails the Client and Event owner three days before a Confirmed Event.
- `Notify_Client_of_Event_Cancellation` emails the linked Client when an Event changes to Canceled.
- `Event_Cancellation_Process` is active, routes to the record owner's manager, notifies Event Coordinators and owners, sets approved requests to Canceled, and returns rejected requests to Confirmed.
- `PreventDoubleBooking` rejects conflicting Event bookings, including duplicates in a bulk insert.
- `VenueStatusHelper` reserves venues for Confirmed, Scheduled, and Pending Cancellation Events and releases them after cancellation or completion.
- `BatchCompleteEvents` and `ScheduleCompleteEvents` are deployed; the daily `Daily Event Completion` job is scheduled in the connected org.

## Access and Navigation

The `EventForce Management` Lightning app includes the Event, Client, Vendor, Venue, Feedback, and Operations Dashboard tabs. The legacy `Event Planner` app remains in the org; the new Lightning app is the verified working navigation target. The connected org also has Event Admin, Event Coordinator, Vendor Manager, and Client profiles, corresponding roles, and Feedback Manager permissions.

The Event owner for the existing records has an active Event Admin user assigned as Manager so hierarchy-based cancellation approval resolves to an approver.

## Operations Dashboard

The Operations Dashboard is a custom Lightning tab backed by `EventForceDashboardController`. It displays upcoming-event count, upcoming budget, and the next ten Events. This provides live operational visibility without depending on report metadata.

The org does not expose a report type for the custom `Event__c` object through Report Builder or the Analytics API, even after Event reporting was enabled. The only matching native report type is Salesforce's standard calendar `Events`, which does not report `Event__c` CRM records. A Salesforce-native custom report and Dashboard component could not be deployed; the Lightning dashboard is the working alternative.

## Deploy and Test

Authorize the target development org, then deploy the package:

```sh
sf org login web --alias eventforce
sf project deploy start --target-org eventforce --source-dir force-app/main/default --test-level RunSpecifiedTests --tests EventForceTest
```

Run the focused Apex suite independently:

```sh
sf apex run test --target-org eventforce --class-names EventForceTest
```

The data repair script only fills Feedback Client lookups that are blank:

```sh
sf apex run --target-org eventforce --file scripts/apex/link_feedback_clients.apex
```

The complete package dry run passed with all eight `EventForceTest` tests. Because Salesforce blocks Apex class deployment while scheduler jobs are pending, the existing nightly job was temporarily paused for the dry run and immediately restored with the same cron expression (`0 0 0 * * ?`). Its current state is `WAITING`.