import { LightningElement, api, track } from 'lwc';

export default class CustomPicklistModal extends LightningElement {

    @api options = [];
    @api selected;
    @api label = 'Select';

    @track searchTerm = '';

    get filteredOptions() {
        const opts = this.options || [];
        const term = this.searchTerm.toLowerCase();

        return opts
            .filter(o => !term || (o.label || '').toLowerCase().includes(term))
            .map(o => ({
                ...o,
                selected: o.value === this.selected
            }));
    }

    get noResults() {
        return this.filteredOptions.length === 0;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
    }

    selectOption(event) {
        const value = event.currentTarget.dataset.value;

        this.dispatchEvent(
            new CustomEvent('save', { detail: value })
        );
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleBackdropClick(e) {
        if (e.target.classList.contains('backdrop')) {
            this.handleClose();
        }
    }
}