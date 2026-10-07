import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation'; 
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';

import ORDER_OBJECT from '@salesforce/schema/Order';
import SERVICE_ORDER_TYPE_FIELD from '@salesforce/schema/Order.Service_Order_Type__c';

import getRequestDetails from '@salesforce/apex/ProductRequestActionController.getRequestDetails';
import createOrder from '@salesforce/apex/ProductRequestActionController.createOrder'; 

export default class ConvertToSalesOrder extends NavigationMixin(LightningElement) {
    @api recordId;
    
    @track hasValidationErrors = false;
    @track initialErrors = [];
    
    requestData;
    @track lineItems = [];
    error;
    isLoading = false; 
    panelTitle = 'Loading...';
    
    isPageTwo = false;

    accountName;
    contactName;
    shipToPartyName;
    shipToPartyCode;
    shippingAddress;

    @track orderTypeOptions = [];
    plantOptions = [];
    yesNoOptions = [
        { label: 'Y', value: 'Y' },
        { label: 'N', value: 'N' }
    ];

    @track formData = {
        orderType: '',
        orderReason: 'ZF1',
        salesOrg: '',
        distChannel: '',
        division: '',
        poNumber: '',
        poDate: '',
        bgRequired: '',
        ldClause: '',
        tpc: '',
        paymentTerms: '',
        deliveryPlant: '',
        freightTerms: '',
        insuranceTerms: '',
        scopeOfOA: ''
    };

    @wire(getObjectInfo, { objectApiName: ORDER_OBJECT })
    orderInfo;

    @wire(getPicklistValues, { recordTypeId: '$orderInfo.data.defaultRecordTypeId', fieldApiName: SERVICE_ORDER_TYPE_FIELD })
    wiredOrderTypes({ error, data }) {
        if (data) {
            this.orderTypeOptions = data.values;
        } else if (error) {
            console.error('Error fetching Service Order Type picklist values', error);
        }
    }

    @wire(getRequestDetails, { recordId: '$recordId' })
    wiredRequest({ error, data }) {
        if (data) {
            
            // 1. PERFORM UPFRONT VALIDATIONS
            let errors = [];
            
            if (!data.WorkOrder?.Account?.Sales_Org__c) errors.push('Sales Org: Please fill this in the account level first.');
            if (!data.WorkOrder?.Account?.Division__c) errors.push('Division: Please fill this in the account level first.');
            if (!data.WorkOrder?.Account?.Distribution_Channel__c) errors.push('Distribution Channel: Please fill this in the account level first.');
            if (!data.WorkOrder?.Account?.Payment_Terms__c) errors.push('Payment Terms: Please fill this in the account level first.');

            if (data.ProductRequestLineItems) {
                data.ProductRequestLineItems.forEach(item => {
                    let lineNum = item.ProductRequestLineItemNumber || 'Unknown';
                    if (!item.Material_Master__c) {
                        errors.push(`Line ${lineNum}: Please tag material master in the product request line item level.`);
                    }
                    if (!item.Material_Master__r?.Plant__c) {
                        errors.push(`Line ${lineNum}: Please fill the plant code in the product request line item level.`);
                    }
                });
            }

            if (errors.length > 0) {
                this.initialErrors = errors;
                this.hasValidationErrors = true;
                this.requestData = data; 
                this.panelTitle = 'Validation Errors Found';
                return; // Stop processing and lock the user out
            }

            // 2. IF VALID, PROCEED AS NORMAL
            this.requestData = data;
            this.panelTitle = 'Convert To Service Order';
            // if (data.Product_Request_Type__c === 'FOC' || data.Product_Request_Type__c === 'RGP') {
            //     this.panelTitle = 'Convert To Sales Order';
            // } else if (data.Product_Request_Type__c === 'Paid') {
            //     this.panelTitle = 'Convert To Service Order';
            // } else {
            //     this.panelTitle = 'Convert Order';
            // }

            this.accountName = data.WorkOrder?.Account?.Name || '';
            this.contactName = data.WorkOrder?.Contact?.Name || '';
            this.shipToPartyName = data.Ship_To_Party__r?.Name || '';
            this.shipToPartyCode = data.Ship_To_Party__r?.SAP_Account_Number__c || '';
            
            let addr = [];
            if (data.ShipToStreet) addr.push(data.ShipToStreet);
            if (data.ShipToCity) addr.push(data.ShipToCity);
            if (data.ShipToState) addr.push(data.ShipToState);
            if (data.ShipToPostalCode) addr.push(data.ShipToPostalCode);
            if (data.ShipToCountry) addr.push(data.ShipToCountry);
            this.shippingAddress = addr.join(', ');

            this.formData.salesOrg = data.WorkOrder?.Account?.Sales_Org__c || '';
            this.formData.distChannel = data.WorkOrder?.Account?.Distribution_Channel__c || '';
            this.formData.division = data.WorkOrder?.Account?.Division__c || '';
            this.formData.paymentTerms = data.WorkOrder?.Account?.Payment_Terms__c || '';

            let plantsSet = new Set();
            if (data.ProductRequestLineItems) {
                this.lineItems = data.ProductRequestLineItems.map(item => {
                    if (item.Material_Master__r?.Plant__c) {
                        plantsSet.add(item.Material_Master__r.Plant__c);
                    }
                    return {
                        ...item,
                        MaterialCode: item.Material_Code__c || '',
                        MaterialDescription: item.Material_Description__c || '',
                        productWarranty: null, // New field tracking
                        performanceWarranty: null // New field tracking
                    };
                });
            } else {
                this.lineItems = [];
            }

            this.plantOptions = Array.from(plantsSet).map(plant => ({ label: plant, value: plant }));
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
            this.requestData = undefined;
            this.lineItems = [];
            this.panelTitle = 'Error';
        }
    }

