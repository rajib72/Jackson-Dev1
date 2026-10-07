import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import CUSTOMER_ACCOUNT_GROUP_FIELD from '@salesforce/schema/Account.Customer_Account_Group__c';

import getInitialDetails from '@salesforce/apex/Ctrl_createSalesOrderFromQuote.getInitialDetails';
import createOrder from '@salesforce/apex/Ctrl_createSalesOrderFromQuote.createOrder';

const COLUMNS = [
    { label: 'Material Code', fieldName: 'Material_Code__c', type: 'text' },
    { label: 'Plant Code', fieldName: 'Plant_Code__c', type: 'text' },
    { label: 'Remaining Quantity', fieldName: 'Nos__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Order Quantity', fieldName: 'quantityOrdered', type: 'number', editable: true, cellAttributes: { alignment: 'left' } },
    { label: 'Product Warranty', fieldName: 'Product_Warranty__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Performance Warranty', fieldName: 'Performance_Warranty__c', type: 'number', cellAttributes: { alignment: 'left' } }
];

export default class Lwc_createSalesOrderFromQuote extends NavigationMixin(LightningElement) {
    _recordId;
    _hasLoadedInitialDetails = false;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;

        if (value && !this._hasLoadedInitialDetails) {
            this._hasLoadedInitialDetails = true;
            this.loadInitialDetails();
        }
    }

    @track isLoading = false;
    currentStep = 1;
    columns = COLUMNS;

    activeSectionsStep1 = ['Section1', 'Section2'];
    activeSectionsStep2 = ['Section3', 'Section4'];

    @track hasValidationErrors = false;
    @track initialErrors = [];
    @track draftValues = [];
    @track selectedRowIds = [];

    @track quoteData = {};
    @track quoteLineItems = [];

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

    bgOptions = [
        { label: 'Y', value: 'Y' },
        { label: 'N', value: 'N' }
    ];

    tpcOptions = [
        { label: 'Y', value: 'Y' },
        { label: 'N', value: 'N' }
    ];

    ldOptions = [
        { label: 'Y', value: 'Y' },
        { label: 'N', value: 'N' }
    ];

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$accountObjectInfo.data.defaultRecordTypeId',
        fieldApiName: CUSTOMER_ACCOUNT_GROUP_FIELD
    })
    wiredOrderTypeOptions({ error, data }) {
        if (data) {
            this.orderTypeOptions = data.values;
        } else if (error) {
            this.showToast(
                'Error fetching Order Type options',
                error.body?.message || error.message,
                'error'
            );
        }
    }

    loadInitialDetails() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;
        this.hasValidationErrors = false;
        this.initialErrors = [];

        getInitialDetails({ quoteId: this.recordId })
            .then((data) => {
                const quote = data.quoteRecord;
                let errors = [];

                if (!quote.Account?.Sales_Org__c) {
                    errors.push('Sales Org: Please fill this in the Account level first.');
                }

                if (!quote.Account?.Division__c) {
                    errors.push('Division: Please fill this in the Account level first.');
                }

                if (!quote.Account?.Distribution_Channel__c) {
                    errors.push('Distribution Channel: Please fill this in the Account level first.');
                }

                data.quoteLineItems.forEach((item) => {
                    let lineNum = item.LineNumber || 'Unknown';

                    if (!item.Material_Master__c) {
                        errors.push(`Line ${lineNum}: Please tag Material Master in the Quote Line Item level.`);
                    }

                    if (item.Performance_Warranty__c == null || item.Performance_Warranty__c === '') {
                        errors.push(`Line ${lineNum}: Please fill Performance Warranty in the Quote Line Item level.`);
                    }

                    if (item.Product_Warranty__c == null || item.Product_Warranty__c === '') {
                        errors.push(`Line ${lineNum}: Please fill Product Warranty in the Quote Line Item level.`);
                    }
                });

                if (errors.length > 0) {
                    this.initialErrors = errors;
                    this.hasValidationErrors = true;
                    this.isLoading = false;
                    return;
                }

                this.quoteLineItems = data.quoteLineItems.map(item => {
                    const remainingQty = item.Nos__c !== null && item.Nos__c !== undefined
                        ? Number(item.Nos__c)
                        : 0;

                    return {
                        ...item,
                        Nos__c: remainingQty,
                        quantityOrdered: remainingQty
                    };
                });

                this.quoteData = {
                    ...quote,
                    AccountName: quote.Account?.Name,
                    OpportunityName: quote.Opportunity?.Name,
                    ContactName: quote.Contact?.Name,
                    DistributionChannel: quote.Account?.Distribution_Channel__c,
                    SalesOrg: quote.Account?.Sales_Org__c,
                    Division: quote.Account?.Division__c,
                    BillToPartyName: quote.Bill_To_Party__r?.Name,
                    BillToPartyCode: quote.Bill_To_Party__r?.SAP_Account_Number__c,
                    ShipToPartyName: quote.Ship_To_Party__r?.Name,
                    ShipToPartyCode: quote.Ship_To_Party__r?.SAP_Account_Number__c
                };

                this.formData.orderType = quote.Account?.Customer_Account_Group__c;
                this.isLoading = false;
            })
            .catch((error) => {
                this.isLoading = false;

                this.showToast(
                    'Error fetching quote details',
                    error.body?.message || error.message,
                    'error'
                );
            });
    }

    get isStep1() {
        return this.currentStep === 1;
    }

    get isStep2() {
        return this.currentStep === 2;
    }

    get isStep3() {
        return this.currentStep === 3;
    }

    get showPrevious() {
        return this.currentStep > 1;
    }

    get showNext() {
        return this.currentStep < 3;
    }

    get showFinish() {
        return this.currentStep === 3;
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

    handleNext() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (!allValid) {
            this.showToast(
                'Error',
                'Please complete all required fields on this page before proceeding.',
                'error'
            );
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
            this.showToast('Error', 'Please select at least one Quote Line Item to process.', 'error');
            return;
        }

        let orderedQuantities = {};
        let hasZeroQuantity = false;
        let hasExceedingQuantity = false;
        let errorLineNumber = '';

        const selectedItems = this.quoteLineItems.filter(qli => this.selectedRowIds.includes(qli.Id));

        for (let qli of selectedItems) {
            const draft = this.draftValues.find(d => d.Id === qli.Id);
            let finalQty = draft && draft.quantityOrdered !== undefined
                ? draft.quantityOrdered
                : qli.quantityOrdered;

            let parsedQty = parseFloat(finalQty) || 0;
            let maxQty = parseFloat(qli.Nos__c) || 0;

            if (parsedQty <= 0) {
                hasZeroQuantity = true;
                errorLineNumber = qli.LineNumber || 'Unknown';
                break;
            }

            if (parsedQty > maxQty) {
                hasExceedingQuantity = true;
                errorLineNumber = qli.LineNumber || 'Unknown';
                break;
            }

            orderedQuantities[qli.Id] = parsedQty;
        }

        if (hasZeroQuantity) {
            this.showToast(
                'Error',
                `Quantity Ordered must be greater than 0. Check Line ${errorLineNumber}.`,
                'error'
            );
            return;
        }

        if (hasExceedingQuantity) {
            this.showToast(
                'Error',
                `Quantity Ordered cannot exceed the remaining Quantity. Check Line ${errorLineNumber}.`,
                'error'
            );
            return;
        }

        this.isLoading = true;

        createOrder({
            quoteId: this.recordId,
            formData: this.formData,
            orderedQuantities: orderedQuantities
        })
            .then((orderId) => {
                this.isLoading = false;

                this.showToast(
                    'Success',
                    'Order created successfully!',
                    'success'
                );

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: orderId,
                        objectApiName: 'Order',
                        actionName: 'view'
                    }
                });
            })
            .catch((error) => {
                this.isLoading = false;

                let errorMsg = error.body ? error.body.message : error.message;

                this.showToast(
                    'Error creating Order',
                    errorMsg,
                    'error'
                );
            });
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

