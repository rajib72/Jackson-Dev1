import { LightningElement, api, wire } from 'lwc';
import getMilestones from '@salesforce/apex/ProjectMilestonePathController.getMilestones';
import getCurrentMilestone from '@salesforce/apex/ProjectMilestonePathController.getCurrentMilestone';
import { refreshApex } from '@salesforce/apex';

export default class ProjectPathDynamic extends LightningElement {

    @api recordId;

    milestones = [];
    currentMilestoneName;

    wiredMilestones;
    wiredCurrentMilestone;

    intervalId;

    // Get milestones
    @wire(getMilestones, { recordId: '$recordId' })
    milestoneHandler(result) {

        this.wiredMilestones = result;

        if (result.data) {
            this.milestones = result.data;
        }

        if (result.error) {
            console.error(result.error);
        }
    }

    // Get current milestone
    @wire(getCurrentMilestone, { recordId: '$recordId' })
    currentMilestoneHandler(result) {

        this.wiredCurrentMilestone = result;

        if (result.data) {
            this.currentMilestoneName = result.data.Milestone_Name__c;
        }

        if (result.error) {
            console.error(result.error);
        }
    }

    // Auto refresh every 4 seconds
    connectedCallback() {

        this.intervalId = setInterval(() => {
            this.refreshData();
        }, 4000);
    }

    disconnectedCallback() {
        clearInterval(this.intervalId);
    }

    refreshData() {

        refreshApex(this.wiredMilestones);
        refreshApex(this.wiredCurrentMilestone);
    }

    // Path processing logic
    get processedMilestones() {

        if (!this.milestones || this.milestones.length === 0) {
            return [];
        }

        let passedCurrent = false;

        return this.milestones.map(milestone => {

            let cssClass = "slds-path__item ";

            if (milestone.Milestone_Name__c === this.currentMilestoneName) {

                cssClass += "slds-is-current slds-is-active";
                passedCurrent = true;

            } else if (!passedCurrent) {

                cssClass += "slds-is-complete";

            } else {

                cssClass += "slds-is-incomplete";
            }

            return {
                ...milestone,
                cssClass
            };
        });
    }
}