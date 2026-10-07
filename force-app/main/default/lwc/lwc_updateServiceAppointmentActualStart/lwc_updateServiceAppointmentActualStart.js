import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { updateRecord } from 'lightning/uiRecordApi';

import ID_FIELD from '@salesforce/schema/ServiceAppointment.Id';
import ACTUAL_START_TIME_FIELD from '@salesforce/schema/ServiceAppointment.ActualStartTime';

export default class UpdateServiceAppointmentActualStart extends LightningElement {
    @api recordId;
    @track currentDateTime;
    @track isLoading = false;

    connectedCallback() {
        // This generates the full, valid ISO 8601 string Salesforce requires
        this.currentDateTime = new Date().toISOString(); 
    }

    handleUpdate() {
        this.isLoading = true;

        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[ACTUAL_START_TIME_FIELD.fieldApiName] = this.currentDateTime;

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Actual Start Date/Time updated successfully.',
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                let message = 'Something went wrong while updating the record.';
                if (error?.body?.message) {
                    message = error.body.message;
                }

                console.log('DEBUG:: error - ' + JSON.stringify(error));

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}