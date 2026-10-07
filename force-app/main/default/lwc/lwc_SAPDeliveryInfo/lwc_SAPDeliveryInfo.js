import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDeliveryInformation from '@salesforce/apex/API_ctrl_SAPDeliveryInfoController.getDeliveryInformation';

export default class SapDeliveryInformation extends LightningElement {
    @track filterType = '';
    @track fromDate = null;
    @track toDate = null;
    @track salesOrderNumber = '';
    @track deliveryData = [];
    @track isLoading = false;
    @track showTable = false;

    filterTypeOptions = [
        { label: 'From Date & To Date', value: 'date' },
        { label: 'Sales Order Number', value: 'salesOrder' }
    ];

    columns = [
        { label: 'Delivery No', fieldName: 'deliveryNo' },
        { label: 'Delivery Line Item No', fieldName: 'deliveryLineItemNo' },
        { label: 'Sales Order No', fieldName: 'salesOrderNo' },
        { label: 'Sales Order Line Item', fieldName: 'salesOrderLineItem' },
        { label: 'Delivery Item', fieldName: 'deliveryItem' },
        { label: 'Delivery Item Description', fieldName: 'deliveryItemDescription' },
        { label: 'Delivery Date', fieldName: 'deliveryDate' },
        { label: 'Delivery Quantity', fieldName: 'deliveryQuantity' },
        { label: 'Plant', fieldName: 'plant' },
        { label: 'Storage Location', fieldName: 'storageLocation' },
        { label: 'Net Price', fieldName: 'netPrice' },
        { label: 'Net Value', fieldName: 'netValue' }
    ];

    get isDateFilter() {
        return this.filterType === 'date';
    }

    get isSalesOrderFilter() {
        return this.filterType === 'salesOrder';
    }

    get showActionButtons() {
        return this.filterType === 'date' || this.filterType === 'salesOrder';
    }

    get hasData() {
        return this.deliveryData && this.deliveryData.length > 0;
    }

    handleFilterTypeChange(event) {
        this.filterType = event.detail.value;
        this.fromDate = null;
        this.toDate = null;
        this.salesOrderNumber = '';
        this.deliveryData = [];
        this.showTable = false;
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
    }

    handleSalesOrderChange(event) {
        this.salesOrderNumber = event.target.value;
    }

    async handleFetch() {
        try {
            if (!this.filterType) {
                this.showToast('Error', 'Please select a filter type.', 'error');
                return;
            }

            if (this.filterType === 'date') {
                if (!this.fromDate || !this.toDate) {
                    this.showToast('Error', 'Please enter From Date and To Date.', 'error');
                    return;
                }

                if (this.fromDate > this.toDate) {
                    this.showToast('Error', 'From Date cannot be greater than To Date.', 'error');
                    return;
                }
            }

            if (this.filterType === 'salesOrder') {
                if (!this.salesOrderNumber || !this.salesOrderNumber.trim()) {
                    this.showToast('Error', 'Please enter Sales Order Number.', 'error');
                    return;
                }
            }

            this.isLoading = true;
            this.showTable = false;
            this.deliveryData = [];

            const result = await getDeliveryInformation({
                filterType: this.filterType,
                fromDate: this.filterType === 'date' ? this.fromDate : null,
                toDate: this.filterType === 'date' ? this.toDate : null,
                salesOrderNumber: this.filterType === 'salesOrder' ? this.salesOrderNumber : null
            });

            const rows = (result || []).map((row, index) => {
                return {
                    ...row,
                    uniqueKey: `${row.deliveryNo || ''}-${row.deliveryLineItemNo || ''}-${index}`
                };
            });

            this.deliveryData = rows;
            this.showTable = true;

            if (this.deliveryData.length > 0) {
                this.showToast('Success', `Records fetched successfully: ${this.deliveryData.length}`, 'success');
            } else {
                this.showToast('Info', 'No records found.', 'info');
            }
        } catch (error) {
            let message = 'Unknown error';
            if (error && error.body && error.body.message) {
                message = error.body.message;
            } else if (error && error.message) {
                message = error.message;
            }

            this.showToast('Error', message, 'error');
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
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}