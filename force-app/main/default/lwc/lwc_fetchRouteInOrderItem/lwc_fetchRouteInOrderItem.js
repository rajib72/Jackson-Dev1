import { LightningElement, api, track } from 'lwc';
import getRouteOptions from '@salesforce/apex/API_ctrl_OrderItemRouteController.getRouteOptions';
import saveSelectedRoute from '@salesforce/apex/API_ctrl_OrderItemRouteController.saveSelectedRoute';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class OrderItemRoutePicker extends LightningElement {
    @api recordId;

    @track routeOptions = [];
    selectedRoute = '';
    isLoading = false;
    message = '';
    errorMessage = '';

    get disableSave() {
        return !this.selectedRoute || this.isLoading;
    }

    async handleFetchRoutes() {
        this.isLoading = true;
        this.message = '';
        this.errorMessage = '';
        this.routeOptions = [];
        this.selectedRoute = '';

        try {
            const response = await getRouteOptions({ orderItemId: this.recordId });

            if (response && response.options) {
                this.routeOptions = response.options.map(item => ({
                    label: item.label,
                    value: item.value
                }));
            }

            this.message = response && response.message ? response.message : 'Routes fetched successfully.';

            if (!this.routeOptions.length) {
                this.showToast('Info', 'No route values found from API.', 'info');
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast('Error', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRouteChange(event) {
        this.selectedRoute = event.detail.value;
    }

    async handleSave() {
        this.isLoading = true;
        this.message = '';
        this.errorMessage = '';

        try {
            const result = await saveSelectedRoute({
                orderItemId: this.recordId,
                selectedValue: this.selectedRoute
            });

            this.message = result;
            this.showToast('Success', result, 'success');
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast('Error', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'Unknown error';
    }
}