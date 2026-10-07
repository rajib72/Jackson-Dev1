import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';

import STAGE_FIELD from '@salesforce/schema/Opportunity.KAM_SRT_Opp_Stages__c';
import RECORD_TYPE_FIELD from '@salesforce/schema/Opportunity.RecordTypeId';
import QUALIFICATION_FIELD from '@salesforce/schema/Opportunity.Qualification_To_SalesTeam__c';
import TEST1_FIELD from '@salesforce/schema/Opportunity.Test1__c';
import PO_FIELD from '@salesforce/schema/Opportunity.PO_Received__c';
import OFFER_PROCESS_FIELD from '@salesforce/schema/Opportunity.Offer_Management_Process__c';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import updateStageAndCreateRemark
    from '@salesforce/apex/UpdateKamSRTOpportunityStageController.updateStageAndCreateRemark';

export default class UpdateKamSRTOpportunityStage extends LightningElement {

    @api recordId;

    @track isStepOne = true;
    @track isStepTwo = false;

    @track stageOptions = [];
    @track selectedStage = '';
    @track selectedStageLabel = '';

    @track remarks = '';

    @track qualificationChecked = false;
    @track test1Checked = false;
    @track poReceivedChecked = false;

    @track offerProcessValue = '';
    @track offerProcessOptions = [];
    @track offerProcessLabel = '';

    @track uploadedFiles = [];

    // Modal state for picklist
    @track isPicklistOpen = false;
    @track modalOptions = [];
    @track modalLabel = '';
    @track modalSelected = '';
    // Which picklist opened: 'stage' or 'offer'
    modalTarget = null;

    recordTypeId;
    currentStage;

    /* Store wired result for refresh */
    wiredOppResult;

    /* ================= LOAD RECORD ================= */
    @wire(getRecord, {
        recordId: '$recordId',
        fields: [
            STAGE_FIELD,
            RECORD_TYPE_FIELD,
            QUALIFICATION_FIELD,
            TEST1_FIELD,
            PO_FIELD
        ]
    })
    wiredOpp(result) {
        this.wiredOppResult = result;

        const { data } = result;
        if (data) {
            this.currentStage = getFieldValue(data, STAGE_FIELD);
            this.selectedStage = this.currentStage;
            this.selectedStageLabel = this.getLabelFromOptions(this.stageOptions, this.currentStage) || this.currentStage || '';

            this.recordTypeId = getFieldValue(data, RECORD_TYPE_FIELD);

            this.qualificationChecked =
                getFieldValue(data, QUALIFICATION_FIELD);

            this.test1Checked =
                getFieldValue(data, TEST1_FIELD);

            this.poReceivedChecked =
                getFieldValue(data, PO_FIELD);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: STAGE_FIELD
    })
    wiredPicklist({ data }) {
        if (data) {
            this.stageOptions = data.values.map(v => ({
                label: v.label,
                value: v.value
            }));
            // update selected label if needed
            this.selectedStageLabel = this.getLabelFromOptions(this.stageOptions, this.selectedStage) || this.selectedStageLabel;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: OFFER_PROCESS_FIELD
    })
    wiredOfferProcess({ data }) {
        if (data) {
            this.offerProcessOptions = data.values.map(v => ({
                label: v.label,
                value: v.value
            }));
            this.offerProcessLabel = this.getLabelFromOptions(this.offerProcessOptions, this.offerProcessValue) || this.offerProcessLabel;
        }
    }

    /* ================= VISIBILITY ================= */

    get showQualificationCheckbox() {
        return this.currentStage === 'Qualification';
    }

    get showQualificationUpload() {
        return this.showQualificationCheckbox &&
               this.qualificationChecked;
    }

    get showTest1Checkbox() {
        return this.currentStage === 'Assign to Sales Team';
    }

    get showTest1Upload() {
        return this.showTest1Checkbox &&
               this.test1Checked;
    }

    get showOfferProcessPicklist() {
        return this.currentStage === 'Assign to Pre Design Team' &&
               this.selectedStage === 'Techno Commercial Offer';
    }

    get showPOSection() {
        return this.currentStage === 'Submit to Customer'
               && this.selectedStage === 'PO Received';
    }

    /* ================= HELPERS ================= */

    getLabelFromOptions(options, value) {
        if (!options || !value) return '';
        const opt = options.find(o => o.value === value);
        return opt ? opt.label : '';
    }

