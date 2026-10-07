import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import BILLING_POSTAL_CODE_FIELD from '@salesforce/schema/Quote.BillingPostalCode';
import SHIPPING_POSTAL_CODE_FIELD from '@salesforce/schema/Quote.ShippingPostalCode';

import getPostOffices from '@salesforce/apex/API_Ctrl_PostalPincodeController.getPostOffices';
import updateQuoteBillingFromSelection from '@salesforce/apex/API_Ctrl_PostalPincodeController.updateQuoteBillingFromSelection';
import updateQuoteShippingFromSelection from '@salesforce/apex/API_Ctrl_PostalPincodeController.updateQuoteShippingFromSelection';

const FIELDS = [
    BILLING_POSTAL_CODE_FIELD,
    SHIPPING_POSTAL_CODE_FIELD
];

export default class LwcFetchPincodeInQuote extends LightningElement {
    @api recordId;

    billingPincode = '';
    shippingPincode = '';
    pincode = '';

    selectedAddressType = '';
    message = '';
    isLoading = false;
    showNoPincodeMessage = false;

    @track rows = [];
    selectedRow = null;
    selectedRowKeys = [];

    columns = [
        { label: 'Name', fieldName: 'name', type: 'text' },
        { label: 'Division', fieldName: 'division', type: 'text' },
        { label: 'Region', fieldName: 'region', type: 'text' },
        { label: 'State', fieldName: 'state', type: 'text' },
        { label: 'Country', fieldName: 'country', type: 'text' },
        { label: 'Pincode', fieldName: 'pincode', type: 'text' }
    ];

    get addressTypeOptions() {
        return [
            { label: 'Billing', value: 'Billing' },
            { label: 'Shipping', value: 'Shipping' }
        ];
    }

    get showComponentBody() {
        return this.selectedAddressType;
    }

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    get disableUpdate() {
        return !this.selectedRow || this.isLoading;
    }

    get updateButtonLabel() {
        if (this.selectedAddressType === 'Billing') {
            return 'Update Billing Address';
        }

        if (this.selectedAddressType === 'Shipping') {
            return 'Update Shipping Address';
        }

        return 'Update Address';
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredQuote({ error, data }) {
        if (data) {
            this.billingPincode = getFieldValue(data, BILLING_POSTAL_CODE_FIELD) || '';
            this.shippingPincode = getFieldValue(data, SHIPPING_POSTAL_CODE_FIELD) || '';

            console.log('Quote recordId =>', this.recordId);
            console.log('Billing Postal Code =>', this.billingPincode);
            console.log('Shipping Postal Code =>', this.shippingPincode);
        } else if (error) {
            console.error('getRecord error =>', JSON.stringify(error));
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    handleAddressTypeChange(event) {
        this.selectedAddressType = event.detail.value;

        this.message = '';
        this.rows = [];
        this.selectedRow = null;
        this.selectedRowKeys = [];
        this.showNoPincodeMessage = false;

        if (this.selectedAddressType === 'Billing') {
            this.pincode = this.billingPincode;
        } else if (this.selectedAddressType === 'Shipping') {
            this.pincode = this.shippingPincode;
        } else {
            this.pincode = '';
        }

        if (!this.pincode) {
            this.showNoPincodeMessage = true;
            return;
        }

        this.searchPostOffices();
    }

    async searchPostOffices() {
        try {
            if (!this.pincode || !/^\d{6}$/.test(this.pincode)) {
                this.showNoPincodeMessage = true;
                this.showToast('Error', 'Please select an address type with a valid 6 digit pincode.', 'error');
                return;
            }

            this.isLoading = true;
            this.message = '';
            this.rows = [];
            this.selectedRow = null;
            this.selectedRowKeys = [];
            this.showNoPincodeMessage = false;

            const result = await getPostOffices({ pincode: this.pincode });

            this.message = result?.message || '';

            const postOffices = result?.postOffices || [];

            this.rows = postOffices.map((row, index) => {
                return {
                    ...row,
                    uniqueKey: `${row.name || 'ROW'}_${row.pincode || ''}_${index}`
                };
            });

            if (!this.rows.length) {
                this.showToast('Info', 'No records found for this pincode.', 'info');
            }
        } catch (error) {
            console.error('searchPostOffices error =>', JSON.stringify(error));
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];

        if (selectedRows.length > 0) {
            this.selectedRow = selectedRows[0];
            this.selectedRowKeys = [selectedRows[0].uniqueKey];
        } else {
            this.selectedRow = null;
            this.selectedRowKeys = [];
        }
    }

    async handleUpdateAddress() {
        if (this.selectedAddressType === 'Billing') {
            await this.handleUpdateBilling();
        } else if (this.selectedAddressType === 'Shipping') {
            await this.handleUpdateShipping();
        } else {
            this.showToast('Error', 'Please select Billing or Shipping.', 'error');
        }
    }

    async handleUpdateBilling() {
        try {
            if (!this.selectedRow) {
                this.showToast('Error', 'Please select one row.', 'error');
                return;
            }

            this.isLoading = true;

            await updateQuoteBillingFromSelection({
                qId: this.recordId,
                stateValue: this.selectedRow.state,
                countryValue: this.selectedRow.country,
                cityValue: this.selectedRow.division
            });

            this.showToast('Success', 'Quote Billing Address updated successfully.', 'success');
            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            console.error('handleUpdateBilling error =>', JSON.stringify(error));
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleUpdateShipping() {
        try {
            if (!this.selectedRow) {
                this.showToast('Error', 'Please select one row.', 'error');
                return;
            }

            this.isLoading = true;

            await updateQuoteShippingFromSelection({
                qId: this.recordId,
                stateValue: this.selectedRow.state,
                countryValue: this.selectedRow.country,
                cityValue: this.selectedRow.division
            });

            this.showToast('Success', 'Quote Shipping Address updated successfully.', 'success');
            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            console.error('handleUpdateShipping error =>', JSON.stringify(error));
            this.showToast('Error', this.getErrorMessage(error), 'error');
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
        return error?.body?.message || error?.message || 'Unknown error';
    }
}