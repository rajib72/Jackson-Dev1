import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import getDeliveryRecords from '@salesforce/apex/SAPBillingLWCController.getDeliveryRecords';
import fetchFromSAP from '@salesforce/apex/SAPBillingLWCController.fetchFromSAP';
import saveInvoiceDetails from '@salesforce/apex/SAPBillingLWCController.saveInvoiceDetails';

const COLUMNS = [
    { label: 'Billing Document', fieldName: 'billingDocument', sortable: true },
    { label: 'Billing Line Item No', fieldName: 'billingLineItemNo', sortable: true },
    { label: 'Billing Document Date', fieldName: 'billingDocumentDate', type: 'date-local', sortable: true },
    // Updated currency formatting
    { label: 'Billing Document Amount', fieldName: 'billingDocumentAmount', type: 'currency', typeAttributes: { currencyCode: 'INR', step: '0.01' }, sortable: true },
    { label: 'Delivery Number', fieldName: 'deliveryNumber', sortable: true },
    { label: 'Sales Order No', fieldName: 'salesOrderNo', sortable: true }
];

export default class Lwc_SAPBillingInfoButton extends LightningElement {
    @api recordId; 
    
    @track deliveryOptions = [];
    @track selectedDeliveries = [];
    @track billingData = [];
    columns = COLUMNS;
    
    isAllDeliveries = false;
    isLoading = false;
    allDeliveryNumbers = [];

    @wire(getDeliveryRecords, { orderId: '$recordId' })
    wiredDeliveries({ error, data }) {
        if (data) {
            this.deliveryOptions = data.map(record => {
                return { label: record.SAP_Delivery_No__c, value: record.SAP_Delivery_No__c };
            }).filter(opt => opt.value);

            this.allDeliveryNumbers = data.map(record => record.SAP_Delivery_No__c).filter(val => val);
        } else if (error) {
            this.showToast('Error', 'Failed to fetch Delivery records.', 'error');
        }
    }

    get showTable() {
        return this.billingData && this.billingData.length > 0;
    }

    get isFetchDisabled() {
        return !this.isAllDeliveries && this.selectedDeliveries.length === 0;
    }

    handleCheckboxChange(event) {
        this.isAllDeliveries = event.target.checked;
        if (this.isAllDeliveries) {
            this.selectedDeliveries = []; 
        }
    }

    handleDeliverySelection(event) {
        this.selectedDeliveries = event.detail.value;
    }

    fetchDetails() {
        this.isLoading = true;
        
        let deliveriesToFetch = this.isAllDeliveries ? this.allDeliveryNumbers : this.selectedDeliveries;

        if (deliveriesToFetch.length === 0) {
            this.showToast('Warning', 'No delivery numbers found to fetch.', 'warning');
            this.isLoading = false;
            return;
        }

        fetchFromSAP({ deliveryNumbers: deliveriesToFetch })
            .then((result) => {
                if(result.length === 0) {
                    this.showToast('Info', 'No billing information found for the selected deliveries.', 'info');
                    this.billingData = [];
                } else {
                    this.billingData = result;
                    this.showToast('Success', 'Billing information fetched successfully.', 'success');
                }
            })
            .catch((error) => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSave() {
        this.isLoading = true;
        const payload = JSON.stringify(this.billingData);

        saveInvoiceDetails({ orderId: this.recordId, jsonString: payload })
            .then(() => {
                this.showToast('Success', 'Billing information saved successfully.', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch((error) => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}