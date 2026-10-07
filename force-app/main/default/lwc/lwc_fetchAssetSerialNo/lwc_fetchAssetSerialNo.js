import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchAndSaveSerialNumber from '@salesforce/apex/Ctrl_fetchAssetSerialNo.fetchAndSaveSerialNumber';

// Import events to close the action and refresh the standard page
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

export default class Lwc_fetchAssetSerialNo extends LightningElement {
    @api recordId; 
    isLoading = false;

    handleFetchClick() {
        this.isLoading = true;

        fetchAndSaveSerialNumber({ assetId: this.recordId })
            .then((result) => {
                this.showToast('Success', result, 'success');
                this.closeAndRefresh();
            })
            .catch((error) => {
                let errorMessage = 'An unknown error occurred';
                if (error && error.body && error.body.message) {
                    errorMessage = error.body.message;
                }
                this.showToast('Error', errorMessage, 'error');
                this.isLoading = false; // Stop spinner so user can retry or cancel
            });
    }

    handleCancel() {
        // Dispatches event to close the quick action modal
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    closeAndRefresh() {
        // 1. Close the modal
        this.dispatchEvent(new CloseActionScreenEvent());
        
        // 2. Refresh the standard record page to show the newly inserted Serial Number record
        this.dispatchEvent(new RefreshEvent());
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }
}