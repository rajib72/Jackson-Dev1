import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LEAD_ACCOUNT_NAME from '@salesforce/schema/Lead.Company';
import LEAD_CONTACT_NAME from '@salesforce/schema/Lead.LastName';
import LEAD_CONTACT_FIRSTNAME from '@salesforce/schema/Lead.FirstName';

import checkIfAccountExists from '@salesforce/apex/LeadConversionSRTSalesController.checkIfAccountExists';
import checkIfContactExists from '@salesforce/apex/LeadConversionSRTSalesController.checkIfContactExists';
import convertLead from '@salesforce/apex/LeadConversionSRTSalesController.convertLead';
import fetchMatchingAccounts from '@salesforce/apex/LeadConversionSRTSalesController.fetchMatchingAccounts';
import fetchMatchingContacts from '@salesforce/apex/LeadConversionSRTSalesController.fetchMatchingContacts';
import fetchAccountDetails from '@salesforce/apex/LeadConversionSRTSalesController.fetchAccountDetails';

import EXPECTED_CAPACITY from '@salesforce/schema/Lead.Expected_Capacity__c';
import UOM from '@salesforce/schema/Lead.UOM__c';
import BUSINESS_SEGMENT from '@salesforce/schema/Lead.Business_Segment__c';

const SEARCH_PAGE_SIZE = 20;
const SEARCH_DEBOUNCE_MS = 250;

export default class ConvertLead extends NavigationMixin(LightningElement) {

    @api recordId;

    @track isModalOpen = true;
    @track isLoading = false;

    @track accountExists = false;
    @track contactExists = false;

    @track accountName = '';
    @track originalAccountName = '';

    @track contactName = '';
    @track contactFirstName = '';
    @track fullcontactName = '';
    @track originalContactName = '';

    @track opportunityName = '';

    @track matchingAccounts = [];
    @track isLoadingAccounts = false;
    @track hasMoreAccounts = true;
    @track selectedAccountId = '';
    @track selectedAccountName = '';

    @track matchingContacts = [];
    @track isLoadingContacts = false;
    @track hasMoreContacts = true;
    @track selectedContactId = '';
    @track selectedContactName = '';

    @track panNumber = '';
    @track billingGstNumber = '';
    @track shippingGstNumber = '';

    @track expectedCapacity;
    @track uom;
    @track businessSegment;

    accountSearchSequence = 0;
    contactSearchSequence = 0;
    accountSearchTimeout;
    contactSearchTimeout;


    /* ---------------- GETTERS ---------------- */

    get showNoMatchingAccounts() {
        return this.accountName && this.accountName.length >= 2 && !this.matchingAccounts.length && !this.isLoadingAccounts;
    }

    get showNoMatchingContacts() {
        return this.selectedAccountId && this.fullcontactName && this.fullcontactName.length >= 2 && !this.matchingContacts.length && !this.isLoadingContacts;
    }


