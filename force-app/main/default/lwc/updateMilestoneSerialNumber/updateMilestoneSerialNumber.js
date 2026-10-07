import { LightningElement, api, wire, track } from 'lwc';
import getMilestones from '@salesforce/apex/SerialNumberUpdateController.getMilestones';
import updateMilestones from '@salesforce/apex/SerialNumberUpdateController.updateMilestones';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { refreshApex } from '@salesforce/apex';
import { RefreshEvent } from 'lightning/refresh'; 
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi'; // ADDED: Directly pokes Lightning Data Service

export default class UpdateMilestoneSerialNumber extends LightningElement {
    @api recordId;
    
    @track displayMilestones = [];
    wiredMilestonesResult;
    
    validSerialNumbers = new Set();
    error;

    readOnlyMilestoneNames = ['Draft', 'Project Start with File Handover', 'Allocate Manager'];
    readOnlySerialNumbers = [1, 2, 3];

    @wire(getMilestones, { recordId: '$recordId' })
    wiredMilestones(result) {
        this.wiredMilestonesResult = result;
        if (result.data) {
            this.error = undefined;
            this.validSerialNumbers.clear();
            
            this.displayMilestones = result.data.map(m => {
                this.validSerialNumbers.add(m.Serial_Number__c);
                
                const isReadOnlyRec = (this.readOnlySerialNumbers.includes(m.Serial_Number__c) || 
                                       this.readOnlyMilestoneNames.includes(m.Milestone_Name__c));
                
                return {
                    Id: m.Id,
                    Milestone_Name__c: m.Milestone_Name__c,
                    originalSerial: m.Serial_Number__c,
                    currentSerial: m.Serial_Number__c,
                    isReadOnly: isReadOnlyRec
                };
            });
        } else if (result.error) {
            this.error = 'Failed to load milestones.';
            this.displayMilestones = [];
        }
    }

    handleInputChange(event) {
        const recordId = event.target.dataset.id;
        const newValue = event.target.value;
        
        this.displayMilestones = this.displayMilestones.map(m => {
            if (m.Id === recordId) {
                return { ...m, currentSerial: newValue !== '' ? Number(newValue) : null };
            }
            return m;
        });
    }

    async handleUpdate() {
        let hasChanges = false;
        let finalState = new Map();
        let draftValues = []; 

        for (let i = 0; i < this.displayMilestones.length; i++) {
            const m = this.displayMilestones[i];
            
            if (m.currentSerial === null || m.currentSerial === '') {
                this.showToast('Error', 'Serial numbers cannot be blank.', 'error');
                return;
            }

            const newSn = Number(m.currentSerial);
            finalState.set(m.Id, newSn);

            if (newSn !== m.originalSerial) {
                hasChanges = true;
                draftValues.push({ Id: m.Id, Serial_Number__c: newSn });

                if (newSn === 0) {
                    this.showToast('Error', 'Don\'t update serial number by 0', 'error');
                    return;
                }
                
                if (this.readOnlySerialNumbers.includes(newSn)) {
                    this.showToast('Error', `Cannot update serial number to ${newSn} as it is reserved.`, 'error');
                    return;
                }
                
                if (!this.validSerialNumbers.has(newSn)) {
                    this.showToast('Error', `You can only use existing serial numbers. ${newSn} is not valid.`, 'error');
                    return;
                }
            }
        }

        if (!hasChanges) {
            this.showToast('Info', 'No changes to update.', 'info');
            return;
        }

        let seenNumbers = new Set();
        for (let serialNum of finalState.values()) {
            if (seenNumbers.has(serialNum)) {
                this.showToast('Error', `Duplicate found: Serial Number ${serialNum} already exists.`, 'error');
                return;
            }
            seenNumbers.add(serialNum);
        }

        try {
            // 1. Save to Salesforce
            await updateMilestones({ milestonesToUpdate: draftValues });
            this.showToast('Success', 'Serial Numbers updated!', 'success');
            
            // 2. Refresh the LWC's internal memory
            await refreshApex(this.wiredMilestonesResult);
            
            // 3. Explicitly tell Salesforce to clear the cache for these specific records AND the parent
            const recordsToRefresh = draftValues.map(draft => ({ recordId: draft.Id }));
            recordsToRefresh.push({ recordId: this.recordId }); // Force parent to refresh related list
            await notifyRecordUpdateAvailable(recordsToRefresh);
            
            // 4. Fire the standard UI refresh event
            this.dispatchEvent(new RefreshEvent());
            
            // 5. CRITICAL FIX: Wait 500ms before closing so the event isn't killed
            setTimeout(() => {
                this.dispatchEvent(new CloseActionScreenEvent());
            }, 500);

        } catch (error) {
            this.showToast('Error', 'An error occurred while saving.', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}