import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getApprovalDashboard from '@salesforce/apex/OpportunityApprovalDashboardController.getApprovalDashboard';

const PAGE_SIZE = 15;
// Refresh approval dashboard
const AUTO_REFRESH_INTERVAL = 15000;

export default class ApprovalDashboard extends LightningElement {
    rows = [];
    paginatedRows = [];
    tableColumns = [];

    error;
    wiredDashboardResult;
    // refresh
    refreshIntervalId;

    isLoading = true;
    pageSize = PAGE_SIZE;
    currentPage = 1;

    sortedBy = 'submittedDate';
    sortedDirection = 'desc';

    connectedCallback() {
        this.buildTableColumns();

    // refresh approval dashboard
        this.refreshIntervalId = setInterval(() => {
            this.refreshDashboard();
        }, AUTO_REFRESH_INTERVAL);
    }
    // refresh
     disconnectedCallback() {
        if (this.refreshIntervalId) {
            clearInterval(this.refreshIntervalId);
            this.refreshIntervalId = null;
        }
    }

    @wire(getApprovalDashboard)
    wiredDashboard(result) {
        this.wiredDashboardResult = result;

        const { data, error } = result;

        if (data) {
            this.rows = this.prepareRows(data);
            this.error = undefined;
            this.currentPage = 1;
            this.sortData(this.sortedBy, this.sortedDirection);
            this.isLoading = false;
        } else if (error) {
            this.rows = [];
            this.paginatedRows = [];
            this.error = this.reduceErrors(error).join(', ');
            this.isLoading = false;
        }
    }

    async refreshDashboard(showSpinner = false) {
        if (!this.wiredDashboardResult) {
            return;
        }

        if (showSpinner) {
            this.isLoading = true;
        }

        try {
            await refreshApex(
                this.wiredDashboardResult
            );
        } catch (error) {
            this.error =
                this.reduceErrors(error).join(', ');
        } finally {
            if (showSpinner) {
                this.isLoading = false;
            }
        }
    }

    handleRefresh() {
        this.refreshDashboard(true);
    }

    prepareRows(data) {
        return data.map((row) => {
            return {
                ...row,
                opportunityUrl: row.opportunityId
                    ? `/lightning/r/Opportunity/${row.opportunityId}/view`
                    : '',
                submittedByInitial: this.getInitial(row.submittedBy),
                approvalStatusBadgeClass: this.getApprovalStatusBadgeClass(row.approvalStatus)
            };
        });
    }

    getInitial(name) {
        if (!name) {
            return '?';
        }

        return name.trim().charAt(0).toUpperCase();
    }

    getApprovalStatusBadgeClass(statusValue) {
        let baseClass = 'status-badge';

        if (!statusValue) {
            return `${baseClass} status-neutral`;
        }

        const status = statusValue.toLowerCase();

        if (status.includes('design')) {
            return `${baseClass} status-design`;
        }

        if (status.includes('quality')) {
            return `${baseClass} status-quality`;
        }

        if (status.includes('commercial')) {
            return `${baseClass} status-commercial`;
        }

        if (status.includes('coo')) {
            return `${baseClass} status-coo`;
        }

        if (status.includes('sales')) {
            return `${baseClass} status-sales`;
        }

        if (status.includes('plant')) {
            return `${baseClass} status-plant`;
        }

        if (status.includes('finance')) {
            return `${baseClass} status-finance`;
        }

        if (status.includes('technical')) {
            return `${baseClass} status-technical`;
        }

        return `${baseClass} status-neutral`;
    }

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    get recordCount() {
        return this.rows ? this.rows.length : 0;
    }

    get totalPages() {
        return this.recordCount > 0
            ? Math.ceil(this.recordCount / this.pageSize)
            : 1;
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get showingFrom() {
        if (!this.hasRows) {
            return 0;
        }

        return (this.currentPage - 1) * this.pageSize + 1;
    }

    get showingTo() {
        if (!this.hasRows) {
            return 0;
        }

        return Math.min(this.currentPage * this.pageSize, this.recordCount);
    }

    buildTableColumns() {
        const columns = [
            {
                label: 'Opportunity Name',
                fieldName: 'opportunityName'
            },
            {
                label: 'Approval Status',
                fieldName: 'approvalStatus'
            },
            {
                label: 'Submitted By',
                fieldName: 'submittedBy'
            },
            {
                label: 'Submitted To',
                fieldName: 'submittedTo'
            },
            {
                label: 'Submitted Date',
                fieldName: 'submittedDate'
            }
        ];

        this.tableColumns = columns.map((column) => {
            const isSorted = column.fieldName === this.sortedBy;

            return {
                ...column,
                isSorted,
                sortIcon: this.sortedDirection === 'asc'
                    ? 'utility:arrowup'
                    : 'utility:arrowdown',
                headerClass: isSorted
                    ? 'table-sort-button sorted-column'
                    : 'table-sort-button'
            };
        });
    }

    handleRefresh() {
        this.isLoading = true;

        refreshApex(this.wiredDashboardResult)
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleHeaderSort(event) {
        const fieldName = event.currentTarget.dataset.field;

        if (this.sortedBy === fieldName) {
            this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortedBy = fieldName;
            this.sortedDirection = 'asc';
        }

        this.currentPage = 1;
        this.sortData(this.sortedBy, this.sortedDirection);
    }

    sortData(fieldName, direction) {
        const sortedData = [...this.rows];

        sortedData.sort((rowA, rowB) => {
            let valueA = rowA[fieldName];
            let valueB = rowB[fieldName];

            if (fieldName === 'submittedDate') {
                valueA = valueA ? new Date(valueA).getTime() : 0;
                valueB = valueB ? new Date(valueB).getTime() : 0;
            } else {
                valueA = valueA ? String(valueA).toLowerCase() : '';
                valueB = valueB ? String(valueB).toLowerCase() : '';
            }

            if (valueA > valueB) {
                return direction === 'asc' ? 1 : -1;
            }

            if (valueA < valueB) {
                return direction === 'asc' ? -1 : 1;
            }

            return 0;
        });

        this.rows = sortedData;
        this.buildTableColumns();
        this.updatePaginatedRows();
    }

    updatePaginatedRows() {
        if (this.currentPage > this.totalPages) {
            this.currentPage = this.totalPages;
        }

        if (this.currentPage < 1) {
            this.currentPage = 1;
        }

        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;

        this.paginatedRows = this.rows.slice(startIndex, endIndex);
    }

    handleFirstPage() {
        this.currentPage = 1;
        this.updatePaginatedRows();
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
            this.updatePaginatedRows();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage += 1;
            this.updatePaginatedRows();
        }
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
        this.updatePaginatedRows();
    }

    reduceErrors(error) {
        if (!Array.isArray(error)) {
            error = [error];
        }

        return error
            .filter((err) => !!err)
            .map((err) => {
                if (Array.isArray(err.body)) {
                    return err.body.map((e) => e.message);
                }

                if (err.body && typeof err.body.message === 'string') {
                    return err.body.message;
                }

                if (typeof err.message === 'string') {
                    return err.message;
                }

                return 'Unknown error';
            })
            .reduce((previous, current) => previous.concat(current), [])
            .filter((message) => !!message);
    }
}