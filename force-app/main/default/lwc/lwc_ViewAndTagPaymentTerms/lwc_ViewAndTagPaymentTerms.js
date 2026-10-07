import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import fetchPaymentTerms from '@salesforce/apex/Ctrl_OrderPaymentTermSelection.fetchPaymentTerms';
import saveSelectedPaymentTerm from '@salesforce/apex/Ctrl_OrderPaymentTermSelection.saveSelectedPaymentTerm';

export default class Lwc_ViewAndTagPaymentTerms extends LightningElement {
    _recordId;

    @track termOptions = [];
    @track filteredOptions = [];
    @track searchKey = '';
    @track selectedTermCode = '';
    @track selectedTermDesc = '';
    @track isLoading = false;
    @track hasData = false;
    @track dataLoaded = false;
    @track showDropdown = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value && !this.dataLoaded) {
            this.dataLoaded = true;
            this.loadTerms();
        }
    }

    get isSaveDisabled() {
        return this.isLoading || !this.selectedTermCode;
    }

    get noRecordsFound() {
        return this.showDropdown && !this.isLoading && this.filteredOptions.length === 0;
    }

    get hasSelectedTerm() {
        return !!this.selectedTermCode;
    }

    async loadTerms() {
        if (!this.recordId) return;

        this.isLoading = true;
        this.hasData = false;
        this.termOptions = [];
        this.filteredOptions = [];
        this.searchKey = '';
        this.selectedTermCode = '';
        this.selectedTermDesc = '';
        this.showDropdown = false;

        try {
            const result = await fetchPaymentTerms({ orderId: this.recordId });

            if (result && result.length > 0) {
                this.termOptions = result.map((item) => ({
                    ...item,
                    isSelected: false,
                    cssClass: 'dropdown-item'
                }));

                // If only one option returns from SAP, auto-select it for convenience
                if (this.termOptions.length === 1) {
                    this.selectTerm(this.termOptions[0].termCode, this.termOptions[0].termDesc);
                } else {
                    this.filteredOptions = [...this.termOptions];
                }
                this.hasData = true;
            } else {
                this.showToast('Info', 'No Payment Terms returned from SAP.', 'info');
            }
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSearchFocus() {
        this.showDropdown = true;
        this.filterTerms();
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value || '';
        this.showDropdown = true;
        this.filterTerms();
    }

    filterTerms() {
        const key = this.searchKey.trim().toLowerCase();

        let filtered = [];
        if (!key) {
            filtered = [...this.termOptions];
        } else {
            filtered = this.termOptions.filter((item) => {
                const code = (item.termCode || '').toLowerCase();
                const desc = (item.termDesc || '').toLowerCase();
                return code.includes(key) || desc.includes(key);
            });
        }

        this.filteredOptions = filtered.map((item) => {
            const isSelected = item.termCode === this.selectedTermCode;
            return {
                ...item,
                isSelected,
                cssClass: isSelected ? 'dropdown-item selected-item' : 'dropdown-item'
            };
        });
    }

    handleSelectTerm(event) {
        const code = event.currentTarget.dataset.code;
        const name = event.currentTarget.dataset.name;
        this.selectTerm(code, name);
    }

    selectTerm(code, desc) {
        this.selectedTermCode = code;
        this.selectedTermDesc = desc;
        this.searchKey = `${code} - ${desc}`;
        this.showDropdown = false;
        this.filterTerms();
    }

    handleClearSelection() {
        this.selectedTermCode = '';
        this.selectedTermDesc = '';
        this.searchKey = '';
        this.showDropdown = true;
        this.filterTerms();
    }

    async handleSave() {
        if (!this.selectedTermCode) {
            this.showToast('Error', 'Please select a Payment Term.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const message = await saveSelectedPaymentTerm({
                orderId: this.recordId,
                termCode: this.selectedTermCode,
                termDesc: this.selectedTermDesc
            });

            this.showToast('Success', message, 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadTerms();
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    reduceError(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}