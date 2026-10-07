import {
    LightningElement,
    api,
    wire
} from 'lwc';

import {
    getRecord,
    updateRecord,
    getFieldValue
} from 'lightning/uiRecordApi';

import {
    getPicklistValues,
    getObjectInfo
} from 'lightning/uiObjectInfoApi';

import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';

import {
    RefreshEvent
} from 'lightning/refresh';

import CASE_OBJECT from
    '@salesforce/schema/Case';

import CASE_ID from
    '@salesforce/schema/Case.Id';

import SRT_CASE_STATUS from
    '@salesforce/schema/Case.SRT_Case_Status__c';

import CLOSURE_REASON from
    '@salesforce/schema/Case.Closure_Reason__c';

import FAILURE_CATEGORY from
    '@salesforce/schema/Case.Failure_Category__c';

import UNPRODUCTIVE_REMARK from
    '@salesforce/schema/Case.Unproductive_Remark__c';

import CLOSURE_REMARK from
    '@salesforce/schema/Case.Closure_Remark__c';

import UNPRODUCTIVE_REASON from
    '@salesforce/schema/Case.Unproductive_Reason__c';


const CASE_FIELDS = [
    SRT_CASE_STATUS,
    CLOSURE_REASON,
    FAILURE_CATEGORY,
    UNPRODUCTIVE_REMARK,
    UNPRODUCTIVE_REASON,
    CLOSURE_REMARK
];


