import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';

import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import SUB_STAGE_FIELD from '@salesforce/schema/Opportunity.Institutional_Opp_Sub_Stages__c';
import RECORDTYPE_FIELD from '@salesforce/schema/Opportunity.RecordTypeId';

export default class InstCustomOppSubStagePath extends LightningElement {


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
            
        }
    }

    // Get picklist values for that record type
    @wire(getPicklistValuesByRecordType, {
        objectApiName: OPPORTUNITY_OBJECT,
        recordTypeId: '$recordTypeId'
    })
    wiredPicklists({ data, error }) {
        if (data) {
            const fieldInfo = data.picklistFieldValues?.Institutional_Opp_Sub_Stages__c;
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

        const currentIdx = this.picklistValues.findIndex(v => v.value === this.currentValue);

        return this.picklistValues.map((v, idx) => {
            let css = 'step';

            if (this.currentValue && idx < currentIdx) {
                css = 'step complete';
            } else if (v.value === this.currentValue) {
                css = 'step active';
            } else {
                css = 'step future';
            }

            return {
                label: v.label,
                value: v.value,
                css
            };
        });
    }
}