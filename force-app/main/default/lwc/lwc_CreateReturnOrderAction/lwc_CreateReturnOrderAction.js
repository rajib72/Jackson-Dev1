import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';

import getProductRequestDetails from '@salesforce/apex/Ctrl_CreateReturnOrderAction.getProductRequestDetails';
import getLocationDetails from '@salesforce/apex/Ctrl_CreateReturnOrderAction.getLocationDetails';

export default class Lwc_CreateReturnOrderAction extends NavigationMixin(LightningElement) {
    @api recordId;

    accountId;
    contactId;
    caseId;
    isReady = false;

    allLocations = [];

    // Search States
    sourceLocationId;
    sourceLocationName = '';
    filteredSourceOptions = [];
    showSourceDropdown = false;

    destLocationId;
    destLocationName = '';
    filteredDestOptions = [];
    showDestDropdown = false;

    // Custom Address States
    shipFromStreet = '';
    shipFromCity = '';
    shipFromState = '';
    shipFromZip = '';
    shipFromCountry = '';

    @wire(getProductRequestDetails, { productRequestId: '$recordId' })
    wiredProductRequest({ error, data }) {
        if (data) {
            if (data.WorkOrder) {
                this.accountId = data.WorkOrder.AccountId;
                this.contactId = data.WorkOrder.ContactId;
                this.caseId = data.WorkOrder.CaseId;
            }
            this.isReady = true;
        } else if (error) {
            this.showToast('Error', 'Could not load Product Request details.', 'error');
            this.isReady = true;
        }
    }

    @wire(getLocationDetails)
    wiredLocations({ error, data }) {
        if (data) this.allLocations = data;
    }

    // Capture Address changes
    handleAddressChange(event) {
        const field = event.target.dataset.field;
        if (field === 'street') this.shipFromStreet = event.target.value;
        else if (field === 'city') this.shipFromCity = event.target.value;
        else if (field === 'state') this.shipFromState = event.target.value;
        else if (field === 'zip') this.shipFromZip = event.target.value;
        else if (field === 'country') this.shipFromCountry = event.target.value;
    }

    handleSearch(event) {
        const field = event.target.dataset.field;
        const searchTerm = event.target.value.toLowerCase();

        if (field === 'source') {
            this.sourceLocationName = event.target.value;
            this.sourceLocationId = null;
            if (searchTerm) {
                this.filteredSourceOptions = this.allLocations.filter(loc => loc.LocationName.toLowerCase().includes(searchTerm));
                this.showSourceDropdown = this.filteredSourceOptions.length > 0;
            } else {
                this.showSourceDropdown = false;
            }
        } else {
            this.destLocationName = event.target.value;
            this.destLocationId = null;
            if (searchTerm) {
                this.filteredDestOptions = this.allLocations.filter(loc => loc.LocationName.toLowerCase().includes(searchTerm));
                this.showDestDropdown = this.filteredDestOptions.length > 0;
            } else {
                this.showDestDropdown = false;
            }
        }
    }

    handleFocus(event) {
        const field = event.target.dataset.field;
        if (field === 'source' && !this.sourceLocationName) {
            this.filteredSourceOptions = this.allLocations.slice(0, 5);
            this.showSourceDropdown = true;
        } else if (field === 'dest' && !this.destLocationName) {
            this.filteredDestOptions = this.allLocations.slice(0, 5);
            this.showDestDropdown = true;
        }
    }

    handleBlur(event) {
        const field = event.target.dataset.field;
        setTimeout(() => {
            if (field === 'source') this.showSourceDropdown = false;
            else this.showDestDropdown = false;
        }, 150);
    }

    handleSelect(event) {
        const field = event.currentTarget.dataset.field;
        const locId = event.currentTarget.dataset.id;
        const locName = event.currentTarget.dataset.name;

        if (field === 'source') {
            this.sourceLocationId = locId;
            this.sourceLocationName = locName;
            this.showSourceDropdown = false;
        } else {
            this.destLocationId = locId;
            this.destLocationName = locName;
            this.showDestDropdown = false;
        }
    }

    handleSaveClick() {
        const hiddenSubmitBtn = this.template.querySelector('.hidden-submit-btn');
        if (hiddenSubmitBtn) {
            hiddenSubmitBtn.click();
        }
    }

    handleSubmit(event) {
        event.preventDefault();

        // 1. Clone the fields object so LDS recognizes the mutations
        const fields = Object.assign({}, event.detail.fields);

        console.log('@@@DEBUG:: submit clicked' + JSON.stringify(fields));
        this.showToast('Success', JSON.stringify(fields), 'success');

        // 2. Inject custom Location Lookups
        fields.SourceLocationId = this.sourceLocationId;
        fields.DestinationLocationId = this.destLocationId;

        // 3. Inject custom Address variables into the standard Salesforce fields
        fields.ShipFromStreet = this.shipFromStreet;
        fields.ShipFromCity = this.shipFromCity;
        fields.ShipFromState = this.shipFromState;
        fields.ShipFromPostalCode = this.shipFromZip;
        fields.ShipFromCountry = this.shipFromCountry;

        // 4. Submit form seamlessly with the newly cloned and updated object
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess(event) {
        const newRecordId = event.detail.id;
        this.showToast('Success', `Return Order ${event.detail.id} created successfully!`, 'success');
        this.closeAction();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: newRecordId,
                objectApiName: 'ReturnOrder',
                actionName: 'view'
            }
        });
    }

    handleError(event) {
        console.error('Error saving record: ', JSON.stringify(event.detail));
        this.showToast('Error', event.detail.detail || event.detail.message, 'error');
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title: title, message: message, variant: variant }));
    }
}