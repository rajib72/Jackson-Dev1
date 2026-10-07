import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, updateRecord, getFieldValue } from 'lightning/uiRecordApi';

import REFER_FIELD from '@salesforce/schema/WorkOrder.Refer_WO_to_Service_Coordinator__c';
import ID_FIELD from '@salesforce/schema/WorkOrder.Id';

// Import necessary Work Order fields for validation
import ESTIMATION_COST_FIELD from '@salesforce/schema/WorkOrder.Final_Service_Estimation_Cost__c';
import EXECUTION_MODE_FIELD from '@salesforce/schema/WorkOrder.Execution_Mode__c';

// Add validation fields to the wire array
const FIELDS = [REFER_FIELD, ESTIMATION_COST_FIELD, EXECUTION_MODE_FIELD];

export default class ReferWorkOrderToCoordinator extends LightningElement {
    @api recordId;

    referValue = false;
    isLoading = true;
    showError = false; // Tracks UI validation

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredWorkOrder({ error, data }) {
        if (data) {
            // Get the existing refer value
            this.referValue = getFieldValue(data, REFER_FIELD) || false;

            // UI Validation Logic
            const cost = getFieldValue(data, ESTIMATION_COST_FIELD) || 0;
            const mode = getFieldValue(data, EXECUTION_MODE_FIELD);

            // Condition 1: Mode = Site Visit and Cost > 0
            const isSiteVisitWithCost = (mode === 'Site Visit' && cost > 0);
            
            // Condition 2: Mode = Remote
            const isRemote = (mode === 'Remote');
            
            // Condition 3: Mode = Site Visit and Cost = 0
            const isSiteVisitWithoutCost = (mode === 'Site Visit' && cost === 0);

            // If ANY of these 3 conditions are true, the LWC works normally.
            const showLwcNormally = isSiteVisitWithCost || isRemote || isSiteVisitWithoutCost;

            // Trigger the error message if conditions fail
            this.showError = !showLwcNormally;
            
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    handleCheckboxChange(event) {
        this.referValue = event.target.checked;
    }

    async handleSave() {
        this.isLoading = true;

        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[REFER_FIELD.fieldApiName] = this.referValue;

        const recordInput = { fields };

        try {
            await updateRecord(recordInput);

            this.showToast(
                'Success',
                'Work Order has been updated successfully.',
                'success'
            );

            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
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
        if (!error) {
            return 'Unknown error';
        }

        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }

        if (typeof error.body?.message === 'string') {
            return error.body.message;
        }

        if (typeof error.message === 'string') {
            return error.message;
        }

        return 'Something went wrong while updating the Work Order.';
    }
}