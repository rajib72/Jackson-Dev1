import { LightningElement, track } from 'lwc';
import search from '@salesforce/apex/Ctrl_CaseCreationForm.search';
import loadByAccountId from '@salesforce/apex/Ctrl_CaseCreationForm.loadByAccountId';
import getInitData from '@salesforce/apex/Ctrl_CaseCreationForm.getInitData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import createCase2 from '@salesforce/apex/Ctrl_CaseCreationForm.createCase2';

export default class CaseCreationFormLWC extends NavigationMixin(LightningElement) {

    @track searchKey = '';
    @track isLoading = false;

    @track account = null;
    @track contacts = [];
    @track assets = [];
    @track matchedBy = '';

    @track accountResults = [];
    @track showAccountPicklist = false;
    @track selectedAccountRows = [];

    @track selectedContactId = null;
    @track selectedAssetIds = [];

    @track showContactRequiredMsg = false;
    @track showAssetRequiredMsg = false;

    @track complaintTypeOptions = [];
    @track statusOptions = [];
    @track originOptions = [];
    @track productCategoryOptions = [];
    @track installerTypeOptions = [];
    @track customerPersonaOptions = [];

    @track subject = '';
    @track description = '';
    @track complaintTypeVal = '';
    @track statusVal = 'New';
    @track originVal = '';

    @track productCategoryVal = '';
    @track otherProductCategoryVal = '';
    @track vocText = '';
    @track installerTypeVal = '';
    @track otherInstallerVal = '';
    @track customerPersonaVal = '';
    @track otherComplaintTypeVal = '';

    // NEW: create new account/contact flow
    @track isNewAccountContactFlow = false;

    @track newAccountName = '';
    @track newAccountPhone = '';
    @track newAccountBillingCity = '';
    @track newAccountBillingState = '';
    @track newAccountBillingStreet = '';
    @track newAccountBillingPostalCode = '';
    @track newAccountBillingCountry = '';

    @track newContactFirstName = '';
    @track newContactLastName = '';
    @track newContactPhone = '';
    @track newContactMobilePhone = '';
    @track newContactEmail = '';
    @track newContactDepartment = '';

    accountColumns = [
        { label: 'Account', fieldName: 'name' },
        { label: 'Phone', fieldName: 'phone' },
        { label: 'City', fieldName: 'billingCity' },
        { label: 'State', fieldName: 'billingState' }
    ];

    getId(obj) { return obj?.id || obj?.Id || null; }

    get selectedAssetIdsText() {
        return (this.selectedAssetIds || []).join(', ');
    }

    getSelectedCheckboxValues(checkboxName) {
        const boxes = this.template.querySelectorAll(`lightning-input[name="${checkboxName}"]`);
        if (!boxes || !boxes.length) return [];
        return Array.from(boxes)
            .filter(b => b.checked)
            .map(b => b.dataset?.id)
            .filter(x => !!x);
    }

    get hasAccount() { return !!this.getId(this.account); }

    get showNoResult() {
        return !this.isLoading && !this.hasAccount && this.isNewAccountContactFlow;
    }

    get showCreateNewFlow() {
        return this.isNewAccountContactFlow && !this.hasAccount;
    }

    get showCaseSection() {
        return this.hasAccount || this.isNewAccountContactFlow;
    }

    get accountSectionLabel() {
        return this.matchedBy ? `Account Details (Matched By: ${this.matchedBy})` : 'Account Details';
    }
    get contactSectionLabel() { return `Related Contacts (${this.contacts?.length || 0})`; }
    get assetSectionLabel() { return `Related Assets (${this.assets?.length || 0})`; }

   // get showOtherInstaller() { return this.installerTypeVal === 'Other'; }
    get showOtherComplaintType() { return this.complaintTypeVal === 'Any Other Problem'; }
    get showOtherProductCategory() { return this.productCategoryVal === 'Other'; }

    get disableCreateCase() {
        // Existing account flow
        if (this.hasAccount) {
            return (
                !this.hasAccount ||
                !this.selectedContactId ||
                !this.subject || this.subject.trim().length === 0 ||
                !this.originVal || this.originVal.trim().length === 0 ||
                !this.description || this.description.trim().length === 0 ||
                //(this.showOtherInstaller && (!this.otherInstallerVal || this.otherInstallerVal.trim().length === 0)) ||
                (this.showOtherComplaintType && (!this.otherComplaintTypeVal || this.otherComplaintTypeVal.trim().length === 0)) ||
                (this.showOtherProductCategory && (!this.otherProductCategoryVal || this.otherProductCategoryVal.trim().length === 0))
            );
        }

        // New account/contact flow
        if (this.isNewAccountContactFlow) {
            return (
                !this.newAccountName || this.newAccountName.trim().length === 0 ||
                !this.newContactLastName || this.newContactLastName.trim().length === 0 ||
                !this.subject || this.subject.trim().length === 0 ||
                !this.originVal || this.originVal.trim().length === 0 ||
                !this.description || this.description.trim().length === 0 ||
                //(this.showOtherInstaller && (!this.otherInstallerVal || this.otherInstallerVal.trim().length === 0)) ||
                (this.showOtherComplaintType && (!this.otherComplaintTypeVal || this.otherComplaintTypeVal.trim().length === 0)) ||
                (this.showOtherProductCategory && (!this.otherProductCategoryVal || this.otherProductCategoryVal.trim().length === 0))
            );
        }

        return true;
    }

