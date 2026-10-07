import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';

import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import SUB_STAGE_FIELD from '@salesforce/schema/Opportunity.Key_Account_Opp_Sub_Stages__c';
import RECORDTYPE_FIELD from '@salesforce/schema/Opportunity.RecordTypeId';

export default class KamOppSubStageSimplePath extends LightningElement {
    @api recordId;

    recordTypeId;
    currentValue;

    picklistValues = [];

    // Get current value + record type
    @wire(getRecord, { recordId: '$recordId', fields: [SUB_STAGE_FIELD, RECORDTYPE_FIELD] })
    wiredOpp({ data, error }) {
        if (data) {
            this.currentValue = getFieldValue(data, SUB_STAGE_FIELD);
            this.recordTypeId = getFieldValue(data, RECORDTYPE_FIELD);
        } else if (error) {
            // optional: console log
            // console.error(error);
        }
    }

    // Get picklist values for that record type
    @wire(getPicklistValuesByRecordType, {
        objectApiName: OPPORTUNITY_OBJECT,
        recordTypeId: '$recordTypeId'
    })
    wiredPicklists({ data, error }) {
        if (data) {
            const fieldInfo = data.picklistFieldValues?.Key_Account_Opp_Sub_Stages__c;
            this.picklistValues = fieldInfo?.values || [];
        } else if (error) {
            // console.error(error);
        }
    }

    get currentLabel() {
        if (!this.currentValue) return '—';
        const found = (this.picklistValues || []).find(v => v.value === this.currentValue);
        return found ? found.label : this.currentValue;
    }

    // Build steps like your Lead component
get steps() {
    if (!this.picklistValues || this.picklistValues.length === 0) return [];

    // Define the approval levels in the correct sequence
    const LEVEL_ORDER = ['design team', 'coo', 'commercial head', 'sales head', 'ceo'];

    const normalize = (s) => (s || '').toLowerCase().trim();

    const getStatus = (label) => {
        const t = normalize(label);
        if (t.includes('reject')) return 'rejected';
        if (t.includes('approve')) return 'approved';
        if (t.includes('submit')) return 'submitted'; // handles "Submit" and "Submitted"
        return 'neutral';
    };

    const getLevel = (label) => {
        const t = normalize(label);
        // Find which level it belongs to
        return LEVEL_ORDER.find(lvl => t.includes(lvl)) || null;
    };

    const getLevelIndex = (lvl) => (lvl ? LEVEL_ORDER.indexOf(lvl) : -1);

    const currentPick = this.picklistValues.find(v => v.value === this.currentValue);
    const currentLabel = currentPick ? currentPick.label : this.currentValue;

    const currentLevel = getLevel(currentLabel);
    const currentStatus = getStatus(currentLabel);
    const currentLevelIdx = getLevelIndex(currentLevel);

    return this.picklistValues.map((v) => {
        const stepLabel = v.label;
        const stepLevel = getLevel(stepLabel);
        const stepStatus = getStatus(stepLabel);
        const stepLevelIdx = getLevelIndex(stepLevel);

        let css = 'step future';

        // If we cannot detect levels (fallback)
        if (!currentLevel || !stepLevel) {
            // fallback to your old logic but DO NOT mark rejected as complete
            css = (v.value === this.currentValue) ? 'step active' : 'step future';
            return { label: v.label, value: v.value, css };
        }

        // 1) Future levels (after current level)
        if (stepLevelIdx > currentLevelIdx) {
            css = 'step future';
        }

        // 2) Past levels (before current level)
        else if (stepLevelIdx < currentLevelIdx) {
            // For past levels, show only Submitted + Approved as completed.
            // Rejected should remain grey because rejection did not happen.
            if (stepStatus === 'approved') css = 'step approved';
            else if (stepStatus === 'submitted') css = 'step complete'; // keep your blue for submitted
            else if (stepStatus === 'rejected') css = 'step future';    // keep grey
            else css = 'step complete';
        }

        // 3) Current level (same level)
      else {
    // Same approval level as current (e.g., CEO)
    if (v.value === this.currentValue) {
        // highlight current
        if (stepStatus === 'approved') css = 'step approved';
        else if (stepStatus === 'rejected') css = 'step rejected';
        else css = 'step active';
    } else {
        // Keep "Submitted" BLUE once level has progressed to Approved/Rejected
        if (stepStatus === 'submitted' && (currentStatus === 'approved' || currentStatus === 'rejected')) {
            css = 'step complete';   // your blue
        }
        // If current is Approved, do NOT make Rejected red—keep grey
        else if (stepStatus === 'rejected' && currentStatus === 'approved') {
            css = 'step future';     // grey
        }
        // If current is Rejected, do NOT make Approved green—keep grey
        else if (stepStatus === 'approved' && currentStatus === 'rejected') {
            css = 'step future';     // grey
        }
        else {
            css = 'step future';     // grey
        }
    }
}

        return {
            label: v.label,
            value: v.value,
            css
        };
    });
}
}