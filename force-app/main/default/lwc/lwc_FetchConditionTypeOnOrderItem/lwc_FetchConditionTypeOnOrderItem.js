import { LightningElement, api } from 'lwc';
import {
    updateRecord,
    notifyRecordUpdateAvailable
} from 'lightning/uiRecordApi';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import fetchConditionTypesFromSAP
    from '@salesforce/apex/Ctrl_FetchConditionType.fetchConditionTypesFromSAP';

import ID_FIELD from '@salesforce/schema/OrderItem.Id';
import CONDITION_TYPE_FIELD
    from '@salesforce/schema/OrderItem.Condition_Type__c';
import CONDITION_DESC_FIELD
    from '@salesforce/schema/OrderItem.Condition_Type_Description__c';

export default class Lwc_FetchConditionTypeOnOrderItem extends LightningElement {
    @api recordId;

    conditionOptions = [];
    filteredConditionOptions = [];

    selectedValue = '';
    selectedDescription = '';
    searchKey = '';

    isLoading = false;
    showDropdownArea = false;
    isDropdownOpen = false;
    showSuccess = false;
    showEmptyMessage = false;

    successMessage = '';
    errorMessage = '';

    blurTimeout;

    get isSaveDisabled() {
        return !this.selectedValue || this.isLoading;
    }

    get showConditionDropdown() {
        return (
            this.isDropdownOpen &&
            Array.isArray(this.filteredConditionOptions) &&
            this.filteredConditionOptions.length > 0
        );
    }

    get showNoSearchResults() {
        return (
            this.isDropdownOpen &&
            Boolean((this.searchKey || '').trim()) &&
            this.conditionOptions.length > 0 &&
            this.filteredConditionOptions.length === 0
        );
    }