// import { LightningElement, api, wire, track } from 'lwc';
// import { NavigationMixin } from 'lightning/navigation';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
// import ACCOUNT_OBJECT from '@salesforce/schema/Account';
// import CUSTOMER_ACCOUNT_GROUP_FIELD from '@salesforce/schema/Account.Customer_Account_Group__c';
// import getInitialDetails from '@salesforce/apex/Ctrl_createSalesOrderFromQuote.getInitialDetails';
// import createOrder from '@salesforce/apex/Ctrl_createSalesOrderFromQuote.createOrder';

// const COLUMNS = [
//     { label: 'Material Code', fieldName: 'Material_Code__c', type: 'text' },
//     { label: 'Plant Code', fieldName: 'Plant_Code__c', type: 'text' },
//     { label: 'Remaining Quantity', fieldName: 'Nos__c', type: 'number', cellAttributes: { alignment: 'left' } },
//     { label: 'Order Quantity', fieldName: 'quantityOrdered', type: 'number', editable: true, cellAttributes: { alignment: 'left' } },
//     { label: 'Product Warranty', fieldName: 'Product_Warranty__c', type: 'number', cellAttributes: { alignment: 'left' } },
//     { label: 'Performance Warranty', fieldName: 'Performance_Warranty__c', type: 'number', cellAttributes: { alignment: 'left' } }
// ];

