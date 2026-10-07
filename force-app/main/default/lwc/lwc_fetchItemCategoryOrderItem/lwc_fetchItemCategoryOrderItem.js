import { LightningElement, api } from 'lwc';

import fetchItemCategories
    from '@salesforce/apex/API_ctrl_OrderItemCategoryController.fetchItemCategories';

import saveItemCategory
    from '@salesforce/apex/API_ctrl_OrderItemCategoryController.saveItemCategory';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

export default class OrderItemCategorySelector extends LightningElement {
    @api recordId;

    itemCategoryOptions = [];
    filteredItemCategoryOptions = [];

    selectedItemCategory = '';
    searchKey = '';

    isLoading = false;
    isSaving = false;
    isDropdownOpen = false;

    errorMessage = '';

    blurTimeout;
    hasInitialLoadCompleted = false;

    connectedCallback() {
        this.loadItemCategories();
    }

    get hasOptions() {
        return (
            Array.isArray(this.itemCategoryOptions) &&
            this.itemCategoryOptions.length > 0
        );
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    get showDropdown() {
        return (
            this.isDropdownOpen &&
            Array.isArray(this.filteredItemCategoryOptions) &&
            this.filteredItemCategoryOptions.length > 0
        );
    }

    get showNoResults() {
        return (
            this.isDropdownOpen &&
            Boolean((this.searchKey || '').trim()) &&
            this.hasOptions &&
            this.filteredItemCategoryOptions.length === 0
        );
    }

    get isSaveDisabled() {
        return (
            this.isLoading ||
            this.isSaving ||
            !this.selectedItemCategory
        );
    }

    get isRefreshDisabled() {
        return this.isLoading || this.isSaving;
    }

    /**
     * Fetch Item Categories from SAP.
     */
    async loadItemCategories() {
        if (!this.recordId) {
            this.errorMessage = 'Order Item Id is not available.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        this.resetSelection();

        this.itemCategoryOptions = [];
        this.filteredItemCategoryOptions = [];

        try {
            const result = await fetchItemCategories({
                orderItemId: this.recordId
            });

            if (result && result.success) {
                const returnedOptions = Array.isArray(result.options)
                    ? result.options
                    : [];

                this.itemCategoryOptions = returnedOptions.map(
                    (item, index) => {
                        const value = item.value || '';
                        const label = item.label || value;

                        return {
                            key: `${value}-${index}`,
                            value,
                            label,
                            searchText: this.normalizeSearchText(
                                `${value} ${label}`
                            )
                        };
                    }
                );

                this.filteredItemCategoryOptions = [
                    ...this.itemCategoryOptions
                ];

                /*
                 * Automatically select the value when SAP
                 * returns only one Item Category.
                 */
                if (this.itemCategoryOptions.length === 1) {
                    const onlyOption =
                        this.itemCategoryOptions[0];

                    this.selectedItemCategory =
                        onlyOption.value;

                    this.searchKey =
                        onlyOption.label;
                }

                this.showToast(
                    'Success',
                    result.message ||
                        'Item Categories fetched successfully.',
                    'success'
                );
            } else {
                this.errorMessage =
                    result && result.message
                        ? result.message
                        : 'No Item Category found from SAP.';
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
            this.hasInitialLoadCompleted = true;
        }
    }

    /**
     * Filter while the user enters text.
     */
    handleCategorySearch(event) {
        const inputValue =
            event && event.target
                ? event.target.value
                : '';

        this.searchKey = inputValue || '';

        /*
         * Clear the previous selection when the text changes.
         * The user must select a result from the dropdown.
         */
        this.selectedItemCategory = '';
        this.errorMessage = '';

        this.filterItemCategories(
            this.searchKey
        );

        this.isDropdownOpen = true;
    }

    /**
     * Open the dropdown when the search input receives focus.
     */
    handleSearchFocus() {
        this.clearBlurTimeout();

        if (!this.hasOptions) {
            return;
        }

        /*
         * When an option is already selected, show all values
         * so the user can easily select another one.
         */
        if (this.selectedItemCategory) {
            this.filteredItemCategoryOptions = [
                ...this.itemCategoryOptions
            ];
        } else {
            this.filterItemCategories(
                this.searchKey
            );
        }

        this.isDropdownOpen = true;
    }

    /**
     * Delay dropdown closure to allow the click event
     * on a result to complete.
     */
    handleSearchBlur() {
        this.clearBlurTimeout();

        this.blurTimeout = window.setTimeout(() => {
            this.isDropdownOpen = false;
        }, 250);
    }

    /**
     * Keep the dropdown open while the user clicks a result.
     */
    handleDropdownMouseDown(event) {
        event.preventDefault();
        this.clearBlurTimeout();
    }

    /**
     * Select an Item Category from the dropdown.
     */
    handleCategorySelect(event) {
        this.clearBlurTimeout();

        const selectedValue =
            event.currentTarget.dataset.value;

        const selectedOption =
            this.itemCategoryOptions.find(
                option =>
                    option.value === selectedValue
            );

        if (!selectedOption) {
            return;
        }

        this.selectedItemCategory =
            selectedOption.value;

        this.searchKey =
            selectedOption.label;

        this.filteredItemCategoryOptions = [
            ...this.itemCategoryOptions
        ];

        this.isDropdownOpen = false;
        this.errorMessage = '';
    }

    /**
     * Filter Item Category values.
     */
    filterItemCategories(searchValue) {
        const normalizedSearch =
            this.normalizeSearchText(
                searchValue
            );

        if (!normalizedSearch) {
            this.filteredItemCategoryOptions = [
                ...this.itemCategoryOptions
            ];

            return;
        }

        this.filteredItemCategoryOptions =
            this.itemCategoryOptions.filter(
                option => {
                    return this.doesOptionMatch(
                        option,
                        normalizedSearch
                    );
                }
            );
    }

    /**
     * Match by partial code or minor typing mistake.
     */
    doesOptionMatch(option, normalizedSearch) {
        const optionSearchText =
            option.searchText || '';

        /*
         * Standard partial match.
         *
         * Example:
         * TAN matches TANN.
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
            searchWord => {
                return optionWords.some(
                    optionWord => {
                        if (
                            optionWord.includes(searchWord) ||
                            searchWord.includes(optionWord)
                        ) {
                            return true;
                        }

                        /*
                         * Allow one-character typing mistakes
                         * for values with at least four characters.
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
                );
            }
        );
    }

    /**
     * Convert text into a common searchable format.
     */
    normalizeSearchText(value) {
        return String(value || '')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    /**
     * Calculate the number of character changes needed
     * to convert one value into another.
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
                const charactersAreEqual =
                    second.charAt(row - 1) ===
                    first.charAt(column - 1);

                const substitutionCost =
                    charactersAreEqual ? 0 : 1;

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
     * Save the selected Item Category.
     */
    async handleSave() {
        if (!this.selectedItemCategory) {
            this.showToast(
                'Validation Error',
                'Please select an Item Category from the search results.',
                'warning'
            );

            return;
        }

        this.isSaving = true;
        this.errorMessage = '';
        this.isDropdownOpen = false;

        try {
            const result =
                await saveItemCategory({
                    orderItemId: this.recordId,
                    selectedItemCategory:
                        this.selectedItemCategory
                });

            await notifyRecordUpdateAvailable([
                {
                    recordId: this.recordId
                }
            ]);

            this.showToast(
                'Success',
                result ||
                    'Item Category saved successfully on Order Item.',
                'success'
            );

            this.dispatchEvent(
                new CloseActionScreenEvent()
            );
        } catch (error) {
            const message =
                this.reduceError(error);

            this.errorMessage = message;

            this.showToast(
                'Error',
                message,
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
        this.selectedItemCategory = '';
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
            typeof error.body.message ===
                'string'
        ) {
            return error.body.message;
        }

        if (
            typeof error.message ===
                'string'
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