    /**
     * Calls the existing Apex method and prepares the
     * returned SAP values for client-side searching.
     */
    async handleFetch() {
        if (!this.recordId) {
            this.showError(
                'Order Item Id is not available.'
            );
            return;
        }

        this.isLoading = true;
        this.showSuccess = false;
        this.showEmptyMessage = false;
        this.successMessage = '';
        this.errorMessage = '';

        this.resetSelection();

        this.conditionOptions = [];
        this.filteredConditionOptions = [];
        this.showDropdownArea = false;

        try {
            const result =
                await fetchConditionTypesFromSAP({
                    orderItemId: this.recordId
                });

            const parsedData =
                this.parseSapResponse(result);

            const rawItems =
                this.extractConditionItems(parsedData);

            this.conditionOptions =
                this.buildConditionOptions(rawItems);

            this.filteredConditionOptions = [
                ...this.conditionOptions
            ];

            if (!this.conditionOptions.length) {
                this.showEmptyMessage = true;

                this.showToast(
                    'Information',
                    'No condition values found from SAP.',
                    'info'
                );

                return;
            }

            this.showDropdownArea = true;

            /*
             * Automatically select the Condition when SAP
             * returns only one option.
             */
            if (this.conditionOptions.length === 1) {
                const onlyOption =
                    this.conditionOptions[0];

                this.selectedValue =
                    onlyOption.value;

                this.selectedDescription =
                    onlyOption.description;

                this.searchKey =
                    onlyOption.label;
            }

            this.showSuccess = true;
            this.successMessage =
                'Condition values fetched successfully.';

            this.showToast(
                'Success',
                this.successMessage,
                'success'
            );
        } catch (error) {
            this.errorMessage =
                this.reduceError(error);

            this.showToast(
                'Error fetching condition types',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Parse the String returned by the existing Apex method.
     */
    parseSapResponse(result) {
        if (!result) {
            return {};
        }

        if (typeof result === 'string') {
            try {
                return JSON.parse(result);
            } catch (error) {
                throw new Error(
                    'SAP returned an invalid JSON response.'
                );
            }
        }

        return result;
    }

    /**
     * Supports both:
     *
     * "item": [{...}, {...}]
     *
     * and:
     *
     * "item": {...}
     */
    extractConditionItems(parsedData) {
        if (
            !parsedData ||
            !parsedData.RESULT ||
            !parsedData.RESULT.item
        ) {
            return [];
        }

        const itemData =
            parsedData.RESULT.item;

        if (Array.isArray(itemData)) {
            return itemData;
        }

        if (typeof itemData === 'object') {
            return [itemData];
        }

        return [];
    }

    /**
     * Converts raw SAP records into searchable options.
     */
    buildConditionOptions(rawItems) {
        const uniqueValues =
            new Set();

        const options = [];

        rawItems.forEach((item, index) => {
            const conditionType =
                String(
                    item?.CONDITION_TYPE || ''
                ).trim();

            const description =
                String(
                    item?.DESCRIPTION || ''
                ).trim();

            if (!conditionType) {
                return;
            }

            /*
             * Avoid duplicate Condition Codes.
             */
            const normalizedCode =
                conditionType.toLowerCase();

            if (
                uniqueValues.has(
                    normalizedCode
                )
            ) {
                return;
            }

            uniqueValues.add(
                normalizedCode
            );

            const label =
                description
                    ? `${description} - ${conditionType}`
                    : conditionType;

            options.push({
                key: `${conditionType}-${index}`,
                value: conditionType,
                description,
                label,
                searchText:
                    this.normalizeSearchText(
                        `${conditionType} ${description} ${label}`
                    )
            });
        });

        return options;
    }

    /**
     * Runs while the user enters text.
     */
    handleConditionSearch(event) {
        const inputValue =
            event?.detail?.value ??
            event?.target?.value ??
            '';

        this.searchKey =
            inputValue || '';

        /*
         * Clear the old selection whenever the user changes
         * the displayed search text.
         */
        this.selectedValue = '';
        this.selectedDescription = '';

        this.showSuccess = false;
        this.successMessage = '';
        this.errorMessage = '';

        this.filterConditions(
            this.searchKey
        );

        this.isDropdownOpen = true;
    }

    /**
     * Open the searchable list when the field receives focus.
     */
    handleSearchFocus() {
        this.clearBlurTimeout();

        if (!this.conditionOptions.length) {
            return;
        }

        /*
         * When an option is already selected, show all options
         * so the user can select a different Condition.
         */
        if (this.selectedValue) {
            this.filteredConditionOptions = [
                ...this.conditionOptions
            ];
        } else {
            this.filterConditions(
                this.searchKey
            );
        }

        this.isDropdownOpen = true;
    }

    /**
     * Delay closure so the option click can finish first.
     */
    handleSearchBlur() {
        this.clearBlurTimeout();

        this.blurTimeout =
            window.setTimeout(() => {
                this.isDropdownOpen = false;
            }, 250);
    }

    /**
     * Prevent the input blur event from closing the list
     * before a result is selected.
     */
    handleDropdownMouseDown(event) {
        event.preventDefault();
        this.clearBlurTimeout();
    }

    /**
     * Select one Condition from the search results.
     */
    handleConditionSelect(event) {
        this.clearBlurTimeout();

        const selectedKey =
            event.currentTarget.dataset.key;

        const selectedOption =
            this.conditionOptions.find(
                option =>
                    option.key === selectedKey
            );

        if (!selectedOption) {
            return;
        }

        this.selectedValue =
            selectedOption.value;

        this.selectedDescription =
            selectedOption.description;

        this.searchKey =
            selectedOption.label;

        this.filteredConditionOptions = [
            ...this.conditionOptions
        ];

        this.isDropdownOpen = false;
        this.showSuccess = false;
        this.successMessage = '';
        this.errorMessage = '';
    }

    /**
     * Filter by Condition Code, Description, or full label.
     */
    filterConditions(searchValue) {
        const normalizedSearch =
            this.normalizeSearchText(
                searchValue
            );

        if (!normalizedSearch) {
            this.filteredConditionOptions = [
                ...this.conditionOptions
            ];

            return;
        }

        this.filteredConditionOptions =
            this.conditionOptions.filter(
                option =>
                    this.doesConditionMatch(
                        option,
                        normalizedSearch
                    )
            );
    }

    /**
     * Supports partial matching and minor one-character
     * typing mistakes.
     */
    doesConditionMatch(
        option,
        normalizedSearch
    ) {
        const optionSearchText =
            option.searchText || '';

        /*
         * Normal partial search.
         *
         * Examples:
         * PR matches PR00.
         * discount matches Discount Condition.
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
                         * One-character typo tolerance for
                         * words containing at least four characters.
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
     * Convert punctuation-separated SAP values into
     * searchable plain text.
     */
    normalizeSearchText(value) {
        return String(value || '')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    /**
     * Levenshtein distance used for typo tolerance.
     */
    calculateEditDistance(
        firstValue,
        secondValue
    ) {
        const first =
            firstValue || '';

        const second =
            secondValue || '';

        const firstLength =
            first.length;

        const secondLength =
            second.length;

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
            matrix[0][column] =
                column;
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
                const isSameCharacter =
                    second.charAt(row - 1) ===
                    first.charAt(column - 1);

                const substitutionCost =
                    isSameCharacter ? 0 : 1;

                matrix[row][column] =
                    Math.min(
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
     * Save the selected Condition using UI Record API.
     */
    async handleSave() {
        if (!this.selectedValue) {
            this.showToast(
                'Validation Error',
                'Please select a Condition from the search results.',
                'warning'
            );

            return;
        }

        this.isLoading = true;
        this.showSuccess = false;
        this.successMessage = '';
        this.errorMessage = '';
        this.isDropdownOpen = false;

        const fields = {};

        fields[ID_FIELD.fieldApiName] =
            this.recordId;

        fields[CONDITION_TYPE_FIELD.fieldApiName] =
            this.selectedValue;

        fields[CONDITION_DESC_FIELD.fieldApiName] =
            this.selectedDescription;

        try {
            await updateRecord({
                fields
            });

            await notifyRecordUpdateAvailable([
                {
                    recordId: this.recordId
                }
            ]);

            this.showSuccess = true;
            this.successMessage =
                'Condition Type updated successfully.';

            this.showToast(
                'Success',
                this.successMessage,
                'success'
            );
        } catch (error) {
            this.errorMessage =
                this.reduceError(error);

            this.showToast(
                'Error saving record',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    resetSelection() {
        this.selectedValue = '';
        this.selectedDescription = '';
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

    showError(message) {
        this.errorMessage =
            message;

        this.showToast(
            'Error',
            message,
            'error'
        );
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