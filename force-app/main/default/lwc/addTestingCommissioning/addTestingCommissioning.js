import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInitialData from '@salesforce/apex/TestingCommissioningController.getInitialData';
import saveCompletedMaterials from '@salesforce/apex/TestingCommissioningController.saveCompletedMaterials';

export default class AddTestingCommissioning extends LightningElement {
    @api recordId; // This must automatically get the Project ID
    
    @track rows = [];
    allMaterials = []; 
    milestoneId;
    isLoading = true;

    connectedCallback() {
        // Log the recordId to ensure the component knows which Project it is on
        console.log('--- Current Project ID ---', this.recordId);
        
        // Use a slight delay to ensure recordId is fully populated by the Lightning page
        setTimeout(() => {
            this.fetchData();
        }, 100);
    }

    fetchData() {
        if (!this.recordId) {
            this.showToast('Error', 'Project ID is missing. Are you running this from a Project record page?', 'error');
            this.isLoading = false;
            return;
        }

        getInitialData({ projectId: this.recordId })
            .then(result => {
                console.log('--- Apex Result ---', JSON.stringify(result)); // See exactly what Apex returned

                if (result.milestoneId) {
                    this.milestoneId = result.milestoneId;
                } else {
                    this.showToast('Warning', 'No "Testing & Commissioning" milestone found for this project.', 'warning');
                }

                if (result.pendingMaterials && result.pendingMaterials.length > 0) {
                    this.allMaterials = result.pendingMaterials.map(mat => {
                        return { label: mat.Material_Name__c || mat.Name, value: mat.Id };
                    });
                    this.addRow(); // Add the first row only if we have materials
                } else {
                    // ALERT: If this toast pops up, your database has no pending materials for this project!
                    this.showToast('Notice', 'There are no pending materials for this project that require testing.', 'info');
                }
                
                this.isLoading = false;
            })
            .catch(error => {
                console.error('--- Apex Error ---', error);
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
                this.isLoading = false;
            });
    }

    // --- Row Management ---
    addRow() {
        const newRow = {
            id: Date.now().toString(),
            materialId: null,
            isCheckboxChecked: false,
            isFileUploaded: false,
            availableOptions: [] 
        };
        this.rows.push(newRow);
        this.updateDropdownOptions();
    }

    removeRow(event) {
        if (this.rows.length === 1) {
            this.showToast('Error', 'At least one row is required.', 'error');
            return;
        }
        const index = event.currentTarget.dataset.index;
        this.rows.splice(index, 1);
        this.updateDropdownOptions();
    }

    // --- Dynamic Dropdown Logic ---
    updateDropdownOptions() {
        const selectedMaterialIds = this.rows
            .map(row => row.materialId)
            .filter(id => id !== null);

        this.rows.forEach(row => {
            row.availableOptions = this.allMaterials.filter(mat => {
                return !selectedMaterialIds.includes(mat.value) || mat.value === row.materialId;
            });
        });
    }

    // --- Event Handlers ---
    handleMaterialChange(event) {
        const index = event.currentTarget.dataset.index;
        this.rows[index].materialId = event.detail.value;
        this.updateDropdownOptions();
    }

    handleCheckboxChange(event) {
        const index = event.currentTarget.dataset.index;
        this.rows[index].isCheckboxChecked = event.target.checked;
    }

    handleUploadFinished(event) {
        const index = event.currentTarget.dataset.index;
        if (event.detail.files && event.detail.files.length > 0) {
            this.rows[index].isFileUploaded = true;
        }
    }

    // --- Save & Validation Logic ---
    handleSave() {
        let isValid = true;
        let selectedIdsToSave = [];

        for (let i = 0; i < this.rows.length; i++) {
            const row = this.rows[i];
            
            if (!row.materialId) {
                this.showToast('Validation Error', `Row ${i + 1}: Please select a material.`, 'error');
                isValid = false; break;
            }
            if (!row.isCheckboxChecked) {
                this.showToast('Validation Error', `Row ${i + 1}: You must check "Testing Completed".`, 'error');
                isValid = false; break;
            }
            if (!row.isFileUploaded) {
                this.showToast('Validation Error', `Row ${i + 1}: A Testing Proof file is mandatory.`, 'error');
                isValid = false; break;
            }
            selectedIdsToSave.push(row.materialId);
        }

        if (isValid && selectedIdsToSave.length > 0) {
            this.isLoading = true;
            saveCompletedMaterials({ materialIds: selectedIdsToSave })
                .then(() => {
                    this.showToast('Success', 'Materials updated successfully.', 'success');
                    this.closeAction();
                })
                .catch(error => {
                    this.showToast('Error', error.body ? error.body.message : error.message, 'error');
                    this.isLoading = false;
                });
        }
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}