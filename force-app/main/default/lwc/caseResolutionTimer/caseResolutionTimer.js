import {
    LightningElement,
    api,
    wire
} from 'lwc';

import { refreshApex } from '@salesforce/apex';

import {
    registerRefreshHandler,
    unregisterRefreshHandler
} from 'lightning/refresh';

import getTimerDetails
    from '@salesforce/apex/CaseResolutionTimerController.getTimerDetails';

const CLOSED_STATUS = 'Closed';

const SECOND = 1000;
const MINUTE = 60 * SECOND;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

export default class CaseResolutionTimer extends LightningElement {

    @api recordId;

    wiredTimerResult;
    refreshHandlerId;
    timerInterval;

    isLoading = true;
    hasError = false;

    errorMessage = '';

    caseNumber;
    subject;
    status;

    createdDate;
    closedDate;

    elapsedDays = '00';
    elapsedHours = '00';
    elapsedMinutes = '00';
    elapsedSeconds = '00';


    /* =========================================================
       RECORD DATA
       ========================================================= */

    @wire(
        getTimerDetails,
        {
            caseId: '$recordId'
        }
    )
    wiredTimer(result) {

        this.wiredTimerResult = result;

        const {
            data,
            error
        } = result;

        if (data) {

            this.caseNumber =
                data.CaseNumber;

            this.subject =
                data.Subject;

            /*
             * Use SRT Case Status instead of
             * standard Case.Status.
             */
            this.status =
                data.SRT_Case_Status__c;

            this.createdDate =
                data.CreatedDate;

            this.closedDate =
                data.ClosedDate;

            this.hasError = false;
            this.errorMessage = '';
            this.isLoading = false;

            this.configureTimer();

        } else if (error) {

            this.stopTimer();

            this.hasError = true;
            this.isLoading = false;

            this.errorMessage =
                this.getErrorMessage(
                    error
                );
        }
    }


    /* =========================================================
       COMPONENT LIFECYCLE
       ========================================================= */

    connectedCallback() {

        this.refreshHandlerId =
            registerRefreshHandler(
                this,
                this.handleRefresh.bind(this)
            );
    }

    disconnectedCallback() {

        this.stopTimer();

        if (
            this.refreshHandlerId !== undefined &&
            this.refreshHandlerId !== null
        ) {
            unregisterRefreshHandler(
                this.refreshHandlerId
            );
        }
    }


    /* =========================================================
       REFRESH HANDLER
       ========================================================= */

    async handleRefresh() {

        try {

            await refreshApex(
                this.wiredTimerResult
            );

            return true;

        } catch (error) {

            console.error(
                'Timer refresh error:',
                error
            );

            return false;
        }
    }


    /* =========================================================
       SRT CLOSED STATUS
       ========================================================= */

    get isClosed() {

        return (
            this.status === CLOSED_STATUS
        );
    }


    /* =========================================================
       TIMER CONFIGURATION
       ========================================================= */

    configureTimer() {

        this.stopTimer();

        this.calculateElapsedTime();

        /*
         * Timer stops when SRT Case Status = Closed.
         */
        if (this.isClosed) {
            return;
        }

        /*
         * No Apex call happens every second.
         * Only browser-side duration calculation.
         */
        this.timerInterval =
            window.setInterval(
                () => {
                    this.calculateElapsedTime();
                },
                1000
            );
    }


    /* =========================================================
       CALCULATE ELAPSED TIME
       ========================================================= */

    calculateElapsedTime() {

        if (!this.createdDate) {
            return;
        }

        const startTime =
            new Date(
                this.createdDate
            ).getTime();

        let endTime;

        /*
         * At present ClosedDate is still the
         * standard Case ClosedDate.
         */
        if (
            this.isClosed &&
            this.closedDate
        ) {

            endTime =
                new Date(
                    this.closedDate
                ).getTime();

        } else {

            endTime =
                Date.now();
        }

        let difference =
            Math.max(
                0,
                endTime - startTime
            );

        const days =
            Math.floor(
                difference / DAY
            );

        difference =
            difference % DAY;

        const hours =
            Math.floor(
                difference / HOUR
            );

        difference =
            difference % HOUR;

        const minutes =
            Math.floor(
                difference / MINUTE
            );

        difference =
            difference % MINUTE;

        const seconds =
            Math.floor(
                difference / SECOND
            );

        this.elapsedDays =
            this.padNumber(
                days
            );

        this.elapsedHours =
            this.padNumber(
                hours
            );

        this.elapsedMinutes =
            this.padNumber(
                minutes
            );

        this.elapsedSeconds =
            this.padNumber(
                seconds
            );
    }


    /* =========================================================
       STOP TIMER
       ========================================================= */

    stopTimer() {

        if (this.timerInterval) {

            window.clearInterval(
                this.timerInterval
            );

            this.timerInterval =
                null;
        }
    }


    /* =========================================================
       DISPLAY CLASSES
       ========================================================= */

    get timerClass() {

        return this.isClosed
            ? 'timer-shell timer-closed'
            : 'timer-shell timer-active';
    }

    get statusClass() {

        return this.isClosed
            ? 'status-badge status-closed'
            : 'status-badge status-running';
    }

    get messageClass() {

        return this.isClosed
            ? 'timer-message closed-message'
            : 'timer-message running-message';
    }

    get messageIcon() {

        return this.isClosed
            ? 'utility:success'
            : 'utility:clock';
    }

    get timerMessage() {

        if (this.isClosed) {
            return 'SRT Case closed. Resolution timer has stopped.';
        }

        return 'Timer is running until the SRT Case Status becomes Closed.';
    }


    /* =========================================================
       UTILITIES
       ========================================================= */

    padNumber(value) {

        const stringValue =
            String(value);

        return stringValue.length < 2
            ? `0${stringValue}`
            : stringValue;
    }

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

        if (error?.message) {
            return error.message;
        }

        return 'Unable to load Case timer.';
    }
}