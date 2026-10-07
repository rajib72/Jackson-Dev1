import { LightningElement, api } from 'lwc';

import validateOrder from
    '@salesforce/apex/API_Ctrl_ServiceOrderCreationController.validateOrder';

import pushOrderToSAP from
    '@salesforce/apex/API_Ctrl_ServiceOrderCreationController.pushOrderToSAP';

import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Lwc_PushSolarServiceOrderToSAP
    extends LightningElement {

    _recordId;
    hasInitialized = false;

    isLoading = false;
    loadingMessage = 'Validating mandatory fields...';

    validationData;
    orderItemRows = [];
    result;
    errorMessage;

    @api
    set recordId(value) {
        this._recordId = value;

        if (value && !this.hasInitialized) {
            this.hasInitialized = true;
            this.runValidation();
        }
    }

    get recordId() {
        return this._recordId;
    }

    get showValidation() {
        return Boolean(this.validationData) && !this.hasResult;
    }

    get hasResult() {
        return Boolean(this.result);
    }

    get orderNumber() {
        return this.validationData?.orderNumber || 'Service Order';
    }

    get isReadyToPush() {
        return (
            this.showValidation &&
            this.validationData?.isValid === true &&
            !this.errorMessage
        );
    }

    get hasValidationErrors() {
        return (
            this.showValidation &&
            this.validationData?.isValid === false
        );
    }

    get hasOrderMissingFields() {
        return (
            this.validationData?.orderMissingFields?.length > 0
        );
    }

    get hasOrderItemIssues() {
        return this.orderItemRows.length > 0;
    }

    get hasBlockingErrors() {
        return (
            this.validationData?.blockingErrors?.length > 0
        );
    }

    get showRecheckButton() {
        return (
            !this.isLoading &&
            (
                this.hasValidationErrors ||
                this.errorMessage ||
                (
                    this.hasResult &&
                    !this.result?.isSuccess
                )
            )
        );
    }

    async runValidation() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;
        this.loadingMessage =
            'Validating mandatory fields...';

        this.errorMessage = undefined;
        this.validationData = undefined;
        this.orderItemRows = [];
        this.result = undefined;

        try {
            const validationResult = await validateOrder({
                orderId: this.recordId
            });

            this.applyValidationResult(validationResult);

        } catch (error) {
            this.errorMessage = this.reduceError(error);

        } finally {
            this.isLoading = false;
        }
    }

    async handlePushToSAP() {
        if (!this.recordId || !this.isReadyToPush) {
            return;
        }

        this.isLoading = true;
        this.loadingMessage =
            'Sending the Service Order to SAP...';

        this.errorMessage = undefined;
        this.result = undefined;

        try {
            const integrationResult = await pushOrderToSAP({
                orderId: this.recordId
            });

            /*
             * The Apex method performs another validation immediately
             * before the callout. This handles Order data that changed
             * after the quick action was opened.
             */
            if (
                integrationResult.validationResult &&
                integrationResult.validationResult.isValid === false
            ) {
                this.applyValidationResult(
                    integrationResult.validationResult
                );

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Mandatory Fields Missing',
                        message:
                            'The Service Order data changed. Complete the listed fields and try again.',
                        variant: 'warning'
                    })
                );

                return;
            }

            this.result = integrationResult;

            if (integrationResult.isSuccess) {
                this.dispatchEvent(new RefreshEvent());

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'SAP Service Order Created',
                        message:
                            integrationResult.responseMessage,
                        variant: 'success'
                    })
                );
            }

        } catch (error) {
            this.errorMessage = this.reduceError(error);

        } finally {
            this.isLoading = false;
        }
    }

    applyValidationResult(validationResult) {
        this.validationData = validationResult;

        this.orderItemRows = (
            validationResult?.orderItemIssues || []
        ).map((item) => {
            const missingCount =
                item.missingFields?.length || 0;

            return {
                ...item,

                recordUrl:
                    `/lightning/r/OrderItem/${item.orderItemId}/view`,

                missingCountLabel:
                    `${missingCount} Missing ${
                        missingCount === 1
                            ? 'Field'
                            : 'Fields'
                    }`
            };
        });
    }

    handleRecheck() {
        this.runValidation();
    }

    handleClose() {
        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }

    reduceError(error) {
        if (!error) {
            return 'An unexpected error occurred.';
        }

        if (Array.isArray(error.body)) {
            return error.body
                .map((entry) => entry.message)
                .join(', ');
        }

        if (error.body?.message) {
            return error.body.message;
        }

        if (error.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }
}