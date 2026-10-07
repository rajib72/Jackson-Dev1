import { LightningElement, api } from 'lwc';

import searchSuppliers from
    '@salesforce/apex/CaseL3AssignmentController.searchSuppliers';

import escalateToL3 from
    '@salesforce/apex/CaseL3AssignmentController.escalateToL3';

import { ShowToastEvent } from
    'lightning/platformShowToastEvent';

import { CloseActionScreenEvent } from
    'lightning/actions';

import { RefreshEvent } from
    'lightning/refresh';

import { notifyRecordUpdateAvailable }
    from 'lightning/uiRecordApi';


export default class CaseEscalateToL3 extends LightningElement {


    _recordId;
_loadedCaseId;

@api
get recordId() {
    return this._recordId;
}

set recordId(value) {
    this._recordId = value;

    if (value && value !== this._loadedCaseId) {
        this._loadedCaseId = value;
        this.selectedSupplier = null;
        this.suppliers = [];
        this.loadSuppliers();
    }
}


    searchTerm = '';

    suppliers = [];

    selectedSupplier = null;

    remarks = '';

    isLoading = false;

    isSupplierLoading = false;



    get showSearchResults() {

        return (
            this.suppliers &&
            this.suppliers.length > 0
        );

    }



    get isSubmitDisabled() {

        return !(
            this.selectedSupplier &&
            this.remarks
        );

    }





    handleSupplierSearch(event) {

        this.searchTerm =
            event.detail.value || '';

        console.log(
            'Typed Supplier:',
            this.searchTerm
        );

        if (this.searchTimer) {
            clearTimeout(this.searchTimer);
        }


        if (
            this.searchTerm.trim().length < 2
        ) {

            this.suppliers = [];

            this.isSupplierLoading = false;

            return;
        }



        this.searchTimer =
            setTimeout(
                () => {

                    this.loadSuppliers();

                },
                300
            );

    }



    async loadSuppliers() {
    if (!this.recordId) {
        return;
    }

    this.isSupplierLoading = true;

    try {
        const result = await searchSuppliers({
            searchKey: '',
            caseId: this.recordId
        });

        this.suppliers = result || [];

    } catch (error) {
        console.error('L3 Supplier Load Error:', error);

        this.suppliers = [];

        this.showToast(
            'Unable to Load Suppliers',
            error?.body?.message ||
                error?.message ||
                'Unable to load suppliers.',
            'error'
        );

    } finally {
        this.isSupplierLoading = false;
    }
}

get supplierOptions() {
    return this.suppliers.map(supplier => ({
        label: supplier.contactPerson
            ? `${supplier.contactPerson} (${supplier.name})`
            : supplier.name,
        value: supplier.id
    }));
}

handleSupplierChange(event) {
    const supplierId = event.detail.value;

    this.selectedSupplier =
        this.suppliers.find(
            supplier => supplier.id === supplierId
        ) || null;
}

get selectedSupplierId() {
    return this.selectedSupplier?.id || '';
}





    handleSupplierSelect(event) {


        const supplierId =
            event.currentTarget.dataset.id;



        this.selectedSupplier =
            this.suppliers.find(
                supplier =>
                    supplier.id === supplierId
            );



        console.log(
            'Selected Supplier -->',
            JSON.stringify(this.selectedSupplier)
        );



        this.suppliers = [];


        this.searchTerm =
            this.selectedSupplier.name;


    }





    handleChangeSupplier() {


        this.selectedSupplier = null;

        this.searchTerm = '';

    }





    handleRemarksChange(event) {


        this.remarks =
            event.target.value;


    }





    async handleSubmit() {

    if (
        this.isLoading ||
        !this.recordId ||
        !this.selectedSupplier?.id ||
        !this.remarks?.trim()
    ) {
        return;
    }

    this.isLoading = true;

    try {

        // 1. Assign the L3 supplier using Apex.
        await escalateToL3({

            caseId: this.recordId,

            supplierId: this.selectedSupplier.id,

            remarks: this.remarks.trim()

        });

        // 2. Notify Salesforce that the Case was
        //    updated outside Lightning Data Service.
        try {

            await notifyRecordUpdateAvailable([
                {
                    recordId: this.recordId
                }
            ]);

        } catch (refreshError) {

            console.error(
                'Case record refresh failed:',
                refreshError
            );

        }

        // 3. Request a refresh of the current view.
        this.dispatchEvent(
            new RefreshEvent()
        );

        // 4. Show success.
        this.showToast(
            'Success',
            'Case escalated to L3 Supplier successfully.',
            'success'
        );

        // 5. Close the Quick Action modal.
        this.dispatchEvent(
            new CloseActionScreenEvent()
        );

    } catch (error) {

        console.error(
            'L3 Assignment Error:',
            error
        );

        this.showToast(
            'Error',
            error?.body?.message ||
            error?.message ||
            'Unable to assign the L3 Supplier.',
            'error'
        );

    } finally {

        this.isLoading = false;

    }
}





    handleCancel() {


        this.dispatchEvent(
            new CloseActionScreenEvent()
        );


    }





    showToast(title, message, variant) {


        this.dispatchEvent(
            new ShowToastEvent({

                title: title,

                message: message,

                variant: variant

            })
        );

    }


}