    connectedCallback() {
        this.loadInit();
        this.statusVal = 'New';
    }

    async loadInit() {
        try {
            const res = await getInitData();
            this.complaintTypeOptions = this.toComboWithSelect(res.complaintTypeOptions);
            this.statusOptions = this.toComboWithSelect(res.caseStatusOptions);
            this.originOptions = this.toComboWithSelect(res.caseOriginOptions);
            this.productCategoryOptions = this.toComboWithSelect(res.productCategoryOptions);
            this.installerTypeOptions = this.toComboWithSelect(res.installerTypeOptions);
            this.customerPersonaOptions = this.toComboWithSelect(res.customerPersonaOptions);
            this.statusVal = 'New';
        } catch (e) {
            this.toast('Error', this.reduceError(e), 'error');
        }
    }

    toComboWithSelect(list) {
        const opts = (list || []).map(x => ({ label: x.label, value: x.value }));
        return [{ label: '--Select--', value: '' }, ...opts];
    }

    handleChange(e) { this.searchKey = e.target.value; }
    handleKeyUp(e) { if (e.key === 'Enter') this.handleSearch(); }

    async handleSearch() {
        const key = (this.searchKey || '').trim();
        if (key.length < 2) {
            this.toast('Validation', 'Please enter at least 2 characters.', 'warning');
            return;
        }

        this.isLoading = true;
        this.resetSearchData();

        try {
            const res = await search({ term: key });

            if (res && res.account) {
                this.isNewAccountContactFlow = false;

                this.account = res.account;
                this.matchedBy = res.matchedBy;

                this.accountResults = (res.accountResults || []);
                this.showAccountPicklist = (this.matchedBy === 'Account' && this.accountResults.length > 1);

                this.contacts = (res.contacts || []).map(c => {
                    const id = this.getId(c);
                    return { ...c, id, isSelected: false };
                });

                this.assets = (res.assets || []).map(a => {
                    const id = this.getId(a);
                    return { ...a, id, isSelected: false };
                });
            } else {
                this.account = null;
                this.contacts = [];
                this.assets = [];
                this.matchedBy = 'None';
                this.isNewAccountContactFlow = true;
            }

        } catch (e) {
            this.account = null;
            this.contacts = [];
            this.assets = [];
            this.matchedBy = 'None';
            this.isNewAccountContactFlow = true;
        } finally {
            this.isLoading = false;
        }
    }

