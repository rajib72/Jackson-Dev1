import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import fetchPlants from '@salesforce/apex/Ctrl_OrderPlantSelection.fetchPlants';
import saveSelectedPlant from '@salesforce/apex/Ctrl_OrderPlantSelection.saveSelectedPlant';

export default class Lwc_FetchDeliveringPlant extends LightningElement {
    _recordId;

    @track plantOptions = [];
    @track filteredPlantOptions = [];
    @track searchKey = '';
    @track selectedPlantCode = '';
    @track selectedPlantName = '';
    @track isLoading = false;
    @track hasData = false;
    @track dataLoaded = false;
    @track showDropdown = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value && !this.dataLoaded) {
            this.dataLoaded = true;
            this.loadPlants();
        }
    }

    get isSaveDisabled() {
        return this.isLoading || !this.selectedPlantCode;
    }

    get noRecordsFound() {
        return this.showDropdown && !this.isLoading && this.filteredPlantOptions.length === 0;
    }

    get hasSelectedPlant() {
        return !!this.selectedPlantCode;
    }

    async loadPlants() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;
        this.hasData = false;
        this.plantOptions = [];
        this.filteredPlantOptions = [];
        this.searchKey = '';
        this.selectedPlantCode = '';
        this.selectedPlantName = '';
        this.showDropdown = false;

        try {
            const result = await fetchPlants({ orderId: this.recordId });

            if (result && result.length > 0) {
                this.plantOptions = result.map((item) => ({
                    label: item.label,
                    value: item.value,
                    plantCode: item.plantCode,
                    plantName: item.plantName,
                    isSelected: false,
                    cssClass: 'dropdown-item'
                }));

                this.filteredPlantOptions = [...this.plantOptions];
                this.hasData = true;
            } else {
                this.showToast('Info', 'No plant values returned from SAP.', 'info');
            }
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSearchFocus() {
        this.showDropdown = true;
        this.filterPlants();
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value || '';
        this.showDropdown = true;
        this.filterPlants();
    }

    filterPlants() {
        const key = this.searchKey.trim().toLowerCase();

        let filtered = [];
        if (!key) {
            filtered = [...this.plantOptions];
        } else {
            filtered = this.plantOptions.filter((item) => {
                const code = (item.plantCode || '').toLowerCase();
                const name = (item.plantName || '').toLowerCase();
                const label = (item.label || '').toLowerCase();

                return (
                    code.includes(key) ||
                    name.includes(key) ||
                    label.includes(key)
                );
            });
        }

        this.filteredPlantOptions = filtered.map((item) => {
            const isSelected = item.plantCode === this.selectedPlantCode;
            return {
                ...item,
                isSelected,
                cssClass: isSelected ? 'dropdown-item selected-item' : 'dropdown-item'
            };
        });
    }

    handleSelectPlant(event) {
        const plantCode = event.currentTarget.dataset.code;
        const plantName = event.currentTarget.dataset.name;

        this.selectedPlantCode = plantCode;
        this.selectedPlantName = plantName;
        this.searchKey = `${plantCode} - ${plantName}`;
        this.showDropdown = false;

        this.filterPlants();
    }

    handleClearSelection() {
        this.selectedPlantCode = '';
        this.selectedPlantName = '';
        this.searchKey = '';
        this.showDropdown = true;
        this.filterPlants();
    }

    async handleSave() {
        if (!this.selectedPlantCode) {
            this.showToast('Error', 'Please select a plant.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const message = await saveSelectedPlant({
                orderId: this.recordId,
                plantCode: this.selectedPlantCode
            });

            this.showToast('Success', message, 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadPlants();
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    reduceError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Unknown error';
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