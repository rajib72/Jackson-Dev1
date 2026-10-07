import { LightningElement, track } from 'lwc';
import importSalesOrders from '@salesforce/apex/API_ctrl_SapSalesOrderImportController.importSalesOrders';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SapSalesOrderImport extends LightningElement {
    fromDate;
    toDate;

    isLoading = false;
    hasResult = false;

    @track result;

    columns = [
        { label: 'Status', fieldName: 'status', initialWidth: 120 },
        { label: 'Sales Order', fieldName: 'salesOrder', initialWidth: 140 },
        { label: 'Creation Date', fieldName: 'creationDate', initialWidth: 130 },
        { label: 'Line Item No', fieldName: 'lineItemNo', initialWidth: 130 },
        { label: 'Material Code', fieldName: 'materialCode', initialWidth: 190 },
        { label: 'Quantity', fieldName: 'qty', initialWidth: 100 },
        { label: 'Net Price', fieldName: 'netPrice', initialWidth: 110 },
        { label: 'Net Value', fieldName: 'netValue', initialWidth: 110 },
        { label: 'Plant', fieldName: 'plant', initialWidth: 100 },
        { label: 'Item Category', fieldName: 'itemCategory', initialWidth: 130 },
        { label: 'Route', fieldName: 'route', initialWidth: 120 },
        { label: 'Sales Org', fieldName: 'salesOrg', initialWidth: 110 },
        { label: 'Dist Chan', fieldName: 'distChan', initialWidth: 110 },
        { label: 'Division', fieldName: 'division', initialWidth: 100 },
        { label: 'Sales Group', fieldName: 'salesGroup', initialWidth: 120 },
        { label: 'Sales Office', fieldName: 'salesOffice', initialWidth: 120 },
        { label: 'Document Type', fieldName: 'documentType', initialWidth: 130 },
        { label: 'Order Reason', fieldName: 'orderReason', initialWidth: 130 },
        { label: 'Delivering Plant', fieldName: 'deliveringPlant', initialWidth: 140 },
        { label: 'BG Required', fieldName: 'bgRequired', initialWidth: 120 },
        { label: 'LD Clause', fieldName: 'ldClause', initialWidth: 110 },
        { label: 'TPC', fieldName: 'tpc', initialWidth: 90 },
        { label: 'Performance Warranty', fieldName: 'performanceWarranty', initialWidth: 170 },
        { label: 'Product Warranty', fieldName: 'productWarranty', initialWidth: 150 }
    ];

    connectedCallback() {
        this.setDefaultDates();
    }

    setDefaultDates() {
        const today = new Date();
        const firstDay = new Date(today.getFullYear(), today.getMonth(), 1);

        this.fromDate = this.formatDateForInput(firstDay);
        this.toDate = this.formatDateForInput(today);
    }

    formatDateForInput(dateObj) {
        const year = dateObj.getFullYear();
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const day = String(dateObj.getDate()).padStart(2, '0');

        return `${year}-${month}-${day}`;
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
    }

    get tableData() {
        if (this.result && this.result.records) {
            return this.result.records;
        }

        return [];
    }

    get hasTableData() {
        return this.tableData.length > 0;
    }

    async handleFetchData() {
        this.hasResult = false;
        this.result = undefined;

        if (!this.fromDate || !this.toDate) {
            this.showToast('Validation Error', 'Please select From Date and To Date.', 'error');
            return;
        }

        if (this.toDate < this.fromDate) {
            this.showToast('Validation Error', 'To Date cannot be less than From Date.', 'error');
            return;
        }

        this.isLoading = true;

        try {
            const response = await importSalesOrders({
                fromDate: this.fromDate,
                toDate: this.toDate
            });

            this.result = response;
            this.hasResult = true;

            this.showToast('Success', 'Sales order sync completed successfully.', 'success');

        } catch (error) {
            let message = 'Error while fetching sales order data.';

            if (error && error.body && error.body.message) {
                message = error.body.message;
            } else if (error && error.message) {
                message = error.message;
            }

            this.showToast('Error', message, 'error');

        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.setDefaultDates();
        this.result = undefined;
        this.hasResult = false;
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