import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import fetchDeliveryData from '@salesforce/apex/SAPDeliveryLWCController.fetchDeliveryData';
import saveDeliveryRecords from '@salesforce/apex/SAPDeliveryLWCController.saveDeliveryRecords';

const COLUMNS = [
    { label: 'Delivery No', fieldName: 'deliveryNo', type: 'text' },
    { label: 'Delivery Line Item No', fieldName: 'deliveryLineItemNo', type: 'text' },
    { label: 'Sales Order No', fieldName: 'salesOrderNo', type: 'text' },
    { label: 'Sales Order Line Item', fieldName: 'salesOrderLineItem', type: 'text' },
    { label: 'Delivery Item', fieldName: 'deliveryItem', type: 'text' },
    { label: 'Delivery Item Desc', fieldName: 'deliveryItemDescription', type: 'text' },
    { label: 'Delivery Date', fieldName: 'deliveryDate', type: 'text' },
    { label: 'Delivery Quantity', fieldName: 'deliveryQuantity', type: 'text' },
    { label: 'Plant', fieldName: 'plant', type: 'text' },
    { label: 'Storage Location', fieldName: 'storageLocation', type: 'text' },
    { label: 'Net Price', fieldName: 'netPrice', type: 'text' },
    { label: 'Net Value', fieldName: 'netValue', type: 'text' }
];

export default class Lwc_SAPDeliveryInfoButton extends LightningElement {
    _recordId; 
    @track deliveryData = [];
    columns = COLUMNS;
    isLoading = true;
    hasSaved = false;

    @api set recordId(value) {
        this._recordId = value;
        if (this._recordId) {
            this.getDeliveriesFromSAP();
        }
    }
    
    get recordId() {
        return this._recordId;
    }

    get isSaveDisabled() {
        return this.deliveryData.length === 0 || this.hasSaved;
    }

    get hasData() {
        return this.deliveryData.length > 0;
    }

    // NEW: Calculate total records for the UI Badge
    get totalRecordsCount() {
        return this.deliveryData ? this.deliveryData.length : 0;
    }

    getDeliveriesFromSAP() {
        this.isLoading = true;
        fetchDeliveryData({ orderId: this._recordId })
            .then((result) => {
                this.deliveryData = result;
                this.isLoading = false;
            })
            .catch((error) => {
                this.isLoading = false;
                this.showToast('Error fetching data', error.body.message, 'error');
            });
    }

    handleSave() {
        this.isLoading = true;
        const jsonString = JSON.stringify(this.deliveryData);

        saveDeliveryRecords({ orderId: this._recordId, deliveryDataJson: jsonString })
            .then((saveResult) => {
                this.isLoading = false;
                this.hasSaved = true; 
                
                // NEW: Dynamic Toast Message using data returned from Apex
                const toastMessage = `Saved ${saveResult.addedCount} new records. Skipped ${saveResult.skippedCount} duplicates.`;
                this.showToast('Save Complete', toastMessage, 'success');
                
                this.handleClose(); // Auto-close upon success
            })
            .catch((error) => {
                this.isLoading = false;
                this.showToast('Error saving records', error.body.message, 'error');
            });
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}