import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

import getOrderDetails from '@salesforce/apex/Ctrl_AddSrtOrderDetailsToOrder.getOrderDetails';
import searchIncoterms from '@salesforce/apex/Ctrl_AddSrtOrderDetailsToOrder.searchIncoterms';
import saveOrderDetails from '@salesforce/apex/Ctrl_AddSrtOrderDetailsToOrder.saveOrderDetails';

export default class LwcAddSrtOrderDetails extends LightningElement {
    @api recordId;

    @track incotermOptions = [];

    selectedIncoterm = null;
    incotermSearchKey = '';

    salesOffice = 'COP1';
    salesGroup = 'DC1';

    isLoading = false;
    isSaving = false;

    showIncotermDropdown = false;
    incotermError = '';

    searchTimeout;

    connectedCallback() {
        this.loadInitialData();
    }

    get hasSelectedIncoterm() {
        return this.selectedIncoterm !== null && this.selectedIncoterm !== undefined;
    }

    get hasIncotermOptions() {
        return this.incotermOptions && this.incotermOptions.length > 0;
    }

    get saveButtonLabel() {
        return this.isSaving ? 'Saving...' : 'Save Details';
    }

    get disableSave() {
        return this.isLoading || this.isSaving;
    }

    async loadInitialData() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;

        try {
            const result = await getOrderDetails({
                orderId: this.recordId
            });

            if (result) {
                this.salesOffice = result.salesOffice || 'COP1';
                this.salesGroup = result.salesGroup || 'DC1';

                if (result.incotermValue) {
                    this.selectedIncoterm = {
                        id: result.incotermId,
                        value: result.incotermValue,
                        label: result.incotermLabel || result.incotermValue,
                        detail: result.incotermDetail || ''
                    };

                    this.incotermSearchKey = this.selectedIncoterm.label;
                }
            }

            await this.loadIncoterms('');
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadIncoterms(searchKey) {
        try {
            const result = await searchIncoterms({
                searchKey: searchKey || ''
            });

            this.incotermOptions = result || [];
        } catch (error) {
            this.incotermOptions = [];
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    handleIncotermFocus() {
        if (!this.hasSelectedIncoterm) {
            this.showIncotermDropdown = true;
            this.loadIncoterms(this.incotermSearchKey);
        }
    }

    handleIncotermSearchInput(event) {
        this.incotermSearchKey = event.target.value;
        this.incotermError = '';
        this.showIncotermDropdown = true;

        window.clearTimeout(this.searchTimeout);

        this.searchTimeout = window.setTimeout(() => {
            this.loadIncoterms(this.incotermSearchKey);
        }, 250);
    }

    handleSearchBlur() {
        window.setTimeout(() => {
            this.showIncotermDropdown = false;
        }, 250);
    }

    handleIncotermSelect(event) {
        const selectedId = event.currentTarget.dataset.id;

        const selectedRecord = this.incotermOptions.find((item) => {
            return item.id === selectedId;
        });

        if (selectedRecord) {
            this.selectedIncoterm = selectedRecord;
            this.incotermSearchKey = selectedRecord.label;
            this.incotermError = '';
        }

        this.showIncotermDropdown = false;
    }

    clearIncoterm() {
        this.selectedIncoterm = null;
        this.incotermSearchKey = '';
        this.incotermError = '';
        this.showIncotermDropdown = true;

        this.loadIncoterms('');
    }

    handleSalesOfficeChange(event) {
        this.salesOffice = event.target.value;
    }

    handleSalesGroupChange(event) {
        this.salesGroup = event.target.value;
    }

    async handleSave() {
        const inputFields = this.template.querySelectorAll('lightning-input');
        let inputsValid = true;

        inputFields.forEach((inputCmp) => {
            inputCmp.reportValidity();

            if (!inputCmp.checkValidity()) {
                inputsValid = false;
            }
        });

        if (!this.hasSelectedIncoterm) {
            this.incotermError = 'Please select an Incoterms value.';
        }

        if (!inputsValid || !this.hasSelectedIncoterm) {
            return;
        }

        this.isSaving = true;

        try {
            await saveOrderDetails({
                orderId: this.recordId,
                incotermsValue: this.selectedIncoterm.value,
                salesOffice: this.salesOffice,
                salesGroup: this.salesGroup
            });

            this.showToast('Success', 'SRT Order details updated successfully.', 'success');

            notifyRecordUpdateAvailable([
                {
                    recordId: this.recordId
                }
            ]);

            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
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
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }

        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}