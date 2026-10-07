import { LightningElement, wire, track } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import LEAD_OBJECT from '@salesforce/schema/Lead';
import { createRecord, getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import SMALL_PHOTO_URL from '@salesforce/schema/User.SmallPhotoUrl';
import INTERNAL_TEAM_FIELD from '@salesforce/schema/User.Internal_Business_Team__c';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';

import { getFieldValue } from 'lightning/uiRecordApi';

import CURRENCY_FIELD from '@salesforce/schema/Lead.CurrencyIsoCode';
import BUSINESS_SEGMENT_FIELD from '@salesforce/schema/Lead.Business_Segment__c';
import BUSINESS_SUB_SEGMENT_FIELD from '@salesforce/schema/Lead.Business_Sub_Segment__c';
import MARKET_SEGMENT_FIELD from '@salesforce/schema/Lead.Market_Segment__c';
import LEADSOURCE_FIELD from '@salesforce/schema/Lead.LeadSource';
import RATING_FIELD from '@salesforce/schema/Lead.Rating';

import TENDER_TYPE_FIELD from '@salesforce/schema/Lead.Tender_Type__c';
import TENDER_SOURCE_FIELD from '@salesforce/schema/Lead.Tender_Source__c';

import checkDuplicateLead from '@salesforce/apex/LeadCreationController.checkDuplicateLead';

export default class CreateNewLeadComponent extends NavigationMixin(LightningElement) {

    @track isStep1 = true;
    @track isStep2 = false;
    @track isLoadingAuth = true;
    @track hasPermission = false;

    @track businessSegmentOptions = [];
    @track businessSubSegmentOptions = [];
    @track marketSegmentOptions = [];
    @track leadSourceOptions = [];
    @track ratingOptions = [];
    @track currencyOptions = [];
    @track tenderTypeOptions = [];
    @track tenderSourceOptions = [];

    @track formFields = {
        Salutation: '', FirstName: '', MiddleName: '', LastName: '', Suffix: '',
        Company: '', Website: '', Email: '', OwnerId: USER_ID, MobilePhone: '',
        Phone: '', CurrencyIsoCode: 'INR', Business_Sub_Segment__c: '',
        Market_Segment__c: '', Market_Segment_Others__c: '', LeadSource: '',
        Lead_Source_Others__c: '', Rating: '', Expected_Closure_Date__c: '',
        Description: '', Street: '', PostalCode: '', Tender_ID__c: '',
        Tender_Source__c: '', Tender_Name__c: '', Tender_Due_Date__c: '',
        Tender_Type__c: '', Estimated_Tender_Value__c: '', Tender_Details__c: '',
        Internal_Business_Team__c: ''
    };

    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD, SMALL_PHOTO_URL, INTERNAL_TEAM_FIELD, PROFILE_NAME_FIELD] })
    wiredCurrentUser(result) {
        this.currentUser = result;
        if (result.data) {
            const team = getFieldValue(result.data, INTERNAL_TEAM_FIELD);
            const profileName = getFieldValue(result.data, PROFILE_NAME_FIELD);

            if (profileName === 'System Administrator') {
                this.internalBusinessTeamValue = 'Solar Sales';
            } else {
                this.internalBusinessTeamValue = team;
            }

            if (team === 'Solar Sales' || profileName === 'System Administrator') {
                this.hasPermission = true;
            } else {
                this.hasPermission = false;
            }
            this.isLoadingAuth = false;
        } else if (result.error) {
            this.isLoadingAuth = false;
            console.error('Error retrieving User Record: ', result.error);
        }
    }

    @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
    objectInfo({ error, data }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: BUSINESS_SEGMENT_FIELD }) wiredBusinessSegment({ data }) { this.businessSegmentOptions = data ? this.addNoneOption(data.values) : []; }
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: BUSINESS_SUB_SEGMENT_FIELD }) wiredBusinessSubSegment({ data }) { this.businessSubSegmentOptions = data ? this.addNoneOption(data.values) : []; }
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: MARKET_SEGMENT_FIELD }) wiredMarketSegment({ data }) { this.marketSegmentOptions = data ? this.addNoneOption(data.values) : []; }
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: LEADSOURCE_FIELD }) wiredLeadSource({ data }) { this.leadSourceOptions = data ? this.addNoneOption(data.values) : []; }
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: RATING_FIELD }) wiredRating({ data }) { this.ratingOptions = data ? this.addNoneOption(data.values) : []; }
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: CURRENCY_FIELD }) wiredCurrency({ data }) { this.currencyOptions = data ? this.addNoneOption(data.values) : []; }
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: TENDER_TYPE_FIELD }) wiredTenderType({ data }) { this.tenderTypeOptions = data ? this.addNoneOption(data.values) : []; }
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: TENDER_SOURCE_FIELD }) wiredTenderSource({ data }) { this.tenderSourceOptions = data ? this.addNoneOption(data.values) : []; }

    leadStatusValue = 'New';
    salutationOptions = [
        { label: '--None--', value: '' }, { label: 'Mr.', value: 'Mr.' }, { label: 'Ms.', value: 'Ms.' },
        { label: 'Mrs.', value: 'Mrs.' }, { label: 'Dr.', value: 'Dr.' }, { label: 'Prof.', value: 'Prof.' }, { label: 'Mx.', value: 'Mx.' }
    ];

    recordTypeId;
    currentUser;
    businessSegmentValue;
    internalBusinessTeamValue = '';

    get ownerName() { return (this.currentUser && this.currentUser.data) ? getFieldValue(this.currentUser.data, NAME_FIELD) : ''; }
    get ownerPhoto() { return (this.currentUser && this.currentUser.data) ? getFieldValue(this.currentUser.data, SMALL_PHOTO_URL) : ''; }
    get businessSegmentRadioOptions() { return [{ label: 'KAM', value: 'KAM' }, { label: 'Mid - Market', value: 'Retail' }, { label: 'Institutional', value: 'Institutional' }]; }
    get showKAMOrRetail() { return this.isStep2 && (this.businessSegmentValue === 'KAM' || this.businessSegmentValue === 'Retail'); }
    get showInstitutional() { return this.isStep2 && this.businessSegmentValue === 'Institutional'; }
    get showInstitutionalBusinessSegmentInUI() { return this.businessSegmentValue === 'Institutional' && this.formFields.Tender_Type__c === 'Module'; }
    get showMarketSegmentOthers() { return this.formFields.Market_Segment__c === 'Others'; }
    get showLeadSourceOthers() { return this.formFields.LeadSource === 'Others'; }
    get isExpectedClosureDisabled() { return this.businessSegmentValue === 'Institutional' && !this.formFields.Tender_Due_Date__c; }
    get businessSegmentDisplayValue() {
        if (this.businessSegmentValue === 'Retail') {
            return 'Mid - Market';
        }
        return this.businessSegmentValue;
    }

    get todayDateString() {
        const today = new Date();
        const dd = String(today.getDate()).padStart(2, '0');
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const yyyy = today.getFullYear();
        return `${yyyy}-${mm}-${dd}`;
    }

    handleBusinessSegmentChange(event) { this.businessSegmentValue = event.detail.value; }

    goToStep2() {
        if (!this.businessSegmentValue) {
            this.showToast('Validation Error', 'Please select a Business Segment.', 'error');
            return;
        }
        this.isStep1 = false;
        this.isStep2 = true;
        this.formFields.Business_Segment__c = this.businessSegmentValue;
        this.formFields.Internal_Business_Team__c = this.internalBusinessTeamValue;
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = (event.detail && event.detail.value !== undefined) ? event.detail.value : event.target.value;
        if (!field) return;
        this.formFields = { ...this.formFields, [field]: value };

        if (field === 'Market_Segment__c' && value !== 'Others') this.formFields.Market_Segment_Others__c = '';
        if (field === 'LeadSource' && value !== 'Others') this.formFields.Lead_Source_Others__c = '';
        if (field === 'Tender_Type__c' && this.businessSegmentValue === 'Institutional') {
            this.formFields.Business_Segment__c = (value === 'Module') ? 'Institutional' : '';
        }
        if (field === 'Tender_Due_Date__c' && !value && this.businessSegmentValue === 'Institutional') {
            this.formFields.Expected_Closure_Date__c = '';
        }
    }

    validateForm() {
        const errors = [];
        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea');
        let isFormValid = true;

        inputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isFormValid = false;
            }
        });

        // Mandatory Logic
        if (!this.formFields.Company) errors.push('Company is required.');
        if (!this.formFields.FirstName) errors.push('First Name is required.');
        if (!this.formFields.LastName) errors.push('Last Name is required.');
        if (!this.formFields.Email) errors.push('Email is required.');
        if (!this.formFields.CurrencyIsoCode) errors.push('Lead Currency is required.');
        if (!this.formFields.Market_Segment__c) errors.push('Market Segment is required.');
        if (this.showMarketSegmentOthers && !this.formFields.Market_Segment_Others__c) errors.push('Market Segment Others is required.');
        if (!this.formFields.Business_Sub_Segment__c) errors.push('Business Sub Segment is required.');
        if (!this.formFields.LeadSource) errors.push('Lead Source is required.');
        if (this.showLeadSourceOthers && !this.formFields.Lead_Source_Others__c) errors.push('Lead Source Others is required.');
        if (!this.formFields.Expected_Closure_Date__c) errors.push('Expected Closure Date is required.');
        if (!this.formFields.Rating) errors.push('Priority is required.');

        // --- START NEW MANDATORY ADDR CHECK ---
        if (!this.formFields.Street) errors.push('Street/Landmark is required.');
        if (!this.formFields.PostalCode) errors.push('Postal Code is required.');
        // --- END NEW MANDATORY ADDR CHECK ---

        // Date Validation Logic
        let today = new Date();
        today.setHours(0, 0, 0, 0);

        if (this.formFields.Expected_Closure_Date__c) {
            let closureParts = this.formFields.Expected_Closure_Date__c.split('-');
            let closureDate = new Date(closureParts[0], closureParts[1] - 1, closureParts[2]);
            closureDate.setHours(0, 0, 0, 0);

            // --- START NEW DATE VALIDATION FOR RETAIL/KAM ---
            if (this.businessSegmentValue === 'Retail' || this.businessSegmentValue === 'KAM') {
                if (closureDate < today) {
                    errors.push('Expected Closure Date must be today or a future date.');
                }
            }
            // --- END NEW DATE VALIDATION ---
        }

        if (this.businessSegmentValue === 'Institutional') {
            if (!this.formFields.Tender_ID__c) errors.push('Tender ID is required.');
            if (!this.formFields.Tender_Name__c) errors.push('Tender Name is required.');
            if (!this.formFields.Tender_Type__c) errors.push('Tender Type is required.');
            if (!this.formFields.Tender_Details__c) errors.push('Tender Details is required.');
            if (!this.formFields.Tender_Source__c) errors.push('Tender Source is required.');
            if (!this.formFields.Tender_Due_Date__c) errors.push('Tender Due Date is required.');
            if (!this.formFields.Estimated_Tender_Value__c) errors.push('Estimated Tender Value is required.');

            if (this.formFields.Tender_Due_Date__c) {
                let tenderParts = this.formFields.Tender_Due_Date__c.split('-');
                let tenderDate = new Date(tenderParts[0], tenderParts[1] - 1, tenderParts[2]);
                tenderDate.setHours(0, 0, 0, 0);
                if (tenderDate < today) errors.push('Tender Due Date cannot be in the past.');

                if (this.formFields.Expected_Closure_Date__c) {
                    let closureParts = this.formFields.Expected_Closure_Date__c.split('-');
                    let closureDate = new Date(closureParts[0], closureParts[1] - 1, closureParts[2]);
                    if (closureDate < tenderDate) errors.push('Expected Closure Date cannot be prior to the Tender Due Date.');
                }
            }
        } else {
            if (!this.formFields.Description) errors.push('Description is required.');
        }

        // Regex Validations
        const phoneRegex = /^[1-9][0-9]{9}$/;
        if (!this.formFields.MobilePhone) errors.push('Mobile is required.');
        else if (!phoneRegex.test(this.formFields.MobilePhone)) errors.push('Mobile: 10 digits, no leading 0.');

        if (this.formFields.Phone && !phoneRegex.test(this.formFields.Phone)) errors.push('Phone: 10 digits, no leading 0.');

        const postalCodeRegex = /^[1-9][0-9]{5}$/;
        if (this.formFields.PostalCode && !postalCodeRegex.test(this.formFields.PostalCode)) {
            errors.push('Postal Code: 6 digits, no leading 0.');
        }

        if (!isFormValid && errors.length === 0) errors.push('Please fix invalid fields.');
        return errors;
    }

    async handleSave() {
        const errors = this.validateForm();
        if (errors.length) {
            this.showToast('Validation Error', errors.join(' '), 'error');
            return;
        }
        try {
            const isDuplicate = await checkDuplicateLead({ email: this.formFields.Email, mobile: this.formFields.MobilePhone, phone: this.formFields.Phone });
            if (isDuplicate) {
                this.showToast('Duplicate Found', 'A Lead with this contact details already exists.', 'error');
                return;
            }
            const recordInput = this.buildRecordInput();
            const savedRecord = await createRecord(recordInput);
            this.showToast('Success', 'Lead created: ' + savedRecord.id, 'success');
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: savedRecord.id, objectApiName: 'Lead', actionName: 'view' } });
        } catch (error) {
            this.showToast('Error', (error.body && error.body.message) || error.message, 'error');
        }
    }

    async handleSaveAndNew() {
        const errors = this.validateForm();
        if (errors.length) {
            this.showToast('Validation Error', errors.join(' '), 'error');
            return;
        }
        try {
            const isDuplicate = await checkDuplicateLead({ email: this.formFields.Email, mobile: this.formFields.MobilePhone, phone: this.formFields.Phone });
            if (isDuplicate) {
                this.showToast('Duplicate Found', 'A Lead with this contact details already exists.', 'error');
                return;
            }
            const recordInput = this.buildRecordInput();
            await createRecord(recordInput);
            this.showToast('Success', 'Lead created', 'success');
            this.resetToStep1();
        } catch (error) {
            this.showToast('Error', (error.body && error.body.message) || error.message, 'error');
        }
    }

    handleCancel() { this.dispatchEvent(new CustomEvent('close')); }

    buildRecordInput() {
        const fields = {};
        const mapIf = (apiName, value) => { if (value !== undefined && value !== null && value !== '') fields[apiName] = value; };

        mapIf('Internal_Business_Team__c', this.formFields.Internal_Business_Team__c);
        mapIf('Salutation', this.formFields.Salutation);
        mapIf('FirstName', this.formFields.FirstName);
        mapIf('MiddleName', this.formFields.MiddleName);
        mapIf('LastName', this.formFields.LastName);
        mapIf('Suffix', this.formFields.Suffix);
        mapIf('Company', this.formFields.Company);
        mapIf('Email', this.formFields.Email);
        mapIf('MobilePhone', this.formFields.MobilePhone);
        mapIf('CurrencyIsoCode', this.formFields.CurrencyIsoCode);
        mapIf('LeadSource', this.formFields.LeadSource);
        mapIf('Lead_Source_Others__c', this.formFields.Lead_Source_Others__c);
        mapIf('Website', this.formFields.Website);
        mapIf('OwnerId', USER_ID);
        mapIf('Phone', this.formFields.Phone);
        mapIf('Status', this.leadStatusValue);
        mapIf('Business_Sub_Segment__c', this.formFields.Business_Sub_Segment__c);
        mapIf('Market_Segment__c', this.formFields.Market_Segment__c);
        mapIf('Market_Segment_Others__c', this.formFields.Market_Segment_Others__c);
        mapIf('Rating', this.formFields.Rating);
        mapIf('Expected_Closure_Date__c', this.formFields.Expected_Closure_Date__c);
        mapIf('Description', this.formFields.Description);
        mapIf('Street', this.formFields.Street);
        mapIf('PostalCode', this.formFields.PostalCode);

        if (this.businessSegmentValue === 'KAM' || this.businessSegmentValue === 'Retail') {
            mapIf('Business_Segment__c', this.businessSegmentValue);
        } else if (this.businessSegmentValue === 'Institutional' && this.formFields.Tender_Type__c === 'Module') {
            mapIf('Business_Segment__c', 'Institutional');
        }

        if (this.businessSegmentValue === 'Institutional') {
            mapIf('Tender_ID__c', this.formFields.Tender_ID__c);
            mapIf('Tender_Source__c', this.formFields.Tender_Source__c);
            mapIf('Tender_Name__c', this.formFields.Tender_Name__c);
            mapIf('Tender_Due_Date__c', this.formFields.Tender_Due_Date__c);
            mapIf('Tender_Type__c', this.formFields.Tender_Type__c);
            mapIf('Estimated_Tender_Value__c', this.formFields.Estimated_Tender_Value__c);
            mapIf('Tender_Details__c', this.formFields.Tender_Details__c);
        }

        return { apiName: LEAD_OBJECT.objectApiName, fields };
    }

    resetToStep1() {
        this.isStep1 = true;
        this.isStep2 = false;
        this.businessSegmentValue = null;
        this.formFields = {
            Salutation: '', FirstName: '', MiddleName: '', LastName: '', Suffix: '',
            Company: '', Website: '', Email: '', OwnerId: USER_ID, MobilePhone: '',
            Phone: '', CurrencyIsoCode: 'INR', Business_Sub_Segment__c: '',
            Market_Segment__c: '', Market_Segment_Others__c: '', LeadSource: '',
            Lead_Source_Others__c: '', Rating: '', Expected_Closure_Date__c: '',
            Description: '', Street: '', PostalCode: '', Tender_ID__c: '',
            Tender_Source__c: '', Tender_Name__c: '', Tender_Due_Date__c: '',
            Tender_Type__c: '', Estimated_Tender_Value__c: '', Tender_Details__c: '',
            Internal_Business_Team__c: this.internalBusinessTeamValue
        };
    }

    showToast(title, message, variant = 'info') { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
    addNoneOption(values) {
        const opts = values ? values.map(v => ({ label: v.label, value: v.value })) : [];
        return [{ label: '--None--', value: '' }, ...opts];
    }
}