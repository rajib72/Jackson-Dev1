import { LightningElement, wire, track } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import LEAD_OBJECT from '@salesforce/schema/Lead';
import { createRecord, getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import SMALL_PHOTO_URL from '@salesforce/schema/User.SmallPhotoUrl';
// Import the custom team field
import TEAM_FIELD from '@salesforce/schema/User.Internal_Business_Team__c';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';

/* Lead Fields */
import BUSINESS_SUB_SEGMENT_FIELD from '@salesforce/schema/Lead.Business_Sub_Segment__c';
import MARKET_SEGMENT_FIELD from '@salesforce/schema/Lead.Market_Segment__c';
import LEADSOURCE_FIELD from '@salesforce/schema/Lead.LeadSource';
import RATING_FIELD from '@salesforce/schema/Lead.Rating';
import INDUSTRY_FIELD from '@salesforce/schema/Lead.Industry';
import UOM_FIELD from '@salesforce/schema/Lead.UOM__c';
import CURRENCY_FIELD from '@salesforce/schema/Lead.CurrencyIsoCode';

import checkDuplicateLead from '@salesforce/apex/LeadCreationController.checkDuplicateLead';

export default class CreateNewLeadSRTComponent extends NavigationMixin(LightningElement) {

    @track isLoading = false;
    @track isStep1 = true;
    @track isStep2 = false;

    // Permission tracking flags
    @track isCheckingPermission = true;
    @track hasPermission = false;

    /* ================= OPTIONS ================= */
    @track businessSubSegmentOptions = [];
    @track marketSegmentOptions = [];
    @track leadSourceOptions = [];
    @track ratingOptions = [];
    @track currencyOptions = [];
    @track industryOptions = [];
    @track uomOptions = [];

    @track internalBusinessTeamValue = '';

    /* ================= FORM ================= */
    @track formFields = {
        Salutation: '',
        FirstName: '',
        MiddleName: '',
        LastName: '',
        Suffix: '',
        Company: '',
        Website: '',
        Email: '',
        OwnerId: USER_ID,
        MobilePhone: '',
        Phone: '',
        Industry: '',
        CurrencyIsoCode: 'INR',
        Business_Sub_Segment__c: '',
        Market_Segment__c: '',
        Market_Segment_Others__c: '',
        LeadSource: '',
        Lead_Source_Others__c: '',
        Rating: '',
        Expected_Closure_Date__c: '',
        Description: '',

        Expected_Capacity__c: '',
        UOM__c: '',
        Street: '',
        PostalCode: '',

        Tender_ID__c: '',
        Tender_Source__c: '',
        Tender_Name__c: '',
        Tender_Due_Date__c: '',
        Tender_Type__c: '',
        Estimated_Tender_Value__c: '',
        Tender_Details__c: '',
        Event_Name__c: '',
        Event_Description__c: '',
        Event_Date__c: '',
    };

    leadStatusValue = 'New';
    recordTypeId;
    businessSegmentValue;
    currentUser;

    showEventDetails = false;
    showMarketSegmentOthers = false;
    showLeadSourceOthers = false;

    // Combined getter for spinner logic
    get showSpinner() {
        return this.isLoading || this.isCheckingPermission;
    }

    get todayDate() {
        return new Date().toISOString().split('T')[0];
    }

    /* ================= SALUTATION ================= */
    salutationOptions = [
        { label: '--None--', value: '' },
        { label: 'Mr.', value: 'Mr.' },
        { label: 'Ms.', value: 'Ms.' },
        { label: 'Mrs.', value: 'Mrs.' },
        { label: 'Dr.', value: 'Dr.' },
        { label: 'Prof.', value: 'Prof.' },
        { label: 'Mx.', value: 'Mx.' }
    ];

    // @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD, SMALL_PHOTO_URL, TEAM_FIELD, PROFILE_NAME_FIELD] })
    // wiredUser(result) {
    //     this.currentUser = result;
    //     if (result.data) {
    //         // Check permission logic here
    //         const team = getFieldValue(result.data, TEAM_FIELD);
    //         const profileName = getFieldValue(result.data, PROFILE_NAME_FIELD);

    //         // Allow access if team is SRT Sales OR Profile is System Administrator
    //         this.hasPermission = (team === 'SRT Sales' || profileName === 'System Administrator');
    //         this.isCheckingPermission = false;
    //     } else if (result.error) {
    //         console.error('Error fetching user data', result.error);
    //         this.hasPermission = false;
    //         this.isCheckingPermission = false;
    //     }
    // }

    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD, SMALL_PHOTO_URL, TEAM_FIELD, PROFILE_NAME_FIELD] })
    wiredUser(result) {
        this.currentUser = result;
        if (result.data) {
            // Fetch fields
            const team = getFieldValue(result.data, TEAM_FIELD);
            const profileName = getFieldValue(result.data, PROFILE_NAME_FIELD);

            // Allow access if team is SRT Sales OR Profile is System Administrator
            this.hasPermission = (team === 'SRT Sales' || profileName === 'System Administrator');

            // Set Internal Business Team dynamically
            if (profileName === 'System Administrator') {
                this.internalBusinessTeamValue = 'SRT Sales';
            } else {
                this.internalBusinessTeamValue = team;
            }

            this.isCheckingPermission = false;
        } else if (result.error) {
            console.error('Error fetching user data', result.error);
            this.hasPermission = false;
            this.isCheckingPermission = false;
        }
    }

    get ownerName() {
        return this.currentUser?.data ? getFieldValue(this.currentUser.data, NAME_FIELD) : '';
    }

    get ownerPhoto() {
        return this.currentUser?.data ? getFieldValue(this.currentUser.data, SMALL_PHOTO_URL) : '';
    }

    /* ================= OBJECT INFO ================= */
    @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
    objectInfo({ data }) {
        if (data) this.recordTypeId = data.defaultRecordTypeId;
    }

    /* ================= PICKLISTS ================= */
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: BUSINESS_SUB_SEGMENT_FIELD })
    wiredSubSegment({ data }) {
        this.businessSubSegmentOptions = data ? this.addNoneOption(data.values) : [];
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: MARKET_SEGMENT_FIELD })
    wiredMarket({ data }) {
        this.marketSegmentOptions = data ? this.addNoneOption(data.values) : [];
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: LEADSOURCE_FIELD })
    wiredLeadSource({ data }) {
        this.leadSourceOptions = data ? this.addNoneOption(data.values) : [];
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: RATING_FIELD })
    wiredRating({ data }) {
        this.ratingOptions = data ? this.addNoneOption(data.values) : [];
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: CURRENCY_FIELD })
    wiredCurrency({ data }) {
        this.currencyOptions = data ? this.addNoneOption(data.values) : [];
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: INDUSTRY_FIELD })
    wiredIndustry({ data }) {
        this.industryOptions = data ? this.addNoneOption(data.values) : [];
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: UOM_FIELD })
    wiredUOM({ data }) {
        this.uomOptions = data ? this.addNoneOption(data.values) : [];
    }

    /* ================= BUSINESS SEGMENT ================= */
    get businessSegmentRadioOptions() {
        return [
            { label: 'KAM (SRT)', value: 'KAM (SRT)' },
            { label: 'Commercial & Industrial (SRT)', value: 'Commercial & Industrial (SRT)' },
            { label: 'Residential (SRT)', value: 'Residential (SRT)' }
        ];
    }

    handleBusinessSegmentChange(event) {
        this.businessSegmentValue = event.detail.value;
    }

    goToStep2() {
        if (!this.businessSegmentValue) {
            this.showToast('Validation Error', 'Please select Business Segment.', 'error');
            return;
        }

        this.isStep1 = false;
        this.isStep2 = true;

        this.formFields = {
            ...this.formFields,
            Business_Segment__c: this.businessSegmentValue
        };
    }

    resetToStep1() {
        this.isStep1 = true;
        this.isStep2 = false;
        this.businessSegmentValue = null;
    }

    handleFieldChange(event) {
        let field = event.target?.dataset?.field || event.target?.name || event.target?.fieldName || event.detail?.fieldApiName;
        const value = event.detail?.value ?? event.target?.value;

        if (!field) {
            return;
        }

        let updatedFields = { ...this.formFields, [field]: value };

        // Handle Lead Source logic
        if (field === 'LeadSource') {
            this.showEventDetails = (value === 'Event & Miscellaneous');

            // Add conditional toggle for Lead Source Others
            if (value === 'Others') {
                this.showLeadSourceOthers = true;
            } else {
                this.showLeadSourceOthers = false;
                updatedFields.Lead_Source_Others__c = '';
            }
        }

        // Handle Market Segment logic
        if (field === 'Market_Segment__c') {
            if (value === 'Others') {
                this.showMarketSegmentOthers = true;
            } else {
                this.showMarketSegmentOthers = false;
                updatedFields.Market_Segment_Others__c = '';
            }
        }

        this.formFields = updatedFields;
    }

    /* ================= SAVE ================= */
    async handleSave() {
        const errors = this.validateForm();
        if (errors.length) {
            this.showToast('Validation Error', errors.join(' '), 'error');
            return;
        }

        this.isLoading = true;

        try {
            const isDuplicate = await checkDuplicateLead({
                email: this.formFields.Email,
                mobile: this.formFields.MobilePhone,
                phone: this.formFields.Phone || ''
            });

            if (isDuplicate) {
                this.showToast('Duplicate Found', 'A Lead with this Email and Mobile/Phone already exists.', 'error');
                return;
            }

            const recordInput = this.buildRecordInput();
            const res = await createRecord(recordInput);

            this.showToast('Success', 'Lead created successfully', 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: res.id,
                    objectApiName: 'Lead',
                    actionName: 'view'
                }
            });

        } catch (error) {
            console.error(JSON.stringify(error, null, 2));
            this.showToast(
                'Error',
                error?.body?.output?.errors?.[0]?.message || error.body?.message || error.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleSaveAndNew() {
        const errors = this.validateForm();
        if (errors.length) {
            this.showToast('Validation Error', errors.join(' '), 'error');
            return;
        }

        this.isLoading = true;

        try {
            const isDuplicate = await checkDuplicateLead({
                email: this.formFields.Email,
                mobile: this.formFields.MobilePhone,
                phone: this.formFields.Phone || ''
            });

            if (isDuplicate) {
                this.showToast('Duplicate Found', 'A Lead with this Email and Mobile/Phone already exists.', 'error');
                return;
            }

            const recordInput = this.buildRecordInput();
            await createRecord(recordInput);

            this.resetToStep1();
            this.resetForm();
            this.showToast('Success', 'Lead created', 'success');

        } catch (error) {
            console.error(JSON.stringify(error, null, 2));
            this.showToast(
                'Error',
                error?.body?.output?.errors?.[0]?.message || error.body?.message || error.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
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

        if (!this.formFields.FirstName) errors.push('First Name is required.');
        if (!this.formFields.Company) errors.push('Company is required.');
        if (!this.formFields.LastName) errors.push('Last Name is required.');
        if (!this.formFields.Email) errors.push('Email is required.');
        if (!this.formFields.MobilePhone) errors.push('Mobile is required.');
        if (!this.formFields.CurrencyIsoCode) errors.push('Lead Currency is required.');
        if (!this.formFields.LeadSource) errors.push('Lead Source is required.');
        if (!this.formFields.Street) errors.push('Street/Landmark is required.');
        if (!this.formFields.PostalCode) errors.push('Postal Code is required.');

        if (this.formFields.Expected_Closure_Date__c) {
            const selectedDate = new Date(this.formFields.Expected_Closure_Date__c);
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            if (selectedDate < today) {
                errors.push('Expected Closure Date cannot be in the past.');
            }
        }

        if (this.showLeadSourceOthers && !this.formFields.Lead_Source_Others__c) {
            errors.push('Lead Source Others is required.');
        }

        if (!this.formFields.Business_Sub_Segment__c) errors.push('Business Sub Segment is required.');
        if (!this.formFields.Market_Segment__c) errors.push('Market Segment is required.');

        if (this.showMarketSegmentOthers && !this.formFields.Market_Segment_Others__c) {
            errors.push('Market Segment Others is required.');
        }

        if (!this.formFields.Rating) errors.push('Priority is required.');
        if (!this.formFields.Description) errors.push('Description is required.');

        const phoneRegex = /^[1-9][0-9]{9}$/;

        if (!this.formFields.MobilePhone) {
            errors.push('Mobile is required.');
        } else if (!phoneRegex.test(this.formFields.MobilePhone)) {
            errors.push('Mobile must be exactly 10 digits and cannot start with 0.');
        }

        if (this.formFields.Phone && !phoneRegex.test(this.formFields.Phone)) {
            errors.push('Phone must be exactly 10 digits and cannot start with 0.');
        }

        const postalCodeRegex = /^[1-9][0-9]{5}$/;

        if (this.formFields.PostalCode && !postalCodeRegex.test(this.formFields.PostalCode)) {
            errors.push('Postal Code must be exactly 6 digits and cannot start with 0.');
        }

        if (!isFormValid && errors.length === 0) {
            errors.push('Please fix the invalid fields on the form.');
        }

        return errors;
    }

    buildRecordInput() {
        const fields = {};
        const mapIf = (api, val) => {
            if (val !== undefined && val !== null && val !== '') fields[api] = val;
        };

        fields['Internal_Business_Team__c'] = this.internalBusinessTeamValue;

        mapIf('Salutation', this.formFields.Salutation);
        mapIf('FirstName', this.formFields.FirstName);
        mapIf('MiddleName', this.formFields.MiddleName);
        mapIf('LastName', this.formFields.LastName);
        mapIf('Company', this.formFields.Company);
        mapIf('Website', this.formFields.Website);
        mapIf('Email', this.formFields.Email);
        mapIf('MobilePhone', this.formFields.MobilePhone);
        mapIf('Phone', this.formFields.Phone);

        mapIf('Industry', this.formFields.Industry);
        mapIf('CurrencyIsoCode', this.formFields.CurrencyIsoCode);
        mapIf('LeadSource', this.formFields.LeadSource);
        mapIf('Lead_Source_Others__c', this.formFields.Lead_Source_Others__c);
        mapIf('Rating', this.formFields.Rating);
        mapIf('Description', this.formFields.Description);
        mapIf('Expected_Capacity__c', this.formFields.Expected_Capacity__c);
        mapIf('UOM__c', this.formFields.UOM__c);

        mapIf('Expected_Closure_Date__c', this.formFields.Expected_Closure_Date__c);
        mapIf('Business_Segment__c', this.businessSegmentValue);
        mapIf('Business_Sub_Segment__c', this.formFields.Business_Sub_Segment__c);
        mapIf('Market_Segment__c', this.formFields.Market_Segment__c);
        mapIf('Market_Segment_Others__c', this.formFields.Market_Segment_Others__c);

        mapIf('Event_Name__c', this.formFields.Event_Name__c);
        mapIf('Event_Description__c', this.formFields.Event_Description__c);
        mapIf('Event_Date__c', this.formFields.Event_Date__c);

        mapIf('Street', this.formFields.Street);
        mapIf('PostalCode', this.formFields.PostalCode);

        mapIf('Status', this.leadStatusValue);
        mapIf('OwnerId', USER_ID);

        return { apiName: LEAD_OBJECT.objectApiName, fields };
    }

    resetForm() {
        this.formFields = {
            Salutation: '',
            FirstName: '',
            MiddleName: '',
            LastName: '',
            Suffix: '',
            Company: '',
            Website: '',
            Email: '',
            OwnerId: USER_ID,
            MobilePhone: '',
            Phone: '',
            Industry: '',
            CurrencyIsoCode: '',
            Business_Sub_Segment__c: '',
            Market_Segment__c: '',
            Market_Segment_Others__c: '',
            LeadSource: '',
            Lead_Source_Others__c: '',
            Rating: '',
            Expected_Closure_Date__c: '',
            Description: '',

            Expected_Capacity__c: '',
            UOM__c: '',
            Street: '',
            PostalCode: '',

            Estimated_Tender_Value__c: '',

            Event_Name__c: '',
            Event_Description__c: '',
            Event_Date__c: '',

        };
        this.showEventDetails = false;
        this.showMarketSegmentOthers = false;
        this.showLeadSourceOthers = false;
    }

    addNoneOption(values) {
        return [{ label: '--None--', value: '' }, ...values.map(v => ({ label: v.label, value: v.value }))];
    }

    showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}