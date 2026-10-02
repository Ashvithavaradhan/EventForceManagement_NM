import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDashboard from '@salesforce/apex/EventForceDashboardController.getDashboard';

const COLUMNS = [
    { label: 'Event', fieldName: 'name', type: 'text' },
    { label: 'Date', fieldName: 'eventDate', type: 'date-local' },
    { label: 'Type', fieldName: 'eventType', type: 'text' },
    { label: 'Status', fieldName: 'eventStatus', type: 'text' },
    { label: 'Client', fieldName: 'clientName', type: 'text' },
    { label: 'Venue', fieldName: 'venueName', type: 'text' },
    {
        label: 'Budget',
        fieldName: 'eventBudget',
        type: 'currency',
        typeAttributes: { currencyCode: 'INR', maximumFractionDigits: 0 }
    }
];

export default class EventForceDashboard extends LightningElement {
    dashboardData;
    errorMessage;
    wiredDashboardResult;

    @wire(getDashboard)
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        if (result.data) {
            this.dashboardData = result.data;
            this.errorMessage = undefined;
        } else if (result.error) {
            this.dashboardData = undefined;
            this.errorMessage = 'Event data could not be loaded. Refresh the page or contact your Salesforce administrator.';
        }
    }

    get columns() {
        return COLUMNS;
    }

    get hasUpcomingEvents() {
        return Boolean(this.dashboardData?.upcomingEvents?.length);
    }

    get isLoading() {
        return !this.dashboardData && !this.errorMessage;
    }

    handleRefresh() {
        return refreshApex(this.wiredDashboardResult);
    }
}