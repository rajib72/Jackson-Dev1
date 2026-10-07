import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import jaksonLogo from '@salesforce/resourceUrl/JaksonLogo';
import SiteSurveyIMG from '@salesforce/resourceUrl/SiteSurveyIMG';
import { getRecord } from 'lightning/uiRecordApi';
import ACCOUNTID from '@salesforce/schema/Opportunity.AccountId';
import ACCOUNTNAME from '@salesforce/schema/Opportunity.Account.Name';
import STREET from '@salesforce/schema/Opportunity.Account.BillingStreet';
import CITY from '@salesforce/schema/Opportunity.Account.BillingCity';
import STATE from '@salesforce/schema/Opportunity.Account.BillingState';
import POSTALCODE from '@salesforce/schema/Opportunity.Account.BillingPostalCode';
import COUNTRY from '@salesforce/schema/Opportunity.Account.BillingCountry';
import uploadFile from '@salesforce/apex/Ctrl_SiteSurveyForm.uploadFile';
import { NavigationMixin } from 'lightning/navigation';
import markSurveyCompleted from '@salesforce/apex/Ctrl_SiteSurveyForm.markSurveyCompleted';
import getContactsByAccount from '@salesforce/apex/Ctrl_SiteSurveyForm.getContactsByAccount';



const FIELDS = [
    ACCOUNTID,
    ACCOUNTNAME,
    STREET,
    CITY,
    STATE,
    POSTALCODE,
    COUNTRY
];

export default class SiteSurveyFormLWC extends NavigationMixin(LightningElement) {

    @api recordId;

    logoUrl = jaksonLogo;
    roofImage = SiteSurveyIMG;

    docNumber;
    accountName;
    address;

    siteSurveyId;

    jaksonFile;
    clientFile;
    sheetFiles = [];

    isPoorQuality = false;
    showRoofReason = false;
    showRating = false;
    showBusbarSection = false;

    @track isLoading = false;
    @track isNetMeteringRequired = false;
    @track isRooftop = false;

    
    @track contactOptions = [];
    selectedContactId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredOpp({ data, error }) {

        if (data) {

            this.accountId = data.fields.AccountId.value;

            const acc = data.fields.Account?.value;

            if (acc) {

                this.accountName = acc.fields.Name?.value;

                const street = acc.fields.BillingStreet?.value || '';
                const city = acc.fields.BillingCity?.value || '';
                const state = acc.fields.BillingState?.value || '';
                const pin = acc.fields.BillingPostalCode?.value || '';
                const country = acc.fields.BillingCountry?.value || '';

                this.address = `${street}, ${city}, ${state}, ${pin}, ${country}`;
            }
            this.loadContacts();

        } else if (error) {
            console.error(error);
        }
    }

    connectedCallback() {
        this.generateDocNumber();
    }

    /* ---------------- LOAD CONTACTS ---------------- */

    loadContacts() {

        if (!this.accountId) return;

        getContactsByAccount({ accountId: this.accountId })
            .then(result => {

                this.contactOptions = result.map(contact => ({
                    label: contact.Name,
                    value: contact.Id
                }));

            })
            .catch(error => {
                console.error('Error fetching contacts', error);
            });
    }

    handleContactChange(event) {
        this.selectedContactId = event.detail.value;
    }

    connectedCallback() {
        this.generateDocNumber();
    }

    //Document Number
    generateDocNumber() {

        const today = new Date();

        let year = today.getFullYear();
        let month = today.getMonth() + 1;
        let day = today.getDate();

        let startYear;
        let endYear;

        if (month >= 4) {
            startYear = year;
            endYear = year + 1;
        } else {
            startYear = year - 1;
            endYear = year;
        }

        let fy = startYear + '-' + String(endYear).slice(-2);

        let mm = month < 10 ? '0' + month : month;
        let dd = day < 10 ? '0' + day : day;

        this.docNumber = `${fy}/${mm}/${dd}`;
    }

    // ---------------- Address Checkbox ----------------

