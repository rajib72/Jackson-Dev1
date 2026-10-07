import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';

import ID_FIELD from '@salesforce/schema/WorkOrder.Id';
import EXECUTION_MODE_FIELD from '@salesforce/schema/WorkOrder.Execution_Mode__c';

export default class WorkOrderExecutionMode extends LightningElement {
    @api recordId;
    @track selectedValue = '';

    executionModeOptions = [
        { label: 'Site Visit', value: 'Site Visit' },
        { label: 'Remote', value: 'Remote' }
    ];

    get isSaveDisabled() {
        return !this.selectedValue;
    }

    handleChange(event) {
        this.selectedValue = event.detail.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSave() {
        try {
            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.recordId;
            fields[EXECUTION_MODE_FIELD.fieldApiName] = this.selectedValue;

            const recordInput = { fields };
            await updateRecord(recordInput);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Execution Mode updated successfully.',
                    variant: 'success'
                })
            );

            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            let message = 'Something went wrong while updating the Work Order.';
            if (error?.body?.message) {
                message = error.body.message;
            } else if (error?.message) {
                message = error.message;
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: message,
                    variant: 'error'
                })
            );
        }
    }
}