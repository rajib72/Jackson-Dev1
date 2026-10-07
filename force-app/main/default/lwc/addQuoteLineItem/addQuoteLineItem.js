import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { NavigationMixin } from 'lightning/navigation';

import getInitData from '@salesforce/apex/QuoteProductSelectorController.getInitData';
import saveQuoteLineItems from '@salesforce/apex/QuoteProductSelectorController.saveQuoteLineItems';

export default class AddQuoteLineItem extends NavigationMixin(LightningElement) {
    @api recordId;

    @track processedProducts = [];
    @track incotermOptions = [];
    @track uomOptions = [];
    @track isLoading = false;

    modalStyleInjected = false;
    modalStyleElement;
    _retriedLoad = false;

    connectedCallback() {
        if (this.recordId) {
            this.loadData();
        }
    }

    renderedCallback() {
        this.injectModalStyle();

        if (!this.recordId && !this._retriedLoad) {
            this._retriedLoad = true;
            setTimeout(() => {
                if (this.recordId) {
                    this.loadData();
                }
            }, 300);
        }
    }

    disconnectedCallback() {
        if (this.modalStyleElement && this.modalStyleElement.parentNode) {
            this.modalStyleElement.parentNode.removeChild(this.modalStyleElement);
        }
    }

    injectModalStyle() {
        if (this.modalStyleInjected) {
            return;
        }

        this.modalStyleInjected = true;
        this.modalStyleElement = document.createElement('style');
        this.modalStyleElement.innerText = `
            .slds-modal__container {
                width: 96% !important;
                max-width: 96rem !important;
                min-width: 60rem !important;
            }

            .slds-modal__content {
                overflow: hidden !important;
                padding: 0 !important;
            }

            @media only screen and (max-width: 1024px) {
                .slds-modal__container {
                    width: 98% !important;
                    max-width: 98% !important;
                    min-width: auto !important;
                }
            }
        `;
        document.head.appendChild(this.modalStyleElement);
    }

    async loadData() {
        this.isLoading = true;
        try {
            const result = await getInitData({ quoteId: this.recordId });

            this.incotermOptions = result.incotermOptions || [];
            this.uomOptions = result.uomOptions || [];

            this.processedProducts = (result.productRows || []).map((row) => {
                const disableSelection = row.alreadyAdded || row.missingPricebookEntry;
                const rowKey = String(row.opportunityLineItemId);

                return this.calculateRow({
                    rowKey,
                    opportunityLineItemId: rowKey,
                    product2Id: row.product2Id ? String(row.product2Id) : '',
                    pricebookEntryId: row.pricebookEntryId ? String(row.pricebookEntryId) : '',

                    nos: row.nos,
                    projectCapacity: row.projectCapacity,
                    unitPrice: row.unitPrice,
                    gstPercent: row.gstPercent || 0,
                    uom: row.uom ? row.uom : '-',

                    moduleType: row.moduleType || '',
                    cellType: row.cellType || '',
                    moduleTechnology: row.moduleTechnology || '',
                    productRatingBin: row.productRatingBin || '',
                    productSubType: row.productSubType || '',
                    warranty: row.warranty || '',
                    cableLength: row.cableLength || '',

                    selected: false,
                    alreadyAdded: row.alreadyAdded || false,
                    missingPricebookEntry: row.missingPricebookEntry || false,
                    disableSelection,
                    rowClass: disableSelection ? 'disabled-row' : ''
                });
            });
        } catch (error) {
            this.showToast('Error', this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    updateRowByKey(rowKey, updatedValues) {
        this.processedProducts = this.processedProducts.map((item) => {
            if (item.rowKey === rowKey) {
                return this.calculateRow({ ...item, ...updatedValues });
            }
            return item;
        });
    }

    parseNumberValue(value) {
        if (value === '' || value === null || value === undefined) {
            return null;
        }
        const parsed = Number(value);
        return Number.isNaN(parsed) ? null : parsed;
    }

    round2(value) {
        const num = Number(value || 0);
        return Math.round(num * 100) / 100;
    }

    parseRatingValue(value) {
        if (value === null || value === undefined || value === '') {
            return 0;
        }
        const cleaned = String(value).replace(/[^0-9.]/g, '');
        const parsed = Number(cleaned);
        return Number.isNaN(parsed) ? 0 : parsed;
    }

    calculateTotal(nos, unitPrice, productRatingBin) {
        const quantityNos = Number(nos || 0);
        const price = Number(unitPrice || 0);
        const rating = this.parseRatingValue(productRatingBin);

        if (!quantityNos || unitPrice === null || unitPrice === undefined || !rating) {
            return 0;
        }

        return this.round2(quantityNos * price * rating);
    }

    calculateNos(projectCapacity, productRatingBin, uom) {
        const cap = Number(projectCapacity || 0);
        const rating = this.parseRatingValue(productRatingBin);
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

    calculateRow(row) {
        const gstPercent = Number(row.gstPercent || 0);

        const nos = this.calculateNos(
            row.projectCapacity,
            row.productRatingBin,
            row.uom
        );

        const total = this.calculateTotal(
            nos,
            row.unitPrice,
            row.productRatingBin
        );

        const gstAmount = this.round2(total * gstPercent);
        const grandTotal = this.round2(total + gstAmount);

        return {
            ...row,
            nos,
            total,
            gstPercent,
            gstAmount,
            grandTotal,
            gstDisplay: `${this.round2(gstPercent * 100)}%`
        };
    }

    handleCheckboxChange(event) {
        const rowKey = event.target.dataset.rowkey;
        const checked = event.target.checked;
        this.updateRowByKey(rowKey, { selected: checked });
    }

    // handleProjectCapacityChange(event) {
    //     const rowKey = event.target.dataset.rowkey;
    //     const value = event.target.value;

    //     this.updateRowByKey(rowKey, {
    //         projectCapacity: this.parseNumberValue(value)
    //     });
    // }
    handleProjectCapacityChange(event) {
        const rowKey = event.target.dataset.rowkey;
        const value = this.parseNumberValue(event.target.value);

        if (value !== null && value < 0) {
            event.target.value = null;
            this.showToast('Validation Error', 'Project Capacity cannot be negative.', 'warning');
            this.updateRowByKey(rowKey, { projectCapacity: null });
            return;
        }

        this.updateRowByKey(rowKey, {
            projectCapacity: value
        });
    }

    handleUnitPriceChange(event) {
        const rowKey = event.target.dataset.rowkey;
        const value = event.target.value;

        this.updateRowByKey(rowKey, {
            unitPrice: this.parseNumberValue(value)
        });
    }
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Quote',
                actionName: 'view'
            }
        });
    }

