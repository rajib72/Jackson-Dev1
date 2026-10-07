import { LightningElement, api, wire } from 'lwc';

import getProductRequestDetails from '@salesforce/apex/Ctrl_CreateProductRequestLineItem.getProductRequestDetails';
import searchMaterialMasters from '@salesforce/apex/Ctrl_CreateProductRequestLineItem.searchMaterialMasters';
import searchLocations from '@salesforce/apex/Ctrl_CreateProductRequestLineItem.searchLocations';
import createLineItems from '@salesforce/apex/Ctrl_CreateProductRequestLineItem.createLineItems';

import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import PRODUCT_REQUEST_LINE_ITEM_OBJECT from '@salesforce/schema/ProductRequestLineItem';
import QUANTITY_UOM_FIELD from '@salesforce/schema/ProductRequestLineItem.QuantityUnitOfMeasure';
import SHIPMENT_TYPE_FIELD from '@salesforce/schema/ProductRequestLineItem.ShipmentType';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

export default class Lwc_CreateProductRequestLineItem extends LightningElement {
    @api recordId;

    defaults = {};
    rows = [];
    isLoading = true;
    saving = false;

    uomOptions = [];
    shipmentTypeOptions = [];
    searchTimers = {};
    hasInjectedStyle = false;

    // Expand Quick Action Modal Width
    renderedCallback() {
        if (!this.hasInjectedStyle) {
            this.hasInjectedStyle = true;
            const style = document.createElement('style');
            style.innerText = `
                .slds-modal__container {
                    width: 90% !important;
                    max-width: 92rem !important;
                    min-width: 70rem !important;
                }
                .slds-modal__content {
                    overflow-y: auto !important;
                }
            `;
            document.head.appendChild(style);
        }
    }

    @wire(getObjectInfo, { objectApiName: PRODUCT_REQUEST_LINE_ITEM_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: QUANTITY_UOM_FIELD
    })
    wiredUomValues({ data, error }) {
        if (data) {
            this.uomOptions = data.values.map(item => ({ label: item.label, value: item.value }));
        } else if (error) {
            this.showError('Error', this.reduceError(error));
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: SHIPMENT_TYPE_FIELD
    })
    wiredShipmentTypeValues({ data, error }) {
        if (data) {
            this.shipmentTypeOptions = data.values.map(item => ({ label: item.label, value: item.value }));
        } else if (error) {
            this.showError('Error', this.reduceError(error));
        }
    }

    @wire(getProductRequestDetails, { productRequestId: '$recordId' })
    wiredProductRequest({ data, error }) {
        if (data) {
            this.defaults = { ...data };
            this.initializeRows();
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            this.showError('Error Loading Product Request', this.reduceError(error));
        }
    }

    initializeRows() {
        this.rows = [this.createEmptyRow(1)];
    }

    createEmptyRow(number) {
        return {
            id: 'row-' + Date.now() + '-' + Math.random().toString(36).substring(2, 8),
            displayNumber: number,

            materialMasterId: null,
            materialCode: '',
            plant: '',
            materialDescription: '',
            materialSearchTerm: '',
            materialOptions: [],
            showMaterialOptions: false,
            isSearchingMaterial: false,
            materialError: '',

            quantityRequested: null,
            quantityUnitOfMeasure: '',
            price: null,

            sourceLocationId: null,
            sourceLocationName: '',
            sourceSearchTerm: '',
            sourceOptions: [],
            showSourceOptions: false,
            isSearchingSource: false,

            shipmentType: ''
        };
    }

    handleAddRow() {
        this.rows = [...this.rows, this.createEmptyRow(this.rows.length + 1)];
    }

    handleDeleteRow(event) {
        const rowId = event.currentTarget.dataset.rowId;
        if (this.rows.length === 1) return;

        this.rows = this.rows
            .filter(row => row.id !== rowId)
            .map((row, index) => ({ ...row, displayNumber: index + 1 }));
    }

