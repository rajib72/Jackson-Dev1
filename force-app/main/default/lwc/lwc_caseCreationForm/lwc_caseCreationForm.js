import { LightningElement, track } from 'lwc';
import search from '@salesforce/apex/Ctrl_CaseCreationForm.search';
import loadByAccountId from '@salesforce/apex/Ctrl_CaseCreationForm.loadByAccountId';
import getInitData from '@salesforce/apex/Ctrl_CaseCreationForm.getInitData';
import createCase from '@salesforce/apex/Ctrl_CaseCreationForm.createCase';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class Lwc_caseCreationForm extends NavigationMixin(LightningElement) {

    // ---- search state ----
    @track searchKey = '';
    @track isLoading = false;

    @track account = null;
    @track contacts = [];
    @track assets = [];
    @track matchedBy = '';

    @track accountResults = [];
    @track showAccountPicklist = false;
    @track selectedAccountRows = [];

    // ---- selection state ----
    @track selectedContactId = null;
    @track selectedAssetId = null;

    // ---- validation ui ----
    @track showContactRequiredMsg = false;

    // ---- init picklists ----
    @track initLoaded = false;
    @track typeOptions = [];
    @track statusOptions = [];
    @track originOptions = [];
    @track reasonOptions = [];

    @track productCategoryOptions = [];
    @track installerTypeOptions = [];
    @track customerPersonaOptions = [];

    // ---- case fields ----
    @track subject = '';
    @track description = '';      // ✅ NEW mandatory
    @track typeVal = '';
    @track statusVal = '';
    @track originVal = '';        // ✅ NEW mandatory
    @track reasonVal = '';

    @track productCategoryVal = '';
    @track vocText = '';          // ✅ VOC is Long Text Area now
    @track installerTypeVal = '';
    @track otherInstallerVal = '';
    @track customerPersonaVal = '';

    // ---- columns ----
    accountColumns = [
        { label: 'Account', fieldName: 'name' },
        { label: 'Phone', fieldName: 'phone' },
        { label: 'City', fieldName: 'billingCity' },
        { label: 'State', fieldName: 'billingState' }
    ];

    contactColumns = [
        {
            label: 'Select', fieldName: 'selectLabel', type: 'button',
            typeAttributes: { label: { fieldName: 'selectLabel' }, name: 'select', variant: 'brand-outline' }
        },
        { label: 'Contact Name', fieldName: 'name' },
        { label: 'Mobile', fieldName: 'mobilePhone' },
        { label: 'Phone', fieldName: 'phone' },
        { label: 'Email', fieldName: 'email' }
    ];

    assetColumns = [
        {
            label: 'Select', fieldName: 'selectLabel', type: 'button',
            typeAttributes: { label: { fieldName: 'selectLabel' }, name: 'select', variant: 'brand-outline' }
        },
        { label: 'Asset', fieldName: 'name' },
        { label: 'Serial No', fieldName: 'serialNumber' },
        { label: 'Invoice No', fieldName: 'invoiceNumber' },
        { label: 'Product', fieldName: 'productName' },
        { label: 'Contact', fieldName: 'contactName' }
    ];

    // ---- computed ----
    get hasAccount() { return this.account && this.account.id; }
    get showNoResult() {
        return !this.isLoading && !this.hasAccount && (this.searchKey || '').trim().length >= 2;
    }
    get accountSectionLabel() {
        return this.matchedBy ? `Account Details (Matched By: ${this.matchedBy})` : 'Account Details';
    }
    get contactSectionLabel() { return `Related Contacts (${this.contacts?.length || 0})`; }
    get assetSectionLabel() { return `Related Assets (${this.assets?.length || 0})`; }

    get showOtherInstaller() {
        return this.installerTypeVal === 'Other';
    }

    // ✅ Mandatory: Account + Contact + Subject + Origin + Description
    get disableCreateCase() {
        return (
            !this.hasAccount ||
            !this.selectedContactId ||
            !this.subject || this.subject.trim().length === 0 ||
            !this.originVal || this.originVal.trim().length === 0 ||
            !this.description || this.description.trim().length === 0
        );
    }

    connectedCallback() {
        this.loadInit();
    }

    async loadInit() {
        try {
            const res = await getInitData();

            // ✅ Add "--Select--" so user must pick values (no manual typing)
            this.typeOptions = this.toComboWithSelect(res.caseTypeOptions);
            this.statusOptions = this.toComboWithSelect(res.caseStatusOptions);
            this.originOptions = this.toComboWithSelect(res.caseOriginOptions); // mandatory
            this.reasonOptions = this.toComboWithSelect(res.caseReasonOptions);

            this.productCategoryOptions = this.toComboWithSelect(res.productCategoryOptions);
            this.installerTypeOptions = this.toComboWithSelect(res.installerTypeOptions);
            this.customerPersonaOptions = this.toComboWithSelect(res.customerPersonaOptions);

            this.initLoaded = true;
        } catch (e) {
            this.toast('Error', this.reduceError(e), 'error');
        }
    }

    toComboWithSelect(list) {
        const opts = (list || []).map(x => ({ label: x.label, value: x.value }));
        return [{ label: '--Select--', value: '' }, ...opts];
    }

    // ---- search handlers ----
    handleChange(event) { this.searchKey = event.target.value; }
    handleKeyUp(event) { if (event.key === 'Enter') this.handleSearch(); }

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
            if (!res || !res.account) return;

            this.account = res.account;
            this.matchedBy = res.matchedBy;

            this.accountResults = (res.accountResults || []);
            this.showAccountPicklist = (this.matchedBy === 'Account' && this.accountResults.length > 1);

            this.contacts = (res.contacts || []).map(c => ({
                ...c,
                selectLabel: (c.id === this.selectedContactId ? 'Selected' : 'Select')
            }));

            this.assets = (res.assets || []).map(a => ({
                ...a,
                selectLabel: (a.id === this.selectedAssetId ? 'Selected' : 'Select')
            }));

            // default contact selection (still mandatory)
            if (!this.selectedContactId && this.contacts.length) {
                this.selectedContactId = this.contacts[0].id;
                this.refreshSelectionLabels();
            }

        } catch (e) {
            this.toast('Error', this.reduceError(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleAccountRowSelect(event) {
        const rows = event.detail.selectedRows;
        if (!rows || rows.length === 0) return;

        const selected = rows[0];
        this.searchKey = selected.name;
        this.showAccountPicklist = false;
        this.selectedAccountRows = [selected.id];

        this.isLoading = true;
        try {
            const res = await loadByAccountId({ accountId: selected.id });
            if (!res || !res.account) return;

            this.account = res.account;
            this.matchedBy = res.matchedBy;

            this.contacts = (res.contacts || []).map(c => ({ ...c, selectLabel: 'Select' }));
            this.assets = (res.assets || []).map(a => ({ ...a, selectLabel: 'Select' }));

            this.selectedContactId = this.contacts.length ? this.contacts[0].id : null;
            this.selectedAssetId = null;
            this.refreshSelectionLabels();

            this.selectedAccountRows = [];
        } catch (e) {
            this.toast('Error', this.reduceError(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ---- contact/asset select ----
    handleContactRowAction(event) {
        const row = event.detail.row;
        this.selectedContactId = row.id;
        this.showContactRequiredMsg = false;
        this.refreshSelectionLabels();
    }

    handleAssetRowAction(event) {
        const row = event.detail.row;
        this.selectedAssetId = row.id;
        this.refreshSelectionLabels();
    }

    refreshSelectionLabels() {
        this.contacts = (this.contacts || []).map(c => ({
            ...c,
            selectLabel: (c.id === this.selectedContactId ? 'Selected' : 'Select')
        }));
        this.assets = (this.assets || []).map(a => ({
            ...a,
            selectLabel: (a.id === this.selectedAssetId ? 'Selected' : 'Select')
        }));
    }

    // ---- case field handlers ----
    handleSubject(e){ this.subject = e.target.value; }
    handleDescription(e){ this.description = e.target.value; }   // ✅ NEW

    handleType(e){ this.typeVal = e.detail.value; }
    handleStatus(e){ this.statusVal = e.detail.value; }
    handleOrigin(e){ this.originVal = e.detail.value; }          // ✅ mandatory
    handleReason(e){ this.reasonVal = e.detail.value; }

    handleProductCategory(e){ this.productCategoryVal = e.detail.value; }

    handleVocText(e){ this.vocText = e.target.value; }           // ✅ VOC textarea

    handleInstallerType(e){
        this.installerTypeVal = e.detail.value;
        if (this.installerTypeVal !== 'Other') this.otherInstallerVal = '';
    }
    handleOtherInstaller(e){ this.otherInstallerVal = e.target.value; }
    handleCustomerPersona(e){ this.customerPersonaVal = e.detail.value; }

    // ---- create case ----
    async handleCreateCase() {

        if (!this.selectedContactId) {
            this.showContactRequiredMsg = true;
            this.toast('Validation', 'Contact is mandatory. Please select a Contact.', 'warning');
            return;
        }

        if (this.disableCreateCase) {
            this.toast('Validation', 'Please fill Subject, Origin, Description and select Contact.', 'warning');
            return;
        }

        if (this.showOtherInstaller && (!this.otherInstallerVal || this.otherInstallerVal.trim().length === 0)) {
            this.toast('Validation', 'Please fill Other Installer Type.', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            const payload = {
                accountId: this.account.id,
                contactId: this.selectedContactId,
                assetId: this.selectedAssetId,

                subject: this.subject,
                description: this.description,     // ✅ NEW
                type: this.typeVal,
                status: this.statusVal,
                origin: this.originVal,            // ✅ mandatory
                reason: this.reasonVal,

                productCategory: this.productCategoryVal,
                vocText: this.vocText,             // ✅ LONG TEXT
                installerType: this.installerTypeVal,
                otherInstaller: this.otherInstallerVal,
                customerPersona: this.customerPersonaVal
            };

            const caseId = await createCase({ req: payload });

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
        this.selectedAssetId = null;
        this.showContactRequiredMsg = false;
    }

    resetAll() {
        this.resetSearchData();

        this.subject = '';
        this.description = '';

        this.typeVal = '';
        this.statusVal = '';
        this.originVal = '';
        this.reasonVal = '';

        this.productCategoryVal = '';
        this.vocText = '';
        this.installerTypeVal = '';
        this.otherInstallerVal = '';
        this.customerPersonaVal = '';
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