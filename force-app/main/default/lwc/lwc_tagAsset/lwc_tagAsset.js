import { LightningElement, api, track } from 'lwc';
import getInitialData from '@salesforce/apex/ctrl_CaseAssetTaggingController.getInitialData';
import getSerialNumbers from '@salesforce/apex/ctrl_CaseAssetTaggingController.getSerialNumbers';
import saveTaggedAsset from '@salesforce/apex/ctrl_CaseAssetTaggingController.saveTaggedAsset';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

export default class TagAsset extends LightningElement {
    _recordId;
    @track assets = [];
    @track serialNumbers = [];
    @track filteredSerialNumbers = [];
    selectedSerialIds = new Set();
    selectedAssetId;
    selectedAssetLabel;
    searchTerm = '';
    isLoading = false;
    isSaving = false;
    dataLoaded = false;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        if (value && !this.dataLoaded) {
            this.loadAssets();
        }
    }

    async loadAssets() {
        if (!this._recordId) {
            return;
        }

        this.isLoading = true;

        try {
            const result = await getInitialData({
                caseId: this._recordId
            });

            this.assets = (result.assets || []).map(asset => ({
                label: asset.label,
                value: asset.id,
                invoiceNumber: asset.Invoice_Number__c
            }));

            this.dataLoaded = true;
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleAssetChange(event) {
        this.selectedAssetId = event.detail.value;

        const selected = this.assets.find(
            asset => asset.value === this.selectedAssetId
        );

        this.selectedAssetLabel = selected ? selected.label : '';
        this.serialNumbers = [];
        this.filteredSerialNumbers = [];
        this.selectedSerialIds = new Set();
        this.searchTerm = '';

        if (!this.selectedAssetId || !this._recordId) {
            return;
        }

        this.isLoading = true;

        try {
            const result = await getSerialNumbers({
                caseId: this._recordId,
                assetId: this.selectedAssetId
            });

            this.serialNumbers = (result || []).map(serial => ({
                id: serial.id,
                label: serial.label,
                serialNumber: serial.serialNumber,
                productWarrantyEndDate: serial.productWarrantyEndDate,
                performanceWarrantyEndDate: serial.performanceWarrantyEndDate,
                selected: false
            }));

            this.filteredSerialNumbers = [...this.serialNumbers];
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleSearch(event) {
        this.searchTerm = (event.target.value || '').toLowerCase();

        if (!this.searchTerm) {
            this.filteredSerialNumbers = [...this.serialNumbers];
            return;
        }

        this.filteredSerialNumbers = this.serialNumbers.filter(serial =>
            (serial.serialNumber || '').toLowerCase().includes(this.searchTerm)
        );
    }

    handleSelectAll(event) {
        const checked = event.target.checked;

        this.serialNumbers = this.serialNumbers.map(serial => ({
            ...serial,
            selected: checked
        }));

        this.serialNumbers.forEach(serial => {
            if (checked) {
                this.selectedSerialIds.add(serial.id);
            } else {
                this.selectedSerialIds.delete(serial.id);
            }
        });

        this.refreshFilteredSerialNumbers();
    }

    handleSerialChange(event) {
        const serialId = event.target.dataset.id;
        const checked = event.target.checked;

        this.serialNumbers = this.serialNumbers.map(serial => {
            if (serial.id === serialId) {
                return {
                    ...serial,
                    selected: checked
                };
            }

            return serial;
        });

        if (checked) {
            this.selectedSerialIds.add(serialId);
        } else {
            this.selectedSerialIds.delete(serialId);
        }

        this.refreshFilteredSerialNumbers();
    }

    refreshFilteredSerialNumbers() {
        if (!this.searchTerm) {
            this.filteredSerialNumbers = [...this.serialNumbers];
            return;
        }

        this.filteredSerialNumbers = this.serialNumbers.filter(serial =>
            (serial.serialNumber || '')
                .toLowerCase()
                .includes(this.searchTerm)
        );
    }

    get allSelected() {
        return this.serialNumbers.length > 0 &&
            this.serialNumbers.every(serial => serial.selected);
    }

    get selectedCount() {
        return this.selectedSerialIds.size;
    }

    get hasSerialNumbers() {
        return this.serialNumbers.length > 0;
    }

    get hasNoSerialNumbers() {
        return this.selectedAssetId && this.serialNumbers.length === 0;
    }

    get saveDisabled() {
        return !this.selectedAssetId ||
            this.selectedSerialIds.size === 0 ||
            this.isSaving;
    }

    async handleSave() {
        if (!this._recordId) {
            this.showToast(
                'Error',
                'Case Id could not be determined.',
                'error'
            );
            return;
        }

        if (!this.selectedAssetId) {
            this.showToast(
                'Error',
                'Please select an Asset.',
                'error'
            );
            return;
        }

        if (this.selectedSerialIds.size === 0) {
            this.showToast(
                'Error',
                'Please select at least one Serial Number.',
                'error'
            );
            return;
        }

        this.isSaving = true;

        try {
            await saveTaggedAsset({
                caseId: this._recordId,
                assetId: this.selectedAssetId,
                serialNumberIds: Array.from(this.selectedSerialIds)
            });

            this.showToast(
                'Success',
                'Asset tagged successfully.',
                'success'
            );

            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showError(error);
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
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

    showError(error) {
        let message = 'An unexpected error occurred.';

        if (error?.body?.message) {
            message = error.body.message;
        } else if (error?.message) {
            message = error.message;
        }

        this.showToast(
            'Error',
            message,
            'error'
        );
    }
}