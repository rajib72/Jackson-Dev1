import { LightningElement, api, wire, track } from 'lwc';
import getInitialData from '@salesforce/apex/SRTTechnoCommercialOfferController.getInitialData';
import createQuote from '@salesforce/apex/SRTTechnoCommercialOfferController.createQuote';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class TechnoCommercialOffer extends NavigationMixin(LightningElement) {

    @api recordId;

    @track isStepOne = true;
    @track isStepTwo = false;

    @track accountId;
    @track accountName;
    @track opportunityName;
    @track contactOptions = [];
    @track contactId;

    @track quoteName;
    @track expirationDate;
    @track description;

    @track billingStreet;
    @track billingCity;
    @track billingState;
    @track billingPostalCode;
    @track billingCountry;

    @track shippingStreet;
    @track shippingCity;
    @track shippingState;
    @track shippingPostalCode;
    @track shippingCountry;

    isLoading = false;

    /* ================= LOAD INITIAL DATA ================= */

    @wire(getInitialData, { oppId: '$recordId' })
    wiredData({ data, error }) {
        if (data) {

            this.accountId = data.account.Id;
            this.accountName = data.account.Name;
            this.opportunityName = data.opportunity.Name;

            this.contactOptions = data.contacts.map(c => ({
                label: c.Name,
                value: c.Id
            }));

            const acc = data.account;

            this.billingStreet = acc.BillingStreet;
            this.billingCity = acc.BillingCity;
            this.billingState = acc.BillingState;
            this.billingPostalCode = acc.BillingPostalCode;
            this.billingCountry = acc.BillingCountry;

            this.shippingStreet = acc.ShippingStreet;
            this.shippingCity = acc.ShippingCity;
            this.shippingState = acc.ShippingState;
            this.shippingPostalCode = acc.ShippingPostalCode;
            this.shippingCountry = acc.ShippingCountry;
        }

        if (error) {
            this.showToast('Error', 'Error loading data', 'error');
        }
    }

    /* ================= INPUT HANDLERS ================= */

    handleContactChange(event){
        this.contactId = event.detail.value;
    }

    handleQuoteNameChange(event){
        this.quoteName = event.target.value;
    }

    handleExpirationChange(event){
        this.expirationDate = event.target.value;
    }

    handleDescriptionChange(event){
        this.description = event.target.value;
    }

    /* ================= STEP NAVIGATION ================= */

    handleNext(){
        if(!this.quoteName || !this.expirationDate || !this.contactId){
            this.showToast('Error','Please fill all required fields','error');
            return;
        }
        this.isStepOne = false;
        this.isStepTwo = true;
    }

    handlePrevious(){
        this.isStepOne = true;
        this.isStepTwo = false;
    }

    /* ================= CREATE QUOTE ================= */

    handleCreate(){

        this.isLoading = true;

        createQuote({
            opportunityId: this.recordId,
            accountId: this.accountId,
            contactId: this.contactId,
            name: this.quoteName,
            expirationDate: this.expirationDate,
            description: this.description,
            billingStreet: this.billingStreet,
            billingCity: this.billingCity,
            billingState: this.billingState,
            billingPostalCode: this.billingPostalCode,
            billingCountry: this.billingCountry,
            shippingStreet: this.shippingStreet,
            shippingCity: this.shippingCity,
            shippingState: this.shippingState,
            shippingPostalCode: this.shippingPostalCode,
            shippingCountry: this.shippingCountry
        })
        .then(result=>{

            this.isLoading = false;

            this.showToast('Success','Quote Created Successfully','success');

            // 🔥 Close Aura Quick Action
            this.dispatchEvent(
                new CustomEvent('closequickaction', {
                    bubbles: true,
                    composed: true
                })
            );

            // Navigate to created Quote
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result,
                    objectApiName: 'Quote',
                    actionName: 'view'
                }
            });

        })
        .catch(error=>{

            this.isLoading = false;

            this.showToast(
                'Error',
                error?.body?.message || 'Error creating quote',
                'error'
            );
        });
    }

    /* ================= CLOSE ================= */

    handleClose(){
        this.dispatchEvent(
            new CustomEvent('closequickaction', {
                bubbles: true,
                composed: true
            })
        );
    }

    /* ================= TOAST ================= */

    showToast(title,message,variant){
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }

}