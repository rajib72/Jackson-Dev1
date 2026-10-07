import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getSerialNumbers from '@salesforce/apex/ctrl_AssetSerialNoController.getSerialNumbers';
import saveSerialNumbers from '@salesforce/apex/ctrl_AssetSerialNoController.saveSerialNumbers';
import deleteSerialNumber from '@salesforce/apex/ctrl_AssetSerialNoController.deleteSerialNumber';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class AssetSerialNoManager extends NavigationMixin(LightningElement) {
    @api recordId;

    @track serialRows = [];
    isLoading = false;
    wiredSerialResult;

    rowCounter = 0;

    @wire(getSerialNumbers, { assetId: '$recordId' })
    wiredSerialNumbers(result) {
        this.wiredSerialResult = result;

        if (result.data) {
            this.serialRows = result.data.map((item, index) => {
                return {
                    rowKey: item.Id,
                    Id: item.Id,
                    Name: item.Name,
                    displayIndex: index + 1
                };
            });
        } else if (result.error) {
            this.showToast('Error', this.getErrorMessage(result.error), 'error');
        }
    }

    handleAddRow() {
        this.rowCounter++;

        const newRow = {
            rowKey: 'temp_' + Date.now() + '_' + this.rowCounter,
            Id: null,
            Name: '',
            displayIndex: this.serialRows.length + 1
        };

        this.serialRows = [...this.serialRows, newRow];
        this.updateDisplayIndexes();
    }

    handleInputChange(event) {
        const index = event.target.dataset.index;
        const value = event.target.value;

        this.serialRows[index].Name = value;
        this.serialRows = [...this.serialRows];
    }

    async handleDeleteRow(event) {
        const index = event.currentTarget.dataset.index;
        const selectedRow = this.serialRows[index];

        if (selectedRow.Id) {
            this.isLoading = true;

            try {
                await deleteSerialNumber({ serialId: selectedRow.Id });

                this.serialRows.splice(index, 1);
                this.serialRows = [...this.serialRows];
                this.updateDisplayIndexes();

                this.showToast('Success', 'Serial number deleted successfully.', 'success');

                await refreshApex(this.wiredSerialResult);
            } catch (error) {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            } finally {
                this.isLoading = false;
            }
        } else {
            this.serialRows.splice(index, 1);
            this.serialRows = [...this.serialRows];
            this.updateDisplayIndexes();
        }
    }

    async handleSave() {
        const validRows = this.serialRows.filter(row => row.Name && row.Name.trim() !== '');

        if (validRows.length === 0) {
            this.showToast('Warning', 'Please enter at least one serial number.', 'warning');
            return;
        }

        const recordsToSave = validRows.map(row => {
            return {
                Id: row.Id,
                Name: row.Name
            };
        });

        this.isLoading = true;

        try {
            await saveSerialNumbers({
                assetId: this.recordId,
                serialList: recordsToSave
            });

            this.showToast('Success', 'Serial numbers saved successfully.', 'success');

            await refreshApex(this.wiredSerialResult);

            this.redirectToAssetRecord();

        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    redirectToAssetRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Asset',
                actionName: 'view'
            }
        });
    }

    updateDisplayIndexes() {
        this.serialRows = this.serialRows.map((row, index) => {
            return {
                ...row,
                displayIndex: index + 1
            };
        });
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

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}