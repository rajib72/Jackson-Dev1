import { LightningElement, api } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_STATUS from '@salesforce/schema/Case.SRT_Case_Status__c';
import RESOLVED_REMARKS from '@salesforce/schema/Case.Resolved_Remarks__c';
import RESOLVE_CHECKBOX from '@salesforce/schema/Case.Resolve__c';
import RESOLVE_DATE from '@salesforce/schema/Case.Resolve_Date__c';

export default class CaseResolvedAction extends LightningElement {

    _recordId;
    resolvedRemarks = '';
    isSaving = false;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
    }

    handleRemarksChange(event) {
        this.resolvedRemarks = event.target.value;

        event.target.setCustomValidity('');
        event.target.reportValidity();
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSave() {

        if (this.isSaving) {
            return;
        }

        const remarksInput = this.template.querySelector(
            '[data-id="resolvedRemarks"]'
        );

        const remarks = (this.resolvedRemarks || '').trim();

        // Resolved Remarks mandatory validation
        if (!remarks) {

            remarksInput.setCustomValidity(
                'Please enter Resolved Remarks.'
            );

            remarksInput.reportValidity();

            return;
        }

        remarksInput.setCustomValidity('');

        if (!remarksInput.reportValidity()) {
            return;
        }

        if (!this._recordId) {
            this.showToast(
                'Error',
                'Case record ID is not available.',
                'error'
            );
            return;
        }

        this.isSaving = true;

        try {

            const fields = {};

            fields[CASE_ID.fieldApiName] =
                this._recordId;

            fields[RESOLVED_REMARKS.fieldApiName] =
                remarks;

            fields[CASE_STATUS.fieldApiName] =
                'Resolved';

            fields[RESOLVE_CHECKBOX.fieldApiName] =
                true;

            fields[RESOLVE_DATE.fieldApiName] =
                this.getTodayDate();

            await updateRecord({ fields });

            this.showToast(
                'Success',
                'Case status has been updated to Resolved.',
                'success'
            );

            this.dispatchEvent(new RefreshEvent());

            this.dispatchEvent(
                new CloseActionScreenEvent()
            );

        } catch (error) {

            const message =
                error?.body?.output?.errors?.[0]?.message ||
                Object.values(
                    error?.body?.output?.fieldErrors || {}
                ).flat()[0]?.message ||
                error?.body?.message ||
                error?.message ||
                'Unable to resolve the Case.';

            this.showToast(
                'Error',
                message,
                'error'
            );

        } finally {

            this.isSaving = false;

        }
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

    getTodayDate() {

        const today = new Date();

        const year = today.getFullYear();

        const month = String(
            today.getMonth() + 1
        ).padStart(2, '0');

        const day = String(
            today.getDate()
        ).padStart(2, '0');

        return `${year}-${month}-${day}`;
    }
}