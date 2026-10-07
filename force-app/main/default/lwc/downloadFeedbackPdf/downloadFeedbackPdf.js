import { LightningElement, api } from 'lwc';
import generatePDF from '@salesforce/apex/FeedbackPDFService.generatePDF';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

export default class DownloadFeedbackPdf extends LightningElement {
    @api recordId;

    handleDownload() {

        if (!this.recordId) return;

        generatePDF({ caseId: this.recordId })
            .then(() => {

                // Refresh Files
                getRecordNotifyChange([{ recordId: this.recordId }]);

                // Open PDF
                window.open(`/apex/FeedbackFormPDF?id=${this.recordId}`, '_blank');

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'PDF generated and saved!',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                console.error(error);
            });
    }
}