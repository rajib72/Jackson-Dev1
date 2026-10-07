import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

import getInitData from '@salesforce/apex/OpportunityProductQuickActionController.getInitData';
import createOpportunityProduct from '@salesforce/apex/OpportunityProductQuickActionController.createOpportunityProduct';
import JaksonLogo from '@salesforce/resourceUrl/JaksonLogo';

export default class OpportunityProductQuickAction extends LightningElement {
    @api recordId; // Opportunity Id
    jaksonLogo = JaksonLogo;

    allProductRows = [];

    @track moduleTypeOptions = [];
    @track cellTypeOptions = [];
    @track moduleTechnologyOptions = [];
    @track productRatingOptions = [];
    @track productSubTypeOptions = [];
    @track warrantyOptions = [];
    @track cableLengthOptions = [];

    moduleType = '';
    cellType = '';
    moduleTechnology = '';
    productRatingBin = '';
    productSubType = '';
    warranty = '';
    cableLength = '400';

    // NEW
    projectCapacity = null;
    uom = '';
    uomOptions = [
        { label: 'KW', value: 'KW' },
        { label: 'MW', value: 'MW' }
    ];

    isLoading = false;

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        try {
            const result = await getInitData();

            this.allProductRows = result.productRows || [];
            this.warrantyOptions = result.warrantyOptions || [];
            this.cableLengthOptions = result.cableLengthOptions || [];

            this.moduleTypeOptions = this.buildOptions(
                this.allProductRows.map(row => row.moduleType)
            );

            this.cellTypeOptions = [];
            this.moduleTechnologyOptions = [];
            this.productRatingOptions = [];
            this.productSubTypeOptions = [];

            const has400 = (this.cableLengthOptions || []).some(opt => opt.value === '400');
            if (!has400) {
                this.cableLength = '';
            }
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleChange(event) {
        const fieldName = event.target.dataset.field;
        const value = event.detail.value;

        this[fieldName] = value;

        if (fieldName === 'moduleType') {
            this.cellType = '';
            this.moduleTechnology = '';
            this.productRatingBin = '';
            this.productSubType = '';

            this.cellTypeOptions = this.buildOptions(
                this.allProductRows
                    .filter(row => row.moduleType === this.moduleType)
                    .map(row => row.cellType)
            );

            this.moduleTechnologyOptions = [];
            this.productRatingOptions = [];
            this.productSubTypeOptions = [];
        }

        if (fieldName === 'cellType') {
            this.moduleTechnology = '';
            this.productRatingBin = '';
            this.productSubType = '';

            this.moduleTechnologyOptions = this.buildOptions(
                this.allProductRows
                    .filter(row =>
                        row.moduleType === this.moduleType &&
                        row.cellType === this.cellType
                    )
                    .map(row => row.moduleTechnology)
            );

            this.productRatingOptions = [];
            this.productSubTypeOptions = [];
        }

        if (fieldName === 'moduleTechnology') {
            this.productRatingBin = '';
            this.productSubType = '';

            this.productRatingOptions = this.buildOptions(
                this.allProductRows
                    .filter(row =>
                        row.moduleType === this.moduleType &&
                        row.cellType === this.cellType &&
                        row.moduleTechnology === this.moduleTechnology
                    )
                    .map(row => row.productRatingBin)
            );

            this.productSubTypeOptions = [];
        }

        if (fieldName === 'productRatingBin') {
            this.productSubType = '';

            this.productSubTypeOptions = this.buildOptions(
                this.allProductRows
                    .filter(row =>
                        row.moduleType === this.moduleType &&
                        row.cellType === this.cellType &&
                        row.moduleTechnology === this.moduleTechnology &&
                        row.productRatingBin === this.productRatingBin
                    )
                    .map(row => row.productSubType)
            );
        }
    }

    buildOptions(values) {
        const uniqueValues = [...new Set((values || []).filter(v => v && v.trim() !== ''))];
        uniqueValues.sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
        return uniqueValues.map(value => ({
            label: value,
            value: value
        }));
    }

    get isCellTypeDisabled() {
        return !this.moduleType;
    }

    get isModuleTechnologyDisabled() {
        return !this.moduleType || !this.cellType;
    }

    get isProductRatingDisabled() {
        return !this.moduleType || !this.cellType || !this.moduleTechnology;
    }

    get isProductSubTypeDisabled() {
        return !this.moduleType || !this.cellType || !this.moduleTechnology || !this.productRatingBin;
    }

    validateFields() {
        return !!(
            this.moduleType &&
            this.cellType &&
            this.moduleTechnology &&
            this.productRatingBin &&
            this.productSubType &&
            this.projectCapacity !== null &&
            this.projectCapacity !== '' &&
            Number(this.projectCapacity) > 0 &&
            this.uom
        );
    }

    async handleSave() {
        if (!this.validateFields()) {
    this.showToast(
        'Error',
        'Please fill all required product fields. Project Capacity must be greater than 0.',
        'error'
    );
    return;
}

        this.isLoading = true;
        try {
            await createOpportunityProduct({
                opportunityId: this.recordId,
                moduleType: this.moduleType,
                cellType: this.cellType,
                moduleTechnology: this.moduleTechnology,
                productRatingBin: this.productRatingBin,
                productSubType: this.productSubType,
                warranty: this.warranty,
                cableLength: this.cableLength,
                projectCapacity: this.projectCapacity,
                uom: this.uom
            });

            this.showToast('Success', 'Opportunity Product created successfully.', 'success');

            getRecordNotifyChange([{ recordId: this.recordId }]);
            this.dispatchEvent(new RefreshEvent());

            setTimeout(() => {
                this.dispatchEvent(new CloseActionScreenEvent());
            }, 300);

        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
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

    reduceError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return error?.message || 'Unknown error';
    }
}