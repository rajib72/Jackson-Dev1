import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFullApprovalHistory from '@salesforce/apex/ApprovalHistoryController.getFullApprovalHistory';
import processApprovalAction from '@salesforce/apex/ApprovalHistoryController.processApprovalAction';

function getRowActions(row, doneCallback) {
    const actions = [];
    if (row.IsPending) {
        actions.push({ label: 'Approve', name: 'Approve' });
        actions.push({ label: 'Reject', name: 'Reject' });
    }
    doneCallback(actions);
}

const COLUMNS = [
    { label: 'Step Name', fieldName: 'StepName', type: 'text', initialWidth: 180 },
    { 
        label: 'Date', 
        fieldName: 'CreatedDate', 
        type: 'date', 
        typeAttributes: { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' },
        initialWidth: 170
    },
    { label: 'Status', fieldName: 'Status', type: 'text' },
    { label: 'Assigned To', fieldName: 'AssignedTo', type: 'text' },
    { label: 'Actual Approver', fieldName: 'ActualApprover', type: 'text' },
    { label: 'Comments', fieldName: 'Comments', type: 'text' },
    { type: 'action', typeAttributes: { rowActions: getRowActions } }
];

export default class ApprovalHistory extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    
    @track approvalData = [];
    wiredResult;
    
    // UI State variables
    isLoading = false;
    showModal = false;
    modalAction = '';
    comments = '';
    
    // Internal variables
    activeWorkItemId = null;
    pendingWorkItemId = null; 

    get cardTitle() {
        return `Approval History (${this.approvalData.length})`;
    }

    // Controls the visibility of the top Approve/Reject buttons
    get showTopActions() {
        return this.pendingWorkItemId !== null;
    }

    @wire(getFullApprovalHistory, { recordId: '$recordId' })
    wiredApprovals(result) {
        this.wiredResult = result;
        if (result.data) {
            this.approvalData = result.data;
            
            // Find the pending WorkItem for the top-level buttons
            const pendingRow = this.approvalData.find(row => row.IsPending);
            this.pendingWorkItemId = pendingRow ? pendingRow.Id : null;
            
        } else if (result.error) {
            this.showToast('Error', 'Could not load approval history.', 'error');
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    handleTopApprove() {
        this.openModal(this.pendingWorkItemId, 'Approve');
    }

    handleTopReject() {
        this.openModal(this.pendingWorkItemId, 'Reject');
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const rowId = event.detail.row.Id;
        this.openModal(rowId, actionName);
    }

    openModal(workItemId, actionName) {
        this.activeWorkItemId = workItemId;
        this.modalAction = actionName;
        this.comments = ''; 
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
        this.activeWorkItemId = null;
        this.modalAction = '';
    }

    handleCommentChange(event) {
        this.comments = event.target.value;
    }

    submitAction() {
        this.isLoading = true;
        this.showModal = false; 

        processApprovalAction({ 
            workItemId: this.activeWorkItemId, 
            actionName: this.modalAction, 
            comments: this.comments 
        })
        .then(() => {
            this.showToast('Success', `Approval successfully ${this.modalAction.toLowerCase()}d.`, 'success');
            this.handleRefresh(); 
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || 'An error occurred.', 'error');
            this.isLoading = false;
        })
        .finally(() => {
            this.closeModal(); 
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}