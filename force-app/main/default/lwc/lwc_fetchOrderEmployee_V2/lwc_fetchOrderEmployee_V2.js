import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import fetchSapEmployees from '@salesforce/apex/API_ctrl_OrderSapEmployeeController.fetchSapEmployees';
import saveSelectedEmployee from '@salesforce/apex/API_ctrl_OrderSapEmployeeController.saveSelectedEmployee';

export default class LwcFetchOrderEmployeeAction extends LightningElement {
    _recordId;

    @track employeeOptions = [];
    @track filteredEmployeeOptions = [];
    @track searchKey = '';
    @track selectedEmployeeCode = '';
    @track selectedEmployeeName = '';
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
            this.loadEmployees();
        }
    }

    get isSaveDisabled() {
        return this.isLoading || !this.selectedEmployeeCode;
    }

    get noRecordsFound() {
        return this.showDropdown && !this.isLoading && this.filteredEmployeeOptions.length === 0;
    }

    get hasSelectedEmployee() {
        return !!this.selectedEmployeeCode;
    }

    async loadEmployees() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;
        this.hasData = false;
        this.employeeOptions = [];
        this.filteredEmployeeOptions = [];
        this.searchKey = '';
        this.selectedEmployeeCode = '';
        this.selectedEmployeeName = '';
        this.showDropdown = false;

        try {
            const result = await fetchSapEmployees({ orderId: this.recordId });

            if (result && result.length > 0) {
                this.employeeOptions = result.map((item) => ({
                    label: item.label,
                    value: item.value,
                    employeeCode: item.employeeCode,
                    employeeName: item.employeeName,
                    isSelected: false,
                    cssClass: 'dropdown-item'
                }));

                this.filteredEmployeeOptions = [...this.employeeOptions];
                this.hasData = true;
            } else {
                this.showToast('Info', 'No employee values returned from SAP.', 'info');
            }
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSearchFocus() {
        this.showDropdown = true;
        this.filterEmployees();
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value || '';
        this.showDropdown = true;
        this.filterEmployees();
    }

    filterEmployees() {
        const key = this.searchKey.trim().toLowerCase();

        let filtered = [];
        if (!key) {
            filtered = [...this.employeeOptions];
        } else {
            filtered = this.employeeOptions.filter((item) => {
                const code = (item.employeeCode || '').toLowerCase();
                const name = (item.employeeName || '').toLowerCase();
                const label = (item.label || '').toLowerCase();

                return (
                    code.includes(key) ||
                    name.includes(key) ||
                    label.includes(key)
                );
            });
        }

        this.filteredEmployeeOptions = filtered.map((item) => {
            const isSelected = item.employeeCode === this.selectedEmployeeCode;
            return {
                ...item,
                isSelected,
                cssClass: isSelected ? 'dropdown-item selected-item' : 'dropdown-item'
            };
        });
    }

    handleSelectEmployee(event) {
        const employeeCode = event.currentTarget.dataset.code;
        const employeeName = event.currentTarget.dataset.name;

        this.selectedEmployeeCode = employeeCode;
        this.selectedEmployeeName = employeeName;
        this.searchKey = `${employeeCode} - ${employeeName}`;
        this.showDropdown = false;

        this.filterEmployees();
    }

    handleClearSelection() {
        this.selectedEmployeeCode = '';
        this.selectedEmployeeName = '';
        this.searchKey = '';
        this.showDropdown = true;
        this.filterEmployees();
    }

    async handleSave() {
        if (!this.selectedEmployeeCode || !this.selectedEmployeeName) {
            this.showToast('Error', 'Please select an employee.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const message = await saveSelectedEmployee({
                orderId: this.recordId,
                employeeCode: this.selectedEmployeeCode,
                employeeName: this.selectedEmployeeName
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
        this.loadEmployees();
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