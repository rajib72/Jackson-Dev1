import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getApprovalStatus from '@salesforce/apex/LeadApprovalStatusController.getApprovalStatus';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = ['Lead.Approval_Status__c'];

export default class Lwc_leadApprovalPath extends LightningElement {

    @api recordId;
  currentStatus = 'Not Submitted';

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredLead({ data }) {
        if (data) {
            const status = data.fields.Approval_Status__c.value;
            this.currentStatus = status ? status : 'Not Submitted';
        }
    }

    get steps() {
        return [
            { label: 'Not Submitted', css: this.getClass('Not Submitted') },
            { label: 'Pending Approval', css: this.getClass('Pending') },
            { label: 'Approved', css: this.getClass('Approved') },
            { label: 'Rejected', css: this.getClass('Rejected') }
        ];
    }

    getClass(step) {

        // ACTIVE STEP
        if (this.currentStatus === step) {
            return `step active ${this.getStatusClass(step)}`;
        }

        // COMPLETED STEPS
        if (
            this.currentStatus === 'Approved' && step !== 'Rejected' ||
            this.currentStatus === 'Pending' && step === 'Not Submitted'
        ) {
            return 'step complete';
        }

        return 'step';
    }

    getStatusClass(step) {
        switch (step) {
            case 'Pending':
                return 'pending';
            case 'Approved':
                return 'approved';
            case 'Rejected':
                return 'rejected';
            default:
                return '';
        }
    }

    refreshStatus() {
        refreshApex(this.wiredResult);
    }
}