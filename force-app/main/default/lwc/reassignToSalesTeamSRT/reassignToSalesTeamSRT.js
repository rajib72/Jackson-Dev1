import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

import reassignOpportunity
    from '@salesforce/apex/ReassignOpportunitySRTController.reassignOpportunity';

export default class ReassignToSalesTeam extends LightningElement {

    @api recordId;
    isLoading = false;

    handleReassign() {

        this.isLoading = true;

        reassignOpportunity({ opportunityId: this.recordId })
        .then(() => {

            // Refresh record page
            getRecordNotifyChange([{ recordId: this.recordId }]);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Opportunity reassigned successfully.',
                    variant: 'success'
                })
            );

            this.isLoading = false;

            // 🔥 Let Aura wrapper close the Quick Action
            this.dispatchEvent(
                new CustomEvent('closequickaction', {
                    bubbles: true,
                    composed: true
                })
            );

        })
        .catch(error => {

            this.isLoading = false;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || error.message,
                    variant: 'error'
                })
            );
        });
    }

    handleClose() {

        // 🔥 Let Aura wrapper close the Quick Action
        this.dispatchEvent(
            new CustomEvent('closequickaction', {
                bubbles: true,
                composed: true
            })
        );

    }
}