// export default class Lwc_createSalesOrderFromQuote extends NavigationMixin(LightningElement) {
//     @api recordId;

//     @track isLoading = false;
//     currentStep = 1;
//     columns = COLUMNS;

//     activeSectionsStep1 = ['Section1', 'Section2'];
//     activeSectionsStep2 = ['Section3', 'Section4'];

//     @track hasValidationErrors = false;
//     @track initialErrors = [];
//     @track draftValues = [];
//     @track selectedRowIds = [];

//     @track quoteData = {};
//     @track quoteLineItems = [];

//     @track formData = {
//         orderType: '',
//         poNo: '',
//         bgRequired: '',
//         tpc: '',
//         poDate: new Date().toISOString().split('T')[0],
//         ldClause: '',
//         freightTerms: '',
//         scopeOfOA: '',
//         insuranceTerms: ''
//     };

//     @track orderTypeOptions = [];

//     bgOptions = [{ label: 'Y', value: 'Y' }, { label: 'N', value: 'N' }];
//     tpcOptions = [{ label: 'Y', value: 'Y' }, { label: 'N', value: 'N' }];
//     ldOptions = [{ label: 'Y', value: 'Y' }, { label: 'N', value: 'N' }];

//     @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
//     accountObjectInfo;

//     @wire(getPicklistValues, {
//         recordTypeId: '$accountObjectInfo.data.defaultRecordTypeId',
//         fieldApiName: CUSTOMER_ACCOUNT_GROUP_FIELD
//     })
//     wiredOrderTypeOptions({ error, data }) {
//         if (data) {
//             this.orderTypeOptions = data.values;
//         } else if (error) {
//             this.showToast('Error fetching Order Type options', error.body?.message || error.message, 'error');
//         }
//     }

//     @wire(getInitialDetails, { quoteId: '$recordId' })
//     wiredData({ error, data }) {
//         if (data) {
//             const quote = data.quoteRecord;
//             let errors = [];

//             if (!quote.Account?.Sales_Org__c) errors.push('Sales Org: Please fill this in the Account level first.');
//             if (!quote.Account?.Division__c) errors.push('Division: Please fill this in the Account level first.');
//             if (!quote.Account?.Distribution_Channel__c) errors.push('Distribution Channel: Please fill this in the Account level first.');

//             data.quoteLineItems.forEach((item) => {
//                 let lineNum = item.LineNumber || 'Unknown';
//                 if (!item.Material_Master__c) errors.push(`Line ${lineNum}: Please tag Material Master in the Quote Line Item level.`);
//                 if (item.Performance_Warranty__c == null || item.Performance_Warranty__c === '') errors.push(`Line ${lineNum}: Please fill Performance Warranty in the Quote Line Item level.`);
//                 if (item.Product_Warranty__c == null || item.Product_Warranty__c === '') errors.push(`Line ${lineNum}: Please fill Product Warranty in the Quote Line Item level.`);
//             });

//             if (errors.length > 0) {
//                 this.initialErrors = errors;
//                 this.hasValidationErrors = true;
//                 return;
//             }

//             this.quoteLineItems = data.quoteLineItems.map(item => {
//                 return {
//                     ...item,
//                     Nos__c: item.Nos__c || 0,
//                     quantityOrdered: item.Nos__c || 0
//                 };
//             });

//             this.quoteData = {
//                 ...quote,
//                 AccountName: quote.Account?.Name,
//                 OpportunityName: quote.Opportunity?.Name,
//                 ContactName: quote.Contact?.Name,
//                 DistributionChannel: quote.Account?.Distribution_Channel__c,
//                 SalesOrg: quote.Account?.Sales_Org__c,
//                 Division: quote.Account?.Division__c,
//                 BillToPartyName: quote.Bill_To_Party__r?.Name,
//                 BillToPartyCode: quote.Bill_To_Party__r?.SAP_Account_Number__c,
//                 ShipToPartyName: quote.Ship_To_Party__r?.Name,
//                 ShipToPartyCode: quote.Ship_To_Party__r?.SAP_Account_Number__c
//             };

