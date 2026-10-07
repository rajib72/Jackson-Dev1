import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

import generateAndSendOtp from '@salesforce/apex/FSROtpController.generateAndSendOtp';

    export default class FsrGenerateOtp extends LightningElement {
    @api recordId;
    @track isLoading = false;

    handleGenerateOtp() {
        this.isLoading = true;

        generateAndSendOtp({ fsrId: this.recordId })
            .then((result) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: result,
                        variant: 'success'
                    })
                );

                this.dispatchEvent(new CloseActionScreenEvent());

                setTimeout(() => {
                    window.location.reload();
                }, 1000);
            })
            .catch((error) => {
                let message = 'Something went wrong.';
                if (error?.body?.message) {
                    message = error.body.message;
                }

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