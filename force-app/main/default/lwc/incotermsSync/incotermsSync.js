import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncIncoterms from '@salesforce/apex/ctrl_IncotermsAPIController.syncIncoterms';

const COLUMNS = [
    { label: 'Incoterm Code', fieldName: 'incoterm', type: 'text' },
    { label: 'Description', fieldName: 'description', type: 'text' },
    { label: 'Action', fieldName: 'action', type: 'text', 
      cellAttributes: { 
          class: { fieldName: 'actionClass' } 
      }
    },
    { label: 'Message', fieldName: 'message', type: 'text', wrapText: true }
];

export default class IncotermsSync extends LightningElement {
    columns = COLUMNS;
    @track isLoading = false;
    @track hasProcessed = false;
    
    @track summary = {};

    handleFetch() {
        this.isLoading = true;
        this.hasProcessed = false;

        syncIncoterms()
            .then((result) => {
                // Dynamically apply text colors to the Action column based on the operation
                let decoratedRecords = result.processedRecords.map(record => {
                    let actionColorClass = '';
                    if(record.action === 'Created') actionColorClass = 'slds-text-color_success';
                    else if(record.action === 'Updated') actionColorClass = 'slds-text-color_default';
                    else if(record.action === 'Error') actionColorClass = 'slds-text-color_error';

                    return { ...record, actionClass: actionColorClass };
                });

                this.summary = {
                    totalReceived: result.totalReceived,
                    totalCreated: result.totalCreated,
                    totalUpdated: result.totalUpdated,
                    totalErrors: result.totalErrors,
                    processedRecords: decoratedRecords
                };
                
                this.hasProcessed = true;
                
                if(result.totalErrors > 0) {
                    this.showToast('Warning', 'Sync completed, but there were some errors.', 'warning');
                } else {
                    this.showToast('Success', 'Incoterms synced successfully.', 'success');
                }
            })
            .catch((error) => {
                let errorMsg = error.body ? error.body.message : error.message;
                this.showToast('Error', errorMsg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Resets the component state entirely to hide the results
    handleRefresh() {
        this.hasProcessed = false;
        this.summary = {};
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