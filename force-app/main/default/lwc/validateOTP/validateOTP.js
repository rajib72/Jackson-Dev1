import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import validateOtp from '@salesforce/apex/FSROtpController.validateOtp';

export default class ValidateOTP extends LightningElement {
        @api recordId;
    @track enteredOtp = '';
    @track isLoading = false;

    handleOtpChange(event) {
        this.enteredOtp = event.target.value;
    }

    handleVerifyOtp() {
        if (!this.enteredOtp) {
            this.showToast('Error', 'Please enter OTP.', 'error');
            return;
        }

        if (this.enteredOtp.length !== 4) {
            this.showToast('Error', 'OTP must be 4 digits.', 'error');
            return;
        }

        this.isLoading = true;

        validateOtp({
            fsrId: this.recordId,
            enteredOtp: this.enteredOtp
        })
            .then((result) => {
                this.showToast('Success', result, 'success');
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
                this.showToast('Error', message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
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