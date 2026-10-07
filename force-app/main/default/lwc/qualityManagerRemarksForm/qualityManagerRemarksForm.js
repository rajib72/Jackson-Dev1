import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getInitData from '@salesforce/apex/QualityManagerRemarksController.getInitData';
import savePage from '@salesforce/apex/QualityManagerRemarksController.savePage';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class QualityManagerRemarksForm extends NavigationMixin(LightningElement) {
    _recordId;
    _loadedForRecordId;

    @track headerInfo = {
        projectName: '',
        clientName: ''
    };

    @track allRows = [];
    @track pagedRows = [];

    pageSize = 30;
    currentPage = 0;
    totalPages = 0;
    isLoading = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value && this._loadedForRecordId !== value) {
            this._loadedForRecordId = value;
            this.loadData();
        }
    }

    get qmStatusOptions() {
        return [
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' }
        ];
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages - 1;
    }

    get showNextButton() {
        return !this.isLastPage;
    }

    async loadData() {
        if (!this._recordId) {
            return;
        }

        this.isLoading = true;
        try {
            const res = await getInitData({ projectHotoChecklistId: this._recordId });

            this.headerInfo = res?.headerInfo || { projectName: '', clientName: '' };

            this.allRows = (res?.rows || []).map((r, idx) => {
                const initStatus = r.qmStatus || 'Yes';
                return {
                    ...r,
                    globalIndex: idx,
                    rowNumber: r.rowNumber, // Uses the safe sorted row number from Apex
                    qmStatus: initStatus,
                    qmRemark: r.qmRemark || '',
                    hotoChecked: !!r.hotoChecked,
                    isRemarkRequired: initStatus === 'No' 
                };
            });

            this.totalPages = Math.ceil(this.allRows.length / this.pageSize);
            this.currentPage = 0;
            this.applyPaging();
        } catch (e) {
            this.showToast('Error', e?.body?.message || 'Failed to load data', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    applyPaging() {
        const pageStart = this.currentPage * this.pageSize;
        const pageEnd = pageStart + this.pageSize;

        this.pagedRows = this.allRows.slice(pageStart, pageEnd);
    }

    updateRow(globalIndex, patch) {
        this.allRows = this.allRows.map((row, idx) => {
            if (idx === globalIndex) {
                const updatedRow = { ...row, ...patch };
                if (patch.qmStatus !== undefined) {
                    updatedRow.isRemarkRequired = updatedRow.qmStatus === 'No';
                }
                return updatedRow;
            }
            return row;
        });
        this.applyPaging();
    }

    handleStatusChange(event) {
        const idx = Number(event.target.dataset.index);
        this.updateRow(idx, { qmStatus: event.detail.value });
    }

    handleRemarkChange(event) {
        const idx = Number(event.target.dataset.index);
        // CRITICAL FIX: Base LWC textareas use event.target.value. 
        this.updateRow(idx, { qmRemark: event.target.value }); 
    }

    validateCurrentPage() {
        let isValid = true;
        
        // Triggers the red UI border on textareas that are required but empty
        const textareas = this.template.querySelectorAll('lightning-textarea');
        textareas.forEach(field => {
            if (!field.checkValidity()) {
                field.reportValidity();
                isValid = false;
            }
        });

        if (!isValid) {
            return 'Please fill in all mandatory Remarks highlighted in red.';
        }

        // Fallback programmatic check
        for (const row of this.pagedRows) {
            if (row.qmStatus === 'No' && !row.qmRemark?.trim()) {
                return `QM Remarks are mandatory when QM Status is No. Please fill row ${row.rowNumber} - ${row.label}`;
            }
        }
        return '';
    }

    getRowsForCurrentPage() {
        return this.pagedRows.map(row => ({
            rowNumber: row.rowNumber,
            qmStatus: row.qmStatus || 'Yes',
            qmRemark: row.qmRemark || '',
            label: row.label
        }));
    }

    async handleNext() {
        const err = this.validateCurrentPage();
        if (err) {
            this.showToast('Validation Error', err, 'error');
            return;
        }

        this.isLoading = true;
        try {
            const qmaId = await savePage({
                projectHotoChecklistId: this._recordId,
                headerInfo: this.headerInfo,
                rows: this.getRowsForCurrentPage()
            });

            this.showToast('Success', 'Page saved successfully.', 'success');

            if (!this.isLastPage) {
                this.currentPage += 1;
                this.applyPaging();
            } else {
                this.navigateToRecord(qmaId);
            }
        } catch (e) {
            this.showToast('Error', e?.body?.message || 'Failed to save records', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave() {
        const err = this.validateCurrentPage();
        if (err) {
            this.showToast('Validation Error', err, 'error');
            return;
        }

        this.isLoading = true;
        try {
            const qmaId = await savePage({
                projectHotoChecklistId: this._recordId,
                headerInfo: this.headerInfo,
                rows: this.getRowsForCurrentPage()
            });

            this.showToast('Success', 'Records saved successfully.', 'success');
            this.navigateToRecord(qmaId);
        } catch (e) {
            this.showToast('Error', e?.body?.message || 'Failed to save records', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    navigateToRecord(recordId) {
        if (!recordId) {
            this.closeAction();
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Quality_Manager_Approval__c',
                actionName: 'view'
            }
        });
    }

    handleCancel() {
        this.closeAction();
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
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