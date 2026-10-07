import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import getWorkOrderDetails from '@salesforce/apex/Ctrl_createDiagnosisFromWorkOrder.getWorkOrderDetails';

// Import necessary Work Order fields for validation
import ESTIMATION_COST_FIELD from '@salesforce/schema/WorkOrder.Final_Service_Estimation_Cost__c';
import EXECUTION_MODE_FIELD from '@salesforce/schema/WorkOrder.Execution_Mode__c';
import WORK_ORDER_ID_FIELD from '@salesforce/schema/WorkOrder.Id';
import DIAGNOSIS_CREATED_FIELD from '@salesforce/schema/WorkOrder.Diagnosis_Created__c';

export default class Lwc_createDiagnosisFromWorkOrder extends LightningElement {
    @api recordId; 
    @track caseId;
    @track systemType = ''; // Track the picklist value

    showError = false;
    isLoading = true;

    // Fetch the Work Order record for UI validation
    @wire(getRecord, { recordId: '$recordId', fields: [ESTIMATION_COST_FIELD, EXECUTION_MODE_FIELD] })
    wiredWorkOrderRecord({ error, data }) {
        if (data) {
            // Default to 0 if the field is blank/null
            const cost = getFieldValue(data, ESTIMATION_COST_FIELD) || 0;
            const mode = getFieldValue(data, EXECUTION_MODE_FIELD);

            // Condition 1: Mode = Site Visit and Cost > 0
            const isSiteVisitWithCost = (mode === 'Site Visit' && cost > 0);
            
            // Condition 2: Mode = Remote
            const isRemote = (mode === 'Remote');
            
            // Condition 3: Mode = Site Visit and Cost = 0
            const isSiteVisitWithoutCost = (mode === 'Site Visit' && cost === 0);

            // If ANY of these 3 conditions are true, the LWC works normally.
            const showLwcNormally = isSiteVisitWithCost || isRemote || isSiteVisitWithoutCost;

            // If we are NOT showing the LWC normally, we trigger the error message.
            this.showError = !showLwcNormally;
            this.isLoading = false;

        } else if (error) {
            console.error('Error fetching UI Record details for validation:', error);
            this.isLoading = false;
        }
    }

    // Keep the existing apex method for getting CaseId 
    @wire(getWorkOrderDetails, { workOrderId: '$recordId' })
    wiredWorkOrder({ error, data }) {
        if (data) {
            this.caseId = data.CaseId;
        } else if (error) {
            console.error('Error fetching Work Order details:', error);
        }
    }

    // Logic to check if the system is Off Grid
    get isOffGrid() {
        return this.systemType === 'Off Grid';
    }

    handleFieldChange(event) {
        if (event.target.fieldName === 'System_Type__c') {
            this.systemType = event.detail.value;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // handleSuccess() {
    //     this.showToast('Success', 'Diagnosis created successfully.', 'success');
    //     this.dispatchEvent(new CloseActionScreenEvent());
    // }

    handleSuccess() {
        // 1. Prepare the fields to update on the Work Order
        const fields = {};
        fields[WORK_ORDER_ID_FIELD.fieldApiName] = this.recordId;
        fields[DIAGNOSIS_CREATED_FIELD.fieldApiName] = true;

        const recordInput = { fields };

        // 2. Call updateRecord to update the Work Order
        updateRecord(recordInput)
            .then(() => {
                this.showToast('Success', 'Diagnosis created', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                console.error('Error updating Work Order:', error);
                this.showToast('Partial Success', 'Diagnosis created, but failed to update the Work Order checkbox.', 'warning');
                this.dispatchEvent(new CloseActionScreenEvent());
            });
    }

    handleError(event) {
        this.showToast('Error saving record', event.detail.detail, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}