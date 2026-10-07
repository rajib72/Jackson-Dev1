import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';

import fetchSpareRequestData from '@salesforce/apex/API_ctrl_SAPSpareRequestController.fetchSpareRequestData';
import updateSelectedPrice from '@salesforce/apex/API_ctrl_SAPSpareRequestController.updateSelectedPrice';

import MATERIAL_CODE_FIELD from '@salesforce/schema/ProductRequestLineItem.Material_Code__c';
import PRICE_FIELD from '@salesforce/schema/ProductRequestLineItem.Price__c';

const FIELDS = [MATERIAL_CODE_FIELD, PRICE_FIELD];

export default class SapSpareRequest extends LightningElement {
    @api recordId;

    @track materialCode = '';
    @track tableData = [];
    @track selectedRows = [];
    @track isLoading = false;
    @track currentPrice;
    @track hasSearched = false;

    columns = [
        { label: 'Material Code', fieldName: 'materialCode', type: 'text' },
        { label: 'Description', fieldName: 'materialDescription', type: 'text' },
        { label: 'Plant', fieldName: 'plant', type: 'text' },
        { label: 'Description', fieldName: 'plantDescription', type: 'text' },
        { label: 'Storage Location', fieldName: 'storageLocation', type: 'text' },
        { label: 'Description', fieldName: 'storageLocationDescription', type: 'text' },
        { label: 'UOM', fieldName: 'uom', type: 'text' },
        { label: 'Batch Number', fieldName: 'batchNumber', type: 'text' },
        { label: 'Quantity', fieldName: 'quantity', type: 'number', cellAttributes: { alignment: 'left' } },
        { label: 'Price', fieldName: 'standardPrice', type: 'currency', cellAttributes: { alignment: 'left' } }
    ];

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.materialCode = getFieldValue(data, MATERIAL_CODE_FIELD) || '';
            this.currentPrice = getFieldValue(data, PRICE_FIELD);
        } else if (error) {
            this.showToast('Error', 'Unable to load Product Request Line Item record.', 'error');
        }
    }

    get selectedCount() {
        return this.selectedRows.length;
    }

    get disableFetch() {
        return !this.materialCode || this.isLoading;
    }

    get disableUpdate() {
        return this.selectedRows.length !== 1 || this.isLoading;
    }

    get showTable() {
        return this.tableData && this.tableData.length > 0;
    }

    get noDataFound() {
        return this.hasSearched && !this.isLoading && this.tableData.length === 0;
    }

    handleMaterialCodeChange(event) {
        this.materialCode = event.target.value;
    }

    async handleFetch() {
        if (!this.materialCode) {
            this.showToast('Warning', 'Please enter Material Code.', 'warning');
            return;
        }

        this.isLoading = true;
        this.hasSearched = true;
        this.selectedRows = [];
        this.tableData = [];

        try {
            const result = await fetchSpareRequestData({ materialCode: this.materialCode });

            this.tableData = (result || []).map((row, index) => {
                return {
                    ...row,
                    rowId: String(index + 1)
                };
            });

            if (this.tableData.length === 0) {
                this.showToast('Info', 'No data found from SAP API.', 'info');
            }
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

    async handleUpdatePrice() {
        if (this.selectedRows.length !== 1) {
            this.showToast('Warning', 'Please select exactly one row.', 'warning');
            return;
        }

        const selectedRow = this.selectedRows[0];
        const selectedPrice = selectedRow.standardPrice;

        this.isLoading = true;

        try {
            const message = await updateSelectedPrice({
                recordId: this.recordId,
                selectedPrice: selectedPrice
            });

            this.showToast('Success', message, 'success');
            this.dispatchEvent(new RefreshEvent());
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.tableData = [];
        this.selectedRows = [];
        this.hasSearched = false;
        this.dispatchEvent(new RefreshEvent());
        this.showToast('Success', 'Page refreshed successfully.', 'success');
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
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
}