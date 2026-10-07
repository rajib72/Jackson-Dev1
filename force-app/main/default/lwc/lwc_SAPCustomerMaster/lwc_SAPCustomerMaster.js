import { LightningElement, track } from 'lwc';
import fetchAndSyncCustomerMaster from '@salesforce/apex/API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Customer Code', fieldName: 'customerCode', type: 'text', initialWidth: 150, sortable: true },
    { label: 'Customer Name', fieldName: 'customerName', type: 'text', sortable: true },
    { label: 'Action', fieldName: 'action', type: 'text', initialWidth: 100, sortable: true },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 100, sortable: true },
    { label: 'Message', fieldName: 'message', type: 'text', wrapText: true, sortable: true }
];

export default class SapCustomerMasterSync extends LightningElement {
    @track fromDate;
    @track toDate;
    @track isLoading = false;
    @track results = [];
    @track summary;
    @track showResults = false;

    columns = COLUMNS;

    connectedCallback() {
        const today = new Date();
        const firstDay = new Date(today.getFullYear(), today.getMonth(), 1);

        this.fromDate = this.formatDateForInput(firstDay);
        this.toDate = this.formatDateForInput(today);
    }

    formatDateForInput(dateObj) {
        const year = dateObj.getFullYear();
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const day = String(dateObj.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    handleChange(event) {
        const field = event.target.name;
        this[field] = event.target.value;
    }

    async handleFetchAndSync() {
        if (!this.fromDate || !this.toDate) {
            this.showToast('Error', 'Please select both From Date and To Date.', 'error');
            return;
        }

        if (this.fromDate > this.toDate) {
            this.showToast('Error', 'From Date cannot be greater than To Date.', 'error');
            return;
        }

        this.isLoading = true;
        this.showResults = false;
        this.results = [];
        this.summary = null;

        try {
            const result = await fetchAndSyncCustomerMaster({
                fromDate: this.fromDate,
                toDate: this.toDate
            });

            if (result) {
                this.summary = {
                    success: result.success,
                    message: result.message,
                    totalReceived: result.totalReceived || 0,
                    insertedCount: result.insertedCount || 0,
                    updatedCount: result.updatedCount || 0,
                    failedCount: result.failedCount || 0,
                    skippedCount: result.skippedCount || 0
                };

                this.results = (result.results || []).map((row, index) => {
                    return {
                        ...row,
                        rowId: 'row-' + index
                    };
                });

                this.showResults = true;

                if (result.success) {
                    this.showToast('Success', result.message, 'success');
                } else {
                    this.showToast('Error', result.message, 'error');
                }
            }
        } catch (error) {
            this.showToast(
                'Error',
                error?.body?.message || error.message || 'Unknown error occurred.',
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        window.location.reload();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    get hasResults() {
        return this.results && this.results.length > 0;
    }
}