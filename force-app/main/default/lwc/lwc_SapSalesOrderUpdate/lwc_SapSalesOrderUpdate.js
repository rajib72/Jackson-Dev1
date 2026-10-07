import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateOrderInSAP from '@salesforce/apex/API_Ctrl_SolarSalesUpdateController.updateOrderInSAP';

export default class Lwc_SapSalesOrderUpdate extends LightningElement {
    @api recordId;
    isLoading = false;
    responseMessage = null;
    isSuccess = false;

    // Dynamically sets the SLDS alert classes based on success/error
    get alertClass() {
        return this.isSuccess 
            ? 'slds-notify slds-notify_alert slds-alert_success slds-theme_success slds-m-bottom_medium' 
            : 'slds-notify slds-notify_alert slds-alert_error slds-theme_error slds-m-bottom_medium';
    }

    handleUpdate() {
        this.isLoading = true;
        this.responseMessage = null; // Clear previous messages

        updateOrderInSAP({ orderId: this.recordId })
            .then(result => {
                this.isSuccess = result.isSuccess;
                this.responseMessage = result.message;

                // Configure Toast properties based on the response
                const variant = this.isSuccess ? 'success' : 'error';
                const title = this.isSuccess ? 'SAP Updated Successfully' : 'SAP Update Failed';

                // Dispatch global Toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: title,
                        message: this.responseMessage,
                        variant: variant
                    })
                );
            })
            .catch(error => {
                this.isSuccess = false;
                this.responseMessage = error.body ? error.body.message : 'An unknown Apex error occurred';

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Server Error',
                        message: this.responseMessage,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}