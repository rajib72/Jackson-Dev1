import { LightningElement, api, track } from 'lwc';
import getModuleTypes from '@salesforce/apex/LeadProductController.getModuleTypes';
import getSubTypes from '@salesforce/apex/LeadProductController.getSubTypes';
import getWattPeaks from '@salesforce/apex/LeadProductController.getWattPeaks';
import saveLeadProduct from '@salesforce/apex/LeadProductController.saveLeadProduct';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';


export default class AddLeadProduct extends LightningElement {

    @api recordId; // Lead Id

    moduleType;
    subType;
    wattPeak; // STRING in UI

    @track moduleTypeOptions = [];
    @track subTypeOptions = [];
    @track wattPeakOptions = [];

    disableSubType = true;
    disableWattPeak = true;

    /* ===============================
       LOAD MODULE TYPES
       =============================== */
    connectedCallback() {
        getModuleTypes()
            .then(result => {
                this.moduleTypeOptions = result.map(val => ({
                    label: val,
                    value: val
                }));
            })
            .catch(error => {
                this.showError(error);
            });
    }

    /* ===============================
       MODULE TYPE CHANGE
       =============================== */
    handleModuleTypeChange(event) {
        this.moduleType = event.detail.value;
        this.subType = null;
        this.wattPeak = null;

        this.disableSubType = false;
        this.disableWattPeak = true;
        this.subTypeOptions = [];
        this.wattPeakOptions = [];

        getSubTypes({ moduleType: this.moduleType })
            .then(result => {
                this.subTypeOptions = result.map(val => ({
                    label: val,
                    value: val
                }));
            })
            .catch(error => {
                this.showError(error);
            });
    }

    /* ===============================
       SUB TYPE CHANGE
       =============================== */
    handleSubTypeChange(event) {
        this.subType = event.detail.value;
        this.wattPeak = null;

        this.disableWattPeak = false;
        this.wattPeakOptions = [];

        getWattPeaks({
            moduleType: this.moduleType,
            subType: this.subType
        })
            .then(result => {
                this.wattPeakOptions = result.map(val => ({
                    label: `${val} Wp`,
                    value: val.toString() // ✅ MUST BE STRING
                }));
            })
            .catch(error => {
                this.showError(error);
            });
    }

    /* ===============================
       WATT PEAK CHANGE
       =============================== */
    handleWattPeakChange(event) {
        this.wattPeak = event.detail.value; // STRING
    }

    /* ===============================
       SAVE
       =============================== */
    handleSave() {
        if (!this.moduleType || !this.subType || !this.wattPeak) {
            this.showToast('Error', 'Please select all fields', 'error');
            return;
        }

        saveLeadProduct({
            leadId: this.recordId,
            moduleType: this.moduleType,
            subType: this.subType,
            wattPeak: Number(this.wattPeak) // ✅ Convert to Decimal
        })
            .then(() => {
                this.showToast(
                    'Success',
                    'Product added to Lead successfully',
                    'success'
                );
                // 🔄 THIS refreshes the record page & related lists
                this.dispatchEvent(new RefreshEvent());
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.showError(error);
            });
    }

    /* ===============================
       CANCEL
       =============================== */
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    /* ===============================
       UTILITIES
       =============================== */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }

    showError(error) {
        this.showToast(
            'Error',
            error?.body?.message || 'Unexpected error',
            'error'
        );
    }
}