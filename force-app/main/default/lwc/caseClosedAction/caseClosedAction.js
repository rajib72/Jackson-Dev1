import { LightningElement, api } from 'lwc';

import { ShowToastEvent }
    from 'lightning/platformShowToastEvent';

import { CloseActionScreenEvent }
    from 'lightning/actions';

import { RefreshEvent }
    from 'lightning/refresh';

import { NavigationMixin } from 'lightning/navigation';

export default class CaseClosedAction extends NavigationMixin(LightningElement) {

    @api recordId;

    isSaving = false;

    handleCancel() {

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );

    }

    handleSubmit(event) {

        event.preventDefault();

        if (this.isSaving) {
            return;
        }

        const fields = event.detail.fields;

        const closureRemark =
            (fields.Closure_Remark__c || '').trim();

        // Closure Remark mandatory validation
        if (!closureRemark) {

            this.showToast(
                'Required Field',
                'Please enter Closure Remark.',
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

        // Save trimmed Closure Remark
        fields.Closure_Remark__c =
            closureRemark;

        // Update Case Status
        fields.SRT_Case_Status__c =
            'Closed';

        // Mark Closed checkbox TRUE
        fields.Closed__c =
            true;

        this.isSaving = true;

        this.template.querySelector(
            'lightning-record-edit-form'
        ).submit(fields);

    }

    handleSuccess() {

        this.isSaving = false;

        this.showToast(
            'Success',
            'Case has been closed successfully.',
            'success'
        );

        // Close Quick Action
        this.dispatchEvent(
            new CloseActionScreenEvent()
        );

        // Redirect to Case List View
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            },
            state: {
                filterName: 'Recent'
            }
        });

    }

    handleError(event) {

        this.isSaving = false;

        const message =
            event.detail?.message ||
            'Unable to close the Case.';

        this.showToast(
            'Error',
            message,
            'error'
        );

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