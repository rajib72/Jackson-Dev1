import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncOrderToSAP from '@salesforce/apex/API_Ctrl_SRTSalesCreationController.syncOrderToSAP';

export default class Lwc_SAPOrderSyncBtn extends LightningElement {
    @api recordId; 
    isLoading = false;
    @track validationErrors = null;

    handleSync() {
        this.isLoading = true;
        this.validationErrors = null; // Clear previous errors

        syncOrderToSAP({ orderId: this.recordId })
            .then(result => {
                if (result.isSuccess) {
                    this.showToast('Success', result.message, 'success');
                } else {
                    if (result.message && result.message.startsWith('MISSING_DATA: ')) {
                        this.validationErrors = result.message.replace('MISSING_DATA: ', '');
                    } else {
                        // Triggers toast with the exact unadulterated response from SAP
                        this.showToast('SAP API Error', result.message, 'error');
                    }
                }
            })
            .catch(error => {
                // Captures the exact exception message if it comes down from Apex
                let errorMsg = 'An unknown error occurred while communicating with the server.';
                if (error && error.body && error.body.message) {
                    errorMsg = error.body.message;
                }
                this.showToast('System Error', errorMsg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: variant === 'error' ? 'sticky' : 'dismissable'
            })
        );
    }
}