import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import uploadSingleFile from '@salesforce/apex/Ctrl_MediaUpload.uploadSingleFile';

import ESTIMATION_COST_FIELD from '@salesforce/schema/WorkOrder.Final_Service_Estimation_Cost__c';
import EXECUTION_MODE_FIELD from '@salesforce/schema/WorkOrder.Execution_Mode__c';

const MAX_FILES = 10;
const MAX_FILE_SIZE = 25 * 1024 * 1024; 

export default class Lwc_mediaUpload extends LightningElement {
    @api recordId;
    @track filesToUpload = [];
    @track savedFiles = []; // Tracks files already uploaded in the current window
    @track isLoading = false;
    
    isRecordDataLoading = true;
    showError = false;

    @wire(getRecord, { recordId: '$recordId', fields: [ESTIMATION_COST_FIELD, EXECUTION_MODE_FIELD] })
    wiredWorkOrderRecord({ error, data }) {
        if (data) {
            const cost = getFieldValue(data, ESTIMATION_COST_FIELD) || 0;
            const mode = getFieldValue(data, EXECUTION_MODE_FIELD);

            const isSiteVisitWithCost = (mode === 'Site Visit' && cost > 0);
            const isRemote = (mode === 'Remote');
            const isSiteVisitWithoutCost = (mode === 'Site Visit' && cost === 0);

            const showLwcNormally = isSiteVisitWithCost || isRemote || isSiteVisitWithoutCost;

            this.showError = !showLwcNormally;
            this.isRecordDataLoading = false;

        } else if (error) {
            console.error('Error fetching Work Order details for validation:', error);
            this.isRecordDataLoading = false;
        }
    }

    get remainingSlots() {
        return MAX_FILES - this.filesToUpload.length;
    }

    get isUploadInputDisabled() {
        return this.filesToUpload.length >= MAX_FILES || this.isLoading;
    }

    get isSaveButtonDisabled() {
        return this.filesToUpload.length === 0 || this.isLoading;
    }

    get uploadLabelClass() {
        return this.isUploadInputDisabled ? 'upload-label upload-disabled' : 'upload-label';
    }

    handleFileChange(event) {
        const incomingFiles = Array.from(event.target.files);
        let oversizedFiles = [];
        let validFiles = [];

        incomingFiles.forEach(file => {
            if (file.size > MAX_FILE_SIZE) {
                oversizedFiles.push(file.name);
            } else {
                validFiles.push(file);
            }
        });

        if (oversizedFiles.length > 0) {
            this.showToast('File Too Large', `The following files exceed the 25MB limit: ${oversizedFiles.join(', ')}`, 'error');
        }

        if (this.filesToUpload.length + validFiles.length > MAX_FILES) {
            this.showToast('Limit Exceeded', `You can only queue a maximum of ${MAX_FILES} files per batch.`, 'error');
            const remainingCount = MAX_FILES - this.filesToUpload.length;
            validFiles = validFiles.slice(0, remainingCount);
        }

        if (validFiles.length > 0) {
            const wrappedFiles = validFiles.map(file => {
                return {
                    id: Math.random().toString(36).substring(2, 15), 
                    originalFile: file,
                    originalName: file.name,
                    newName: file.name
                };
            });
            this.filesToUpload = [...this.filesToUpload, ...wrappedFiles];
        }
        
        event.target.value = null;
    }

    handleNameChange(event) {
        const fileId = event.target.dataset.id;
        const updatedName = event.target.value;
        
        this.filesToUpload = this.filesToUpload.map(item => {
            if (item.id === fileId) {
                return { ...item, newName: updatedName };
            }
            return item;
        });
    }

    removeFile(event) {
        const fileId = event.target.dataset.id;
        this.filesToUpload = this.filesToUpload.filter(item => item.id !== fileId);
    }

    // RENAMED AND UPDATED: Uploads the batch, locks them, and clears the staging area
    async handleSaveAndNext() {
        this.isLoading = true;
        let successCount = 0;
        let newlySaved = [];
        let failedFiles = []; // Holds any files that hit an Apex error

        for (const item of this.filesToUpload) {
            try {
                const processedFile = await this.processFile(item.originalFile);
                
                let finalName = item.newName.trim();
                const extensionIndex = item.originalName.lastIndexOf('.');
                
                if (extensionIndex !== -1) {
                    const originalExt = item.originalName.substring(extensionIndex);
                    if (!finalName.toLowerCase().endsWith(originalExt.toLowerCase())) {
                        finalName += originalExt;
                    }
                }

                await uploadSingleFile({
                    recordId: this.recordId,
                    filename: finalName,
                    base64Data: processedFile.base64
                });
                
                successCount++;
                newlySaved.push({ id: item.id, name: finalName });
            } catch (error) {
                // If a file fails, keep it in the staging area so they can try again
                failedFiles.push(item);
                console.error('Error uploading file:', item.originalName, error);
            }
        }

        if (successCount > 0) {
            this.showToast('Batch Uploaded', `${successCount} files saved. You can add more files to the next batch.`, 'success');
            // Move successful files to the read-only section
            this.savedFiles = [...this.savedFiles, ...newlySaved];
        }

        if (failedFiles.length > 0) {
            this.showToast('Upload Error', `${failedFiles.length} files failed to upload. Please check the files and try again.`, 'error');
        }

        // Clear the staging area of successful files
        this.filesToUpload = failedFiles;
        this.isLoading = false; 
    }

    async processFile(file) {
        if (file.type.match('image.*')) {
            return await this.compressImage(file);
        }
        return await this.readFileAsBase64(file);
    }

    compressImage(file) {
        return new Promise((resolve) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = (event) => {
                const img = new Image();
                img.src = event.target.result;
                img.onload = () => {
                    const canvas = document.createElement('canvas');
                    const MAX_WIDTH = 1200;
                    let width = img.width;
                    let height = img.height;

                    if (width > MAX_WIDTH) {
                        height *= MAX_WIDTH / width;
                        width = MAX_WIDTH;
                    }

                    canvas.width = width;
                    canvas.height = height;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0, width, height);

                    const dataUrl = canvas.toDataURL('image/jpeg', 0.7);
                    resolve({ base64: dataUrl.split(',')[1] });
                };
            };
        });
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve({ base64: reader.result.split(',')[1] });
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    // NEW: Closes the Quick Action module and essentially leaves them on the Work Order page
    handleGoToWorkOrder() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}