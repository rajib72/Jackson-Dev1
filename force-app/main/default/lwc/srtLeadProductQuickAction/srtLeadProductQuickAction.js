import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

import getProductMasterRows from '@salesforce/apex/SRTLeadProductController.getProductMasterRows';
import saveLeadProduct from '@salesforce/apex/SRTLeadProductController.saveLeadProduct';

export default class SrtLeadProductQuickAction extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track isLoading = false;
    @track masterRows = [];
    @track productOptions = [];
    @track moduleTypeOptions = [];
    @track moduleTechnologyOptions = [];
    @track subModuleOptions = [];

    productValue = '';
    moduleTypeValue = '';
    moduleTechnologyValue = '';
    subModuleValue = '';
    projectCapacityValue = null;
    uomValue = '';

    connectedCallback() {
        this.loadMasterData();
    }

    get currentLeadId() {
        const url = new URL(window.location.href);
        return (
            this.recordId ||
            url.searchParams.get('c__leadId') ||
            url.searchParams.get('recordId') ||
            null
        );
    }

    get isSolar() {
        return (this.productValue || '').toLowerCase() === 'solar';
    }

    get isBess() {
        return (this.productValue || '').toLowerCase() === 'bess';
    }

    get showCapacitySection() {
        return !!this.productValue;
    }

    get disableModuleTechnology() {
        return !this.moduleTypeValue;
    }

    get showSubModule() {
        return this.isSolar && this.subModuleOptions.length > 0;
    }

    get uomOptions() {
        if (this.isBess) {
            return [
                { label: 'KWH', value: 'KWH' },
                { label: 'MWH', value: 'MWH' }
            ];
        }

        if (this.isSolar) {
            return [
                { label: 'KW', value: 'KW' },
                { label: 'MW', value: 'MW' }
            ];
        }

        return [];
    }

    loadMasterData() {
        this.isLoading = true;

        getProductMasterRows()
            .then((result) => {
                this.masterRows = result || [];
                this.productOptions = this.buildOptions(
                    this.masterRows.map(row => row.product)
                );
            })
            .catch((error) => {
                this.showToast('Error', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    buildOptions(values) {
        const uniqueValues = [...new Set(
            (values || []).filter(value => value !== null && value !== undefined && value !== '')
        )];

        uniqueValues.sort((a, b) => a.localeCompare(b));

        return uniqueValues.map(value => ({
            label: value,
            value: value
        }));
    }

    handleProductChange(event) {
        this.productValue = event.detail.value;

        this.moduleTypeValue = '';
        this.moduleTechnologyValue = '';
        this.subModuleValue = '';
        this.projectCapacityValue = null;
        this.uomValue = '';

        this.moduleTypeOptions = [];
        this.moduleTechnologyOptions = [];
        this.subModuleOptions = [];

        if (this.isSolar) {
            const filteredRows = this.masterRows.filter(
                row => row.product === this.productValue
            );

            this.moduleTypeOptions = this.buildOptions(
                filteredRows.map(row => row.moduleType)
            );
        }
    }

    handleModuleTypeChange(event) {
        this.moduleTypeValue = event.detail.value;
        this.moduleTechnologyValue = '';
        this.subModuleValue = '';

        this.moduleTechnologyOptions = [];
        this.subModuleOptions = [];

        const filteredRows = this.masterRows.filter(
            row =>
                row.product === this.productValue &&
                row.moduleType === this.moduleTypeValue
        );

        this.moduleTechnologyOptions = this.buildOptions(
            filteredRows.map(row => row.moduleTechnology)
        );
    }

    handleModuleTechnologyChange(event) {
        this.moduleTechnologyValue = event.detail.value;
        this.subModuleValue = '';
        this.subModuleOptions = [];

        const filteredRows = this.masterRows.filter(
            row =>
                row.product === this.productValue &&
                row.moduleType === this.moduleTypeValue &&
                row.moduleTechnology === this.moduleTechnologyValue
        );

        this.subModuleOptions = this.buildOptions(
            filteredRows.map(row => row.subModule)
        );
    }

    handleSubModuleChange(event) {
        this.subModuleValue = event.detail.value;
    }

    handleProjectCapacityChange(event) {
        this.projectCapacityValue = event.detail.value;
    }

    handleUomChange(event) {
        this.uomValue = event.detail.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSave() {
        const leadId = this.currentLeadId;

        if (!leadId) {
            this.showToast('Error', 'Lead Id is missing.', 'error');
            return;
        }

        if (!this.validateForm()) {
            return;
        }

        this.isLoading = true;

        saveLeadProduct({
            leadId: leadId,
            product: this.productValue,
            moduleType: this.isSolar ? this.moduleTypeValue : null,
            moduleTechnology: this.isSolar ? this.moduleTechnologyValue : null,
            subModule: this.isSolar ? this.subModuleValue : null,
            projectCapacity: this.projectCapacityValue,
            uom: this.uomValue
        })
            .then(() => {
                this.showToast('Success', 'Lead Product created successfully.', 'success');
                this.dispatchEvent(new RefreshEvent());

                  notifyRecordUpdateAvailable([{ recordId: leadId }]);
    this.dispatchEvent(new RefreshEvent());

    setTimeout(() => {
        this.dispatchEvent(new CloseActionScreenEvent());
    }, 300);
            })
            .catch((error) => {
                this.showToast('Error', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    validateForm() {
        let isValid = true;

        const allFields = this.template.querySelectorAll('lightning-input, lightning-combobox');
        if (allFields) {
            allFields.forEach(field => {
                if (!field.checkValidity()) {
                    field.reportValidity();
                    isValid = false;
                }
            });
        }

        return isValid;
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