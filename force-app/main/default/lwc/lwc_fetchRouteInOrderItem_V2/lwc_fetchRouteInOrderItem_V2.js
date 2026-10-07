import { LightningElement, api, track } from 'lwc';

import getRouteOptions
    from '@salesforce/apex/API_ctrl_OrderItemRouteController_V2.getRouteOptions';

import saveSelectedRoute
    from '@salesforce/apex/API_ctrl_OrderItemRouteController_V2.saveSelectedRoute';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';

export default class OrderItemRoutePicker extends LightningElement {
    @api recordId;

    @track routeOptions = [];
    @track filteredRouteOptions = [];

    routeOptionMap = {};

    selectedRoute = '';
    selectedRouteDescription = '';
    searchKey = '';

    isLoading = false;
    isDropdownOpen = false;

    message = '';
    errorMessage = '';

    blurTimeout;

    /**
     * Save is disabled when:
     * 1. No Route is selected.
     * 2. The component is processing.
     */
    get disableSave() {
        return !this.selectedRoute || this.isLoading;
    }

    /**
     * Shows the Route selector only when SAP returns Routes.
     */
    get showRouteSelector() {
        return (
            Array.isArray(this.routeOptions) &&
            this.routeOptions.length > 0
        );
    }

    /**
     * Shows the dropdown only when it is open
     * and matching Routes are available.
     */
    get showRouteDropdown() {
        return (
            this.isDropdownOpen &&
            Array.isArray(this.filteredRouteOptions) &&
            this.filteredRouteOptions.length > 0
        );
    }

    /**
     * Shows the no-result message when the search
     * does not match any Route.
     */
    get showNoSearchResults() {
        return (
            this.isDropdownOpen &&
            Boolean((this.searchKey || '').trim()) &&
            this.routeOptions.length > 0 &&
            this.filteredRouteOptions.length === 0
        );
    }

