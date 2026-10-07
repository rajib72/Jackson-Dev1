import { LightningElement, api, wire, track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import getOrderReasons from '@salesforce/apex/Ctrl_AddOrderReasonToServiceOrder.getOrderReasons';
import ID_FIELD from '@salesforce/schema/Order.Id';
import ORDER_REASON_FIELD from '@salesforce/schema/Order.Order_Reason__c';

export default class Lwc_addOrderReasonToServiceOrder extends LightningElement {
    @api recordId; 
    
    @track allOptions = [];
    @track filteredOptions = [];
    
    searchTerm = '';
    showDropdown = false;
    selectedValue = '';
    selectedLabel = '';

    @wire(getOrderReasons)
    wiredReasons({ error, data }) {
        if (data) {
            this.allOptions = data.map(record => ({
                label: record.Order_Reason_Details__c,
                value: record.ORDER_REASON__c
            }));
            this.filteredOptions = [...this.allOptions];
        } else if (error) {
            this.showToast('Error', 'Failed to fetch Order Reasons', 'error');
        }
    }

    // Dynamic class for showing/hiding dropdown via SLDS
    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.showDropdown ? 'slds-is-open' : ''}`;
    }

    get isExpanded() {
        return this.showDropdown;
    }

    get hasOptions() {
        return this.filteredOptions.length > 0;
    }

    get isSaveDisabled() {
        return !this.selectedValue;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.showDropdown = true;
        this.filteredOptions = this.allOptions.filter(option => 
            option.label.toLowerCase().includes(this.searchTerm)
        );
    }

    handleFocus() {
        this.showDropdown = true;
        this.filteredOptions = this.allOptions.filter(option => 
            option.label.toLowerCase().includes(this.searchTerm)
        );
    }

    handleBlur() {
        this.showDropdown = false;
    }

    handleSelect(event) {
        this.selectedValue = event.currentTarget.dataset.value;
        this.selectedLabel = event.currentTarget.dataset.label;
        this.showDropdown = false;
        this.searchTerm = '';
    }

    handleRemove() {
        this.selectedValue = '';
        this.selectedLabel = '';
        this.searchTerm = '';
        this.filteredOptions = [...this.allOptions]; // Reset list
    }

    handleCancel() {
        // Closes the Quick Action Modal
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSave() {
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[ORDER_REASON_FIELD.fieldApiName] = this.selectedValue;

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                this.showToast('Success', 'Order Reason updated successfully!', 'success');
                this.dispatchEvent(new CloseActionScreenEvent()); // Close modal on success
            })
            .catch(error => {
                this.showToast('Error updating record', error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}