//             this.formData.orderType = quote.Account?.Customer_Account_Group__c;

//         } else if (error) {
//             this.showToast('Error fetching quote details', error.body?.message || error.message, 'error');
//         }
//     }

//     get isStep1() { return this.currentStep === 1; }
//     get isStep2() { return this.currentStep === 2; }
//     get isStep3() { return this.currentStep === 3; }

//     get showPrevious() { return this.currentStep > 1; }
//     get showNext() { return this.currentStep < 3; }
//     get showFinish() { return this.currentStep === 3; }

//     handleChange(event) {
//         const field = event.target.dataset.field;
//         this.formData[field] = event.detail.value;
//     }

//     handleCellChange(event) {
//         this.draftValues = event.detail.draftValues;
//     }

//     handleRowSelection(event) {
//         const selectedRows = event.detail.selectedRows;
//         this.selectedRowIds = selectedRows.map(row => row.Id);
//     }

//     handleNext() {
//         const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
//             .reduce((validSoFar, inputCmp) => {
//                 inputCmp.reportValidity();
//                 return validSoFar && inputCmp.checkValidity();
//             }, true);

//         if (!allValid) {
//             this.showToast('Error', 'Please complete all required fields on this page before proceeding.', 'error');
//             return;
//         }

//         this.currentStep++;
//     }

//     handlePrevious() {
//         this.currentStep--;
//     }

//     handleFinish() {
//         const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
//             .reduce((validSoFar, inputCmp) => {
//                 inputCmp.reportValidity();
//                 return validSoFar && inputCmp.checkValidity();
//             }, true);

//         if (!allValid) {
//             this.showToast('Error', 'Please complete all required fields.', 'error');
//             return;
//         }

//         if (this.selectedRowIds.length === 0) {
//             this.showToast('Error', 'Please select at least one Quote Line Item to process.', 'error');
//             return;
//         }

//         let orderedQuantities = {};
//         let hasZeroQuantity = false;
//         let hasExceedingQuantity = false;
//         let errorLineNumber = '';

//         const selectedItems = this.quoteLineItems.filter(qli => this.selectedRowIds.includes(qli.Id));

//         for (let qli of selectedItems) {
//             const draft = this.draftValues.find(d => d.Id === qli.Id);
//             let finalQty = draft && draft.quantityOrdered !== undefined ? draft.quantityOrdered : qli.quantityOrdered;

//             let parsedQty = parseFloat(finalQty) || 0;
//             let maxQty = parseFloat(qli.Nos__c) || 0;

//             if (parsedQty <= 0) {
//                 hasZeroQuantity = true;
//                 errorLineNumber = qli.LineNumber || 'Unknown';
//                 break;
//             }

//             if (parsedQty > maxQty) {
//                 hasExceedingQuantity = true;
//                 errorLineNumber = qli.LineNumber || 'Unknown';
//                 break;
//             }

//             orderedQuantities[qli.Id] = parsedQty;
//         }

//         if (hasZeroQuantity) {
//             this.showToast('Error', `Quantity Ordered must be greater than 0. Check Line ${errorLineNumber}.`, 'error');
//             return;
//         }

//         if (hasExceedingQuantity) {
//             this.showToast('Error', `Quantity Ordered cannot exceed the remaining Quantity. Check Line ${errorLineNumber}.`, 'error');
//             return;
//         }

//         this.isLoading = true;

//         createOrder({
//             quoteId: this.recordId,
//             formData: this.formData,
//             orderedQuantities: orderedQuantities
//         })
//             .then((orderId) => {
//                 this.isLoading = false;
//                 this.showToast('Success', 'Order created successfully!', 'success');

//                 this[NavigationMixin.Navigate]({
//                     type: 'standard__recordPage',
//                     attributes: {
//                         recordId: orderId,
//                         objectApiName: 'Order',
//                         actionName: 'view'
//                     }
//                 });
//             })
//             .catch((error) => {
//                 this.isLoading = false;
//                 let errorMsg = error.body ? error.body.message : error.message;
//                 this.showToast('Error creating Order', errorMsg, 'error');
//             });
//     }

//     showToast(title, message, variant) {
//         this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
//     }
// }