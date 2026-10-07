import { LightningElement, track } from 'lwc';
import fetchAndStoreMaterialMaster from '@salesforce/apex/API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class MaterialMasterSync extends NavigationMixin(LightningElement)  {
    @track filterType = 'DateRange'; // Default filter type
    @track materialCode = '';        // New property for Material Code
    @track fromDate;
    @track toDate;
    @track isLoading = false;
    @track resultData = [];
    @track summaryMessage = '';
    @track totalReceived = 0;
    @track createdCount = 0;
    @track updatedCount = 0;
    @track errorCount = 0;

    columns = [
        { label: 'Material Code', fieldName: 'materialCode' },
        { label: 'Plant', fieldName: 'plant' },
        { label: 'Storage Location', fieldName: 'storageLocation' },
        { label: 'Unique Key', fieldName: 'uniqueKey' },
        { label: 'Action', fieldName: 'action' },
        { label: 'Message', fieldName: 'message' }
    ];

    // Options for the Filter Type Combobox
    get filterOptions() {
        return [
            { label: 'From Date & To Date', value: 'DateRange' },
            { label: 'Material Code', value: 'MaterialCode' }
        ];
    }

    // Getters to control UI visibility
    get isDateRangeFilter() {
        return this.filterType === 'DateRange';
    }

    get isMaterialCodeFilter() {
        return this.filterType === 'MaterialCode';
    }

    connectedCallback() {
        const today = new Date();

        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');

        this.toDate = `${year}-${month}-${day}`;
        this.fromDate = `${year}-${month}-01`;
    }

    handleFilterChange(event) {
        this.filterType = event.detail.value;
    }

    handleChange(event) {
        const field = event.target.name;
        this[field] = event.target.value;
    }

    handleFetch() {
        // Validation based on selected filter type
        if (this.isDateRangeFilter) {
            if (!this.fromDate || !this.toDate) {
                this.showToast('Error', 'Please select both From Date and To Date.', 'error');
                return;
            }
            if (this.fromDate > this.toDate) {
                this.showToast('Error', 'From Date cannot be greater than To Date.', 'error');
                return;
            }
        } else if (this.isMaterialCodeFilter) {
            if (!this.materialCode) {
                this.showToast('Error', 'Please enter a Material Code.', 'error');
                return;
            }
        }

        this.isLoading = true;
        this.resultData = [];
        this.summaryMessage = '';
        this.totalReceived = 0;
        this.createdCount = 0;
        this.updatedCount = 0;
        this.errorCount = 0;

        fetchAndStoreMaterialMaster({
            filterType: this.filterType,
            fromDate: this.fromDate,
            toDate: this.toDate,
            materialCode: this.materialCode
        })
            .then((result) => {
                this.totalReceived = result.totalReceived;
                this.createdCount = result.createdCount;
                this.updatedCount = result.updatedCount;
                this.errorCount = result.errorCount;
                this.summaryMessage = result.message;
                this.resultData = result.results || [];

                if (result.success) {
                    this.showToast('Success', result.message, 'success');
                } else {
                    this.showToast('Warning', result.message, 'warning');
                }
            })
            .catch((error) => {
                let message = 'Unknown error';
                if (error && error.body && error.body.message) {
                    message = error.body.message;
                } else if (error && error.message) {
                    message = error.message;
                }

                this.showToast('Error', message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRefresh() {
        window.location.reload();
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

    get hasResults() {
        return this.resultData && this.resultData.length > 0;
    }
}