    //     async handleSave() {
    //         const selectedRows = this.processedProducts.filter((row) => row.selected === true);
    //         if (row.projectCapacity === null || row.projectCapacity === undefined || row.projectCapacity <= 0) {
    //     this.showToast('Validation Error', 'Project Capacity must be greater than zero for all selected rows.', 'warning');
    //     return;
    // }

    //         if (!selectedRows.length) {
    //             this.showToast('Validation Error', 'Please select at least one row.', 'warning');
    //             return;
    //         }

    //         for (const row of selectedRows) {
    //             if (!row.opportunityLineItemId) {
    //                 this.showToast('Validation Error', 'Opportunity Product is missing.', 'warning');
    //                 return;
    //             }

    //             if (row.projectCapacity === null || row.projectCapacity === undefined || row.projectCapacity <= 0) {
    //                 this.showToast('Validation Error', 'Project Capacity must be greater than zero for all selected rows.', 'warning');
    //                 return;
    //             }

    //             if (row.unitPrice === null || row.unitPrice === undefined || row.unitPrice < 0) {
    //                 this.showToast('Validation Error', 'Sales Price cannot be blank or negative.', 'warning');
    //                 return;
    //             }
    //         }

    //         const payload = selectedRows.map((row) => ({
    //             opportunityLineItemId: row.opportunityLineItemId,
    //             product2Id: row.product2Id,
    //             pricebookEntryId: row.pricebookEntryId,

    //             nos: row.nos,
    //             projectCapacity: row.projectCapacity,
    //             unitPrice: row.unitPrice,
    //             total: row.total,
    //             gstPercent: row.gstPercent,
    //             gstAmount: row.gstAmount,
    //             grandTotal: row.grandTotal,
    //             uom: row.uom,

    //             moduleType: row.moduleType,
    //             cellType: row.cellType,
    //             moduleTechnology: row.moduleTechnology,
    //             productRatingBin: row.productRatingBin,
    //             productSubType: row.productSubType,
    //             warranty: row.warranty,
    //             cableLength: row.cableLength
    //         }));

    //         this.isLoading = true;
    //         try {
    //             await saveQuoteLineItems({
    //                 quoteId: this.recordId,
    //                 selectedRowsJson: JSON.stringify(payload)
    //             });

    //             this.showToast('Success', 'Quote Line Items created successfully.', 'success');
    //             this.dispatchEvent(new RefreshEvent());
    //             this.dispatchEvent(new CloseActionScreenEvent());
    //         } catch (error) {
    //             this.showToast('Error', this.reduceErrors(error), 'error');
    //         } finally {
    //             this.isLoading = false;
    //         }
    //     }
    async handleSave() {
        const selectedRows = this.processedProducts.filter((row) => row.selected === true);

        if (!selectedRows.length) {
            this.showToast('Validation Error', 'Please select at least one row.', 'warning');
            return;
        }

        for (const row of selectedRows) {
            if (!row.opportunityLineItemId) {
                this.showToast('Validation Error', 'Opportunity Product is missing.', 'warning');
                return;
            }

            if (row.projectCapacity === null || row.projectCapacity === undefined || row.projectCapacity <= 0) {
                this.showToast('Validation Error', 'Project Capacity must be greater than zero for all selected rows.', 'warning');
                return;
            }

            if (row.unitPrice === null || row.unitPrice === undefined || row.unitPrice < 0) {
                this.showToast('Validation Error', 'Sales Price cannot be blank or negative.', 'warning');
                return;
            }
        }

        const payload = selectedRows.map((row) => ({
            opportunityLineItemId: row.opportunityLineItemId,
            product2Id: row.product2Id,
            pricebookEntryId: row.pricebookEntryId,
            nos: row.nos,
            projectCapacity: row.projectCapacity,
            unitPrice: row.unitPrice,
            total: row.total,
            gstPercent: row.gstPercent,
            gstAmount: row.gstAmount,
            grandTotal: row.grandTotal,
            uom: row.uom,
            moduleType: row.moduleType,
            cellType: row.cellType,
            moduleTechnology: row.moduleTechnology,
            productRatingBin: row.productRatingBin,
            productSubType: row.productSubType,
            warranty: row.warranty,
            cableLength: row.cableLength
        }));

        this.isLoading = true;
        try {
            await saveQuoteLineItems({
                quoteId: this.recordId,
                selectedRowsJson: JSON.stringify(payload)
            });

            this.showToast('Success', 'Quote Line Items created successfully.', 'success');
            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast('Error', this.reduceErrors(error), 'error');
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

    reduceErrors(error) {
        if (!error) {
            return 'Unknown error';
        }

        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }

        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }

        if (typeof error.message === 'string') {
            return error.message;
        }

        return 'Unknown error';
    }
}