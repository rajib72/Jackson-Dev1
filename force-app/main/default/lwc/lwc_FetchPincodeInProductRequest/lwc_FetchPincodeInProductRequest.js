import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// Import the Postal Code component of the ShipToAddress field
import POSTAL_CODE_FIELD from '@salesforce/schema/ProductRequest.ShipToPostalCode';

import getPostOffices from '@salesforce/apex/API_Ctrl_PostalPincodeController.getPostOffices';
import updateProductRequestFromSelection from '@salesforce/apex/API_Ctrl_PostalPincodeController.updateProductRequestFromSelection';

const FIELDS = [POSTAL_CODE_FIELD];

export default class Lwc_FetchPincodeInProductRequest extends LightningElement {
    @api recordId;

    pincode = '';
    message = '';
    isLoading = false;
    showNoPincodeMessage = false;
    hasSearched = false;

    @track rows = [];
    selectedRow = null;
    selectedRowKeys = [];

    columns = [
        { label: 'Name', fieldName: 'name', type: 'text' },
        { label: 'Division', fieldName: 'division', type: 'text' },
        { label: 'Region', fieldName: 'region', type: 'text' },
        { label: 'State', fieldName: 'state', type: 'text' },
        { label: 'Country', fieldName: 'country', type: 'text' },
        { label: 'Pincode', fieldName: 'pincode', type: 'text' }
    ];

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    get disableUpdate() {
        return !this.selectedRow || this.isLoading;
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredProductRequest({ error, data }) {
        if (data) {
            this.pincode = getFieldValue(data, POSTAL_CODE_FIELD) || '';
            console.log('Product Request recordId =>', this.recordId);
            console.log('Fetched ShipToPostalCode =>', this.pincode);

            this.showNoPincodeMessage = !this.pincode;

            if (this.pincode && !this.hasSearched) {
                this.hasSearched = true;
                this.searchPostOffices();
            }
        } else if (error) {
            console.error('getRecord error =>', JSON.stringify(error));
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    async searchPostOffices() {
        try {
            if (!this.pincode || !/^\d{6}$/.test(this.pincode)) {
                this.showNoPincodeMessage = true;
                return;
            }

            this.isLoading = true;
            this.message = '';
            this.rows = [];
            this.selectedRow = null;
            this.selectedRowKeys = [];

            const result = await getPostOffices({ pincode: this.pincode });

            this.message = result?.message || '';

            const postOffices = result?.postOffices || [];
            this.rows = postOffices.map((row, index) => {
                return {
                    ...row,
                    uniqueKey: `${row.name || 'ROW'}_${row.pincode || ''}_${index}`
                };
            });

            if (!this.rows.length) {
                this.showToast('Info', 'No records found for this pincode.', 'info');
            }
        } catch (error) {
            console.error('searchPostOffices error =>', JSON.stringify(error));
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];

        if (selectedRows.length > 0) {
            this.selectedRow = selectedRows[0];
            this.selectedRowKeys = [selectedRows[0].uniqueKey];
        } else {
            this.selectedRow = null;
            this.selectedRowKeys = [];
        }
    }

    async handleUpdate() {
        try {
            if (!this.selectedRow) {
                this.showToast('Error', 'Please select one row.', 'error');
                return;
            }

            this.isLoading = true;

            await updateProductRequestFromSelection({
                prId: this.recordId,
                stateValue: this.selectedRow.state,
                countryValue: this.selectedRow.country,
                cityValue: this.selectedRow.division
            });

            this.showToast('Success', 'Product Request updated successfully.', 'success');
            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            console.error('handleUpdate error =>', JSON.stringify(error));
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
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

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'Unknown error';
    }
}