    async handleAccountRowSelect(event) {
        const rows = event.detail.selectedRows;
        if (!rows || rows.length === 0) return;

        const selected = rows[0];
        const accId = this.getId(selected);

        if (selected?.name) this.searchKey = selected.name;

        this.isLoading = true;
        try {
            const res = await loadByAccountId({ accountId: accId });
            if (!res || !res.account) return;

            this.account = res.account;
            this.matchedBy = res.matchedBy;
            this.isNewAccountContactFlow = false;

            this.showAccountPicklist = false;
            this.accountResults = [];
            this.selectedAccountRows = [accId];

            this.contacts = (res.contacts || []).map(c => ({ ...c, id: this.getId(c), isSelected: false }));
            this.assets = (res.assets || []).map(a => ({ ...a, id: this.getId(a), isSelected: false }));

            this.selectedContactId = null;
            this.selectedAssetIds = [];

        } catch (e) {
            this.toast('Error', this.reduceError(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleContactRadioChange(event) {
        const id = event.currentTarget?.dataset?.id || event.target?.value;
        this.selectedContactId = id || null;
        this.showContactRequiredMsg = false;

        this.contacts = (this.contacts || []).map(c => ({ ...c, isSelected: c.id === this.selectedContactId }));
    }

    handleAssetCheckboxChange(event) {
        const id = event.currentTarget?.dataset?.id;
        const checked = event.target?.checked;

        if (!id) return;

        let ids = new Set(this.selectedAssetIds || []);
        if (checked) ids.add(id);
        else ids.delete(id);

        this.selectedAssetIds = Array.from(ids);
        this.showAssetRequiredMsg = false;

        this.assets = (this.assets || []).map(a => ({ ...a, isSelected: ids.has(a.id) }));
    }

    // case fields
    handleSubject(e) { this.subject = e.target.value; }
    handleDescription(e) { this.description = e.target.value; }
    handleComplaintType(e) {
        this.complaintTypeVal = e.detail.value;
        if (this.complaintTypeVal !== 'Other') this.otherComplaintTypeVal = '';
    }
    handleStatus(e) { this.statusVal = e.detail.value; }
    handleOrigin(e) { this.originVal = e.detail.value; }
    handleProductCategory(e) {
        this.productCategoryVal = e.detail.value;
        if (this.productCategoryVal !== 'Other') this.otherProductCategoryVal = '';
    }
    handleOtherProductCategory(e) { this.otherProductCategoryVal = e.target.value; }
    handleVocText(e) { this.vocText = e.target.value; }
    handleInstallerType(e) {
        this.installerTypeVal = e.detail.value;
        if (this.installerTypeVal !== 'Other') this.otherInstallerVal = '';
    }
    handleOtherInstaller(e) { this.otherInstallerVal = e.target.value; }
    handleCustomerPersona(e) { this.customerPersonaVal = e.detail.value; }
    handleOtherComplaintType(e) { this.otherComplaintTypeVal = e.target.value; }

    // NEW account fields
    handleNewAccountName(e) { this.newAccountName = e.target.value; }
    handleNewAccountPhone(e) { this.newAccountPhone = e.target.value; }
    handleNewAccountBillingCity(e) { this.newAccountBillingCity = e.target.value; }
    handleNewAccountBillingState(e) { this.newAccountBillingState = e.target.value; }
    handleNewAccountBillingStreet(e) { this.newAccountBillingStreet = e.target.value; }
    handleNewAccountBillingPostalCode(e) { this.newAccountBillingPostalCode = e.target.value; }
    handleNewAccountBillingCountry(e) { this.newAccountBillingCountry = e.target.value; }

    // NEW contact fields
    handleNewContactFirstName(e) { this.newContactFirstName = e.target.value; }
    handleNewContactLastName(e) { this.newContactLastName = e.target.value; }
    handleNewContactPhone(e) { this.newContactPhone = e.target.value; }
    handleNewContactMobilePhone(e) { this.newContactMobilePhone = e.target.value; }
    handleNewContactEmail(e) { this.newContactEmail = e.target.value; }
    handleNewContactDepartment(e) { this.newContactDepartment = e.target.value; }

    async handleCreateCase() {

       // if (this.showOtherInstaller && (!this.otherInstallerVal || this.otherInstallerVal.trim().length === 0)) {
           //// this.toast('Validation', 'Please fill Other Installer Type.', 'warning');
            //return;
       // }

        if (this.showOtherComplaintType && (!this.otherComplaintTypeVal || this.otherComplaintTypeVal.trim().length === 0)) {
            this.toast('Validation', 'Please fill Other Complaint Type.', 'warning');
            return;
        }

        if (this.showOtherProductCategory && (!this.otherProductCategoryVal || this.otherProductCategoryVal.trim().length === 0)) {
            this.toast('Validation', 'Please fill Other Product Category.', 'warning');
            return;
        }

        // Existing account flow
        if (this.hasAccount) {
            let contactId = this.selectedContactId;
            if (!contactId) {
                this.showContactRequiredMsg = true;
                this.toast('Validation', 'Please select a Contact.', 'warning');
                return;
            }

            let assetIds = (this.selectedAssetIds || []);
            if (!assetIds.length) assetIds = (this.assets || []).filter(x => x.isSelected).map(x => x.id);
            if (!assetIds.length) assetIds = this.getSelectedCheckboxValues('assetCheckbox');

            this.selectedContactId = contactId;
            this.selectedAssetIds = assetIds;

            if (!this.subject?.trim() || !this.originVal?.trim() || !this.description?.trim()) {
                this.toast('Validation', 'Please fill Subject, Origin and Description.', 'warning');
                return;
            }

            const accId = this.getId(this.account);

            this.isLoading = true;
            try {
                const caseId = await createCase2({
                    accountId: accId,
                    contactId: contactId,
                    assetId: assetIds[0] || null,
                    assetIds: assetIds,

                    subject: this.subject,
                    description: this.description,
                    complaintType: this.complaintTypeVal,
                    status: 'New',
                    origin: this.originVal,

                    productCategory: this.productCategoryVal,
                    otherProductCategory: this.otherProductCategoryVal,
                    vocText: this.vocText,
                    installerType: this.installerTypeVal,
                    otherInstaller: this.otherInstallerVal,
                    customerPersona: this.customerPersonaVal,
                    otherComplaintType: this.otherComplaintTypeVal,

                    createNewAccountContact: false,
                    newAccountName: null,
                    newAccountPhone: null,
                    newAccountBillingCity: null,
                    newAccountBillingState: null,
                    newAccountBillingStreet: null,
                    newAccountBillingPostalCode: null,
                    newAccountBillingCountry: null,
                    newContactFirstName: null,
                    newContactLastName: null,
                    newContactPhone: null,
                    newContactMobilePhone: null,
                    newContactEmail: null,
                    newContactDepartment: null
                });

                this.toast('Success', 'Case created successfully.', 'success');

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: caseId, objectApiName: 'Case', actionName: 'view' }
                });

            } catch (e) {
                this.toast('Error', this.reduceError(e), 'error');
            } finally {
                this.isLoading = false;
            }
            return;
        }

        // New account/contact flow
        if (this.isNewAccountContactFlow) {
            if (!this.newAccountName?.trim()) {
                this.toast('Validation', 'Please fill Account Name.', 'warning');
                return;
            }
            if (!this.newContactLastName?.trim()) {
                this.toast('Validation', 'Please fill Contact Last Name.', 'warning');
                return;
            }
            if (!this.subject?.trim() || !this.originVal?.trim() || !this.description?.trim()) {
                this.toast('Validation', 'Please fill Subject, Origin and Description.', 'warning');
                return;
            }

            this.isLoading = true;
            try {
                const caseId = await createCase2({
                    accountId: null,
                    contactId: null,
                    assetId: null,
                    assetIds: [],

                    subject: this.subject,
                    description: this.description,
                    complaintType: this.complaintTypeVal,
                    status: 'New',
                    origin: this.originVal,

                    productCategory: this.productCategoryVal,
                    otherProductCategory: this.otherProductCategoryVal,
                    vocText: this.vocText,
                    installerType: this.installerTypeVal,
                    otherInstaller: this.otherInstallerVal,
                    customerPersona: this.customerPersonaVal,
                    otherComplaintType: this.otherComplaintTypeVal,

                    createNewAccountContact: true,
                    newAccountName: this.newAccountName,
                    newAccountPhone: this.newAccountPhone,
                    newAccountBillingCity: this.newAccountBillingCity,
                    newAccountBillingState: this.newAccountBillingState,
                    newAccountBillingStreet: this.newAccountBillingStreet,
                    newAccountBillingPostalCode: this.newAccountBillingPostalCode,
                    newAccountBillingCountry: this.newAccountBillingCountry,
                    newContactFirstName: this.newContactFirstName,
                    newContactLastName: this.newContactLastName,
                    newContactPhone: this.newContactPhone,
                    newContactMobilePhone: this.newContactMobilePhone,
                    newContactEmail: this.newContactEmail,
                    newContactDepartment: this.newContactDepartment
                });

                this.toast('Success', 'Account, Contact and Case created successfully.', 'success');

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: caseId, objectApiName: 'Case', actionName: 'view' }
                });

            } catch (e) {
                this.toast('Error', this.reduceError(e), 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    handleClear() {
        this.searchKey = '';
        this.resetAll();
    }

    resetSearchData() {
        this.account = null;
        this.contacts = [];
        this.assets = [];
        this.matchedBy = '';
        this.accountResults = [];
        this.showAccountPicklist = false;
        this.selectedAccountRows = [];

        this.selectedContactId = null;
        this.selectedAssetIds = [];

        this.showContactRequiredMsg = false;
        this.showAssetRequiredMsg = false;

        this.isNewAccountContactFlow = false;
    }

    resetAll() {
        this.resetSearchData();

        this.subject = '';
        this.description = '';
        this.complaintTypeVal = '';
        this.statusVal = 'New';
        this.originVal = '';
        this.productCategoryVal = '';
        this.otherProductCategoryVal = '';
        this.vocText = '';
        this.installerTypeVal = '';
        this.otherInstallerVal = '';
        this.customerPersonaVal = '';
        this.otherComplaintTypeVal = '';

        this.newAccountName = '';
        this.newAccountPhone = '';
        this.newAccountBillingCity = '';
        this.newAccountBillingState = '';
        this.newAccountBillingStreet = '';
        this.newAccountBillingPostalCode = '';
        this.newAccountBillingCountry = '';

        this.newContactFirstName = '';
        this.newContactLastName = '';
        this.newContactPhone = '';
        this.newContactMobilePhone = '';
        this.newContactEmail = '';
        this.newContactDepartment = '';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(e) {
        if (e?.body?.message) return e.body.message;
        if (Array.isArray(e?.body)) return e.body.map(x => x.message).join(', ');
        return e?.message || 'Unknown error';
    }
}