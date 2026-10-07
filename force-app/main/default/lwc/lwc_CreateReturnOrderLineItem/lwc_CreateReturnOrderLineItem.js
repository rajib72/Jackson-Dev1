import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { NavigationMixin } from 'lightning/navigation'; // Imported NavigationMixin

import getInitialData from '@salesforce/apex/Ctrl_CreateReturnOrderLineItem.getInitialData';
import saveLineItems from '@salesforce/apex/Ctrl_CreateReturnOrderLineItem.saveLineItems';

// Schema Imports
import ROLI_OBJECT from '@salesforce/schema/ReturnOrderLineItem';
import PROCESSING_PLAN_FIELD from '@salesforce/schema/ReturnOrderLineItem.ProcessingPlan';
import REPAYMENT_METHOD_FIELD from '@salesforce/schema/ReturnOrderLineItem.RepaymentMethod';
import UOM_FIELD from '@salesforce/schema/ReturnOrderLineItem.QuantityUnitOfMeasure';

// Extended with NavigationMixin
export default class Lwc_CreateReturnOrderLineItem extends NavigationMixin(LightningElement) {
    @api recordId; // ReturnOrderId
    @track rows = [];

    initialData = null;
    prliOptions = [];
    assetOptions = [];

    // 1. Fetch Picklist Details
    @wire(getObjectInfo, { objectApiName: ROLI_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: PROCESSING_PLAN_FIELD })
    processingPlanValues;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: REPAYMENT_METHOD_FIELD })
    repaymentMethodValues;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: UOM_FIELD })
    uomValues;

    get processingPlanOptions() { return this.processingPlanValues.data?.values || []; }
    get repaymentMethodOptions() { return this.repaymentMethodValues.data?.values || []; }
    get uomOptions() { return this.uomValues.data?.values || []; }

    // 2. Fetch Parent Context / Relationship Variables
    @wire(getInitialData, { returnOrderId: '$recordId' })
    wiredInitialData({ error, data }) {
        if (data) {
            this.initialData = data;
            this.prliOptions = data.prliOptions || [];
            this.assetOptions = data.assetOptions || [];

            if (this.rows.length === 0) {
                this.addRow();
            }
        } else if (error) {
            this.showToast('Error', 'Failed to load initial order data.', 'error');
        }
    }

    // 3. Row Management Logic
    addRow() {
        this.rows.push({
            id: Date.now() + Math.random(),
            ReturnOrderId: this.recordId,
            ProductRequestLineItemId: '',
            AssetId: '',
            ProcessingPlan: '',
            ReasonForChangeText: '',
            RepaymentMethod: '',
            QuantityReturned: null,
            QuantityUnitOfMeasure: '',
            SourceLocationId: this.initialData?.sourceLocationId,
            SourceLocationName: this.initialData?.sourceLocationName,
            DestinationLocationId: this.initialData?.destLocationId,
            DestinationLocationName: this.initialData?.destLocationName,
            Description: ''
        });
    }

    removeRow(event) {
        if (this.rows.length > 1) {
            const index = event.target.dataset.index;
            this.rows.splice(index, 1);
        } else {
            this.showToast('Warning', 'You must have at least one line item.', 'warning');
        }
    }

    handleInputChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        this.rows[index][field] = event.target.value;
    }

    // 4. Save Logic & Navigation
    handleSave() {
        // Enforce required fields validation (Quantity Returned)
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (!allValid) {
            this.showToast('Validation Error', 'Please complete all required fields.', 'error');
            return;
        }

        // Map UI tracked rows to sobjects
        const recordsToSave = this.rows.map(row => {
            return {
                sobjectType: 'ReturnOrderLineItem',
                ReturnOrderId: row.ReturnOrderId,
                ProductRequestLineItemId: row.ProductRequestLineItemId || null,
                AssetId: row.AssetId || null,
                ProcessingPlan: row.ProcessingPlan || null,
                ReasonForChangeText: row.ReasonForChangeText,
                RepaymentMethod: row.RepaymentMethod || null,
                QuantityReturned: parseFloat(row.QuantityReturned),
                QuantityUnitOfMeasure: row.QuantityUnitOfMeasure || null,
                SourceLocationId: row.SourceLocationId,
                DestinationLocationId: row.DestinationLocationId,
                Description: row.Description
            };
        });

        saveLineItems({ lineItems: recordsToSave })
            .then(() => {
                this.showToast('Success', `${recordsToSave.length} Line Item(s) successfully created.`, 'success');

                // Redirect to the ReturnOrder record page
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        objectApiName: 'ReturnOrder',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                this.showToast('Error saving records', error.body?.message || 'Unknown error occurred', 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}