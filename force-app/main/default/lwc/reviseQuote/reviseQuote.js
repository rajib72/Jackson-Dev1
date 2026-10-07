import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';

import getQuoteDetails from '@salesforce/apex/ReviseQuoteController.getQuoteDetails';
import getQuoteLineItems from '@salesforce/apex/ReviseQuoteController.getQuoteLineItems';
import cloneQuoteAndItems from '@salesforce/apex/ReviseQuoteController.cloneQuoteAndItems';
import getAccountContacts from '@salesforce/apex/ReviseQuoteController.getAccountContacts';
import Quantity from '@salesforce/schema/Asset.Quantity';

export default class ReviseQuote extends NavigationMixin(LightningElement) {
    _recordId;

    @track quoteRecord;
    @track lineItems = [];
    @track isLoading = false;
    _modalStyleAdded = false;

    @track contactOptions = [];
    @track incotermOptions = [];
    @track uomOptions = [];

    selectedContactId = '';

    accountName = '';
    opportunityName = '';

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadData();
        }
    }

    get todayDate() {
        return new Date().toISOString().split('T')[0];
    }

    get revisedVersionNumber() {
        if (!this.quoteRecord) {
            return '';
        }
        return Number(this.quoteRecord.Version__c || 1) + 1;
    }

    get revisedQuoteName() {
        if (!this.quoteRecord) {
            return '';
        }

        const currentVersion = Number(this.quoteRecord.Version__c || 1);
        const nextVersion = currentVersion + 1;
        const baseName = (this.quoteRecord.Name || 'Quote').replace(/_Version\s*\(\d+\)$/i, '');
        return `${baseName}_Version (${nextVersion})`;
    }

    get billToAddress() {
        return [
            this.quoteRecord?.BillingStreet,
            this.quoteRecord?.BillingCity,
            this.quoteRecord?.BillingState,
            this.quoteRecord?.BillingPostalCode,
            this.quoteRecord?.BillingCountry
        ].filter(Boolean).join(', ');
    }

    get shipToAddress() {
        return [
            this.quoteRecord?.ShippingStreet,
            this.quoteRecord?.ShippingCity,
            this.quoteRecord?.ShippingState,
            this.quoteRecord?.ShippingPostalCode,
            this.quoteRecord?.ShippingCountry
        ].filter(Boolean).join(', ');
    }

    renderedCallback() {
        if (this._modalStyleAdded) {
            return;
        }
        this._modalStyleAdded = true;

        const style = document.createElement('style');
        style.innerText = `
        .slds-modal__container {
            width: 99vw !important;
            max-width: 99vw !important;
            min-width: 99vw !important;
            height: 94vh !important;
            margin: 0 auto !important;
            overflow: hidden !important;
        }

        .slds-modal__header {
            padding: 0 !important;
            border-bottom: none !important;
        }

        .slds-modal__content {
            height: calc(94vh - 115px) !important;
            max-height: calc(94vh - 115px) !important;
            overflow-y: auto !important;
            overflow-x: hidden !important;
            padding: 0 !important;
        }

        .slds-modal__footer {
            padding: 0.75rem 1rem !important;
            border-top: 1px solid #d8dde6 !important;
        }

        @media only screen and (max-width: 1024px) {
            .slds-modal__container {
                width: 99vw !important;
                max-width: 99vw !important;
                min-width: 99vw !important;
                height: 96vh !important;
            }

            .slds-modal__content {
                height: calc(96vh - 115px) !important;
                max-height: calc(96vh - 115px) !important;
            }
        }
    `;
        document.head.appendChild(style);
    }

    formatDateTime(value) {
        if (!value) return '';
        try {
            return new Intl.DateTimeFormat('en-IN', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric',
                hour: 'numeric',
                minute: '2-digit'
            }).format(new Date(value));
        } catch (e) {
            return value;
        }
    }

    extractGstPercent(value) {
        if (!value) return 0;
        const match = String(value).match(/[\d.]+/);
        return match ? this.toNumber(match[0]) : 0;
    }

    toNumber(value) {
        const num = parseFloat(value);
        return isNaN(num) ? 0 : num;
    }

    formatNumber(value, decimals = 2) {
        const num = this.toNumber(value);
        return num.toFixed(decimals);
    }

    calculateNos(projectCapacity, productRatingBin, uom) {
        const cap = Number(projectCapacity || 0);
        const rating = this.toNumber(productRatingBin);
        const currentUom = (uom || '').toUpperCase();

        if (!cap || !rating) {
            return 0;
        }

        let nos = 0;

        if (currentUom === 'KW') {
            nos = cap * (1000 / rating);
        } else if (currentUom === 'MW') {
            nos = cap * (1000000 / rating);
        } else {
            return 0;
        }

        if (nos > 0 && nos <= 1) {
            return 1;
        }

        return Math.round(nos);
    }

    calculateRowValues(row, preserveInitial = false) {
        const gstValue = this.toNumber(row.gstValue);

        if (preserveInitial) {
            return {
                ...row,
                total: this.formatNumber(row.total, 2),
                subtotal: this.toNumber(row.total),
                grandTotal: this.formatNumber(row.grandTotal, 2),
                gstDisplay: `${this.formatNumber(gstValue, 0)}%`
            };
        }

        const quantity = this.calculateNos(row.projectCapacity, row.productRatingBin, row.uom);
        const unitPrice = this.toNumber(row.unitPrice);
        const ratingBin = this.toNumber(row.productRatingBin);

        const total = quantity * ratingBin * unitPrice;
        const grandTotal = total + (total * gstValue / 100);

        return {
            ...row,
            quantity: quantity,
            total: this.formatNumber(total, 2),
            subtotal: this.toNumber(total),
            grandTotal: this.formatNumber(grandTotal, 2),
            gstDisplay: `${this.formatNumber(gstValue, 0)}%`
        };
    }

    updateLineItemRow(rowKey, updatedValues) {
        this.lineItems = this.lineItems.map(item => {
            if (item.rowKey === rowKey) {
                return this.calculateRowValues({ ...item, ...updatedValues });
            }
            return item;
        });
    }
    async loadData() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;
        try {
            const [quoteResult, lineItemResult, contactResult] = await Promise.all([
                getQuoteDetails({ quoteId: this.recordId }),
                getQuoteLineItems({ quoteId: this.recordId }),
                getAccountContacts({ quoteId: this.recordId })
            ]);

            this.quoteRecord = { ...quoteResult };
            this.accountName = quoteResult.Account ? quoteResult.Account.Name : '';
            this.opportunityName = quoteResult.Opportunity ? quoteResult.Opportunity.Name : '';

            this.contactOptions = contactResult || [];
            this.selectedContactId = quoteResult.ContactId || '';

            this.incotermOptions = lineItemResult?.incotermOptions || [];
            this.uomOptions = lineItemResult?.uomOptions || [];

            const rawGstValue = this.toNumber(lineItemResult?.gstPercent);
            const gstValue = rawGstValue > 0 && rawGstValue < 1 ? rawGstValue * 100 : rawGstValue;

            this.lineItems = (lineItemResult?.lineItems || []).map((item, index) => {
                const disableSelection = item.missingPricebookEntry === true;
                const productRatingBin = this.toNumber(item.productRatingBin);

                const row = {
                    rowKey: String(item.rowId || index),
                    id: item.rowId,
                    pricebookEntryId: item.pricebookEntryId || '',
                    product2Id: item.product2Id || '',

                    quantity: this.toNumber(item.quantity),
                    unitPrice: this.toNumber(item.unitPrice),
                    subtotal: this.toNumber(item.subtotal),
                    total: this.toNumber(item.subtotal),
                    grandTotal: this.toNumber(item.grandTotal),

                    uom: item.uom || '',
                    incoTermsId: item.incoTermsId || '',

                    moduleType: item.moduleType || '',
                    cellType: item.cellType || '',
                    moduleTechnology: item.moduleTechnology || '',
                    productRatingBin: productRatingBin,
                    productSubType: item.productSubType || '',
                    warranty: item.warranty || '',
                    cableLength: item.cableLength || '',
                    projectCapacity: this.toNumber(item.projectCapacity),
                    opportunityProductId: item.opportunityProductId || '',

                    gstValue: gstValue,

                    selected: false,
                    alreadyAdded: item.alreadyAdded || false,
                    missingPricebookEntry: item.missingPricebookEntry || false,
                    disableSelection: disableSelection,
                    rowClass: disableSelection ? 'disabled-row' : '',
                    materialDescription:
                        `${productRatingBin || ''} WP - ${item.moduleTechnology || ''} - ${item.cableLength || ''} (Cable length) - ${item.productSubType || ''} - ${item.moduleType || ''}`
                };

                return this.calculateRowValues(row, true);
            });
        } catch (error) {
            this.quoteRecord = null;
            this.lineItems = [];
            this.accountName = '';
            this.opportunityName = '';
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleContactChange(event) {
        this.selectedContactId = event.detail.value;

        this.quoteRecord = {
            ...this.quoteRecord,
            ContactId: this.selectedContactId
        };
    }

    handleQuoteChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;

        this.quoteRecord = {
            ...this.quoteRecord,
            [field]: value
        };
    }

    handleLineItemSelect(event) {
        const rowKey = event.target.dataset.rowkey;
        const checked = event.target.checked;
        this.updateLineItemRow(rowKey, { selected: checked });
    }

    handleProjectCapacityChange(event) {
        const rowKey = event.target.dataset.rowkey;
        const inputValue = this.toNumber(event.target.value);

        if (inputValue <= 0) {
            this.showToast('Error', 'Project Capacity must be greater than 0.', 'error');

            this.lineItems = this.lineItems.map(item => {
                if (item.rowKey === rowKey) {
                    return {
                        ...item,
                        projectCapacity: ''
                    };
                }
                return item;
            });
            return;
        }

        this.updateLineItemRow(rowKey, {
            projectCapacity: inputValue
        });
    }

    handleUnitPriceChange(event) {
        const rowKey = event.target.dataset.rowkey;
        this.updateLineItemRow(rowKey, {
            unitPrice: this.toNumber(event.target.value)
        });
    }

    //ADD VALIDATION ON SUBJECT AND COMMERCIAL OFFER FOR FIELDS
    validateQuotePdfFields() {
        const requiredFields = [
            {
                field: 'Commercial_offer_for__c',
                message: 'Commercial Offer For is mandatory.'
            },
            {
                field: 'Project_Capacity__c',
                message: 'Subject is mandatory.'
            }
        ];

        let isValid = true;

        requiredFields.forEach(req => {
            const inputCmp = this.template.querySelector(
                `lightning-input[data-field="${req.field}"]`
            );

            if (inputCmp) {
                const value = inputCmp.value;

                if (!value || String(value).trim() === '') {
                    inputCmp.setCustomValidity(req.message);
                    isValid = false;
                } else {
                    inputCmp.setCustomValidity('');
                }

                inputCmp.reportValidity();
            }
        });

        return isValid;
    }

    async handleReviseQuote() {
        if (!this.quoteRecord) {
            this.showToast('Error', 'Quote data is not loaded.', 'error');
            return;
        }
        if (!this.validateQuotePdfFields()) {
            this.showToast(
                'Error',
                'Please fill all mandatory Quotation PDF related fields.',
                'error'
            );
            return;
        }

        if (!this.quoteRecord.ExpirationDate) {
            this.showToast('Error', 'Expiration Date is mandatory.', 'error');
            return;
        }

        if (this.quoteRecord.ExpirationDate < this.todayDate) {
            this.showToast('Error', 'Past Expiration Date is not allowed.', 'error');
            return;
        }

        const selectedItems = this.lineItems.filter(item => item.selected === true);

        if (!selectedItems.length) {
            this.showToast('Error', 'Please select at least one line item.', 'error');
            return;
        }

        const invalidItem = selectedItems.find(item =>
            this.toNumber(item.quantity) <= 0 ||
            this.toNumber(item.unitPrice) < 0
        );

        if (invalidItem) {
            this.showToast(
                'Error',
                'For selected rows: Nos must be greater than 0 and Price/Wp cannot be negative.',
                'error'
            );
            return;
        }

        this.isLoading = true;
        try {
            const newQuotePayload = { ...this.quoteRecord };

            delete newQuotePayload.attributes;
            delete newQuotePayload.Id;
            delete newQuotePayload.Name;
            delete newQuotePayload.AccountId;
            delete newQuotePayload.OpportunityId;
            delete newQuotePayload.Version__c;
            delete newQuotePayload.BillingAddress;
            delete newQuotePayload.ShippingAddress;
            delete newQuotePayload.Account;
            delete newQuotePayload.Opportunity;

            const updatedItemsPayload = selectedItems.map(item => ({
                Id: item.id,
                PricebookEntryId: item.pricebookEntryId,
                Quantity: 1,
                Nos__c: this.toNumber(item.quantity),
                Opportunity_Product__c: item.opportunityProductId,
                UnitPrice: this.toNumber(item.unitPrice),
                UOM__c: item.uom,
                IncoTerms__c: item.incoTermsId,
                Total__c: this.toNumber(item.total),
                Grand_Total__c: this.toNumber(item.grandTotal),
                Product_Capacity__c: this.toNumber(item.projectCapacity),
                Module_Type__c: item.moduleType,
                Cell_Type__c: item.cellType,
                Module_Technology__c: item.moduleTechnology,
                Product_Rating_BIN__c: item.productRatingBin != null ? String(item.productRatingBin) : '',
                Product_Sub_Type__c: item.productSubType,
                Warranty__c: item.warranty,
                Cable_Length__c: item.cableLength
            }));

            const selectedBillingAddress = {};
            const selectedShippingAddress = {};

            const newQuoteId = await cloneQuoteAndItems({
                newQuote: newQuotePayload,
                updatedItems: updatedItemsPayload,
                oldQuoteId: this.recordId,
                selectedBillingAddress,
                selectedShippingAddress
            });

            this.showToast('Success', 'Quote revised successfully.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: newQuoteId,
                    objectApiName: 'Quote',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
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
}