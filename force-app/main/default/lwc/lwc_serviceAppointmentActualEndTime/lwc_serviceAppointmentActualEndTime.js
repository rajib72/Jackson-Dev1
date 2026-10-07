import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';

import ID_FIELD from '@salesforce/schema/ServiceAppointment.Id';
import ACTUAL_END_TIME_FIELD from '@salesforce/schema/ServiceAppointment.ActualEndTime';

export default class ServiceAppointmentActualEndTime extends LightningElement {
    @api recordId;
    isSaving = false;
    currentDateTime;

    connectedCallback() {
        this.setCurrentDateTime();
    }

    setCurrentDateTime() {
        const now = new Date();

        // For display in lightning-input type="datetime"
        const pad = (n) => String(n).padStart(2, '0');

        const year = now.getFullYear();
        const month = pad(now.getMonth() + 1);
        const day = pad(now.getDate());
        const hours = pad(now.getHours());
        const minutes = pad(now.getMinutes());

        this.currentDateTime = `${year}-${month}-${day}T${hours}:${minutes}`;
    }

    async handleUpdate() {
        this.isSaving = true;

        try {
            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.recordId;
            fields[ACTUAL_END_TIME_FIELD.fieldApiName] = new Date().toISOString();

            await updateRecord({ fields });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Actual End Date/Time updated successfully.',
                    variant: 'success'
                })
            );

            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            let message = 'An error occurred while updating the record.';
            if (error?.body?.message) {
                message = error.body.message;
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message,
                    variant: 'error'
                })
            );
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}