import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

import uploadPoToSap from '@salesforce/apex/API_ctrl_OrderPoAttachmentController.uploadPoToSap';
import removeUploadedFile from '@salesforce/apex/API_ctrl_OrderPoAttachmentController.removeUploadedFile';

import SAP_ORDER_ID_FIELD from '@salesforce/schema/Order.SAP_Order_ID__c';

const ORDER_FIELDS = [SAP_ORDER_ID_FIELD];

export default class PoAttachmentQuickAction extends LightningElement {
    @api recordId;

    isLoading = false;
    successMessage;
    errorMessage;
    dmsDocumentNo;

    selectedContentDocumentId;
    selectedFileName;
    isSapUploaded = false;

    @wire(getRecord, { recordId: '$recordId', fields: ORDER_FIELDS })
    orderRecord;

    get sapOrderId() {
        return getFieldValue(this.orderRecord.data, SAP_ORDER_ID_FIELD);
    }

    get sapDescription() {
        return this.sapOrderId ? `SO NUMBER ${this.sapOrderId}` : 'SO NUMBER not available';
    }

    get acceptedFormats() {
        return ['.pdf'];
    }

    get disableFileSelection() {
        return this.isLoading || !this.sapOrderId;
    }

    get showUploadButton() {
        return this.selectedContentDocumentId && !this.isSapUploaded;
    }

    get disableUploadButton() {
        return this.isLoading || !this.selectedContentDocumentId || !this.sapOrderId;
    }

    handleUploadFinished(event) {
        this.successMessage = null;
        this.errorMessage = null;
        this.dmsDocumentNo = null;
        this.isSapUploaded = false;

        const uploadedFiles = event.detail.files;

        if (!uploadedFiles || uploadedFiles.length === 0) {
            this.errorMessage = 'No file selected.';
            return;
        }

        const uploadedFile = uploadedFiles[0];

        this.selectedContentDocumentId = uploadedFile.documentId;
        this.selectedFileName = uploadedFile.name;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'File Attached',
                message: 'File has been attached to this Order. Please click Upload to send it to SAP.',
                variant: 'success'
            })
        );

        this.dispatchEvent(new RefreshEvent());
    }

    async handleRemoveFile() {
        this.successMessage = null;
        this.errorMessage = null;
        this.dmsDocumentNo = null;

        if (!this.selectedContentDocumentId) {
            return;
        }

        try {
            this.isLoading = true;

            await removeUploadedFile({
                orderId: this.recordId,
                contentDocumentId: this.selectedContentDocumentId
            });

            this.selectedContentDocumentId = null;
            this.selectedFileName = null;
            this.isSapUploaded = false;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'File Removed',
                    message: 'Selected file has been removed. You can attach another file now.',
                    variant: 'success'
                })
            );

            this.dispatchEvent(new RefreshEvent());

        } catch (error) {
            this.errorMessage = this.reduceError(error);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Remove Failed',
                    message: this.errorMessage,
                    variant: 'error',
                    mode: 'sticky'
                })
            );

        } finally {
            this.isLoading = false;
        }
    }

    async handleUploadToSap() {
        this.successMessage = null;
        this.errorMessage = null;
        this.dmsDocumentNo = null;

        if (!this.selectedContentDocumentId) {
            this.errorMessage = 'Please select a PO document first.';
            return;
        }

        try {
            this.isLoading = true;

            const result = await uploadPoToSap({
                orderId: this.recordId,
                contentDocumentId: this.selectedContentDocumentId
            });

            this.isSapUploaded = true;
            this.successMessage = result?.message || 'PO document uploaded to SAP successfully.';
            this.dmsDocumentNo = result?.dmsDocumentNo;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: this.successMessage,
                    variant: 'success'
                })
            );

            this.dispatchEvent(new RefreshEvent());

        } catch (error) {
            this.errorMessage = this.reduceError(error);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'SAP Upload Failed',
                    message: this.errorMessage,
                    variant: 'error',
                    mode: 'sticky'
                })
            );

        } finally {
            this.isLoading = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }

        if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }

        if (typeof error?.message === 'string') {
            return error.message;
        }

        return 'Unknown error occurred.';
    }
}