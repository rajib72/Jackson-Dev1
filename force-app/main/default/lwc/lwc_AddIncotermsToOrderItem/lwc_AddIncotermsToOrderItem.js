import { LightningElement, api } from 'lwc';

import getIncotermsOptions
    from '@salesforce/apex/Ctrl_OrderItemIncotermsSelector.getIncotermsOptions';

import {
    updateRecord,
    notifyRecordUpdateAvailable
} from 'lightning/uiRecordApi';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import ID_FIELD from '@salesforce/schema/OrderItem.Id';
import INCOTERMS_FIELD from '@salesforce/schema/OrderItem.InCoTerms__c';

export default class OrderItemIncotermsSelector extends LightningElement {
    @api recordId;

    incotermsOptions = [];
    filteredOptions = [];

    selectedIncoterms = '';
    selectedIncotermsDetails = '';
    searchKey = '';

    isLoading = false;
    isSaving = false;
    isDropdownOpen = false;

    errorMessage = '';

    blurTimeout;

    connectedCallback() {
        this.loadIncoterms();
    }

    get hasOptions() {
        return (
            Array.isArray(this.incotermsOptions) &&
            this.incotermsOptions.length > 0
        );
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    get showDropdown() {
        return (
            this.isDropdownOpen &&
            Array.isArray(this.filteredOptions) &&
            this.filteredOptions.length > 0
        );
    }

    get showNoResults() {
        return (
            this.isDropdownOpen &&
            Boolean((this.searchKey || '').trim()) &&
            this.hasOptions &&
            this.filteredOptions.length === 0
        );
    }

    get isSaveDisabled() {
        return (
            this.isLoading ||
            this.isSaving ||
            !this.selectedIncoterms
        );
    }

    get isActionDisabled() {
        return this.isLoading || this.isSaving;
    }

    /**
     * Loads all active Incoterms Master records.
     */
    async loadIncoterms() {
        this.isLoading = true;
        this.errorMessage = '';

        this.resetSelection();

        this.incotermsOptions = [];
        this.filteredOptions = [];

        try {
            const result = await getIncotermsOptions();

            const returnedOptions = Array.isArray(result)
                ? result
                : [];

            this.incotermsOptions = returnedOptions.map(
                (item, index) => {
                    const value = String(
                        item.value || ''
                    ).trim();

                    const details = String(
                        item.details || ''
                    ).trim();

                    const label =
                        item.label ||
                        (
                            details
                                ? `${details} - ${value}`
                                : value
                        );

                    return {
                        key: item.recordId || `${value}-${index}`,
                        recordId: item.recordId,
                        value,
                        details,
                        label,
                        searchText: this.normalizeSearchText(
                            `${value} ${details} ${label}`
                        )
                    };
                }
            );

            this.filteredOptions = [
                ...this.incotermsOptions
            ];

            /*
             * Automatically select when only one value exists.
             */
            if (this.incotermsOptions.length === 1) {
                const onlyOption =
                    this.incotermsOptions[0];

                this.selectedIncoterms =
                    onlyOption.value;

                this.selectedIncotermsDetails =
                    onlyOption.details;

                this.searchKey =
                    onlyOption.label;
            }
        } catch (error) {
            this.errorMessage =
                this.reduceError(error);

            this.showToast(
                'Error',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Filters the available values while the user types.
     */
    handleSearchChange(event) {
        const inputValue =
            event?.target?.value ??
            event?.detail?.value ??
            '';

        this.searchKey =
            inputValue || '';

        /*
         * The user must select a record from the result list.
         */
        this.selectedIncoterms = '';
        this.selectedIncotermsDetails = '';

        this.errorMessage = '';

        this.filterOptions(
            this.searchKey
        );

        this.isDropdownOpen = true;
    }

    /**
     * Opens the list when the search field receives focus.
     */
    handleSearchFocus() {
        this.clearBlurTimeout();

        if (!this.hasOptions) {
            return;
        }

        /*
         * When a value is already selected, show the full list
         * so the user can easily select another value.
         */
        if (this.selectedIncoterms) {
            this.filteredOptions = [
                ...this.incotermsOptions
            ];
        } else {
            this.filterOptions(
                this.searchKey
            );
        }

        this.isDropdownOpen = true;
    }

    /**
     * Delays closing so a result can be selected first.
     */
    handleSearchBlur() {
        this.clearBlurTimeout();

        this.blurTimeout = window.setTimeout(() => {
            this.isDropdownOpen = false;
        }, 250);
    }

    /**
     * Prevents the search input blur from removing the list
     * before the clicked option is selected.
     */
    handleDropdownMouseDown(event) {
        event.preventDefault();
        this.clearBlurTimeout();
    }

    /**
     * Selects one Incoterms option.
     */
    handleOptionSelect(event) {
        this.clearBlurTimeout();

        const selectedKey =
            event.currentTarget.dataset.key;

        const selectedOption =
            this.incotermsOptions.find(
                option => option.key === selectedKey
            );

        if (!selectedOption) {
            return;
        }

        this.selectedIncoterms =
            selectedOption.value;

        this.selectedIncotermsDetails =
            selectedOption.details;

        this.searchKey =
            selectedOption.label;

        this.filteredOptions = [
            ...this.incotermsOptions
        ];

        this.isDropdownOpen = false;
        this.errorMessage = '';
    }

    /**
     * Filters using code, details, or full label.
     */
    filterOptions(searchValue) {
        const normalizedSearch =
            this.normalizeSearchText(
                searchValue
            );

        if (!normalizedSearch) {
            this.filteredOptions = [
                ...this.incotermsOptions
            ];

            return;
        }

        this.filteredOptions =
            this.incotermsOptions.filter(
                option =>
                    this.doesOptionMatch(
                        option,
                        normalizedSearch
                    )
            );
    }

    /**
     * Supports:
     * 1. Partial code search
     * 2. Partial details search
     * 3. Case-insensitive search
     * 4. One-character typing differences
     */
    doesOptionMatch(
        option,
        normalizedSearch
    ) {
        const optionSearchText =
            option.searchText || '';

        /*
         * Standard partial match.
         *
         * Examples:
         * EXW matches EXW.
         * free matches Free Carrier.
         */
        if (
            optionSearchText.includes(
                normalizedSearch
            )
        ) {
            return true;
        }

        const searchWords =
            normalizedSearch
                .split(' ')
                .filter(Boolean);

        const optionWords =
            optionSearchText
                .split(' ')
                .filter(Boolean);

        return searchWords.every(
            searchWord =>
                optionWords.some(
                    optionWord => {
                        if (
                            optionWord.includes(searchWord) ||
                            searchWord.includes(optionWord)
                        ) {
                            return true;
                        }

                        /*
                         * Allow one-character mistakes only for
                         * words of four or more characters.
                         */
                        if (
                            searchWord.length >= 4 &&
                            optionWord.length >= 4
                        ) {
                            return (
                                this.calculateEditDistance(
                                    searchWord,
                                    optionWord
                                ) <= 1
                            );
                        }

                        return false;
                    }
                )
        );
    }

    /**
     * Converts values into a common searchable format.
     */
    normalizeSearchText(value) {
        return String(value || '')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    /**
     * Calculates character differences for typo tolerance.
     */
    calculateEditDistance(
        firstValue,
        secondValue
    ) {
        const first = firstValue || '';
        const second = secondValue || '';

        const firstLength = first.length;
        const secondLength = second.length;

        if (
            Math.abs(
                firstLength - secondLength
            ) > 1
        ) {
            return 2;
        }

        const matrix = [];

        for (
            let row = 0;
            row <= secondLength;
            row++
        ) {
            matrix[row] = [row];
        }

        for (
            let column = 0;
            column <= firstLength;
            column++
        ) {
            matrix[0][column] = column;
        }

        for (
            let row = 1;
            row <= secondLength;
            row++
        ) {
            for (
                let column = 1;
                column <= firstLength;
                column++
            ) {
                const charactersMatch =
                    second.charAt(row - 1) ===
                    first.charAt(column - 1);

                const substitutionCost =
                    charactersMatch ? 0 : 1;

                matrix[row][column] = Math.min(
                    matrix[row - 1][column] + 1,
                    matrix[row][column - 1] + 1,
                    matrix[row - 1][column - 1] +
                        substitutionCost
                );
            }
        }

        return matrix[secondLength][firstLength];
    }

    /**
     * Updates OrderItem.InCoTerms__c.
     */
    async handleSave() {
        if (!this.selectedIncoterms) {
            this.showToast(
                'Validation Error',
                'Please select an InCoTerms value from the search results.',
                'warning'
            );

            return;
        }

        if (!this.recordId) {
            this.showToast(
                'Error',
                'Order Item Id is not available.',
                'error'
            );

            return;
        }

        this.isSaving = true;
        this.errorMessage = '';
        this.isDropdownOpen = false;

        const fields = {};

        fields[ID_FIELD.fieldApiName] =
            this.recordId;

        fields[INCOTERMS_FIELD.fieldApiName] =
            this.selectedIncoterms;

        try {
            await updateRecord({
                fields
            });

            await notifyRecordUpdateAvailable([
                {
                    recordId: this.recordId
                }
            ]);

            this.showToast(
                'Success',
                'InCoTerms saved successfully on the Order Product.',
                'success'
            );

            this.dispatchEvent(
                new CloseActionScreenEvent()
            );
        } catch (error) {
            this.errorMessage =
                this.reduceError(error);

            this.showToast(
                'Error',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }

    resetSelection() {
        this.selectedIncoterms = '';
        this.selectedIncotermsDetails = '';
        this.searchKey = '';
        this.isDropdownOpen = false;
    }

    clearBlurTimeout() {
        if (this.blurTimeout) {
            window.clearTimeout(
                this.blurTimeout
            );

            this.blurTimeout = null;
        }
    }

    reduceError(error) {
        if (!error) {
            return 'Unknown error occurred.';
        }

        if (Array.isArray(error.body)) {
            return error.body
                .map(item => item.message)
                .filter(Boolean)
                .join(', ');
        }

        if (
            error.body &&
            typeof error.body.message === 'string'
        ) {
            return error.body.message;
        }

        if (
            typeof error.message === 'string'
        ) {
            return error.message;
        }

        return 'Unknown error occurred.';
    }

    showToast(
        title,
        message,
        variant
    ) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    disconnectedCallback() {
        this.clearBlurTimeout();
    }
}