    handleAddressCheckbox(event) {

        const locationField = this.template.querySelector('[data-id="locationField"]');

        if (!locationField) return;

        if (event.target.checked) {
            locationField.value = this.address;
        } else {
            locationField.value = '';
        }
    }

    // ---------------- Power Quality ----------------

    handlePowerQualityChange(event) {
        this.isPoorQuality = event.detail.value === 'Poor';
    }

    // ---------------- Roof Penetration ----------------

    handleRoofPenetrationChange(event) {
        this.showRoofReason = event.detail.value === 'No';
    }

    // ---------------- Feeder ----------------

    handleFeederChange(event) {

        const value = event.detail.value;

        if (value === 'Yes') {
            this.showRating = true;
            this.showBusbarSection = false;
        } else {
            this.showRating = false;
            this.showBusbarSection = true;
        }
    }

    handleCubicalChange(event) {
        if (event.detail.value === 'No') {
            this.showBusbarSection = true;
        }
    }

    // ---------------- Net Metering ----------------

    handleNetMeteringChange(event) {
        this.isNetMeteringRequired = event.detail.value === 'Required';
    }
    handleProjectSegmentChange(event) {
        const value = event.detail.value;

        this.isRooftop = value === 'Rooftop'; // match picklist value exactly
    }


    // ---------------- FILE READER HELPER ----------------

    readFile(file) {

        return new Promise((resolve) => {

            const reader = new FileReader();

            reader.onload = () => {

                const base64 = reader.result.split(',')[1];

                resolve({
                    fileName: file.name,
                    base64: base64
                });

            };

            reader.readAsDataURL(file);
        });
    }

    // ---------------- FILE HANDLERS ----------------

    async handleJaksonFile(event) {

        const file = event.target.files[0];

        if (!file) return;

        this.jaksonFile = await this.readFile(file);
    }

    async handleClientFile(event) {

        const file = event.target.files[0];

        if (!file) return;

        this.clientFile = await this.readFile(file);
    }

    async handleSheetFile(event) {

        const files = event.target.files;

        for (let file of files) {

            const fileData = await this.readFile(file);

            this.sheetFiles.push(fileData);
        }
    }

    

    // ---------------- Upload Files ----------------

    async uploadFiles() {

        const parentId = this.siteSurveyId;

        if (!parentId) {
            console.error('SiteSurveyId missing');
            return;
        }

        try {

            if (this.jaksonFile) {

                await uploadFile({
                    fileName: this.jaksonFile.fileName,
                    base64Data: this.jaksonFile.base64,
                    recordId: parentId
                });

            }

            if (this.clientFile) {

                await uploadFile({
                    fileName: this.clientFile.fileName,
                    base64Data: this.clientFile.base64,
                    recordId: parentId
                });

            }

            for (let file of this.sheetFiles) {

                await uploadFile({
                    fileName: file.fileName,
                    base64Data: file.base64,
                    recordId: parentId
                });

            }

        } catch (error) {

            console.error('Upload Error', error);

            this.showToast('Error', 'File Upload Failed', 'error');
        }
    }


    handleSubmit(event) {

        event.preventDefault();

        const fields = event.detail.fields;

        


        this.isLoading = true;

        // Link Opportunity
        fields.Opportunity__c = this.recordId;

        // Set Customer (Account)
        if (this.accountId) {
            fields.Customer_Name__c = this.accountId;
        }

        // Set Address
        if (this.address) {
            fields.Address__c = this.address;
        }
        

        fields.Contact_Person_Name__c = this.selectedContactId;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }


    // ---------------- Form Success ----------------

    async handleSuccess(event) {

        console.log('FORM SUBMITTED');

        this.siteSurveyId = event.detail.id;
        try {

            await this.uploadFiles();
            await markSurveyCompleted({
                opportunityId: this.recordId
            });

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.siteSurveyId,
                    objectApiName: 'Site_Survey__c',
                    actionName: 'view'
                }
            });
        }
        catch (error) {

            this.isLoading = false;

            this.showToast('Error', 'Something went wrong', 'error');
        }
    }

    // ---------------- Toast ----------------

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}