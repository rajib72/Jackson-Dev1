import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchContacts from '@salesforce/apex/ctrl_CaseContactLookupController.searchContacts';

export default class CustomCaseCreation extends LightningElement {
    accountId;
    contactId;
    contactOptions = [];
    isSaving = false;

    showOtherComplaintType = false;
    showOtherProductCategory = false;
    showOtherInstallerType = false;
    showOtherCustomerPersona = false;
    otherComplaintType = '';
    otherProductCategory = '';
    otherInstallerType = '';
    otherCustomerPersona = '';
    internalBusinessTeam = 'Solar Sales';
    businessSegment = 'Solar';

    @api
    get parentAccountId() {
        return this.accountId;
    }

    set parentAccountId(value) {
        if (value) {
            this.accountId = value;
            this.loadContacts();
        } else {
            this.getAccountFromContext();
        }
    }

    connectedCallback() {
        this.getAccountFromContext();
    }

    get contactDisabled() {
        return !this.accountId || this.contactOptions.length === 0;
    }

    handleComplaintTypeChange(event) {
        const value = event.detail.value;
        this.showOtherComplaintType = value === 'Any Other Problem';
        if (!this.showOtherComplaintType) {
            this.otherComplaintType = '';
        }
    }

    handleOtherComplaintTypeChange(event) {
        this.otherComplaintType = event.target.value;
        console.log('DEBUG - Other Complaint Type:', this.otherComplaintType);
    }

    handleProductCategoryChange(event) {
        const value = event.detail.value;
        this.showOtherProductCategory = value === 'Other';
        if (!this.showOtherProductCategory) {
            this.otherProductCategory = '';
        }
    }

    handleOtherProductCategoryChange(event) {
        this.otherProductCategory = event.target.value;
        console.log('DEBUG - Other Product Category:', this.otherProductCategory);
    }

    handleInstallerTypeChange(event) {
        const value = event.detail.value;
        this.showOtherInstallerType = value === 'Other';
        if (!this.showOtherInstallerType) {
            this.otherInstallerType = '';
        }
    }

    handleOtherInstallerTypeChange(event) {
        this.otherInstallerType = event.target.value;
        console.log('DEBUG - Other Installer Type:', this.otherInstallerType);
    }

    handleCustomerPersonaChange(event) {
        const value = event.detail.value;
        this.showOtherCustomerPersona = value === 'Other';
        if (!this.showOtherCustomerPersona) {
            this.otherCustomerPersona = '';
        }
    }

    handleOtherCustomerPersonaChange(event) {
        this.otherCustomerPersona = event.target.value;
        console.log('DEBUG - Other Customer Persona:', this.otherCustomerPersona);
    }

    getAccountFromContext() {
        if (this.accountId) {
            this.loadContacts();
            return;
        }
        const urlParams = new URLSearchParams(window.location.search);
        const inContextOfRef = urlParams.get('inContextOfRef');
        console.log('debug:: inContextOfRef' + inContextOfRef);
        if (!inContextOfRef) {
            return;
        }
        try {
            let encodedValue = inContextOfRef;
            if (encodedValue.startsWith('1.')) {
                encodedValue = encodedValue.substring(2);
            }
            encodedValue = encodedValue.replace(/-/g, '+').replace(/_/g, '/');
            while (encodedValue.length % 4) {
                encodedValue += '=';
            }
            const decodedValue = atob(encodedValue);
            const contextData = JSON.parse(decodedValue);
            if (contextData?.attributes?.recordId) {
                this.accountId = contextData.attributes.recordId;
                console.log('debug:: this.accountId ' + this.accountId);
                this.loadContacts();
            }
        } catch (error) {
            console.error('Unable to extract Account Id from context:', error);
        }
    }

    async loadContacts() {
        if (!this.accountId) {
            this.contactOptions = [];
            this.contactId = null;
            return;
        }
        try {
            const contacts = await searchContacts({
                accountId: this.accountId,
                searchTerm: ''
            });
            this.contactOptions = contacts.map(contact => ({
                label: contact.Name,
                value: contact.Id
            }));
            this.contactId = null;
        } catch (error) {
            this.contactOptions = [];
            this.contactId = null;
            this.showError(error);
        }
    }

    handleAccountChange(event) {
        this.accountId = event.detail.value;
        this.contactId = null;
        this.contactOptions = [];
        if (this.accountId) {
            this.loadContacts();
        }
    }

    handleContactChange(event) {
        this.contactId = event.detail.value;
    }

    handleSave() {
        console.log('DEBUG - SAVE BUTTON CLICKED');
        console.log('DEBUG - Other Complaint Type at Save:', this.otherComplaintType);
        const otherComplaintField = this.template.querySelector('.hidden-other-complaint-field lightning-input-field');
        if (otherComplaintField) {
            otherComplaintField.value = this.showOtherComplaintType ? this.otherComplaintType : null;
        }

        const otherProductCategory = this.template.querySelector('.hidden-other-complaint-field lightning-input-field');
        if (otherProductCategory) {
            otherProductCategory.value = this.showOtherProductCategory ? this.otherProductCategory : null;
        }

        const otherInstallerType = this.template.querySelector('.hidden-other-complaint-field lightning-input-field');
        if (otherInstallerType) {
            otherInstallerType.value = this.showOtherInstallerType ? this.otherInstallerType : null;
        }

        const otherCustomerPersona = this.template.querySelector('.hidden-other-complaint-field lightning-input-field');
        if (otherCustomerPersona) {
            otherCustomerPersona.value = this.showOtherCustomerPersona ? this.otherCustomerPersona : null;
        }
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) {
            form.submit();
        }
    }

    handleSubmit(event) {
        console.log('DEBUG - HANDLE SUBMIT FIRED');
        event.preventDefault();
        this.isSaving = true;
        const fields = event.detail.fields;
        fields.AccountId = this.accountId;
        fields.ContactId = this.contactId || null;
        fields.Status = 'New';
        fields.Priority = fields.Priority || 'Medium';
        fields.Other_Complain_Type__c = this.showOtherComplaintType ? this.otherComplaintType : null;
        console.log('DEBUG - Other_Complain_Type__c before submit:', fields.Other_Complain_Type__c);
        fields.Other_Product_Category__c = this.showOtherProductCategory ? this.otherProductCategory : null;
        fields.Other_Installer_Type__c = this.showOtherInstallerType ? this.otherInstallerType : null;
        fields.Other_Customer_Persona__c = this.showOtherCustomerPersona ? this.otherCustomerPersona : null;
        console.log('DEBUG - FINAL CASE FIELDS:', JSON.stringify(fields));
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess(event) {
        this.isSaving = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Case created successfully.',
            variant: 'success'
        }));
        window.location.href = `/lightning/r/Case/${event.detail.id}/view`;
    }

    handleError(event) {
        this.isSaving = false;
        const message = event.detail?.detail || 'An error occurred while creating the Case.';
        this.showError({ body: { message } });
    }

    handleCancel() {
        window.history.back();
    }

    showError(error) {
        const message = error?.body?.message || error?.message || 'An unexpected error occurred.';
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message,
            variant: 'error'
        }));
    }
}