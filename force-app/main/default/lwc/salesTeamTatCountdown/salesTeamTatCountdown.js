import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';

import SALES_ASSIGNED from '@salesforce/schema/Opportunity.Sales_Team_Assigned_DateTime__c';
import PREDESIGN_ASSIGNED from '@salesforce/schema/Opportunity.Pre_Design_Assigned_DateTime__c';
import STAGE_FIELD from '@salesforce/schema/Opportunity.KAM_SRT_Opp_Stages__c';

export default class SalesTeamTatCountdown extends LightningElement {

    @api recordId;

    @track hours = '00';
    @track minutes = '00';
    @track seconds = '00';
    @track headerText = '';
    @track showComponent = false;

    interval;
    wiredRecordResult;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [SALES_ASSIGNED, PREDESIGN_ASSIGNED, STAGE_FIELD]
    })
    wiredOpp(result) {

        this.wiredRecordResult = result;

        const { data } = result;

        if (data) {

            const stage = getFieldValue(data, STAGE_FIELD);
            const salesTime = getFieldValue(data, SALES_ASSIGNED);

            clearInterval(this.interval);

            /* Correct stage condition */
            if (stage === 'Assign to Sales Team' ||
                stage === 'Assign to Pre Design Team') {

                this.showComponent = true;
                this.headerText = '⏳ 24 Hour Sales Team TAT Countdown';
                this.startCountdown(salesTime);

            } else {
                this.showComponent = false;
            }
        }
    }

    startCountdown(startTime) {

        if (!startTime) return;

        const start = new Date(startTime);
        const end = new Date(start.getTime() + 60 * 1000); // Change to 24hrs later

        this.interval = setInterval(() => {

            const now = new Date();
            const diff = end - now;

            if (diff <= 0) {
                this.hours = '00';
                this.minutes = '00';
                this.seconds = '00';
                clearInterval(this.interval);
                return;
            }

            const totalSeconds = Math.floor(diff / 1000);
            const hrs = Math.floor(totalSeconds / 3600);
            const mins = Math.floor((totalSeconds % 3600) / 60);
            const secs = totalSeconds % 60;

            this.hours = hrs.toString().padStart(2, '0');
            this.minutes = mins.toString().padStart(2, '0');
            this.seconds = secs.toString().padStart(2, '0');

        }, 1000);
    }

    /* Optional refresh hook if needed later */
    refreshData() {
        if (this.wiredRecordResult) {
            refreshApex(this.wiredRecordResult);
        }
    }

    disconnectedCallback() {
        clearInterval(this.interval);
    }
}