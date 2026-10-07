import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';

import getWorkOrderDefaults from '@salesforce/apex/ctrl_ServiceAppointmentController.getWorkOrderDefaults';
import searchAccounts from '@salesforce/apex/ctrl_ServiceAppointmentController.searchAccounts';
import createServiceAppointment from '@salesforce/apex/ctrl_ServiceAppointmentController.createServiceAppointment';

import ESTIMATION_COST_FIELD from '@salesforce/schema/WorkOrder.Final_Service_Estimation_Cost__c';
import EXECUTION_MODE_FIELD from '@salesforce/schema/WorkOrder.Execution_Mode__c';

export default class CreateServiceAppointmentFromWorkOrder extends NavigationMixin(LightningElement) {
    _recordId;

    @api
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadDefaults();
        }
    }

    get recordId() {
        return this._recordId;
    }
    
    @track form = {
        subject: '',
        status: 'None',
        serviceTerritoryId: null,
        workTypeId: null,
        shipToAccountId: null,
        siteName: '',
        street: '',
        postalCode: '',
        description: ''
    };

    isLoading = true;
    isSaving = false;
    
    showError = false; 
    errorMessage = ''; 

    workOrderNumber;
    shipToSearchText = '';
    selectedShipToName = '';
    showAccountDropdown = false;
    accountOptions = [];
    searchTimer;

    // Address combination tracking
    @track addressOptions = [];
    rawAddressData = [];
    selectedAddressValue = '';

    statusOptions = [
        { label: 'None', value: 'None' },
        { label: 'Scheduled', value: 'Scheduled' },
        { label: 'Dispatched', value: 'Dispatched' },
        { label: 'In Progress', value: 'In Progress' },
        { label: 'Completed', value: 'Completed' },
        { label: 'Canceled', value: 'Canceled' }
    ];

    @wire(getRecord, { recordId: '$recordId', fields: [ESTIMATION_COST_FIELD, EXECUTION_MODE_FIELD] })
    wiredWorkOrder({ error, data }) {
        if (data) {
            const cost = getFieldValue(data, ESTIMATION_COST_FIELD);
            const mode = getFieldValue(data, EXECUTION_MODE_FIELD);
            
            const isCostZero = (cost === 0 || cost == null);
            const isNotSiteVisit = (mode !== 'Site Visit');

            this.showError = isCostZero || isNotSiteVisit;

            if (this.showError) {
                if (isCostZero && isNotSiteVisit) {
                    this.errorMessage = 'THIS BUTTON WILL ONLY WORK IF THE EXECUTION MODE IS SITE VISIT AND THE SERVICE ESTIMATION COST IS GIVEN.';
                } else if (isNotSiteVisit) {
                    this.errorMessage = 'THIS BUTTON WILL ONLY WORK IF THE EXECUTION MODE IS SITE VISIT.';
                } else {
                    this.errorMessage = 'THIS BUTTON WILL WORK IF THE SERVICE ESTIMATION COST IS GIVEN.';
                }
            }
        } else if (error) {
            console.error('Error fetching Work Order details', error);
        }
    }

    async loadDefaults() {
        try {
            const data = await getWorkOrderDefaults({ workOrderId: this._recordId });
            this.workOrderNumber = data.workOrderNumber;

            // Load and map concatenated address options
            this.rawAddressData = data.addressOptions || [];
            this.addressOptions = this.rawAddressData.map(addr => {
                return { label: addr.label, value: addr.value };
            });

            this.form = {
                ...this.form,
                subject: data.subject || `Service Appointment - ${data.workOrderNumber}`,
                serviceTerritoryId: data.serviceTerritoryId,
                workTypeId: data.workTypeId,
                shipToAccountId: data.accountId,
                siteName: '',
                street: '',
                postalCode: ''
            };

            if (data.accountId) {
                this.selectedShipToName = data.accountName;
                this.shipToSearchText = data.accountName;
            }
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.form = {
            ...this.form,
            [field]: event.target.value
        };
    }

    handleAddressChange(event) {
        this.selectedAddressValue = event.detail.value;

        // Find the selected wrapper record and map individual values to the payload form
        const selectedAddressObj = this.rawAddressData.find(addr => addr.value === this.selectedAddressValue);
        
        if (selectedAddressObj) {
            this.form.siteName = selectedAddressObj.siteName;
            this.form.street = selectedAddressObj.street;
            this.form.postalCode = selectedAddressObj.postalCode;
        }
    }

    handleShipToSearch(event) {
        this.shipToSearchText = event.target.value;
        this.selectedShipToName = '';
        this.form.shipToAccountId = null;

        window.clearTimeout(this.searchTimer);
        this.searchTimer = setTimeout(() => {
            this.searchShipToAccounts();
        }, 300);
    }

    showShipToResults() {
        if (this.shipToSearchText && this.shipToSearchText.length >= 2) {
            this.showAccountDropdown = true;
        }
    }

    async searchShipToAccounts() {
        if (!this.shipToSearchText || this.shipToSearchText.length < 2) {
            this.accountOptions = [];
            this.showAccountDropdown = false;
            return;
        }

        try {
            this.accountOptions = await searchAccounts({ searchKey: this.shipToSearchText });
            this.showAccountDropdown = true;
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    selectShipTo(event) {
        const accountId = event.currentTarget.dataset.id;
        const accountName = event.currentTarget.dataset.name;

        this.form.shipToAccountId = accountId;
        this.selectedShipToName = accountName;
        this.shipToSearchText = accountName;
        this.showAccountDropdown = false;
    }

    clearShipTo() {
        this.form.shipToAccountId = null;
        this.selectedShipToName = '';
        this.shipToSearchText = '';
        this.accountOptions = [];
        this.showAccountDropdown = false;
    }

    async handleSave() {
        if (!this.validateForm()) {
            return;
        }

        this.isSaving = true;

        try {
            const serviceAppointmentId = await createServiceAppointment({
                req: {
                    workOrderId: this._recordId,
                    subject: this.form.subject,
                    status: this.form.status,
                    serviceTerritoryId: this.form.serviceTerritoryId,
                    workTypeId: this.form.workTypeId,
                    shipToAccountId: this.form.shipToAccountId,
                    siteName: this.form.siteName,
                    street: this.form.street,
                    postalCode: this.form.postalCode,
                    description: this.form.description
                }
            });

            this.showToast('Success', 'Service Appointment created successfully.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: serviceAppointmentId,
                    objectApiName: 'ServiceAppointment',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    validateForm() {
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')];
        return inputs.reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) return error.body.map(e => e.message).join(', ');
        if (typeof error?.body?.message === 'string') return error.body.message;
        if (typeof error?.message === 'string') return error.message;
        return 'Unknown error occurred.';
    }
}