import { LightningElement, api, wire } from 'lwc';
import getAssets from '@salesforce/apex/CaseAssetController.getAssets';
import saveCaseAssets from '@salesforce/apex/CaseAssetController.saveCaseAssets';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

const columns = [
    { label: 'Asset Name', fieldName: 'Name' },
    { label: 'Serial Number', fieldName: 'SerialNumber' }
];

export default class CaseAssetTagging extends NavigationMixin(LightningElement) {

    @api recordId;
    assetData = [];
    selectedAssetIds = [];
    columns = columns;

    @wire(getAssets, { caseId: '$recordId' })
    wiredAssets({ data, error }) {
        if (data) {
            this.assetData = data;
        } else if (error) {
            console.error(error);
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedAssetIds = selectedRows.map(row => row.Id);
    }

    handleSave() {
        saveCaseAssets({
            caseId: this.recordId,
            assetIds: this.selectedAssetIds
        })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Assets tagged successfully',
                    variant: 'success'
                })
            );

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
        })
        .catch(error => {
            console.error(error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'Something went wrong',
                    variant: 'error'
                })
            );
        });
    }
}