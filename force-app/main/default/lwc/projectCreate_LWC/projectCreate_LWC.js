import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class ProjectCreateLWC extends NavigationMixin(LightningElement) {
    @track isLoading = false;

    handleSave() {
        this.isLoading = true;
        this.template.querySelector('lightning-record-edit-form').submit();
    }

    handleSuccess(event) {
        this.isLoading = false;
        const recordId = event.detail.id;

        // 1. Show Toast Message
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Project Created Successfully!',
            variant: 'success'
        }));

        // 2. Close Modal and Navigate to the new record
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    handleError() {
        this.isLoading = false;
    }

    handleCancel() {
        // Fire custom event to Aura Wrapper to close
        this.dispatchEvent(new CustomEvent('close'));
    }
}