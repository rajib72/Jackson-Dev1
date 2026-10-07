import { LightningElement, track, api, wire } from 'lwc';
import createRegistrationWithFiles from '@salesforce/apex/PartnerRegistrationLWCController.createRegistrationWithFiles';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import REG_OBJECT from '@salesforce/schema/Registration_Details__c';
import TYPE_OF_ENTITY from '@salesforce/schema/Registration_Details__c.Type_Of_Entity__c';
import MSME_STATUS from '@salesforce/schema/Registration_Details__c.MSME_Status__c';

export default class PartnerRegistrationForm extends LightningElement {

    @api recordId;

    @track reg = {};
    @track entityOptions = [];
    @track msmeOptions = [];

    @track docFiles = [];
    @track signatureFile = null;

    @track docFileNames = [];
    @track signatureFileName;

    @track isSubmitted = false;   // ✅ Added

    termsAccepted = false;
    recordTypeId;

    @wire(getObjectInfo, { objectApiName: REG_OBJECT })
    objectInfo({ data }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: TYPE_OF_ENTITY
    })
    entityPicklist({ data }) {
        if (data) {
            this.entityOptions = data.values;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: MSME_STATUS
    })
    msmePicklist({ data }) {
        if (data) {
            this.msmeOptions = data.values;
        }
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.reg[field] = event.target.value;
    }

    handleCheckbox(event) {
        this.termsAccepted = event.target.checked;
    }

    handleDocSelection(event) {
        const files = event.target.files;
        this.docFiles = [];
        this.docFileNames = [];

        for (let i = 0; i < files.length; i++) {
            this.docFiles.push(files[i]);
            this.docFileNames.push(files[i].name);
        }
    }

    handleSignatureSelection(event) {
        const file = event.target.files[0];
        this.signatureFile = file;
        this.signatureFileName = file.name;
    }

    async handleSave() {

        if (!this.recordId) {
            this.showToast('Error', 'Component must be on Partner record page.', 'error');
            return;
        }

        if (!this.termsAccepted) {
            this.showToast('Error', 'Please accept program terms.', 'error');
            return;
        }

        this.reg.Partner__c = this.recordId;

        const docData = await Promise.all(
            this.docFiles.map(file => this.toBase64(file))
        );

        let signatureData = null;
        if (this.signatureFile) {
            signatureData = await this.toBase64(this.signatureFile);
        }

        createRegistrationWithFiles({
            regRecord: this.reg,
            docFiles: docData,
            docFileNames: this.docFileNames,
            signatureFile: signatureData,
            signatureFileName: this.signatureFileName
        })
        .then(() => {
            this.resetForm();
            this.isSubmitted = true;   // ✅ Show success screen
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || 'Error occurred', 'error');
        });
    }

    resetForm() {
        this.reg = {};
        this.docFiles = [];
        this.signatureFile = null;
        this.docFileNames = [];
        this.signatureFileName = null;
        this.termsAccepted = false;

        const fileInputs = this.template.querySelectorAll('lightning-input[type="file"]');
        fileInputs.forEach(input => {
            input.value = null;
        });
    }

    toBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result.split(',')[1]);
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}