import { LightningElement, api } from 'lwc';

import { ShowToastEvent }
    from 'lightning/platformShowToastEvent';

import { CloseActionScreenEvent }
    from 'lightning/actions';

import { RefreshEvent }
    from 'lightning/refresh';

export default class CaseUnproductiveAction extends LightningElement {

    @api recordId;

    isSaving = false;

    // Cancel
    handleCancel() {

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );

    }

    // Submit
    handleSubmit(event) {

        event.preventDefault();

        if (this.isSaving) {
            return;
        }

        const fields = event.detail.fields;

        const unproductiveReason =
            fields.Unproductive_Reason__c;

        const unproductiveRemark =
            (fields.Unproductive_Remark__c || '').trim();

        // Mandatory field validation
        if (
            !unproductiveReason ||
            !unproductiveRemark
        ) {

            this.showToast(
                'Required Fields',
                'Please complete Unproductive Reason and Unproductive Remark.',
                'error'
            );

            return;
        }

        if (!this.recordId) {

            this.showToast(
                'Error',
                'Case record ID is not available.',
                'error'
            );

            return;
        }

        // Save trimmed remarks
        fields.Unproductive_Remark__c =
            unproductiveRemark;

        // Update Case Status
        fields.SRT_Case_Status__c =
            'Rejected';

        // Mark Unproductive checkbox TRUE
        fields.Unproductive__c =
            true;

        this.isSaving = true;

        this.template.querySelector(
            'lightning-record-edit-form'
        ).submit(fields);

    }

    // Success
    handleSuccess() {

        this.isSaving = false;

        this.showToast(
            'Success',
            'Case has been marked as Unproductive successfully.',
            'success'
        );

        this.dispatchEvent(
            new RefreshEvent()
        );

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );

    }

    // Error
    handleError(event) {

        this.isSaving = false;

        const message =
            event.detail?.output?.errors?.[0]?.message ||
            event.detail?.message ||
            'Unable to mark the Case as Unproductive.';

        this.showToast(
            'Error',
            message,
            'error'
        );

    }

    // Toast
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