    handleRowChange(event) {
        const rowId = event.target.dataset.rowId;
        const field = event.target.dataset.field;
        const value = event.detail?.value ?? event.target.value;

        this.rows = this.rows.map(row => {
            if (row.id !== rowId) return row;
            return {
                ...row,
                [this.mapFieldName(field)]: value
            };
        });
    }

    mapFieldName(field) {
        switch (field) {
            case 'quantity': return 'quantityRequested';
            case 'uom': return 'quantityUnitOfMeasure';
            case 'price': return 'price';
            case 'shipmentType': return 'shipmentType';
            default: return field;
        }
    }

    // =========================================================
    // MATERIAL SEARCH (Fired via onchange on every keystroke)
    // =========================================================
    handleMaterialSearch(event) {
        const rowId = event.target.dataset.rowId;
        const searchTerm = event.detail?.value ?? event.target.value ?? '';

        this.clearSearchTimer('material-' + rowId);

        if (searchTerm.trim().length < 2) {
            this.updateRow(rowId, {
                materialSearchTerm: searchTerm,
                materialMasterId: null,
                materialCode: '',
                plant: '',
                materialDescription: '',
                materialOptions: [],
                showMaterialOptions: false,
                isSearchingMaterial: false,
                materialError: ''
            });
            return;
        }

        // Keep dropdown open and display searching state
        this.updateRow(rowId, {
            materialSearchTerm: searchTerm,
            materialMasterId: null,
            materialCode: '',
            plant: '',
            materialDescription: '',
            showMaterialOptions: true,
            isSearchingMaterial: true,
            materialError: ''
        });

        this.searchTimers['material-' + rowId] = setTimeout(async () => {
            try {
                const results = await searchMaterialMasters({ searchTerm: searchTerm.trim() });
                const currentRow = this.rows.find(row => row.id === rowId);

                if (currentRow && currentRow.materialSearchTerm === searchTerm) {
                    this.updateRow(rowId, {
                        materialOptions: results || [],
                        isSearchingMaterial: false,
                        showMaterialOptions: true
                    });
                }
            } catch (error) {
                this.updateRow(rowId, { isSearchingMaterial: false });
                this.showError('Material Search Error', this.reduceError(error));
            }
        }, 300);
    }

    handleMaterialInputClick(event) {
        const rowId = event.target.dataset.rowId;
        const row = this.rows.find(item => item.id === rowId);
        if (row && row.materialOptions && row.materialOptions.length > 0) {
            this.updateRow(rowId, { showMaterialOptions: true });
        }
    }

    handleMaterialSelect(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const materialId = event.currentTarget.dataset.materialId;
        const row = this.rows.find(item => item.id === rowId);
        if (!row) return;

        const material = row.materialOptions.find(item => item.id === materialId);
        if (!material) return;

        this.updateRow(rowId, {
            materialMasterId: material.id,
            materialCode: material.materialCode,
            plant: material.plant,
            materialDescription: material.materialDescription || '',
            materialSearchTerm: `${material.materialCode} - ${material.plant}`,
            materialOptions: [],
            showMaterialOptions: false,
            isSearchingMaterial: false,
            materialError: ''
        });
    }

    // =========================================================
    // SOURCE LOCATION SEARCH (Fired via onchange)
    // =========================================================
    handleSourceSearch(event) {
        const rowId = event.target.dataset.rowId;
        const searchTerm = event.detail?.value ?? event.target.value ?? '';

        this.clearSearchTimer('source-' + rowId);

        if (searchTerm.trim().length < 2) {
            this.updateRow(rowId, {
                sourceSearchTerm: searchTerm,
                sourceLocationId: null,
                sourceLocationName: '',
                sourceOptions: [],
                showSourceOptions: false,
                isSearchingSource: false
            });
            return;
        }

        this.updateRow(rowId, {
            sourceSearchTerm: searchTerm,
            sourceLocationId: null,
            sourceLocationName: '',
            showSourceOptions: true,
            isSearchingSource: true
        });

        this.searchTimers['source-' + rowId] = setTimeout(async () => {
            try {
                const results = await searchLocations({ searchTerm: searchTerm.trim() });
                const currentRow = this.rows.find(row => row.id === rowId);

                if (currentRow && currentRow.sourceSearchTerm === searchTerm) {
                    this.updateRow(rowId, {
                        sourceOptions: results || [],
                        isSearchingSource: false,
                        showSourceOptions: true
                    });
                }
            } catch (error) {
                this.updateRow(rowId, { isSearchingSource: false });
                this.showError('Location Search Error', this.reduceError(error));
            }
        }, 300);
    }

