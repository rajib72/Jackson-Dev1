import { LightningElement, api } from 'lwc';

import generateAndSendOtp
    from '@salesforce/apex/CaseOtpController.generateAndSendOtp';


import { ShowToastEvent }
    from 'lightning/platformShowToastEvent';

import { RefreshEvent }
    from 'lightning/refresh';


import { CloseActionScreenEvent }
    from 'lightning/actions';

import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';



export default class CaseGenerateOtp extends LightningElement {


    @api recordId;

    isLoading = false;



    handleGenerateOtp() {


        this.isLoading = true;



        generateAndSendOtp({

            caseId: this.recordId

        })

            .then(async result => {

                this.showToast(
                    'Success',
                    result,
                    'success'
                );

                // Refresh Case record data after Apex update
                await notifyRecordUpdateAvailable([
                    {
                        recordId: this.recordId
                    }
                ]);

                // Request refresh of the record page
                this.dispatchEvent(
                    new RefreshEvent()
                );

                // Close Quick Action
                this.dispatchEvent(
                    new CloseActionScreenEvent()
                );

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