import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable, updateRecord } from 'lightning/uiRecordApi';

import getMaterialsFromSAP from '@salesforce/apex/Ctrl_FetchTagMaterialToOppLineItem.getMaterialsFromSAP';
import getMaterialsByDescriptionFromSAP from '@salesforce/apex/Ctrl_FetchTagMaterialToOppLineItem.getMaterialsByDescriptionFromSAP';
import saveAndLinkMaterial from '@salesforce/apex/Ctrl_FetchTagMaterialToOppLineItem.saveAndLinkMaterial';

const CODE_COLUMNS = [
    { label: 'Material Code', fieldName: 'MATERIAL_CODE', type: 'text', initialWidth: 180 },
    { label: 'Description', fieldName: 'MATERIAL_DESCRIPTION', type: 'text', initialWidth: 250 },
    { label: 'Created On', fieldName: 'CREATED_ON', type: 'text', initialWidth: 120 },
    { label: 'Created By', fieldName: 'CREATED_BY', type: 'text', initialWidth: 120 },
    { label: 'Material Group', fieldName: 'MATERIAL_GROUP', type: 'text', initialWidth: 140 },
    { label: 'Group Desc', fieldName: 'MATERIAL_GROUP_DESCRIPTION', type: 'text', initialWidth: 200 },
    { label: 'UOM', fieldName: 'UNIT_OF_MEASURE', type: 'text', initialWidth: 100 },
    { label: 'Material Type', fieldName: 'MATERIAL_TYPE', type: 'text', initialWidth: 130 },
    { label: 'Type Desc', fieldName: 'MATERIAL_TYPE_DESCRIPTION', type: 'text', initialWidth: 180 },
    { label: 'Plant', fieldName: 'PLANT', type: 'text', initialWidth: 100 },
    { label: 'Plant Desc', fieldName: 'PLANT_DESCRIPTION', type: 'text', initialWidth: 200 },
    { label: 'Storage Loc', fieldName: 'STORAGE_LOCATION', type: 'text', initialWidth: 120 },
    { label: 'Storage Loc Desc', fieldName: 'STORAGE_LOCATION_DESCRIPTION', type: 'text', initialWidth: 200 },
    { label: 'Sales Org', fieldName: 'SALES_ORG', type: 'text', initialWidth: 120 },
    { label: 'Dist. Channel', fieldName: 'DISTRIBUTION_CHANNEL', type: 'text', initialWidth: 130 },
    { label: 'Dist. Channel Desc', fieldName: 'DISTTRIBUTION_CHANNEL_DESC', type: 'text', initialWidth: 180 },
    { label: 'Division', fieldName: 'DIVISION', type: 'text', initialWidth: 100 },
    { label: 'Division Desc', fieldName: 'DIVISION_DESCRIPTION', type: 'text', initialWidth: 180 }
];

const DESCRIPTION_COLUMNS = [
    { label: 'Material Code', fieldName: 'MATERIAL_CODE', type: 'text', initialWidth: 200 },
    { label: 'Material Description', fieldName: 'MATERIAL_DESCRIPTION', type: 'text', initialWidth: 500 }
];

export default class Lwc_FetchTagMaterialToOppLineItem extends LightningElement {
    @api recordId;

    @track materials = [];

    searchMode = 'CODE';
    searchText = '';

    isLoading = false;
    noResults = false;
    selectedMaterial = null;
    isSaveDisabled = true;

    get searchModeOptions() {
        return [
            { label: 'Material Code', value: 'CODE' },
            { label: 'Material Description', value: 'DESCRIPTION' }
        ];
    }

    get inputLabel() {
        return this.searchMode === 'DESCRIPTION' ? 'Material Description' : 'Material Code';
    }

    get inputPlaceholder() {
        return this.searchMode === 'DESCRIPTION'
            ? 'Enter material description to search...'
            : 'Enter material code to search...';
    }

    get displayColumns() {
        return this.searchMode === 'DESCRIPTION' ? DESCRIPTION_COLUMNS : CODE_COLUMNS;
    }

    get hasResults() {
        return this.materials.length > 0;
    }

    get noResultsMessage() {
        return this.searchMode === 'DESCRIPTION'
            ? 'No materials found in SAP for this description.'
            : 'No materials found in SAP for this code.';
    }

    handleSearchModeChange(event) {
        this.searchMode = event.detail.value;
        this.resetSearchState();
    }

    handleInputChange(event) {
        this.searchText = event.target.value;
    }

    handleSearch() {
        if (!this.searchText || !this.searchText.trim()) {
            this.showToast('Warning', 'Please enter a value before searching.', 'warning');
            return;
        }

        this.isLoading = true;
        this.noResults = false;
        this.materials = [];
        this.selectedMaterial = null;
        this.isSaveDisabled = true;

        const searchValue = this.searchText.trim();

        let apexCall;

        if (this.searchMode === 'DESCRIPTION') {
            apexCall = getMaterialsByDescriptionFromSAP({
                materialDescription: searchValue
            });
        } else {
            apexCall = getMaterialsFromSAP({
                materialCode: searchValue
            });
        }

        apexCall
            .then(result => {
                if (result && result.length > 0) {
                    this.materials = result.map((row, index) => {
                        return {
                            ...row,
                            rowId: 'row-' + index
                        };
                    });
                } else {
                    this.noResults = true;
                    this.markAsTriedToTag();
                }
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error.body ? error.body.message : error.message,
                    'error'
                );
                this.noResults = true;
                this.markAsTriedToTag();
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    markAsTriedToTag() {
        if (!this.recordId) return;

        const fields = {};
        fields.Id = this.recordId;
        fields.Tried_To_Tag_Material_Master__c = true;

        updateRecord({ fields })
            .then(() => {
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            })
            .catch(error => {
                console.error(
                    'Failed to update Tried_To_Tag_Material_Master__c checkbox',
                    error
                );
            });
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;

        if (selectedRows.length > 0) {
            this.selectedMaterial = selectedRows[0];
            this.isSaveDisabled = false;
        } else {
            this.selectedMaterial = null;
            this.isSaveDisabled = true;
        }
    }

    handleSyncAndLink() {
        if (!this.selectedMaterial) {
            this.showToast('Warning', 'Please select a material first.', 'warning');
            return;
        }

        this.isLoading = true;

        saveAndLinkMaterial({
            selectedMaterialJson: JSON.stringify(this.selectedMaterial),
            opportunityLineItemId: this.recordId,
            searchMode: this.searchMode
        })
            .then(() => {
                this.showToast('Success', 'Material successfully linked.', 'success');

                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                this.dispatchEvent(new RefreshEvent());
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.showToast(
                    'Error updating record',
                    error.body ? error.body.message : error.message,
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    resetSearchState() {
        this.searchText = '';
        this.materials = [];
        this.selectedMaterial = null;
        this.noResults = false;
        this.isSaveDisabled = true;
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