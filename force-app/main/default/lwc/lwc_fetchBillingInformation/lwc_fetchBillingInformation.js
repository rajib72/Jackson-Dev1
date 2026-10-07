import { LightningElement, track } from 'lwc';
import fetchBillingInformation from '@salesforce/apex/API_Ctrl_BillingInformationController.fetchBillingInformation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Billing Document', fieldName: 'billingDocument', type: 'text' },
    { label: 'Billing Line Item No', fieldName: 'billingLineItemNo', type: 'text' },
    { label: 'Billing Document Date', fieldName: 'billingDocumentDate', type: 'text' },
    { label: 'Billing Document Amount', fieldName: 'billingDocumentAmount', type: 'text' },
    { label: 'Delivery Number', fieldName: 'deliveryNumber', type: 'text' },
    { label: 'Sales Order No', fieldName: 'salesOrderNo', type: 'text' }
];

export default class BillingInformationViewer extends LightningElement {
    @track filterType = '';
    @track fromDate = null;
    @track toDate = null;
    @track deliveryNumber = '';
    @track records = [];
    @track isLoading = false;
    @track statusMessage = '';
    @track recordCount = 0;

    columns = COLUMNS;

    get filterTypeOptions() {
        return [
            { label: 'From Date & To Date', value: 'DATE' },
            { label: 'Delivery Number', value: 'DELIVERY' }
        ];
    }

    get showDateFilters() {
        return this.filterType === 'DATE';
    }

    get showDeliveryFilter() {
        return this.filterType === 'DELIVERY';
    }

    get showActionButtons() {
        return this.filterType === 'DATE' || this.filterType === 'DELIVERY';
    }

    get hasRecords() {
        return this.records && this.records.length > 0;
    }

    get showResultSummary() {
        return this.statusMessage !== '';
    }

    get showNoData() {
        return !this.isLoading && this.showResultSummary && this.records.length === 0 && this.statusMessage === 'No records found.';
    }

    handleFilterTypeChange(event) {
        this.filterType = event.detail.value;
        this.records = [];
        this.statusMessage = '';
        this.recordCount = 0;

        if (this.filterType === 'DATE') {
            this.deliveryNumber = '';
            this.fromDate = null;
            this.toDate = null;
        } else if (this.filterType === 'DELIVERY') {
            this.fromDate = null;
            this.toDate = null;
            this.deliveryNumber = '';
        }
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
    }

    handleDeliveryNumberChange(event) {
        this.deliveryNumber = event.target.value;
    }

    async handleFetch() {
        if (!this.validateInputs()) {
            return;
        }

        this.isLoading = true;
        this.records = [];
        this.statusMessage = '';
        this.recordCount = 0;

        try {
            const result = await fetchBillingInformation({
                filterType: this.filterType,
                fromDate: this.filterType === 'DATE' ? this.fromDate : null,
                toDate: this.filterType === 'DATE' ? this.toDate : null,
                deliveryNumber: this.filterType === 'DELIVERY' ? this.deliveryNumber : null
            });

            if (result) {
                this.records = (result.records || []).map((item, index) => {
                    return {
                        ...item,
                        uniqueKey: `${item.billingDocument || 'ROW'}_${index}`
                    };
                });

                this.recordCount = result.count || 0;
                this.statusMessage = result.message || '';

                if (!result.success) {
                    this.showToast('Error', this.statusMessage || 'Something went wrong.', 'error');
                } else if (this.recordCount > 0) {
                    this.showToast('Success', 'Billing information fetched successfully.', 'success');
                }
            }
        } catch (error) {
            const msg = this.reduceError(error);
            this.showToast('Error', msg, 'error');
            this.statusMessage = msg;
            this.records = [];
            this.recordCount = 0;
        } finally {
            this.isLoading = false;
        }
    }

    handleReset() {
        this.filterType = '';
        this.fromDate = null;
        this.toDate = null;
        this.deliveryNumber = '';
        this.records = [];
        this.statusMessage = '';
        this.recordCount = 0;
    }

    validateInputs() {
        if (!this.filterType) {
            this.showToast('Validation Error', 'Please select a filter type.', 'error');
            return false;
        }

        if (this.filterType === 'DATE') {
            if (!this.fromDate || !this.toDate) {
                this.showToast('Validation Error', 'Please select both From Date and To Date.', 'error');
                return false;
            }

            if (this.fromDate > this.toDate) {
                this.showToast('Validation Error', 'From Date cannot be greater than To Date.', 'error');
                return false;
            }
        }

        if (this.filterType === 'DELIVERY') {
            if (!this.deliveryNumber || !this.deliveryNumber.trim()) {
                this.showToast('Validation Error', 'Please enter Delivery Number.', 'error');
                return false;
            }
        }

        return true;
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

    reduceError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Unknown error occurred.';
    }
}