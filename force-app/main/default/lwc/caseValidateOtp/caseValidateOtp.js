import { LightningElement, api } from 'lwc';


import validateOtp
    from '@salesforce/apex/CaseOtpController.validateOtp';

import requestAuthorizedOtp
    from '@salesforce/apex/CaseOtpController.requestAuthorizedOtp';


import { ShowToastEvent }
    from 'lightning/platformShowToastEvent';

import { RefreshEvent } from 'lightning/refresh';

import { CloseActionScreenEvent }
    from 'lightning/actions';

import { getRecordNotifyChange } from 'lightning/uiRecordApi';



export default class CaseValidateOtp extends LightningElement {



    @api recordId;


    enteredOtp = '';

    isLoading = false;




    handleOtpChange(event) {


        this.enteredOtp =
            event.target.value;


    }

    handleAuthorizedOtp() {

        if (this.isLoading) {
            return;
        }

        this.isLoading = true;

        requestAuthorizedOtp({
            caseId: this.recordId
        })
            .then(result => {

                this.showToast(
                    'Success',
                    result,
                    'success'
                );

                getRecordNotifyChange([
                    {
                        recordId: this.recordId
                    }
                ]);

                this.dispatchEvent(
                    new RefreshEvent()
                );

                setTimeout(() => {
                    this.dispatchEvent(
                        new CloseActionScreenEvent()
                    );
                }, 500);

            })
            .catch(error => {

                this.showToast(
                    'Error',
                    error?.body?.message ||
                    'Unable to request Authorized OTP.',
                    'error'
                );

            })
            .finally(() => {

                this.isLoading = false;

            });

    }





    handleVerifyOtp() {


        if (!this.enteredOtp) {


            this.showToast(
                'Error',
                'Please enter OTP.',
                'error'
            );


            return;

        }



        if (this.enteredOtp.length !== 4) {


            this.showToast(
                'Error',
                'OTP must be 4 digits.',
                'error'
            );


            return;

        }




        this.isLoading = true;




        validateOtp({

            caseId: this.recordId,

            enteredOtp: this.enteredOtp


        })

            .then(result => {


                this.showToast(

                    'Success',

                    result,

                    'success'

                );

                getRecordNotifyChange([
                    {
                        recordId: this.recordId
                    }
                ]);

                this.dispatchEvent(

                    new RefreshEvent()

                );

                setTimeout(() => {

                    this.dispatchEvent(
                        new CloseActionScreenEvent()
                    );

                }, 500);


            })

            .catch(error => {


                this.showToast(

                    'Error',

                    error.body.message,

                    'error'

                );


            })


            .finally(() => {


                this.isLoading = false;


            });


    }







    handleCancel() {


        this.dispatchEvent(

            new CloseActionScreenEvent()

        );


    }






    showToast(title, message, variant) {


        this.dispatchEvent(

            new ShowToastEvent({

                title: title,

                message: message,

                variant: variant

            })

        );


    }


}