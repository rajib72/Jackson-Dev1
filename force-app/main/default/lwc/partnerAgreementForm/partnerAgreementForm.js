import { LightningElement, track, api } from 'lwc';
import createAgreementWithFiles from '@salesforce/apex/PartnerAgreementLWCController.createAgreementWithFiles';
import getAgreementTypeValues from '@salesforce/apex/PartnerAgreementLWCController.getAgreementTypeValues';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PartnerAgreementForm extends LightningElement {

    @api recordId;

    @track agr = {};
    @track typeOptions = [];

    @track docFiles = [];
    @track docFileNames = [];
    @track signatureFile = null;
    @track signatureFileName;

    @track isSubmitted = false;

    connectedCallback() {
        this.loadPicklist();
    }

    // 🔥 Use Apex instead of LDS
    loadPicklist() {
        getAgreementTypeValues()
            .then(result => {
                this.typeOptions = result.map(value => ({
                    label: value,
                    value: value
                }));
            })
            .catch(error => {
                console.error('Picklist Error:', error);
                this.showToast('Error', 'Unable to load Agreement Type values', 'error');
            });
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;

        const value = event.target.type === 'checkbox'
            ? event.target.checked
            : event.target.value;

        // Immutable update so LWC reactivity picks up changes
        this.agr = { ...this.agr, [field]: value };
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
        if (file) {
            this.signatureFile = file;
            this.signatureFileName = file.name;
        }
    }

    toBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result.split(',')[1]);
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    validate() {
        if (!this.recordId) {
            this.showToast('Error', 'Component must be on Partner record page.', 'error');
            return false;
        }

        const requiredFields = [
            { api: 'Name', label: 'Agreement Details Name' },
            { api: 'Agreement_Date__c', label: 'Agreement Date' },
            { api: 'Agreement_Start_Date__c', label: 'Agreement Start Date' },
            { api: 'Agreement_End_Date__c', label: 'Agreement End Date' }
        ];

        // for (const f of requiredFields) {
        //     if (!this.agr[f.api] || String(this.agr[f.api]).trim() === '') {
        //         this.showToast('Error', `${f.label} is required.`, 'error');
        //         return false;
        //     }
        // }

        if (!this.signatureFile) {
            this.showToast('Error', 'Please upload signature file.', 'error');
            return false;
        }

        return true;
    }

    async handleSave() {

        console.log('Saving agreement...');
        console.log('recordId:', this.recordId);
        console.log('agr object:', JSON.stringify(this.agr));

        if (!this.validate()) {
            console.log('Validation failed');
            return;
        }

        this.agr = {
            ...this.agr,
            Partner__c: this.recordId,
            Agreement_Status__c: 'Signed',
            Agreement_Signed__c: true
        };

        try {

            const docData = await Promise.all(
                this.docFiles.map(file => this.toBase64(file))
            );

            let signatureData = null;
            if (this.signatureFile) {
                signatureData = await this.toBase64(this.signatureFile);
            }

            const result = await createAgreementWithFiles({
                agrRecord: this.agr,
                docFiles: docData,
                docFileNames: this.docFileNames,
                signatureFile: signatureData,
                signatureFileName: this.signatureFileName
            });

            console.log('Insert Success:', result);

            this.resetForm();
            this.isSubmitted = true;
            this.showToast('Success', 'Agreement created successfully!', 'success');

        } catch (error) {

            console.log('FULL ERROR:', JSON.stringify(error));
            alert(JSON.stringify(error));
        }
    }

    resetForm() {
        this.agr = {};
        this.docFiles = [];
        this.docFileNames = [];
        this.signatureFile = null;
        this.signatureFileName = null;

        const fileInputs = this.template.querySelectorAll('lightning-input[type="file"]');
        fileInputs.forEach(input => input.value = null);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}