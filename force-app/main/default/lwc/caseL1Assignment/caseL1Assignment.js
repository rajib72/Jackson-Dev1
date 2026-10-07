import {
    LightningElement,
    api
} from 'lwc';

import {
    CloseActionScreenEvent
} from 'lightning/actions';

import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';

import getAssignmentContext
    from '@salesforce/apex/CaseL1AssignmentController.getAssignmentContext';

import assignL1
    from '@salesforce/apex/CaseL1AssignmentController.assignL1';


export default class CaseL1Assignment
    extends LightningElement {

    _recordId;
    loadedRecordId;

    isLoading = false;

    caseDetails = {};

    assets = [];

    userOptions = [];

    selectedUserId = null;


    /* =========================================================
       RECORD ID
       ========================================================= */

    @api
    set recordId(value) {

        this._recordId =
            value;

        if (
            value &&
            value !== this.loadedRecordId
        ) {

            this.loadedRecordId =
                value;

            this.loadAssignmentContext();
        }
    }

    get recordId() {
        return this._recordId;
    }


    /* =========================================================
       GETTERS
       ========================================================= */

    get hasAssets() {
        return (
            this.assets &&
            this.assets.length > 0
        );
    }

    get isAssignmentDisabled() {

        return (
            this.isLoading ||
            !this.selectedUserId
        );
    }


    /* =========================================================
       LOAD DATA
       ========================================================= */

    async loadAssignmentContext() {

        if (!this.recordId) {
            return;
        }

        this.isLoading =
            true;

        try {

            const responseJson =
                await getAssignmentContext({
                    caseId:
                        this.recordId
                });

            const response =
                JSON.parse(
                    responseJson
                );

            this.caseDetails = {
                caseNumber:
                    response.caseNumber,

                srtCaseNumber:
                    response.srtCaseNumber,

                subject:
                    response.subject,

                status:
                    response.status,

                priority:
                    response.priority,

                accountName:
                    response.accountName,

                contactName:
                    response.contactName,

                ownerName:
                    response.ownerName
            };

            this.assets =
                response.assets || [];

            this.userOptions =
                (response.users || [])
                    .map(user => {

                        let secondaryInfo = '';

                        if (
                            user.profileName &&
                            user.email
                        ) {
                            secondaryInfo =
                                ` — ${user.profileName} — ${user.email}`;

                        } else if (
                            user.profileName
                        ) {
                            secondaryInfo =
                                ` — ${user.profileName}`;

                        } else if (
                            user.email
                        ) {
                            secondaryInfo =
                                ` — ${user.email}`;
                        }

                        return {
                            label:
                                `${user.name}${secondaryInfo}`,

                            value:
                                user.userId
                        };
                    });

        } catch (error) {

            console.error(
                'L1 context error:',
                error
            );

            this.showToast(
                'Unable to Load Assignment',
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
       USER CHANGE
       ========================================================= */

    handleUserChange(event) {

        this.selectedUserId =
            event.detail.value;
    }


    /* =========================================================
       ASSIGN
       ========================================================= */

    async handleAssignment() {

        if (!this.selectedUserId) {

            this.showToast(
                'User Required',
                'Please select a User for L1 Assignment.',
                'warning'
            );

            return;
        }

        this.isLoading =
            true;

        try {

            const responseJson =
                await assignL1({
                    caseId:
                        this.recordId,

                    userId:
                        this.selectedUserId
                });

            const response =
                JSON.parse(
                    responseJson
                );

            this.showToast(
                'L1 Assignment Successful',
                response.message,
                'success'
            );

            /*
             * Close modal first.
             */
            this.dispatchEvent(
                new CloseActionScreenEvent()
            );

            /*
             * Small delay before refreshing
             * Case record page.
             */
            await this.delay(
                300
            );

            /*
             * Clean Case URL prevents the
             * Quick Action from reopening.
             */
            window.location.replace(
                `/lightning/r/Case/${this.recordId}/view`
            );

        } catch (error) {

            console.error(
                'L1 Assignment error:',
                error
            );

            this.showToast(
                'Unable to Complete L1 Assignment',
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

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }


    /* =========================================================
       DELAY
       ========================================================= */

    delay(milliseconds) {

        return new Promise(resolve => {

            setTimeout(
                resolve,
                milliseconds
            );
        });
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
            error?.body?.message
        ) {
            return error.body.message;
        }

        if (
            Array.isArray(
                error?.body
            )
        ) {

            return error.body
                .map(
                    item =>
                        item.message
                )
                .join(', ');
        }

        if (
            error?.message
        ) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }
}