    /**
     * Fetch Routes from SAP.
     */
    async handleFetchRoutes() {
        this.isLoading = true;
        this.message = '';
        this.errorMessage = '';

        this.resetRouteSelection();

        this.routeOptions = [];
        this.filteredRouteOptions = [];
        this.routeOptionMap = {};

        try {
            const response = await getRouteOptions({
                orderItemId: this.recordId
            });

            if (response && Array.isArray(response.options)) {
                this.routeOptions = response.options.map(
                    (item, index) => {
                        const route =
                            item.route ||
                            item.value ||
                            '';

                        const description =
                            item.routeDescription ||
                            '';

                        const label =
                            item.label ||
                            (
                                description
                                    ? `${route} - ${description}`
                                    : route
                            );

                        this.routeOptionMap[route] = description;

                        /*
                         * Store a normalized searchable value.
                         */
                        const searchText =
                            this.normalizeSearchText(
                                `${route} ${description} ${label}`
                            );

                        return {
                            key: `${route}-${index}`,
                            value: route,
                            route,
                            description,
                            label,
                            searchText
                        };
                    }
                );

                this.filteredRouteOptions = [
                    ...this.routeOptions
                ];
            }

            this.message =
                response && response.message
                    ? response.message
                    : 'Routes fetched successfully.';

            if (!this.routeOptions.length) {
                this.showToast(
                    'Information',
                    'No route values found from API.',
                    'info'
                );
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);

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
     * Runs whenever the search input value changes.
     */
    handleRouteSearch(event) {
        /*
         * lightning-input provides its changed value
         * through event.detail.value.
         */
        const inputValue =
            event?.detail?.value ??
            event?.target?.value ??
            '';

        this.searchKey = inputValue;

        /*
         * The previous selection is cleared because the user
         * is searching for another Route.
         */
        this.selectedRoute = '';
        this.selectedRouteDescription = '';

        this.message = '';
        this.errorMessage = '';

        this.filterRouteOptions(this.searchKey);
        this.isDropdownOpen = true;
    }

    /**
     * Open the dropdown when the search box receives focus.
     */
    handleSearchFocus() {
        this.clearBlurTimeout();

        if (!this.routeOptions.length) {
            return;
        }

        /*
         * Show the complete list when a Route was already selected.
         * Otherwise, filter by the currently entered search value.
         */
        if (this.selectedRoute) {
            this.filteredRouteOptions = [
                ...this.routeOptions
            ];
        } else {
            this.filterRouteOptions(this.searchKey);
        }

        this.isDropdownOpen = true;
    }

    /**
     * Close the dropdown after a small delay.
     */
    handleSearchBlur() {
        this.clearBlurTimeout();

        this.blurTimeout = window.setTimeout(() => {
            this.isDropdownOpen = false;
        }, 250);
    }

    /**
     * Prevent the search box from losing focus before
     * the option click is processed.
     */
    handleDropdownMouseDown(event) {
        event.preventDefault();
        this.clearBlurTimeout();
    }

    /**
     * Handle Route selection.
     */
    handleRouteSelect(event) {
        this.clearBlurTimeout();

        const selectedValue =
            event.currentTarget.dataset.value;

        const selectedOption = this.routeOptions.find(
            option => option.value === selectedValue
        );

        if (!selectedOption) {
            return;
        }

        this.selectedRoute = selectedOption.value;

        this.selectedRouteDescription =
            selectedOption.description ||
            this.routeOptionMap[selectedOption.value] ||
            '';

        /*
         * Show Route Code and Description in the search input.
         */
        this.searchKey = selectedOption.label;

        this.filteredRouteOptions = [
            ...this.routeOptions
        ];

        this.isDropdownOpen = false;
        this.message = '';
        this.errorMessage = '';
    }

    /**
     * Filter Routes using:
     * 1. Route Code
     * 2. Route Description
     * 3. Full Route label
     * 4. Minor one-character typing mistakes
     */
    filterRouteOptions(searchValue) {
        const normalizedSearch =
            this.normalizeSearchText(searchValue);

        /*
         * Show all Routes when the search field is empty.
         */
        if (!normalizedSearch) {
            this.filteredRouteOptions = [
                ...this.routeOptions
            ];

            return;
        }

        this.filteredRouteOptions =
            this.routeOptions.filter(option => {
                return this.doesRouteMatch(
                    option,
                    normalizedSearch
                );
            });
    }

    /**
     * Checks whether a Route matches the search value.
     */
    doesRouteMatch(option, normalizedSearch) {
        const optionSearchText =
            option.searchText || '';

        /*
         * Standard partial search.
         *
         * Examples:
         * GNR matches GNRJBL
         * noida matches GR.Noida-To-Bhilwara
         */
        if (optionSearchText.includes(normalizedSearch)) {
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

        /*
         * Every entered word must match at least one word
         * from the Route Code or Route Description.
         */
        return searchWords.every(searchWord => {
            return optionWords.some(optionWord => {
                /*
                 * Normal partial-word match.
                 */
                if (
                    optionWord.includes(searchWord) ||
                    searchWord.includes(optionWord)
                ) {
                    return true;
                }

                /*
                 * Allow one-character typing differences
                 * for words with at least four characters.
                 *
                 * Example:
                 * gurgao matches gurgaon.
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
            });
        });
    }

    /**
     * Convert Route text into a searchable format.
     *
     * Example:
     * GR.Noida-To-Gurgaon
     *
     * Becomes:
     * gr noida to gurgaon
     */
    normalizeSearchText(value) {
        return String(value || '')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    /**
     * Calculate the character difference between two words.
     * This is used to support minor typing mistakes.
     */
    calculateEditDistance(firstValue, secondValue) {
        const first = firstValue || '';
        const second = secondValue || '';

        const firstLength = first.length;
        const secondLength = second.length;

        /*
         * Stop early when the word lengths differ
         * by more than one character.
         */
        if (Math.abs(firstLength - secondLength) > 1) {
            return 2;
        }

        const matrix = [];

        for (let row = 0; row <= secondLength; row++) {
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
     * Save the selected Route on the Order Item.
     */
    async handleSave() {
        if (!this.selectedRoute) {
            this.showToast(
                'Route Required',
                'Please select a route before saving.',
                'warning'
            );

            return;
        }

        this.isLoading = true;
        this.message = '';
        this.errorMessage = '';
        this.isDropdownOpen = false;

        try {
            const result = await saveSelectedRoute({
                orderItemId: this.recordId,
                route: this.selectedRoute,
                routeDescription:
                    this.selectedRouteDescription
            });

            this.message = result;

            this.showToast(
                'Success',
                result,
                'success'
            );

            /*
             * Refresh the Lightning record page.
             */
            this.dispatchEvent(
                new RefreshEvent()
            );
        } catch (error) {
            this.errorMessage = this.reduceError(error);

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
     * Reset selected Route and search details.
     */
    resetRouteSelection() {
        this.selectedRoute = '';
        this.selectedRouteDescription = '';
        this.searchKey = '';
        this.isDropdownOpen = false;
    }

    /**
     * Clear the pending blur timeout.
     */
    clearBlurTimeout() {
        if (this.blurTimeout) {
            window.clearTimeout(this.blurTimeout);
            this.blurTimeout = null;
        }
    }

    /**
     * Display a Salesforce toast.
     */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    /**
     * Return a readable error message.
     */
    reduceError(error) {
        if (
            error &&
            Array.isArray(error.body)
        ) {
            return error.body
                .map(item => item.message)
                .filter(Boolean)
                .join(', ');
        }

        if (
            error &&
            error.body &&
            error.body.message
        ) {
            return error.body.message;
        }

        if (
            error &&
            error.message
        ) {
            return error.message;
        }

        return 'An unknown error occurred.';
    }

    /**
     * Clear timeout when the component is destroyed.
     */
    disconnectedCallback() {
        this.clearBlurTimeout();
    }
}