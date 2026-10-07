import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getInitialData from '@salesforce/apex/ctrl_ProductRequestCreationController.getInitialData';
import createProductRequest from '@salesforce/apex/ctrl_ProductRequestCreationController.createProductRequest';

export default class ProductRequestCreation extends NavigationMixin(LightningElement) {
    @api recordId;
    @track recordTypes = [];
    @track locations = [];
    @track shipAddresses = [];
    currentStep = 'recordType';
    selectedRecordTypeId;
    selectedRequestType;
    workOrderNumber;
    destinationLocationId;
    description;
    needByDate;
    selectedWoliId;
    selectedAssetId;
    siteName;
    state;
    street;
    pinCode;
    city;
    country;
    isLoading = true;
    isSaving = false;
    dataLoaded = false;
    retryCount = 0;
    retryTimer;

    renderedCallback() {
        if (this.dataLoaded || this.retryTimer) return;
        if (this.recordId) {
            this.loadInitialData();
        } else if (this.retryCount < 20) {
            this.retryCount++;
            this.retryTimer = setTimeout(() => {
                this.retryTimer = null;
                this.renderedCallback();
            }, 250);
        } else {
            this.isLoading = false;
            this.showToast('Error', 'Unable to get the Work Order context. Please close and reopen the action.', 'error');
        }
    }

    disconnectedCallback() {
        if (this.retryTimer) {
            clearTimeout(this.retryTimer);
            this.retryTimer = null;
        }
    }

    async loadInitialData() {
        if (!this.recordId || this.dataLoaded) return;
        try {
            this.isLoading = true;
            const result = await getInitialData({ workOrderId: this.recordId });
            if (!result) throw new Error('No data was returned from Salesforce.');
            this.workOrderNumber = result.workOrderNumber;
            this.recordTypes = (result.recordTypes || []).map(rt => ({
                label: rt.label,
                value: rt.id,
                developerName: rt.developerName
            }));
            this.locations = (result.locations || []).map(location => ({
                label: location.name,
                value: location.id
            }));
            this.shipAddresses = (result.shipAddresses || []).map(address => ({
                label: address.displayLabel,
                value: address.workOrderLineItemId,
                workOrderLineItemId: address.workOrderLineItemId,
                assetId: address.assetId,
                assetName: address.assetName,
                siteName: address.siteName,
                state: address.state,
                street: address.street,
                pinCode: address.pinCode,
                city: address.city,
                country: address.country
            }));
            this.dataLoaded = true;
            if (!this.recordTypes.length) {
                this.showToast('Error', 'No active FOC, Paid or RGP Product Request record types were found.', 'error');
            }
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    get isRecordTypeStep() {
        return this.currentStep === 'recordType';
    }

    get isFormStep() {
        return this.currentStep === 'form';
    }

    get formTitle() {
        return this.selectedRequestType ? `New Product Request: ${this.selectedRequestType}` : 'New Product Request';
    }

    get selectedStatusLabel() {
        if (this.selectedRequestType === 'FOC') return 'FOC Status';
        if (this.selectedRequestType === 'Paid') return 'Paid Status';
        if (this.selectedRequestType === 'RGP') return 'RGP Status';
        return 'Status';
    }

    get statusValue() {
        return 'Draft';
    }

    get isNextDisabled() {
        return !this.selectedRecordTypeId;
    }

    get isSaveDisabled() {
        return this.isSaving || !this.destinationLocationId || !this.needByDate || !this.selectedWoliId;
    }

    handleRecordTypeChange(event) {
        this.selectedRecordTypeId = event.detail.value;
        console.log('debug:: this.selectedRecordTypeId ' + this.selectedRecordTypeId);
        const selected = this.recordTypes.find(rt => rt.value === this.selectedRecordTypeId);
        this.selectedRequestType = selected ? selected.label : null;
        console.log('debug:: this.selectedRequestType ' + this.selectedRequestType + ' - selected ' + JSON.stringify(selected));
    }

    handleNext() {
        if (!this.selectedRecordTypeId) {
            this.showToast('Error', 'Please select a record type.', 'error');
            return;
        }
        this.currentStep = 'form';
    }

    handleBack() {
        this.currentStep = 'recordType';
    }

    handleDestinationLocationChange(event) {
        this.destinationLocationId = event.detail.value;
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    handleNeedByDateChange(event) {
        this.needByDate = event.target.value;
    }

    handleShipAddressChange(event) {
        this.selectedWoliId = event.detail.value;
        const selected = this.shipAddresses.find(address => address.workOrderLineItemId === this.selectedWoliId);
        if (!selected) {
            this.selectedAssetId = null;
            this.siteName = null;
            this.state = null;
            this.street = null;
            this.pinCode = null;
            this.city = null;
            this.country = null;
            return;
        }
        this.selectedAssetId = selected.assetId;
        this.siteName = selected.siteName;
        this.state = selected.state;
        this.street = selected.street;
        this.pinCode = selected.pinCode;
        this.city = selected.city;
        this.country = selected.country;
    }

    async handleSave() {
        if (!this.selectedRecordTypeId) {
            this.showToast('Error', 'Please select a record type.', 'error');
            return;
        }
        if (this.isSaveDisabled) {
            this.showToast('Error', 'Please complete all required fields.', 'error');
            return;
        }
        const selectedRecordType = this.recordTypes.find(rt => rt.value === this.selectedRecordTypeId);
        const requestType = selectedRecordType ? selectedRecordType.label : null;
        console.log('Selected Record Type Id:', this.selectedRecordTypeId);
        console.log('Selected Record Type:', selectedRecordType);
        console.log('Request Type:', requestType);
        if (!requestType) {
            this.showToast('Error', 'Unable to determine Product Request Type from selected Record Type.', 'error');
            return;
        }
        try {
            this.isSaving = true;
            const input = {
                workOrderId: this.recordId || null,
                recordTypeId: this.selectedRecordTypeId,
                requestType: requestType,
                destinationLocationId: this.destinationLocationId,
                description: this.description,
                needByDate: this.needByDate,
                workOrderLineItemId: this.selectedWoliId,
                assetId: this.selectedAssetId,
                siteName: this.siteName,
                state: this.state,
                street: this.street,
                pinCode: this.pinCode,
                city: this.city,
                country: this.country
            };
            console.log('FINAL PRODUCT REQUEST INPUT:', JSON.stringify(input));
            const productRequestId = await createProductRequest({ input });
            this.showToast('Success', 'Product Request created successfully.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: productRequestId,
                    objectApiName: 'ProductRequest',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showError(error);
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showError(error) {
        let message = 'An unexpected error occurred.';
        if (error?.body?.message) message = error.body.message;
        else if (error?.message) message = error.message;
        else if (Array.isArray(error?.body)) message = error.body.map(e => e.message).join(', ');
        this.showToast('Error', message, 'error');
    }
}