export default class SrtCaseStatusPath
    extends LightningElement {

    @api recordId;

    currentStatus = null;

    recordTypeId = null;

    statusValues = [];

    isUpdating = false;

    closureReason = null;

    failureCategory = null;

    unproductiveRemark = null;

    unproductiveReason = null;

    closureRemark = null;


    /* =========================================================
       CASE OBJECT INFORMATION
       ========================================================= */

    @wire(
        getObjectInfo,
        {
            objectApiName: CASE_OBJECT
        }
    )
    wiredCaseObjectInfo({
        data,
        error
    }) {

        if (data) {

            /*
             * Fallback for Master/default Record Type.
             *
             * If getRecord has already provided an actual
             * Record Type Id, don't overwrite it.
             */
            if (!this.recordTypeId) {

                this.recordTypeId =
                    data.defaultRecordTypeId;
            }

        } else if (error) {

            // eslint-disable-next-line no-console
            console.error(
                'Unable to load Case object information:',
                error
            );
        }
    }


    /* =========================================================
       LOAD CASE
       ========================================================= */

    @wire(
        getRecord,
        {
            recordId: '$recordId',
            fields: CASE_FIELDS
        }
    )
    wiredCase({
        data,
        error
    }) {

        if (data) {

            this.currentStatus =
                getFieldValue(
                    data,
                    SRT_CASE_STATUS
                );

            this.closureReason = getFieldValue(
                data,
                CLOSURE_REASON
            );

            this.failureCategory = getFieldValue(
                data,
                FAILURE_CATEGORY
            );

            this.unproductiveRemark = getFieldValue(
                data,
                UNPRODUCTIVE_REMARK
            );

            this.unproductiveReason = getFieldValue(
                data,
                UNPRODUCTIVE_REASON
            );

            this.closureRemark = getFieldValue(
                data,
                CLOSURE_REMARK
            );


            /*
             * getRecord already provides recordTypeId.
             *
             * No @salesforce/schema/Case.RecordTypeId
             * import is required.
             */
            if (data.recordTypeId) {

                this.recordTypeId =
                    data.recordTypeId;
            }

        } else if (error) {

            // eslint-disable-next-line no-console
            console.error(
                'Unable to load Case:',
                error
            );
        }
    }


    /* =========================================================
       LOAD SRT CASE STATUS VALUES DYNAMICALLY
       ========================================================= */

    @wire(
        getPicklistValues,
        {
            recordTypeId: '$recordTypeId',
            fieldApiName: SRT_CASE_STATUS
        }
    )
    wiredStatusValues({
        data,
        error
    }) {

        if (data) {

            /*
             * No hardcoded Status values.
             *
             * Salesforce supplies all active values available
             * for this Case Record Type.
             */
            this.statusValues =
                data.values || [];

        } else if (error) {

            // eslint-disable-next-line no-console
            console.error(
                'Unable to load SRT Case Status values:',
                error
            );
        }
    }


    /* =========================================================
       PATH STEPS
       ========================================================= */

    get pathSteps() {

        const currentIndex =
            this.statusValues.findIndex(
                (statusValue) =>
                    statusValue.value ===
                    this.currentStatus
            );


        return this.statusValues.map(
            (
                statusValue,
                index
            ) => {

                let stateClass =
                    'step-upcoming';


                if (
                    index === currentIndex
                ) {

                    stateClass =
                        'step-current';
                }


                return {

                    label:
                        statusValue.label,

                    value:
                        statusValue.value,

                    displayIndex:
                        index + 1,

                    containerClass:
                        `step-container ${stateClass}`,

                    buttonClass:
                        `step-button ${stateClass}`
                };
            }
        );
    }

    get currentStatusLabel() {

        const status = this.statusValues.find(
            item => item.value === this.currentStatus
        );

        return status ? status.label : '';
    }


    /* =========================================================
       STATUS CLICK
       ========================================================= */

    async handleStatusClick(event) {

        if (this.isUpdating) {
            return;
        }


        const selectedStatus =
            event.currentTarget
                .dataset
                .value;


        if (
            !selectedStatus ||
            selectedStatus ===
            this.currentStatus
        ) {
            return;
        }

        const currentIndex = this.statusValues.findIndex(
            item => item.value === this.currentStatus
        );

        const selectedIndex = this.statusValues.findIndex(
            item => item.value === selectedStatus
        );

        if (currentIndex === -1 || selectedIndex === -1) {
            this.showToast(
                'Validation Error',
                'Unable to determine the status sequence. Please refresh the page.',
                'error'
            );
            return;
        }

        if (selectedIndex < currentIndex) {
            this.showToast(
                'Validation Error',
                'Backward status updates are not allowed.',
                'error'
            );
            return;
        }

        const restrictedStatuses = {
            'L1 Assigned': 'Please click on the L1 Assignment button for this update.',
            'L2 Assigned': 'Please click on the Assign to Dealer (L2) button for this update.',
            'L3 Assigned': 'Please click on the Assign to Supplier (L3) button for this update.',
            'Happy Code Pending': 'Please click on the Generate OTP button.',
            'Resolved': 'Please click on the Validate OTP button.',
            'Feedback Completed': 'Please click on the Feedback Form button.'
        };

        if (restrictedStatuses[selectedStatus]) {
            this.showToast(
                'Status Update Restricted',
                restrictedStatuses[selectedStatus],
                'error'
            );
            return;
        }

        console.log('Selected Status:', selectedStatus);
        console.log('Unproductive Remark:', this.unproductiveRemark);

        if (selectedStatus === 'Rejected') {

            const missingFields = [];

            if (!String(this.unproductiveRemark || '').trim()) {
                missingFields.push('Unproductive Remark');
            }

            if (!String(this.unproductiveReason || '').trim()) {
                missingFields.push('Unproductive Reason');
            }

            if (missingFields.length > 0) {

                this.showToast(
                    'Unproductive Validation',
                    'Please update ' + missingFields.join(' and ') +
                    ' before changing the status to Unproductive.',
                    'error'
                );

                return;
            }
        }

        /* =========================================================
   VALIDATE CLOSURE REASON AND FAILURE CATEGORY
   ========================================================= */

        if (selectedStatus === 'Closed') {

            const missingFields = [];

            if (!String(this.closureRemark || '').trim()) {
                missingFields.push('Closure Remark');
            }

            if (
                !this.closureReason ||
                !String(this.closureReason).trim()
            ) {
                missingFields.push('Closure Reason');
            }

            if (
                !this.failureCategory ||
                !String(this.failureCategory).trim()
            ) {
                missingFields.push('Failure Category');
            }

            if (missingFields.length > 0) {

                const validationMessage =
                    'Please fill in ' +
                    missingFields.join(' and ') +
                    ' before closing the Case.';

                this.showToast(
                    'Case Closure Validation',
                    validationMessage,
                    'error'
                );

                return;
            }
        }

        this.isUpdating = true;


        try {

            const fields = {};


            fields[
                CASE_ID.fieldApiName
            ] =
                this.recordId;


            /*
             * Update only custom SRT Case Status.
             */
            fields[
                SRT_CASE_STATUS.fieldApiName
            ] =
                selectedStatus;


            await updateRecord({
                fields
            });


            this.currentStatus =
                selectedStatus;


            this.showToast(
                'Status Updated',
                `Case Status updated to ${selectedStatus}.`,
                'success'
            );


            this.dispatchEvent(
                new RefreshEvent()
            );


        } catch (error) {

            // eslint-disable-next-line no-console
            console.error(
                'SRT Case Status update error:',
                error
            );


            this.showToast(
                'Unable to Update SRT Status',
                this.getErrorMessage(
                    error
                ),
                'error'
            );


        } finally {

            this.isUpdating = false;
        }
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
       ERROR HANDLING
       ========================================================= */

    /* =========================================================
   ERROR HANDLING - SHOW ACTUAL SALESFORCE ERRORS
   ========================================================= */

    getErrorMessage(error) {

        const messages = [];

        const addMessage = (message) => {

            if (
                message &&
                !messages.includes(message)
            ) {
                messages.push(message);
            }
        };

        const body = error?.body;

        /* Salesforce validation / DML errors */

        if (Array.isArray(body?.output?.errors)) {

            body.output.errors.forEach((item) => {
                addMessage(item.message);
            });
        }

        /* Field-level validation errors */

        const fieldErrors =
            body?.output?.fieldErrors;

        if (fieldErrors) {

            Object.keys(fieldErrors).forEach(
                (fieldName) => {

                    (fieldErrors[fieldName] || [])
                        .forEach((item) => {
                            addMessage(item.message);
                        });
                }
            );
        }

        /* Other page-level errors */

        if (Array.isArray(body?.pageErrors)) {

            body.pageErrors.forEach((item) => {
                addMessage(item.message);
            });
        }

        /* Array response errors */

        if (Array.isArray(body)) {

            body.forEach((item) => {
                addMessage(item.message);
            });
        }

        /* Return detailed errors first */

        if (messages.length > 0) {

            return messages.join('\n');
        }

        /* Fallback */

        if (body?.message) {
            return body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred while updating the Case.';
    }
}