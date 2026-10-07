import { LightningElement, api, track } from 'lwc';
import saveLocation from '@salesforce/apex/ctrl_LocationCaptureController.saveLocation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getLocationService } from 'lightning/mobileCapabilities';

export default class CaptureLocation extends NavigationMixin(LightningElement) {
    @api recordId;

    @track latitude;
    @track longitude;
    @track message;

    isButtonDisabled = false;
    locationService = getLocationService();

    get buttonLabel() {
        return this.isButtonDisabled ? 'Capturing Location...' : 'Check In';
    }

    async handleCaptureLocation() {
        this.isButtonDisabled = true;
        this.message = 'Fetching current location...';

        try {
            if (this.locationService && this.locationService.isAvailable()) {
                const position = await this.locationService.getCurrentPosition({
                    enableHighAccuracy: true
                });

                this.latitude = position.coords.latitude;
                this.longitude = position.coords.longitude;
            } else {
                await this.captureBrowserLocation();
            }

            this.message = 'Location captured. Saving location...';
            await this.saveLocationToSalesforce();

        } catch (error) {
            let errorMessage = 'Unable to fetch location.';

            if (error && error.code === 1) {
                errorMessage = 'Location permission denied. Please allow location access.';
            } else if (error && error.code === 2) {
                errorMessage = 'Location information is unavailable.';
            } else if (error && error.code === 3) {
                errorMessage = 'Location request timed out.';
            } else if (error && error.message) {
                errorMessage = error.message;
            }

            this.message = errorMessage;
            this.showToast('Error', errorMessage, 'error');
            this.isButtonDisabled = false;
        }
    }

    captureBrowserLocation() {
        return new Promise((resolve, reject) => {
            if (!navigator.geolocation) {
                reject(new Error('Geolocation is not supported by this browser/device.'));
                return;
            }

            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.latitude = position.coords.latitude;
                    this.longitude = position.coords.longitude;
                    resolve();
                },
                (error) => {
                    reject(error);
                },
                {
                    enableHighAccuracy: true,
                    timeout: 20000,
                    maximumAge: 0
                }
            );
        });
    }

    saveLocationToSalesforce() {
        return saveLocation({
            recordId: this.recordId,
            latitude: this.latitude,
            longitude: this.longitude
        })
            .then(() => {
                this.message = 'Location saved successfully.';
                this.showToast('Success', 'Location saved successfully.', 'success');
                this.navigateToRecord();
            })
            .catch((error) => {
                let errorMessage = 'Error while saving location.';

                if (error?.body?.message) {
                    errorMessage = error.body.message;
                }

                this.message = errorMessage;
                this.showToast('Error', errorMessage, 'error');
                this.isButtonDisabled = false;
            });
    }

    navigateToRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
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
}