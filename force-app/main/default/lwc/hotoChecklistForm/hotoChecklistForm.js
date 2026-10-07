import { LightningElement, track, api } from 'lwc';
import getChecklistFields from '@salesforce/apex/HOTOChecklistController.getChecklistFields';
import saveChecklistPage from '@salesforce/apex/HOTOChecklistController.saveChecklistPage';
import getStatusPicklistValues from '@salesforce/apex/HOTOChecklistController.getStatusPicklistValues';
import deleteOrphanedFiles from '@salesforce/apex/HOTOChecklistController.deleteOrphanedFiles';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';

export default class HotoChecklist extends NavigationMixin(LightningElement) {
    currentUserId = USER_ID;
    _recordId;
    
    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        if (value) { this.loadRows(); }
    }

    @track pagedRows = []; 
    @track projectInfo = {};
    @track dynamicStatusOptions = [];

    newlyUploadedDocIds = [];
    isSaving = false; 

    hasMoreRows = false;
    isLoading = false;

    get isLastPage() { return !this.hasMoreRows; }
    get saveButtonLabel() { return this.isLastPage ? 'Save' : 'Save & Next'; }

    connectedCallback() {
        this.fetchPicklistValues();
    }

    disconnectedCallback() {
        if (!this.isSaving && this.newlyUploadedDocIds.length > 0) {
            deleteOrphanedFiles({ documentIds: this.newlyUploadedDocIds })
                .catch(error => console.error('Error cleaning up files on disconnect', error));
        }
    }

    async fetchPicklistValues() {
        try {
            this.dynamicStatusOptions = await getStatusPicklistValues();
        } catch(error) {
            console.error('Error fetching picklist values', error);
        }
    }

    async loadRows() {
        this.isLoading = true;
        this.pagedRows = [];
        
        try {
            const cacheBuster = new Date().getTime().toString();
            const result = await getChecklistFields({ projectId: this.recordId, cacheBust: cacheBuster });
            
            this.projectInfo = result.projectInfo || {};
            this.hasMoreRows = result.hasMoreRows || false;

            let mappedRows = (result.rows || []).map((item) => {
                return {
                    ...item,
                    checked: item.checked === true,
                    status: item.status || '',
                    remark: item.remark || '',
                    fileNames: item.fileNames || [],
                    documentIds: item.documentIds || [],
                    fileNamesText: item.fileNamesText || '',
                    hasFiles: item.hasFiles || false
                };
            });

            let currentSectionTracker = '';
            this.pagedRows = mappedRows.map(row => {
                let showHeader = false;
                if (row.section !== currentSectionTracker) {
                    showHeader = true;
                    currentSectionTracker = row.section;
                }
                return { ...row, showSectionHeader: showHeader };
            });

        } catch (error) {
            this.showToast('Error', error?.body?.message || 'Error while loading fields', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    updateRow(globalIndex, patch) {
        this.pagedRows = this.pagedRows.map((row) => {
            if (row.globalIndex === globalIndex) {
                return { ...row, ...patch };
            }
            return row;
        });
    }

    handleInfoChange(event) {
        const field = event.target.dataset.field;
        this.projectInfo = { ...this.projectInfo, [field]: event.target.value };
    }

    handleCheckboxChange(event) {
        this.updateRow(Number(event.target.dataset.index), { checked: event.target.checked });
    }

    handleStatusChange(event) {
        this.updateRow(Number(event.target.dataset.index), { status: event.detail.value });
    }

    handleRemarkChange(event) {
        this.updateRow(Number(event.target.dataset.index), { remark: event.target.value });
    }

    handleUploadFinished(event) {
        const globalIndex = Number(event.target.dataset.index);
        const uploadedFiles = event.detail.files || [];
        const targetRow = this.pagedRows.find(r => r.globalIndex === globalIndex);

        const existingNames = targetRow?.fileNames || [];
        const existingDocIds = targetRow?.documentIds || [];
        
        const newNames = uploadedFiles.map(file => file.name);
        const newDocIds = uploadedFiles.map(file => file.documentId);

        this.newlyUploadedDocIds = [...this.newlyUploadedDocIds, ...newDocIds];

        const combinedNames = [...existingNames, ...newNames];
        const combinedDocIds = [...existingDocIds, ...newDocIds];

        this.updateRow(globalIndex, {
            fileNames: combinedNames,
            documentIds: combinedDocIds,
            fileNamesText: combinedNames.join(', '),
            hasFiles: combinedNames.length > 0
        });
    }

    validateCurrentPage() {
        const errors = [];
        for (const row of this.pagedRows) {
            if (!row.checked) {
                errors.push(`Please tick checkbox for row ${row.rowNumber} - ${row.label}`);
            }
            if (!row.status) {
                errors.push(`Please select Status for row ${row.rowNumber} - ${row.label}`);
            }
        }
        return errors;
    }

    async handleSaveNext() {
        const errors = this.validateCurrentPage();
        if (errors.length > 0) {
            this.showToast('Validation Error', errors[0], 'error');
            return;
        }

        this.isLoading = true;
        this.isSaving = true; 

        try {
            await saveChecklistPage({
                projectId: this.recordId,
                projectInfo: this.projectInfo,
                rows: this.pagedRows 
            });

            this.showToast('Success', 'Checklist rows saved successfully.', 'success');

            this.newlyUploadedDocIds = []; 

            if (this.isLastPage) {
                this.navigateToChecklistHome();
            } else {
                this.isSaving = false; 
                this.loadRows();
            }
        } catch (error) {
            this.showToast('Error', error?.body?.message || 'Error saving records', 'error');
            this.isSaving = false; 
            this.isLoading = false;
        }
    }

    handleCancel() { 
        if (this.newlyUploadedDocIds.length > 0) {
            deleteOrphanedFiles({ documentIds: this.newlyUploadedDocIds })
                .then(() => {
                    this.navigateToChecklistHome();
                })
                .catch(error => {
                    console.error('Error deleting files on Cancel', error);
                    this.navigateToChecklistHome();
                });
        } else {
            this.navigateToChecklistHome();
        }
    }

    navigateToChecklistHome() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Project_HOTO_Checklist__c', actionName: 'view' }});
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}