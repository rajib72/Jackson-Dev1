import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateAndSaveQuotePdf from '@salesforce/apex/QuotePdfFileService.generateAndSaveQuotePdf';

export default class GenerateQuotePdfButton extends NavigationMixin(LightningElement) {
    @api recordId;

    isLoading = false;
    isSuccess = false;

    get buttonLabel() {
        return this.isLoading ? 'Generating...' : 'Generate PDF';
    }

    async handleGenerate() {
        this.isLoading = true;

        try {
            await generateAndSaveQuotePdf({ quoteId: this.recordId });

            this.isLoading = false;
            this.isSuccess = true;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'PDF generated and saved in Quote Related Files.',
                    variant: 'success'
                })
            );

            window.setTimeout(() => {
                this.dispatchEvent(new CloseActionScreenEvent());

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        objectApiName: 'Quote',
                        actionName: 'view'
                    }
                });
            }, 1200);

        } catch (error) {
            this.isLoading = false;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'Failed to generate PDF.',
                    variant: 'error'
                })
            );
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}