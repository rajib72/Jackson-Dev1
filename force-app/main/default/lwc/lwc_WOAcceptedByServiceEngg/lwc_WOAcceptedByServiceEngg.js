import { LightningElement, api, wire } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import ID_FIELD from '@salesforce/schema/WorkOrder.Id';
import ACCEPTED_FIELD from '@salesforce/schema/WorkOrder.Accepted_By_Service_Engineer__c';

const FIELDS = [ACCEPTED_FIELD];

export default class WorkOrderAcceptServiceEngineer extends LightningElement {
    @api recordId;

    acceptedValue = false;
    isSaving = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredWorkOrder({ error, data }) {
        if (data) {
            this.acceptedValue = data.fields.Accepted_By_Service_Engineer__c.value || false;
        } else if (error) {
            this.showToast('Error', 'Unable to load Work Order record.', 'error');
        }
    }

    handleCheckboxChange(event) {
        this.acceptedValue = event.target.checked;
    }

    async handleSave() {
        this.isSaving = true;

        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[ACCEPTED_FIELD.fieldApiName] = this.acceptedValue;

        const recordInput = { fields };

        try {
            await updateRecord(recordInput);

            this.showToast(
                'Success',
                'Accepted By Service Engineer has been updated successfully.',
                'success'
            );

            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            let message = 'Something went wrong while updating the Work Order.';
            if (error?.body?.message) {
                message = error.body.message;
            }
            this.showToast('Error', message, 'error');
        } finally {
            this.isSaving = false;
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
}