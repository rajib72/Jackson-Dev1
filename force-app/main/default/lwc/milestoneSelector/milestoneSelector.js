import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh'; 
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi'; // 1. Added LDS import

import getMilestoneData from '@salesforce/apex/MilestoneSelectorController.getMilestoneData';
import saveNewMilestones from '@salesforce/apex/MilestoneSelectorController.saveNewMilestones';

export default class MilestoneSelector extends LightningElement {
    _recordId;
    @track milestonesList = [];
    isLoading = true;

    @api set recordId(value) {
        this._recordId = value;
        if (this._recordId) {
            this.fetchData();
        }
    }
    
    get recordId() {
        return this._recordId;
    }

    fetchData() {
        this.isLoading = true;
        getMilestoneData({ projectId: this.recordId })
            .then(result => {
                this.processMilestoneData(result);
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load milestones', 'error');
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    processMilestoneData(data) {
        const existingIds = new Set();
        const existingNames = new Set();

        if (data.existingProjectMilestones) {
            data.existingProjectMilestones.forEach(pm => {
                if (pm.Milestone_Master__c) {
                    existingIds.add(pm.Milestone_Master__c);
                }
                if (pm.Milestone_Name__c) {
                    existingNames.add(pm.Milestone_Name__c.toLowerCase());
                }
            });
        }

        // We added '(m, index)' here to grab the row number
        this.milestonesList = data.allMilestones.map((m, index) => {
            const isAlreadyAdded = existingIds.has(m.Id) || existingNames.has(m.Milestone_Name__c.toLowerCase());
            return {
                displayIndex: index + 1, // Creates 1, 2, 3...
                label: m.Milestone_Name__c,
                value: m.Id,
                isChecked: isAlreadyAdded,
                isExisting: isAlreadyAdded
            };
        });
    }

    handleCheckboxChange(event) {
        const milestoneId = event.target.dataset.id;
        const isChecked = event.target.checked;

        this.milestonesList = this.milestonesList.map(ms => {
            if (ms.value === milestoneId) {
                return { ...ms, isChecked: isChecked };
            }
            return ms;
        });
    }

    handleAddMilestone() {
        this.isLoading = true;

        const newlySelectedIds = this.milestonesList
            .filter(ms => ms.isChecked && !ms.isExisting)
            .map(ms => ms.value);

        if (newlySelectedIds.length === 0) {
            this.showToast('Info', 'No new milestones were selected.', 'info');
            this.isLoading = false;
            this.closeModal();
            return;
        }

        saveNewMilestones({ projectId: this.recordId, selectedMilestoneIds: newlySelectedIds })
            .then(() => {
                this.showToast('Success', 'Milestones added successfully.', 'success');
                
                // 2. Force the parent record to refresh its data (which updates the related list)
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                
                // 3. Dispatch the UI refresh event
                this.dispatchEvent(new RefreshEvent());
                
                // 4. CRITICAL FIX: Delay closing the modal so the refresh events aren't destroyed
                setTimeout(() => {
                    this.closeModal(); 
                }, 500);
            })
            .catch(error => {
                this.showToast('Error', 'Failed to save milestones.', 'error');
                console.error('Save error:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}