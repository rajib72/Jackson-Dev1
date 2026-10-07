import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';

import fetchSpareRequestData from '@salesforce/apex/API_ctrl_SAPSpareRequestController.fetchSpareRequestData';
import updateSelectedPrice from '@salesforce/apex/API_ctrl_SAPSpareRequestController.updateSelectedPrice';

import MATERIAL_CODE_FIELD from '@salesforce/schema/ProductRequestLineItem.Material_Code__c';
import PLANT_FIELD from '@salesforce/schema/ProductRequestLineItem.Plant__c';
import PRICE_FIELD from '@salesforce/schema/ProductRequestLineItem.Price__c';

const FIELDS = [MATERIAL_CODE_FIELD, PLANT_FIELD, PRICE_FIELD];
const CHUNK_SIZE = 50;

export default class SapSpareRequest extends LightningElement {
    @api recordId;

    @track materialCode = '';
    @track plant = '';
    @track currentPrice;
    @track isLoading = false;
    @track hasSearched = false;

    // Full in-memory datasets
    allRecords = [];
    filteredRecords = [];

    // Datatable visible records
    @track displayedData = [];
    @track enableInfiniteLoading = true;

    // Selection state
    @track selectedRowIds = [];
    selectedRowRecord = null;

    columns = [
        { label: 'Material Code', fieldName: 'materialCode', type: 'text', initialWidth: 160 },
        { label: 'Material Description', fieldName: 'materialDescription', type: 'text', wrapText: true, initialWidth: 260 },
        { label: 'Plant', fieldName: 'plant', type: 'text', initialWidth: 90 },
        { label: 'Plant Description', fieldName: 'plantDescription', type: 'text', wrapText: true, initialWidth: 200 },
        { label: 'Storage Loc', fieldName: 'storageLocation', type: 'text', initialWidth: 110 },
        { label: 'Storage Loc Description', fieldName: 'storageLocationDescription', type: 'text', wrapText: true, initialWidth: 200 },
        { label: 'UOM', fieldName: 'uom', type: 'text', initialWidth: 80 },
        { label: 'Batch Number', fieldName: 'batchNumber', type: 'text', initialWidth: 140 },
        { label: 'Quantity', fieldName: 'quantity', type: 'number', initialWidth: 110, cellAttributes: { alignment: 'left' } },
        { label: 'Standard Price', fieldName: 'standardPrice', type: 'currency', initialWidth: 130, cellAttributes: { alignment: 'left' } }
    ];

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.materialCode = getFieldValue(data, MATERIAL_CODE_FIELD) || '';
            this.plant = getFieldValue(data, PLANT_FIELD) || '';
            this.currentPrice = getFieldValue(data, PRICE_FIELD);
        } else if (error) {
            this.showToast('Error', 'Unable to load record data.', 'error');
        }
    }

    get disableFetch() {
        return !this.materialCode || !this.plant || this.isLoading;
    }

    get disableUpdate() {
        return !this.selectedRowRecord || this.isLoading;
    }

    get showTable() {
        return this.displayedData && this.displayedData.length > 0;
    }

    get noDataFound() {
        return this.hasSearched && !this.isLoading && this.allRecords.length === 0;
    }

    get currentPriceDisplay() {
        return this.currentPrice != null ? Number(this.currentPrice).toFixed(2) : '0.00';
    }

    get selectedPriceDisplay() {
        return this.selectedRowRecord ? Number(this.selectedRowRecord.standardPrice).toFixed(2) : '--';
    }

    get totalRecordCount() {
        return this.allRecords.length;
    }

    get filteredRecordCount() {
        return this.filteredRecords.length;
    }

    handleMaterialCodeChange(event) {
        this.materialCode = event.target.value;
    }

    handlePlantChange(event) {
        this.plant = event.target.value;
    }

    async handleFetch() {
        if (!this.materialCode || !this.plant) {
            this.showToast('Warning', 'Both Material Code and Plant are required.', 'warning');
            return;
        }

        this.isLoading = true;
        this.hasSearched = true;
        this.selectedRowIds = [];
        this.selectedRowRecord = null;
        this.displayedData = [];

        try {
            const result = await fetchSpareRequestData({ 
                materialCode: this.materialCode, 
                plant: this.plant 
            });

            this.allRecords = (result || []).map((row, idx) => ({
                rowId: 'row-' + idx,
                materialCode: row.MATERIAL_CODE || '',
                materialDescription: row.MATERIAL_DESCRIPTION || '',
                plant: row.PLANT || '',
                plantDescription: row.PLANT_DESCRIPTION || '',
                storageLocation: row.STORAGE_LOCATION || '',
                storageLocationDescription: row.STORAGE_LOCATION_DESCRIPTION || '',
                uom: row.UOM || '',
                batchNumber: row.BATCH_NUMBER || '',
                quantity: row.QUANTITY ? parseFloat(row.QUANTITY) : 0,
                standardPrice: row.STANDARD_PRICE ? parseFloat(row.STANDARD_PRICE) : 0
            }));

            this.filteredRecords = [...this.allRecords];
            this.displayedData = this.filteredRecords.slice(0, CHUNK_SIZE);
            this.enableInfiniteLoading = this.displayedData.length < this.filteredRecords.length;

            if (this.allRecords.length === 0) {
                this.showToast('Info', 'No data found from SAP API.', 'info');
            }
        } catch (error) {
            this.allRecords = [];
            this.filteredRecords = [];
            this.displayedData = [];
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleLoadMore(event) {
        const target = event.target;
        target.isLoading = true;

        const currentLength = this.displayedData.length;
        const totalAvailable = this.filteredRecords.length;

        if (currentLength >= totalAvailable) {
            this.enableInfiniteLoading = false;
            target.isLoading = false;
            return;
        }

        const nextChunk = this.filteredRecords.slice(currentLength, currentLength + CHUNK_SIZE);
        this.displayedData = [...this.displayedData, ...nextChunk];

        if (this.displayedData.length >= totalAvailable) {
            this.enableInfiniteLoading = false;
        }

        target.isLoading = false;
    }

    handleFilterChange(event) {
        const query = (event.target.value || '').toLowerCase().trim();

        if (!query) {
            this.filteredRecords = [...this.allRecords];
        } else {
            this.filteredRecords = this.allRecords.filter(row =>
                (row.batchNumber && row.batchNumber.toLowerCase().includes(query)) ||
                (row.plant && row.plant.toLowerCase().includes(query)) ||
                (row.storageLocation && row.storageLocation.toLowerCase().includes(query)) ||
                (row.storageLocationDescription && row.storageLocationDescription.toLowerCase().includes(query))
            );
        }

        this.displayedData = this.filteredRecords.slice(0, CHUNK_SIZE);
        this.enableInfiniteLoading = this.displayedData.length < this.filteredRecords.length;
    }

    handleRowSelection(event) {
        const selected = event.detail.selectedRows;
        if (selected && selected.length > 0) {
            this.selectedRowRecord = selected[0];
            this.selectedRowIds = [selected[0].rowId];
        } else {
            this.selectedRowRecord = null;
            this.selectedRowIds = [];
        }
    }

    async handleUpdatePrice() {
        if (!this.selectedRowRecord) {
            this.showToast('Warning', 'Please select a row to apply standard price.', 'warning');
            return;
        }

        const selectedPrice = this.selectedRowRecord.standardPrice;
        this.isLoading = true;

        try {
            const result = await updateSelectedPrice({
                recordId: this.recordId,
                selectedPrice: selectedPrice
            });

            this.showToast('Success', result, 'success');
            this.currentPrice = selectedPrice;
            this.dispatchEvent(new RefreshEvent());
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.allRecords = [];
        this.filteredRecords = [];
        this.displayedData = [];
        this.selectedRowIds = [];
        this.selectedRowRecord = null;
        this.hasSearched = false;
        this.enableInfiniteLoading = true;
        this.dispatchEvent(new RefreshEvent());
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map(item => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
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