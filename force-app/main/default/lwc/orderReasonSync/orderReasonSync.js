import { LightningElement, track } from 'lwc';
import syncOrderReasons from '@salesforce/apex/ctrl_OrderReasonAPIController.syncOrderReasons';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class OrderReasonSync extends LightningElement {
    @track isLoading = false;
    @track showResults = false;

    @track summary = {
        totalReceived: 0,
        created: 0,
        updated: 0,
        errors: 0
    };

    @track records = [];

    columns = [
        { label: 'Order Reason', fieldName: 'orderReason', type: 'text' },
        { label: 'Description', fieldName: 'description', type: 'text' },
        { label: 'Action', fieldName: 'action', type: 'text' },
        { label: 'Message', fieldName: 'message', type: 'text' }
    ];

    async handleFetch() {
        this.isLoading = true;
        this.showResults = false;

        try {
            const result = await syncOrderReasons();

            this.summary = {
                totalReceived: result?.totalReceived || 0,
                created: result?.created || 0,
                updated: result?.updated || 0,
                errors: result?.errors || 0
            };

            this.records = (result?.records || []).map((row, index) => ({
                key: index + 1,
                ...row
            }));

            this.showResults = true;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `Processed ${this.summary.totalReceived} records`,
                    variant: 'success'
                })
            );
        } catch (error) {
            const message =
                error?.body?.message ||
                error?.message ||
                'Unknown error occurred';

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        window.location.reload();
    }
}