import {
    LightningElement,
    api
} from 'lwc';

import {
    notifyRecordUpdateAvailable
} from 'lightning/uiRecordApi';

import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';

import {
    CloseActionScreenEvent
} from 'lightning/actions';

import {
    RefreshEvent
} from 'lightning/refresh';


import searchDealers from
    '@salesforce/apex/CaseL2AssignmentController.searchDealers';

import escalateToL2 from
    '@salesforce/apex/CaseL2AssignmentController.escalateToL2';


const SEARCH_DELAY = 300;
const MIN_SEARCH_LENGTH = 2;


export default class CaseEscalateToL2
    extends LightningElement {


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
        this.selectedDealer = null;
        this.selectedDealerId = null;
        this.dealers = [];
        this.loadDealers();
    }
}


    searchTerm = '';

    dealers = [];

    selectedDealer = null;

    selectedDealerId = null;

    escalationRemarks = '';


    isDealerLoading = false;

    isLoading = false;


    searchTimer = null;

    latestSearchRequest = 0;


    /* =========================================================
       DEALER SEARCH
       ========================================================= */

    handleDealerSearch(event) {

        this.searchTerm =
            event.target.value || '';


        if (this.searchTimer) {

            clearTimeout(
                this.searchTimer
            );
        }


        if (
            this.searchTerm.trim().length <
            MIN_SEARCH_LENGTH
        ) {

            this.dealers = [];

            this.isDealerLoading = false;

            return;
        }


        this.searchTimer =
            setTimeout(
                () => {

                    this.loadDealers();

                },
                SEARCH_DELAY
            );
    }


    /* =========================================================
       LOAD DEALERS
       ========================================================= */

    async loadDealers() {
    if (!this.recordId) {
        return;
    }

    const requestNumber = ++this.latestSearchRequest;
    this.isDealerLoading = true;

    try {
        const results = await searchDealers({
            searchTerm: '',
            caseId: this.recordId
        });

        if (requestNumber !== this.latestSearchRequest) {
            return;
        }

        this.dealers = results || [];

    } catch (error) {
        if (requestNumber !== this.latestSearchRequest) {
            return;
        }

        this.dealers = [];

        this.showToast(
            'Unable to Load Dealers',
            this.getErrorMessage(error),
            'error'
        );

    } finally {
        if (requestNumber === this.latestSearchRequest) {
            this.isDealerLoading = false;
        }
    }
}

get dealerOptions() {
    return this.dealers.map(dealer => ({
        label: dealer.contactPerson
            ? `${dealer.contactPerson} (${dealer.name})`
            : dealer.name,
        value: dealer.id
    }));
}

handleDealerChange(event) {
    this.selectedDealerId = event.detail.value;

    this.selectedDealer =
        this.dealers.find(
            dealer => dealer.id === this.selectedDealerId
        ) || null;
}


    /* =========================================================
       SELECT DEALER
       ========================================================= */

    handleDealerSelect(event) {

        const dealerId =
            event.currentTarget
                .dataset
                .id;


        if (!dealerId) {
            return;
        }


        const dealer =
            this.dealers.find(
                (item) =>
                    item.id === dealerId
            );


        if (!dealer) {
            return;
        }


        this.selectedDealerId =
            dealer.id;


        this.selectedDealer = {
            ...dealer
        };


        /*
         * Hide results after selection.
         */
        this.dealers = [];


        this.searchTerm =
            dealer.name;
    }


    /* =========================================================
       CHANGE DEALER
       ========================================================= */

    handleChangeDealer() {
    this.selectedDealerId = null;
    this.selectedDealer = null;
}


    /* =========================================================
       REMARKS
       ========================================================= */

    handleRemarksChange(event) {

        this.escalationRemarks =
            event.target.value || '';
    }


    /* =========================================================
       SUBMIT
       ========================================================= */

    async handleSubmit() {

        if (this.isLoading) {
            return;
        }


        if (!this.selectedDealerId) {

            this.showToast(
                'Dealer Required',
                'Please select a Dealer.',
                'warning'
            );

            return;
        }


        const remarks =
            this.escalationRemarks
                ? this.escalationRemarks.trim()
                : '';


        if (!remarks) {

            const remarksInput =
                this.template.querySelector(
                    '[data-remarks]'
                );


            if (remarksInput) {

                remarksInput.reportValidity();
            }


            this.showToast(
                'Escalation Details Required',
                'Please enter Escalation Details.',
                'warning'
            );

            return;
        }


        this.isLoading =
            true;


        try {

            /* =================================================
               UPDATE CASE THROUGH APEX
               ================================================= */

            const result =
                await escalateToL2({

                    caseId:
                        this.recordId,

                    dealerId:
                        this.selectedDealerId,

                    escalationRemarks:
                        remarks
                });


            if (!result?.success) {

                throw new Error(
                    'Unable to complete the escalation.'
                );
            }


            /* =================================================
               IMPORTANT:
               NOTIFY LIGHTNING DATA SERVICE
               ================================================= */

            await notifyRecordUpdateAvailable([
                {
                    recordId:
                        this.recordId
                }
            ]);


            /* =================================================
               REFRESH LIGHTNING PAGE COMPONENTS
               ================================================= */

            this.dispatchEvent(
                new RefreshEvent()
            );


            /* =================================================
               SUCCESS MESSAGE
               ================================================= */

            this.showToast(
                'Escalation Submitted',
                `Case successfully escalated to ${this.selectedDealer.name}.`,
                'success'
            );


            /*
             * Give Lightning a small amount of time
             * to process the refresh before closing
             * the Quick Action.
             */
            await new Promise(
                (resolve) => {

                    setTimeout(
                        resolve,
                        300
                    );
                }
            );


            /* =================================================
               CLOSE QUICK ACTION
               ================================================= */

            this.dispatchEvent(
                new CloseActionScreenEvent()
            );


        } catch (error) {

            // eslint-disable-next-line no-console
            console.error(
                'L2 Escalation Error:',
                error
            );


            this.showToast(
                'Unable to Submit Escalation',
                this.getErrorMessage(
                    error
                ),
                'error'
            );


        } finally {

            this.isLoading =
                false;
        }
    }


    /* =========================================================
       CANCEL
       ========================================================= */

    handleCancel() {

        if (this.isLoading) {
            return;
        }


        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }


    /* =========================================================
       GETTERS
       ========================================================= */

    get showSearchResults() {

        return (
            !this.selectedDealer &&
            !this.isDealerLoading &&
            this.dealers.length > 0
        );
    }


    get showNoResults() {
    return (
        !!this.recordId &&
        !this.isDealerLoading &&
        !this.selectedDealer &&
        this.dealers.length === 0
    );
}


    get isSubmitDisabled() {

        return (
            this.isLoading ||
            !this.selectedDealerId ||
            !this.escalationRemarks ||
            !this.escalationRemarks.trim()
        );
    }


    /* =========================================================
       TOAST
       ========================================================= */

    showToast(
        title,
        message,
        variant
    ) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }


    /* =========================================================
       ERROR
       ========================================================= */

    getErrorMessage(error) {

        if (
            Array.isArray(
                error?.body
            )
        ) {

            return error.body
                .map(
                    (item) =>
                        item.message
                )
                .filter(Boolean)
                .join(', ');
        }


        if (
            error?.body?.message
        ) {

            return error.body.message;
        }


        if (
            error?.message
        ) {

            return error.message;
        }


        return 'An unexpected error occurred.';
    }
}