    // Handles updates to Warranty fields inside the table
    handleLineItemChange(event) {
        const field = event.target.dataset.field;
        const itemId = event.target.dataset.id;
        const value = event.target.value;
        
        const itemIndex = this.lineItems.findIndex(item => item.Id === itemId);
        if (itemIndex !== -1) {
            this.lineItems[itemIndex][field] = value ? parseFloat(value) : null;
        }
    }

    handleNext() {
        // Automatically validate all visible lightning-inputs on the screen (the required warranty fields)
        const allValid = [...this.template.querySelectorAll('lightning-input')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);
        
        if (!allValid) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Missing Required Fields',
                message: 'Please fill out all Warranty fields before proceeding.',
                variant: 'error'
            }));
            return;
        }
        
        this.isPageTwo = true;
    }

    handleBack() {
        this.isPageTwo = false;
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.value;
    }

    handleCreateOrder() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (!allValid) {
            this.dispatchEvent(
                new ShowToastEvent({ 
                    title: 'Incomplete Form', 
                    message: 'Please fill out all required fields before creating the order.', 
                    variant: 'warning' 
                })
            );
            return; 
        }

        this.isLoading = true; 

        let formattedData = { ...this.formData };
        if (formattedData.poDate === '') {
            formattedData.poDate = null;
        }

        // Attach the line item data to the payload
        const payload = {
            recordId: this.recordId,
            ...formattedData,
            lineItems: this.lineItems.map(item => ({
                id: item.Id,
                productWarranty: item.productWarranty,
                performanceWarranty: item.performanceWarranty
            }))
        };

        createOrder({ payloadStr: JSON.stringify(payload) })
            .then(orderId => {
                this.isLoading = false; 
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Service Order created successfully!',
                        variant: 'success'
                    })
                );

                this.dispatchEvent(new CloseActionScreenEvent());

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: orderId,
                        objectApiName: 'Order',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                this.isLoading = false; 
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error creating Order',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
            });
    }
}