    /* ================= PICKLIST MODAL HANDLERS ================= */

    openPicklistModal(event) {
        // determine which picklist was clicked using data attribute
        const target = event.currentTarget.dataset.picklist;
        this.modalTarget = target === 'offer' ? 'offer' : 'stage';

        if (this.modalTarget === 'stage') {
            this.modalOptions = this.stageOptions;
            this.modalLabel = 'Change Stage To';
            this.modalSelected = this.selectedStage;
        } else {
            this.modalOptions = this.offerProcessOptions;
            this.modalLabel = 'Offer Management Process';
            this.modalSelected = this.offerProcessValue;
        }

        this.isPicklistOpen = true;
    }

    closePicklistModal() {
        this.isPicklistOpen = false;
        this.modalOptions = [];
        this.modalSelected = '';
        this.modalLabel = '';
        this.modalTarget = null;
    }

    // allow keyboard Enter to open modal
    handleComboboxKey(e) {
        if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            this.openPicklistModal(e);
        }
    }

    handlePicklistSave(event) {
        const value = event.detail;
        if (this.modalTarget === 'stage') {
            this.selectedStage = value;
            this.selectedStageLabel = this.getLabelFromOptions(this.stageOptions, value) || value;
        } else if (this.modalTarget === 'offer') {
            this.offerProcessValue = value;
            this.offerProcessLabel = this.getLabelFromOptions(this.offerProcessOptions, value) || value;
        }

        // close modal
        this.closePicklistModal();
    }

    /* ================= HANDLERS (existing) ================= */

    handleQualificationChange(event) {
        this.qualificationChecked = event.target.checked;
    }

    handleTest1Change(event) {
        this.test1Checked = event.target.checked;
    }

    handlePOChange(event) {
        this.poReceivedChecked = event.target.checked;
    }

    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }

    handleUploadFinished(event) {
        const uploaded = event.detail.files;

        uploaded.forEach(file => {
            this.uploadedFiles = [
                ...this.uploadedFiles,
                { documentId: file.documentId, name: file.name }
            ];
        });
    }

    goToStepTwo() {
        if (!this.selectedStage) {
            this.showToast('Error', 'Please select a stage', 'error');
            return;
        }
        this.isStepOne = false;
        this.isStepTwo = true;
    }

    goToStepOne() {
        this.isStepOne = true;
        this.isStepTwo = false;
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    /* ================= SAVE (existing) ================= */

    async saveStage() {
        try {
            // ===== Validations =====
            if (!this.remarks) {
                this.showToast('Error', 'Remarks required', 'error');
                return;
            }

            if (this.showQualificationUpload && this.uploadedFiles.length === 0) {
                this.showToast('Error', 'Please upload Qualification files', 'error');
                return;
            }

            if (this.showTest1Upload && this.uploadedFiles.length === 0) {
                this.showToast('Error', 'Please upload Pre Design files', 'error');
                return;
            }

            if (this.showOfferProcessPicklist && !this.offerProcessValue) {
                this.showToast('Error', 'Please select Offer Management Process', 'error');
                return;
            }

            if (this.showPOSection && (!this.poReceivedChecked || this.uploadedFiles.length === 0)) {
                this.showToast('Error', 'Please Check PO Received and upload file', 'error');
                return;
            }

            // ===== Apex Call =====
            await updateStageAndCreateRemark({
                opportunityId: this.recordId,
                selectedStage: this.selectedStage,
                remarksText: this.remarks,
                qualificationChecked: this.qualificationChecked,
                test1Checked: this.test1Checked,
                offerProcessValue: this.offerProcessValue,
                poReceivedChecked: this.poReceivedChecked
            });

            // ===== Refresh UI =====
            await refreshApex(this.wiredOppResult);
            getRecordNotifyChange([{ recordId: this.recordId }]);

            this.showToast('Success', 'Stage updated successfully', 'success');

            // Close after short delay so user sees toast
            setTimeout(() => {
                this.dispatchEvent(new CloseActionScreenEvent());
                this.dispatchEvent(new CustomEvent('closequickaction', { bubbles: true, composed: true }));
            }, 200);

        } catch (error) {
            this.showToast(
                'Error',
                error?.body?.message || error?.message || 'Something went wrong',
                'error'
            );
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}