    handleSourceInputClick(event) {
        const rowId = event.target.dataset.rowId;
        const row = this.rows.find(item => item.id === rowId);
        if (row && row.sourceOptions && row.sourceOptions.length > 0) {
            this.updateRow(rowId, { showSourceOptions: true });
        }
    }

    handleSourceSelect(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const locationId = event.currentTarget.dataset.locationId;
        const row = this.rows.find(item => item.id === rowId);
        if (!row) return;

        const location = row.sourceOptions.find(item => item.id === locationId);
        if (!location) return;

        this.updateRow(rowId, {
            sourceLocationId: location.id,
            sourceLocationName: location.name,
            sourceSearchTerm: location.name,
            sourceOptions: [],
            showSourceOptions: false,
            isSearchingSource: false
        });
    }

    // Prevents input blur from firing before an item selection click completes
    handleDropdownMouseDown(event) {
        event.preventDefault();
    }

    handleSearchBlur(event) {
        const rowId = event.target.dataset.rowId;
        const field = event.target.dataset.field;

        setTimeout(() => {
            if (field === 'material') {
                this.updateRow(rowId, { showMaterialOptions: false });
            } else if (field === 'source') {
                this.updateRow(rowId, { showSourceOptions: false });
            }
        }, 200);
    }

    updateRow(rowId, changes) {
        this.rows = this.rows.map(row => (row.id === rowId ? { ...row, ...changes } : row));
    }

    // =========================================================
    // VALIDATION & SAVE
    // =========================================================
    validateRows() {
        let isValid = true;

        this.rows = this.rows.map(row => {
            let materialError = '';
            if (!row.materialMasterId) {
                materialError = 'Select a Material Master.';
                isValid = false;
            }
            return { ...row, materialError };
        });

        const inputs = this.template.querySelectorAll(
            'lightning-input[data-field], lightning-combobox[data-field]'
        );
        inputs.forEach(input => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });

        return isValid;
    }

    async handleSave() {
        if (this.saving) return;

        if (!this.validateRows()) {
            this.showError('Validation Error', 'Please complete all required fields.');
            return;
        }

        this.saving = true;
        this.isLoading = true;

        const payload = this.rows.map(row => ({
            materialMasterId: row.materialMasterId,
            quantityRequested: row.quantityRequested ? Number(row.quantityRequested) : null,
            quantityUnitOfMeasure: row.quantityUnitOfMeasure,
            price: row.price !== null && row.price !== '' ? Number(row.price) : null,
            sourceLocationId: row.sourceLocationId,
            shipmentType: row.shipmentType
        }));

        try {
            const createdIds = await createLineItems({
                productRequestId: this.recordId,
                inputItems: payload
            });

            this.showSuccess('Success', `${createdIds.length} Product Request Line Item(s) created successfully.`);
            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showError('Error Creating Line Items', this.reduceError(error));
        } finally {
            this.saving = false;
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    clearSearchTimer(key) {
        if (this.searchTimers[key]) {
            clearTimeout(this.searchTimers[key]);
            delete this.searchTimers[key];
        }
    }

    get saveButtonLabel() {
        return `Save Line Items (${this.rows.length})`;
    }

    get disableSave() {
        return this.saving || this.isLoading || this.rows.length === 0;
    }

    get disableDelete() {
        return this.rows.length === 1;
    }

    showSuccess(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'success' }));
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }

    reduceError(error) {
        if (!error) return 'Unknown error.';
        if (Array.isArray(error.body)) return error.body.map(item => item.message).join(', ');
        if (error.body && typeof error.body.message === 'string') return error.body.message;
        if (typeof error.message === 'string') return error.message;
        return 'An unexpected error occurred.';
    }
}