import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getOpportunityProducts from '@salesforce/apex/API_Ctrl_MDMMaterialCreation.getOpportunityProducts';
import createMaterialDrafts from '@salesforce/apex/API_Ctrl_MDMMaterialCreation.createMaterialDrafts';

const MATERIAL_TYPE = 'FG';

export default class Lwc_MDMMaterialCreation extends LightningElement {
    _recordId;
    @track products = [];
    isLoading = false;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        if (value && value !== this._recordId) {
            this._recordId = value;
            this.fetchProducts();
        }
    }

    fetchProducts() {
        this.isLoading = true;

        getOpportunityProducts({ opportunityId: this.recordId })
            .then(result => {
                this.products = result.map(item => {
                    let disabled = false;
                    let reason = '';

                    if (item.Material_Master__c) {
                        disabled = true;
                        reason = 'Parent Material Exists';
                    } else if (item.Sent_To_MDM__c) {
                        disabled = true;
                        reason = 'Sent to MDM';
                    } else if (item.Tried_To_Tag_Material_Master__c === false) {
                        disabled = true;
                        reason = 'Never searched For Material Master';
                    }

                    return {
                        ...item,
                        Material_Type__c: MATERIAL_TYPE,
                        isSelected: false,
                        isDisabled: disabled,
                        disabledReason: reason
                    };
                });
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error?.body?.message || 'Unable to fetch Opportunity Products.',
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasProducts() {
        return this.products && this.products.length > 0;
    }

    get availableCount() {
        return this.products.filter(prod => !prod.isDisabled).length;
    }

    get disableCreate() {
        const hasSelection = this.products.some(prod => prod.isSelected);
        return !this.hasProducts || !hasSelection || this.isLoading;
    }

    handleInputChange(event) {
        const index = Number(event.target.dataset.index);

        this.products = this.products.map((product, productIndex) => {
            if (productIndex !== index) {
                return product;
            }

            return {
                ...product,
                isSelected: event.target.checked
            };
        });
    }

    handleCreate() {
        const selectedProducts = this.products.filter(
            prod => prod.isSelected && !prod.isDisabled
        );

        if (!selectedProducts.length) {
            this.showToast(
                'Validation Error',
                'Please select at least one available product.',
                'error'
            );
            return;
        }

        const payload = selectedProducts.map(prod => ({
            Id: prod.Id,
            MaterialType: MATERIAL_TYPE,
            Material_Desc: prod.Material_Description__c || ''
        }));

        this.isLoading = true;

        createMaterialDrafts({ materials: payload })
            .then(result => {
                if (result === 'Success') {
                    this.showToast(
                        'Success',
                        'Selected Material drafts created successfully in MDM!',
                        'success'
                    );
                    this.closeAction();
                } else {
                    this.showToast('MDM Processing Notice', result, 'warning');
                    this.fetchProducts();
                }
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error?.body?.message || 'Unknown network error',
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}