    /* ---------------- LEAD DATA ---------------- */

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [
            LEAD_ACCOUNT_NAME,
            LEAD_CONTACT_NAME,
            LEAD_CONTACT_FIRSTNAME,
            EXPECTED_CAPACITY,
            UOM,
            BUSINESS_SEGMENT
        ]
    })
    wiredLead({ data, error }) {

        if (data) {

            this.accountName = getFieldValue(data, LEAD_ACCOUNT_NAME) || '';
            this.originalAccountName = this.accountName;

            this.contactName = getFieldValue(data, LEAD_CONTACT_NAME) || '';
            this.contactFirstName = getFieldValue(data, LEAD_CONTACT_FIRSTNAME) || '';

            this.fullcontactName = `${this.contactFirstName || ''} ${this.contactName || ''}`.trim();
            this.originalContactName = this.fullcontactName;

            this.expectedCapacity = getFieldValue(data, EXPECTED_CAPACITY);
            this.uom = getFieldValue(data, UOM);
            this.businessSegment = getFieldValue(data, BUSINESS_SEGMENT);

            this.generateOpportunityName();
            this.checkExistingRecords();

        } else if (error) {

            console.error('Error fetching lead data:', error);

        }
    }


    generateOpportunityName() {

        const now = new Date();
        const month = now.toLocaleString('default', { month: 'short' });
        const year = now.getFullYear();

        const account = this.selectedAccountName || this.accountName || '';
        const segment = this.businessSegment || '';
        const capacity = this.expectedCapacity || '';
        const uom = this.uom || '';

        this.opportunityName = `SRT/${month}/${year}/${segment}/${account}/${capacity}/${uom}`;
    }


    async checkExistingRecords() {

        try {

            if (this.accountName) {

                this.accountExists = await checkIfAccountExists({
                    accountName: this.accountName
                });

                await this.fetchMatchingAccounts();
            }

            if (this.contactName) {

                this.contactExists = await checkIfContactExists({
                    contactName: this.contactName
                });

            }

        } catch (error) {

            console.error('Error checking existing records:', error);

        }
    }


    /* ---------------- ACCOUNT ---------------- */

    handleAccountChange(event) {

        this.accountName = event.target.value;

        this.selectedAccountId = '';
        this.selectedAccountName = '';
        this.accountExists = false;

        this.panNumber = '';
        this.billingGstNumber = '';
        this.shippingGstNumber = '';

        this.matchingContacts = [];
        this.selectedContactId = '';
        this.selectedContactName = '';
        this.contactExists = false;

        clearTimeout(this.accountSearchTimeout);
        this.accountSearchTimeout = setTimeout(() => this.fetchMatchingAccounts(), SEARCH_DEBOUNCE_MS);
        this.generateOpportunityName();
    }


    async fetchMatchingAccounts(loadMore = false) {
        const searchValue = (this.accountName || '').trim();

        if (!searchValue || searchValue.length < 2) {
            this.accountSearchSequence++;
            this.matchingAccounts = [];
            this.hasMoreAccounts = false;
            this.isLoadingAccounts = false;
            return;
        }

        if (loadMore && (this.isLoadingAccounts || !this.hasMoreAccounts)) return;

        const cursor = loadMore ? this.matchingAccounts[this.matchingAccounts.length - 1] : null;
        const requestId = loadMore ? this.accountSearchSequence : ++this.accountSearchSequence;

        if (!loadMore) {
            this.matchingAccounts = [];
            this.hasMoreAccounts = true;
        }

        this.isLoadingAccounts = true;

        try {
            const result = await fetchMatchingAccounts({
                accountName: searchValue,
                lastName: cursor?.name || null,
                lastId: cursor?.value || null,
                pageSize: SEARCH_PAGE_SIZE
            });

            if (requestId !== this.accountSearchSequence || searchValue !== (this.accountName || '').trim()) return;

            const newMatches = (result || []).map(acc => ({
                label: acc.Name,
                name: acc.Name,
                value: acc.Id,
                panNumber: acc.PAN__c,
                billingGstNumber: acc.Billing_GST_No__c,
                shippingGstNumber: acc.Shipping_GST_No__c
            }));

            this.matchingAccounts = loadMore ? [...this.matchingAccounts, ...newMatches] : newMatches;
            this.hasMoreAccounts = newMatches.length === SEARCH_PAGE_SIZE;
            this.accountExists = this.matchingAccounts.length > 0;
        } catch (error) {
            console.error('Error fetching matching accounts:', error);
            if (!loadMore) this.matchingAccounts = [];
            this.hasMoreAccounts = false;
        } finally {
            if (requestId === this.accountSearchSequence) this.isLoadingAccounts = false;
        }
    }


    handleAccountResultsScroll(event) {
        const resultList = event.currentTarget;
        if (resultList.scrollHeight - resultList.scrollTop - resultList.clientHeight <= 24) {
            this.fetchMatchingAccounts(true);
        }
    }


    handleAccountSelection(event) {

        this.selectedAccountId = event.target.value;

        const acc = this.matchingAccounts.find(
            a => a.value === this.selectedAccountId
        );

        if (acc) {

            this.selectedAccountName = acc.label;
            this.accountName = acc.label;

            this.panNumber = acc.panNumber || '';
            this.billingGstNumber = acc.billingGstNumber || '';
            this.shippingGstNumber = acc.shippingGstNumber || '';

            this.accountExists = true;

            this.generateOpportunityName();
            this.fetchAccountDetails();
        }

        this.fetchMatchingContacts();
    }


    fetchAccountDetails() {

        if (!this.selectedAccountId) return;

        fetchAccountDetails({
            accountId: this.selectedAccountId
        })
            .then(res => {

                if (res) {

                    this.panNumber = res.PAN__c || '';
                    this.billingGstNumber = res.Billing_GST_No__c || '';
                    this.shippingGstNumber = res.Shipping_GST_No__c || '';

                }

            })
            .catch(error => {

                console.error('Error fetching account details:', error);

            });
    }


    clearSelection() {

        this.selectedAccountId = '';
        this.selectedAccountName = '';

        this.accountName = this.originalAccountName || '';

        this.panNumber = '';
        this.billingGstNumber = '';
        this.shippingGstNumber = '';

        this.accountExists = false;

        this.matchingContacts = [];
        this.selectedContactId = '';
        this.selectedContactName = '';

        this.contactExists = false;

        this.fullcontactName = this.originalContactName || '';

        this.generateOpportunityName();
        this.fetchMatchingAccounts();
    }


    handlePanChange(event) {

        this.panNumber = event.target.value;

    }

    handleBillingGstChange(event) {

        this.billingGstNumber = event.target.value;

    }

    handleShippingGstChange(event) {

        this.shippingGstNumber = event.target.value;

    }


    /* ---------------- CONTACT ---------------- */

    handleContactChange(event) {

        this.fullcontactName = event.target.value;

        this.selectedContactId = '';
        this.selectedContactName = '';

        this.contactExists = false;

        clearTimeout(this.contactSearchTimeout);
        this.contactSearchTimeout = setTimeout(() => this.fetchMatchingContacts(), SEARCH_DEBOUNCE_MS);
    }


    async fetchMatchingContacts(loadMore = false) {
        const searchValue = (this.fullcontactName || '').trim();

        if (!this.selectedAccountId || !searchValue || searchValue.length < 2) {
            this.contactSearchSequence++;
            this.matchingContacts = [];
            this.hasMoreContacts = false;
            this.isLoadingContacts = false;
            return;
        }

        if (loadMore && (this.isLoadingContacts || !this.hasMoreContacts)) return;

        const cursor = loadMore ? this.matchingContacts[this.matchingContacts.length - 1] : null;
        const requestId = loadMore ? this.contactSearchSequence : ++this.contactSearchSequence;
        const accountId = this.selectedAccountId;

        if (!loadMore) {
            this.matchingContacts = [];
            this.hasMoreContacts = true;
        }

        this.isLoadingContacts = true;

        try {
            const result = await fetchMatchingContacts({
                selectedAccountId: accountId,
                contactName: searchValue,
                lastName: cursor?.name || null,
                lastId: cursor?.value || null,
                pageSize: SEARCH_PAGE_SIZE
            });

            if (
                requestId !== this.contactSearchSequence ||
                accountId !== this.selectedAccountId ||
                searchValue !== (this.fullcontactName || '').trim()
            ) return;

            const newMatches = (result || []).map(contact => ({
                label: contact.Name,
                name: contact.Name,
                value: contact.Id
            }));

            this.matchingContacts = loadMore ? [...this.matchingContacts, ...newMatches] : newMatches;
            this.hasMoreContacts = newMatches.length === SEARCH_PAGE_SIZE;
        } catch (error) {
            console.error('Error fetching matching contacts:', error);
            if (!loadMore) this.matchingContacts = [];
            this.hasMoreContacts = false;
        } finally {
            if (requestId === this.contactSearchSequence) this.isLoadingContacts = false;
        }
    }


    handleContactResultsScroll(event) {
        const resultList = event.currentTarget;
        if (resultList.scrollHeight - resultList.scrollTop - resultList.clientHeight <= 24) {
            this.fetchMatchingContacts(true);
        }
    }


    handleContactSelection(event) {

        this.selectedContactId = event.target.value;

        const con = this.matchingContacts.find(
            c => c.value === this.selectedContactId
        );

        if (con) {

            this.selectedContactName = con.label;
            this.fullcontactName = con.label;
            this.contactExists = true;

        }
    }


    clearSelection1() {

        this.selectedContactId = '';
        this.selectedContactName = '';

        this.fullcontactName = this.originalContactName || '';

        this.contactExists = false;

        this.fetchMatchingContacts();
    }


    /* ---------------- CONVERT ---------------- */

    async handleConvert() {

        if (this.isLoading) return;

        try {

            if (!this.opportunityName) {

                this.showToast('Error', 'Opportunity Name is required', 'error');
                return;

            }

            this.isLoading = true;

            let firstName = this.contactFirstName;
            let lastName = this.contactName;

            if (this.fullcontactName && this.fullcontactName.includes(' ')) {

                const parts = this.fullcontactName.trim().split(/\s+/);

                firstName = parts.shift();
                lastName = parts.join(' ');

            }
            else if (this.fullcontactName) {

                lastName = this.fullcontactName.trim();
                firstName = '';

            }


            const result = await convertLead({

                leadId: this.recordId,

                accountExists: this.accountExists,
                contactExists: this.selectedContactId ? true : false,

                accountName: this.selectedAccountName || this.accountName,
                contactName: lastName,
                contactFirstName: firstName,

                opportunityName: this.opportunityName,

                recordTypeId: null,
                accountId: this.selectedAccountId || null,

                panNumber: this.panNumber,
                billingGstNumber: this.billingGstNumber,
                shippingGstNumber: this.shippingGstNumber

            });


            this.isModalOpen = false;

            this.showToast('Success', 'Lead converted successfully', 'success');


            this[NavigationMixin.Navigate]({

                type: 'standard__recordPage',

                attributes: {
                    recordId: result,
                    objectApiName: 'Opportunity',
                    actionName: 'view'
                }

            });

        } catch (e) {

            this.showToast('Error', e.body?.message || e.message, 'error');

        } finally {

            this.isLoading = false;

        }
    }


    handleCloseModal() {

        this.isModalOpen = false;

        this[NavigationMixin.Navigate]({

            type: 'standard__recordPage',

            attributes: {
                recordId: this.recordId,
                objectApiName: 'Lead',
                actionName: 'view'
            }

        });
    }


    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode: 'sticky'
            })
        );
    }
}