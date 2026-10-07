import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import POSTAL_CODE_FIELD from '@salesforce/schema/Lead.PostalCode';

import getPostOffices from '@salesforce/apex/API_Ctrl_PostalPincodeController.getPostOffices';
import updateLeadFromSelection from '@salesforce/apex/API_Ctrl_PostalPincodeController.updateLeadFromSelection';

const FIELDS = [POSTAL_CODE_FIELD];

export default class PostalPincodeServiceAppointment extends LightningElement {
    @api recordId;

    pincode = '';
    message = '';
    isLoading = false;
    showNoPincodeMessage = false;
    hasSearched = false;

    @track rows = [];
    selectedRow = null;
    selectedRowKeys = [];

    columns = [
        {
            label: 'Name',
            fieldName: 'name',
            type: 'text',

            // Added on 16-07-2026:
            // Wraps long datatable values instead of cutting them off.
            wrapText: true
        },
        {
            label: 'Division',
            fieldName: 'division',
            type: 'text',

            // Added on 16-07-2026:
            // Wraps long datatable values instead of cutting them off.
            wrapText: true
        },
        {
            label: 'Region',
            fieldName: 'region',
            type: 'text',

            // Added on 16-07-2026:
            // Wraps long datatable values instead of cutting them off.
            wrapText: true
        },
        {
            label: 'State',
            fieldName: 'state',
            type: 'text',

            // Added on 16-07-2026:
            // Wraps long datatable values instead of cutting them off.
            wrapText: true
        },
        {
            label: 'Country',
            fieldName: 'country',
            type: 'text',

            // Added on 16-07-2026:
            // Wraps long datatable values instead of cutting them off.
            wrapText: true
        },
        {
            label: 'Pincode',
            fieldName: 'pincode',
            type: 'text'
        }
    ];

    get hasRows() {
        // Changed on 16-07-2026:
        // Added Array.isArray() for safer row validation.
        return Array.isArray(this.rows) && this.rows.length > 0;
    }

    get disableUpdate() {
        return !this.selectedRow || this.isLoading;
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: FIELDS
    })
    wiredLead({ error, data }) {
        if (data) {
            this.pincode =
                getFieldValue(data, POSTAL_CODE_FIELD) || '';

            console.log('Lead recordId =>', this.recordId);
            console.log('Fetched PostalCode =>', this.pincode);

            this.showNoPincodeMessage = !this.pincode;

            if (this.pincode && !this.hasSearched) {
                this.hasSearched = true;
                this.searchPostOffices();
            }
        } else if (error) {
            console.error(
                'getRecord error =>',
                JSON.stringify(error)
            );

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    async searchPostOffices() {
        try {
            // Added on 16-07-2026:
            // Converts the pincode to a string and removes extra spaces.
            const normalizedPincode = String(
                this.pincode || ''
            ).trim();

            // Changed on 16-07-2026:
            // Validates the normalized six-digit pincode.
            if (!/^\d{6}$/.test(normalizedPincode)) {
                this.showNoPincodeMessage = true;

                // Added on 16-07-2026:
                // Clears old data and selection when the pincode is invalid.
                this.rows = [];
                this.selectedRow = null;
                this.selectedRowKeys = [];

                return;
            }

            // Added on 16-07-2026:
            // Stores the cleaned pincode and hides the invalid message.
            this.pincode = normalizedPincode;
            this.showNoPincodeMessage = false;

            this.isLoading = true;
            this.message = '';
            this.rows = [];
            this.selectedRow = null;
            this.selectedRowKeys = [];

            const result = await getPostOffices({
                pincode: this.pincode
            });

            this.message = result?.message || '';

            const postOffices = result?.postOffices || [];

            this.rows = postOffices.map((row, index) => {
                return {
                    ...row,

                    uniqueKey: `${
                        row.name || 'ROW'
                    }_${row.pincode || ''}_${index}`,

                    // Added on 16-07-2026:
                    // Used by the mobile radio-button selection.
                    isSelected: false,

                    // Added on 16-07-2026:
                    // Default CSS class for the mobile card.
                    cardClass: 'mobile-card'
                };
            });

            if (!this.rows.length) {
                this.showToast(
                    'Info',
                    'No records found for this pincode.',
                    'info'
                );
            }
        } catch (error) {
            console.error(
                'searchPostOffices error =>',
                JSON.stringify(error)
            );

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Changed on 16-07-2026:
     * Desktop datatable selection now uses the common applySelection()
     * method so desktop and mobile selections stay synchronized.
     */
    handleRowSelection(event) {
        const selectedRows =
            event.detail.selectedRows || [];

        if (selectedRows.length > 0) {
            const selectedRow = selectedRows[0];

            // Added on 16-07-2026:
            // Uses the common selection method.
            this.applySelection(selectedRow.uniqueKey);
        } else {
            // Added on 16-07-2026:
            // Clears both desktop and mobile selections.
            this.clearSelection();
        }
    }

    /**
     * Added on 16-07-2026:
     * Handles radio-button selection from the mobile card layout.
     */
    handleMobileSelection(event) {
        const selectedKey = event.target.dataset.key;

        if (selectedKey) {
            this.applySelection(selectedKey);
        }
    }

    /**
     * Added on 16-07-2026:
     * Keeps the desktop datatable and mobile card selections synchronized.
     */
    applySelection(selectedKey) {
        const matchedRow = this.rows.find(
            row => row.uniqueKey === selectedKey
        );

        if (!matchedRow) {
            this.clearSelection();
            return;
        }

        // Stores the selected row for the Update Lead operation.
        this.selectedRow = matchedRow;

        // Keeps the desktop lightning-datatable row selected.
        this.selectedRowKeys = [selectedKey];

        // Updates mobile card selection and CSS highlighting.
        this.rows = this.rows.map(row => {
            const isSelected =
                row.uniqueKey === selectedKey;

            return {
                ...row,
                isSelected,

                cardClass: isSelected
                    ? 'mobile-card mobile-card_selected'
                    : 'mobile-card'
            };
        });
    }

    /**
     * Added on 16-07-2026:
     * Clears desktop and mobile row selections.
     */
    clearSelection() {
        this.selectedRow = null;
        this.selectedRowKeys = [];

        this.rows = this.rows.map(row => {
            return {
                ...row,
                isSelected: false,
                cardClass: 'mobile-card'
            };
        });
    }

    async handleUpdate() {
        try {
            if (!this.selectedRow) {
                this.showToast(
                    'Error',

                    // Changed on 16-07-2026:
                    // Updated the message to clearly mention post office.
                    'Please select one post office.',

                    'error'
                );

                return;
            }

            this.isLoading = true;

            await updateLeadFromSelection({
                leadId: this.recordId,
                stateValue: this.selectedRow.state,
                countryValue: this.selectedRow.country,
                cityValue: this.selectedRow.division
            });

            this.showToast(
                'Success',
                'Lead updated successfully.',
                'success'
            );

            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(
                new CloseActionScreenEvent()
            );
        } catch (error) {
            console.error(
                'handleUpdate error =>',
                JSON.stringify(error)
            );

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
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

    getErrorMessage(error) {
        // Added on 16-07-2026:
        // Handles Salesforce errors returned as an array.
        if (Array.isArray(error?.body)) {
            return error.body
                .map(item => item.message)
                .join(', ');
        }

        return (
            error?.body?.message ||
            error?.message ||
            'Unknown error'
        );
    }
}