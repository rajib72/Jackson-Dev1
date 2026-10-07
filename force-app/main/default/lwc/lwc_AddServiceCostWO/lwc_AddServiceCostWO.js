import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';

import EXECUTION_MODE_FIELD
    from '@salesforce/schema/WorkOrder.Execution_Mode__c';

export default class CreateServiceCostDetails extends LightningElement {

    @api recordId;

    isSiteVisit = false;
    isLoading = true;

    hasBlockingServiceCost = false;

    workOrderCheckComplete = false;
    serviceCostCheckComplete = false;

    hasValidationError = false;
    validationErrorMessage = '';

    /*
     * Existing functionality:
     * Check Work Order Execution Mode.
     */
    @wire(getRecord, {
        recordId: '$recordId',
        fields: [EXECUTION_MODE_FIELD]
    })
    wiredWorkOrder({ error, data }) {

        if (data) {

            const mode = getFieldValue(
                data,
                EXECUTION_MODE_FIELD
            );

            this.isSiteVisit =
                mode === 'Site Visit';

        } else if (error) {

            console.error(
                'Error fetching Work Order data:',
                error
            );

            this.hasValidationError = true;

            this.validationErrorMessage =
                'Unable to check Work Order details.';

        }

        this.workOrderCheckComplete = true;
        this.checkLoadingComplete();
    }

    /*
     * NEW VALIDATION:
     *
     * Get all Service Cost Details related
     * to the current Work Order.
     */
    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'Service_Cost_Details__r',
        fields: [
            'Service_Cost_Details__c.Stage__c'
        ],
        pageSize: 1999
    })
    wiredServiceCosts({ error, data }) {

        if (data) {

            /*
             * Block creation if ANY existing
             * Service Cost has Stage other than:
             *
             * Service Head Rejected
             *
             * This means:
             *
             * No Service Costs         -> Allowed
             * All Rejected             -> Allowed
             * One Approved             -> Blocked
             * One Pending              -> Blocked
             * One Submitted            -> Blocked
             * One Blank Stage          -> Blocked
             */
            this.hasBlockingServiceCost =
                data.records.some(record => {

                    const stage =
                        record.fields.Stage__c?.value;

                    return stage !==
                        'Service Head Rejected';
                });

        } else if (error) {

            console.error(
                'Error fetching Service Cost Details:',
                error
            );

            /*
             * Don't allow creation if Salesforce
             * could not check existing Service Costs.
             */
            this.hasValidationError = true;

            this.validationErrorMessage =
                'Unable to check existing Service Cost Details. Please close and try again.';

        }

        this.serviceCostCheckComplete = true;
        this.checkLoadingComplete();
    }

    /*
     * Keep spinner visible until BOTH:
     *
     * 1. Work Order check
     * 2. Service Cost check
     *
     * are complete.
     */
    checkLoadingComplete() {

        if (
            this.workOrderCheckComplete &&
            this.serviceCostCheckComplete
        ) {
            this.isLoading = false;
        }
    }

    /*
     * Show existing form only when:
     *
     * Execution Mode = Site Visit
     * AND
     * no non-rejected Service Cost exists.
     */
    get canCreateServiceCost() {

        return (
            this.isSiteVisit &&
            !this.hasBlockingServiceCost
        );
    }

    /*
     * Show Service Cost blocked message only when:
     *
     * Execution Mode = Site Visit
     * AND
     * at least one non-rejected Service Cost exists.
     */
    get showExistingServiceCostMessage() {

        return (
            this.isSiteVisit &&
            this.hasBlockingServiceCost
        );
    }

    /*
     * Existing submit functionality.
     * No changes to the record creation logic.
     */
    handleSubmit(event) {

        event.preventDefault();

        const fields =
            event.detail.fields;

        /*
         * Existing functionality:
         * Map current Work Order.
         */
        fields.Work_Order__c =
            this.recordId;

        this.template
            .querySelector(
                'lightning-record-edit-form'
            )
            .submit(fields);
    }

    /*
     * Existing success functionality.
     */
    handleSuccess() {

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message:
                    'Service Cost Details created successfully.',
                variant: 'success'
            })
        );

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }

    /*
     * Existing error functionality.
     */
    handleError(event) {

        let message =
            'Something went wrong while creating Service Cost Details.';

        if (
            event.detail &&
            event.detail.detail
        ) {
            message =
                event.detail.detail;
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }

    /*
     * Existing cancel functionality.
     */
    handleCancel() {

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }
}

// import { LightningElement, api, wire } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import { CloseActionScreenEvent } from 'lightning/actions';
// import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// // Import the Execution Mode field reference
// import EXECUTION_MODE_FIELD from '@salesforce/schema/WorkOrder.Execution_Mode__c';

// export default class CreateServiceCostDetails extends LightningElement {
//     @api recordId;
//     isSiteVisit = false;
//     isLoading = true;

//     // Fetch the Work Order record to check Execution Mode
//     @wire(getRecord, { recordId: '$recordId', fields: [EXECUTION_MODE_FIELD] })
//     wiredWorkOrder({ error, data }) {
//         if (data) {
//             const mode = getFieldValue(data, EXECUTION_MODE_FIELD);
//             this.isSiteVisit = (mode === 'Site Visit');
//             this.isLoading = false;
//         } else if (error) {
//             this.isLoading = false;
//             console.error('Error fetching record data', error);
//         }
//     }

//     handleSubmit(event) {
//         event.preventDefault();
//         const fields = event.detail.fields;

//         // WorkOrder Id is automatically mapped to lookup field
//         fields.Work_Order__c = this.recordId;

//         this.template.querySelector('lightning-record-edit-form').submit(fields);
//     }

//     handleSuccess() {
//         this.dispatchEvent(
//             new ShowToastEvent({
//                 title: 'Success',
//                 message: 'Service Cost Details created successfully.',
//                 variant: 'success'
//             })
//         );
//         this.dispatchEvent(new CloseActionScreenEvent());
//     }

//     handleError(event) {
//         let message = 'Something went wrong while creating Service Cost Details.';

//         if (event.detail && event.detail.detail) {
//             message = event.detail.detail;
//         }

//         this.dispatchEvent(
//             new ShowToastEvent({
//                 title: 'Error',
//                 message: message,
//                 variant: 'error'
//             })
//         );
//     }

//     handleCancel() {
//         this.dispatchEvent(new CloseActionScreenEvent());
//     }
// }