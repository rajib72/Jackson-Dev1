import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import CUSTOMER_ACCOUNT_GROUP_FIELD from '@salesforce/schema/Account.Customer_Account_Group__c';
import getInitialDetails from '@salesforce/apex/Ctrl_CreateSalesOrderFromOpp.getInitialDetails';
import getQuoteDetails from '@salesforce/apex/Ctrl_CreateSalesOrderFromOpp.getQuoteDetails';
import createOrderFromQuote from '@salesforce/apex/Ctrl_CreateSalesOrderFromOpp.createOrderFromQuote';
import createOrderFromOpp from '@salesforce/apex/Ctrl_CreateSalesOrderFromOpp.createOrderFromOpp';

const COLUMNS = [
    { label: 'Material Code', fieldName: 'Material_Code__c', type: 'text' },
    { label: 'Plant Code', fieldName: 'Plant_Code__c', type: 'text' },
    { label: 'Remaining Quantity', fieldName: 'Quantity', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Order Quantity', fieldName: 'quantityOrdered', type: 'number', editable: true, cellAttributes: { alignment: 'left' } },
    { label: 'Product Warranty', fieldName: 'Product_Warranty__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Performance Warranty', fieldName: 'Performance_Warranty__c', type: 'number', cellAttributes: { alignment: 'left' } }
];

export default class Lwc_CreateSalesOrderFromOpp extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isLoading = true;
    currentStep = 0; 
    columns = COLUMNS;

    activeSectionsStep1 = ['Section1', 'Section2'];
    activeSectionsStep2 = ['Section3', 'Section4'];

    @track hasValidationErrors = false;
    @track initialErrors = [];
    @track draftValues = [];
    @track selectedRowIds = [];

    @track hasQuotes = false;
    @track quoteOptions = [];
    selectedQuoteId = '';
    sourceMode = ''; 

    rawOppData = {};
    rawOppLineItems = [];
    @track wizardData = {};
    @track wizardLineItems = [];

    @track formData = {
        orderType: '',
        poNo: '',
        bgRequired: '',
        tpc: '',
        poDate: new Date().toISOString().split('T')[0],
        ldClause: '',
        freightTerms: '',
        scopeOfOA: '',
        insuranceTerms: ''
    };

    @track orderTypeOptions = [];

    bgOptions = [{ label: 'Y', value: 'Y' }, { label: 'N', value: 'N' }];
    tpcOptions = [{ label: 'Y', value: 'Y' }, { label: 'N', value: 'N' }];
    ldOptions = [{ label: 'Y', value: 'Y' }, { label: 'N', value: 'N' }];

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$accountObjectInfo.data.defaultRecordTypeId',
        fieldApiName: CUSTOMER_ACCOUNT_GROUP_FIELD
    })
    wiredOrderTypeOptions({ error, data }) {
        if (data) {
            this.orderTypeOptions = data.values;
        }
    }

    @wire(getInitialDetails, { oppId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.rawOppData = data.oppRecord;
            this.rawOppLineItems = data.oppLineItems;

            if (data.acceptedQuotes && data.acceptedQuotes.length > 0) {
                this.hasQuotes = true;
                this.quoteOptions = data.acceptedQuotes.map(q => ({
                    label: `${q.QuoteNumber} - ${q.Name}`,
                    value: q.Id
                }));
            } else {
                this.hasQuotes = false;
            }
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            this.showToast('Error', error.body?.message || error.message, 'error');
        }
    }

    get isStep0() { return this.currentStep === 0; }
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }

    get showPrevious() { return this.currentStep > 1; }
    get showNext() { return this.currentStep >= 1 && this.currentStep < 3; }
    get showFinish() { return this.currentStep === 3; }

    handleQuoteSelection(event) {
        this.selectedQuoteId = event.detail.value;
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.detail.value;
    }

    handleCellChange(event) {
        this.draftValues = event.detail.draftValues;
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedRowIds = selectedRows.map(row => row.Id);
    }

    handleProceedFromStep0() {
        this.isLoading = true;
        this.initialErrors = [];
        this.hasValidationErrors = false;

        if (this.hasQuotes) {
            if (!this.selectedQuoteId) {
                this.isLoading = false;
                this.showToast('Error', 'You must select a Quote to proceed.', 'error');
                return;
            }
            this.sourceMode = 'Quote';
            getQuoteDetails({ quoteId: this.selectedQuoteId })
                .then(data => {
                    this.processDataPayload(data.quoteRecord, data.quoteLineItems, 'Quote');
                })
                .catch(error => {
                    this.isLoading = false;
                    this.showToast('Error', error.body?.message || error.message, 'error');
                });
        } else {
            this.sourceMode = 'Opportunity';
            this.processDataPayload(this.rawOppData, this.rawOppLineItems, 'Opportunity');
        }
    }

    processDataPayload(record, lineItems, mode) {
        let errors = [];

        if (!record.Account?.Sales_Org__c) errors.push('Sales Org: Please fill this in the Account level first.');
        if (!record.Account?.Division__c) errors.push('Division: Please fill this in the Account level first.');
        if (!record.Account?.Distribution_Channel__c) errors.push('Distribution Channel: Please fill this in the Account level first.');

        lineItems.forEach((item) => {
            let identifier = item.LineNumber ? `Line ${item.LineNumber}` : `an Item`;
            
            if (!item.Material_Master__c) errors.push(`${identifier}: Please tag Material Master.`);
            if (!item.Plant_Code__c) errors.push(`${identifier}: Please fill Plant Code.`);
            
            if (item.Performance_Warranty__c == null || item.Performance_Warranty__c === '') errors.push(`${identifier}: Please fill Performance Warranty.`);
            if (item.Product_Warranty__c == null || item.Product_Warranty__c === '') errors.push(`${identifier}: Please fill Product Warranty.`);
        });

        if (errors.length > 0) {
            this.initialErrors = errors;
            this.hasValidationErrors = true;
            this.isLoading = false;
            this.currentStep = 1;
            return;
        }

        this.wizardLineItems = lineItems.map(item => {
            return {
                ...item,
                Quantity: item.Quantity_Remained__c || item.Quantity || 0,
                quantityOrdered: item.Quantity_Remained__c || item.Quantity || 0
            };
        });

        this.wizardData = {
            ...record,
            AccountName: record.Account?.Name,
            OpportunityName: mode === 'Quote' ? record.Opportunity?.Name : record.Name,
            ContactName: mode === 'Quote' ? record.Contact?.Name : record.Contact__r?.Name,
            DistributionChannel: record.Account?.Distribution_Channel__c,
            SalesOrg: record.Account?.Sales_Org__c,
            Division: record.Account?.Division__c,
            
            // --- UI MAPPING FOR BILL TO & SHIP TO ---
            BillToPartyName: mode === 'Quote' ? record.Bill_To_Party__r?.Name : record.Account?.Name,
            BillToPartyCode: mode === 'Quote' ? record.Bill_To_Party__r?.SAP_Account_Number__c : record.Account?.SAP_Account_Number__c,
            ShipToPartyName: mode === 'Quote' ? record.Ship_To_Party__r?.Name : record.Account?.Name,
            ShipToPartyCode: mode === 'Quote' ? record.Ship_To_Party__r?.SAP_Account_Number__c : record.Account?.SAP_Account_Number__c,

            // --- UI MAPPING FOR ADDRESSES ---
            BillingStreet: mode === 'Quote' ? record.BillingStreet : record.Account?.BillingStreet,
            BillingCity: mode === 'Quote' ? record.BillingCity : record.Account?.BillingCity,
            BillingState: mode === 'Quote' ? record.BillingState : record.Account?.BillingState,
            BillingPostalCode: mode === 'Quote' ? record.BillingPostalCode : record.Account?.BillingPostalCode,
            BillingCountry: mode === 'Quote' ? record.BillingCountry : record.Account?.BillingCountry,

            ShippingStreet: mode === 'Quote' ? record.ShippingStreet : record.Account?.ShippingStreet,
            ShippingCity: mode === 'Quote' ? record.ShippingCity : record.Account?.ShippingCity,
            ShippingState: mode === 'Quote' ? record.ShippingState : record.Account?.ShippingState,
            ShippingPostalCode: mode === 'Quote' ? record.ShippingPostalCode : record.Account?.ShippingPostalCode,
            ShippingCountry: mode === 'Quote' ? record.ShippingCountry : record.Account?.ShippingCountry
        };

        this.formData.orderType = record.Account?.Customer_Account_Group__c;

        this.isLoading = false;
        this.currentStep = 1;
    }

    handleNext() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (!allValid) {
            this.showToast('Error', 'Please complete all required fields on this page before proceeding.', 'error');
            return;
        }
        this.currentStep++;
    }

    handlePrevious() {
        this.currentStep--;
    }

    handleFinish() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (!allValid) {
            this.showToast('Error', 'Please complete all required fields.', 'error');
            return;
        }

        if (this.selectedRowIds.length === 0) {
            this.showToast('Error', 'Please select at least one Line Item to process.', 'error');
            return;
        }

        let orderedQuantities = {};
        let hasZeroQuantity = false;
        let hasExceedingQuantity = false;
        let errorLineNumber = '';

        const selectedItems = this.wizardLineItems.filter(item => this.selectedRowIds.includes(item.Id));

        for (let item of selectedItems) {
            const draft = this.draftValues.find(d => d.Id === item.Id);
            let finalQty = draft && draft.quantityOrdered !== undefined ? draft.quantityOrdered : item.quantityOrdered;

            let parsedQty = parseFloat(finalQty) || 0;
            let maxQty = parseFloat(item.Quantity) || 0;

            if (parsedQty <= 0) {
                hasZeroQuantity = true;
                errorLineNumber = item.LineNumber || 'Unknown';
                break;
            }

            if (parsedQty > maxQty) {
                hasExceedingQuantity = true;
                errorLineNumber = item.LineNumber || 'Unknown';
                break;
            }
            orderedQuantities[item.Id] = parsedQty;
        }

        if (hasZeroQuantity) {
            this.showToast('Error', `Quantity Ordered must be greater than 0. Check ${errorLineNumber ? 'Line ' + errorLineNumber : 'the selected item(s)'}.`, 'error');
            return;
        }

        if (hasExceedingQuantity) {
            this.showToast('Error', `Quantity Ordered cannot exceed the remaining Quantity. Check ${errorLineNumber ? 'Line ' + errorLineNumber : 'the selected item(s)'}.`, 'error');
            return;
        }

        this.isLoading = true;

        if (this.sourceMode === 'Quote') {
            createOrderFromQuote({
                quoteId: this.selectedQuoteId,
                formData: this.formData,
                orderedQuantities: orderedQuantities
            })
            .then(this.handleSuccessResponse.bind(this))
            .catch(this.handleErrorResponse.bind(this));
        } else {
            createOrderFromOpp({
                oppId: this.recordId,
                formData: this.formData,
                orderedQuantities: orderedQuantities
            })
            .then(this.handleSuccessResponse.bind(this))
            .catch(this.handleErrorResponse.bind(this));
        }
    }

    handleSuccessResponse(orderId) {
        this.isLoading = false;
        this.showToast('Success', 'Order created successfully!', 'success');

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: orderId,
                objectApiName: 'Order',
                actionName: 'view'
            }
        });
    }

    handleErrorResponse(error) {
        this.isLoading = false;
        let errorMsg = error.body ? error.body.message : error.message;
        this.showToast('Error creating Order', errorMsg, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}