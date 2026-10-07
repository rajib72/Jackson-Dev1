import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchSapEmployees from '@salesforce/apex/API_ctrl_OrderSapEmployeeController.fetchSapEmployees';
import saveSelectedEmployee from '@salesforce/apex/API_ctrl_OrderSapEmployeeController.saveSelectedEmployee';

export default class OrderSapEmployeePicker extends LightningElement {
    @api recordId;

    @track employeeOptions = [];
    @track selectedEmployeeCode = '';
    @track selectedEmployeeName = '';
    @track isLoading = false;
    @track hasData = false;

    get isSaveDisabled() {
        return this.isLoading || !this.hasData;
    }

    connectedCallback() {
        this.loadEmployees();
    }

    async loadEmployees() {
        this.isLoading = true;
        this.hasData = false;
        this.employeeOptions = [];
        this.selectedEmployeeCode = '';
        this.selectedEmployeeName = '';

        try {
            const result = await fetchSapEmployees({ orderId: this.recordId });

            if (result && result.length > 0) {
                this.employeeOptions = result.map(item => ({
                    label: item.label,
                    value: item.value,
                    employeeCode: item.employeeCode,
                    employeeName: item.employeeName
                }));
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

    handleEmployeeChange(event) {
        this.selectedEmployeeCode = event.detail.value;

        const selectedOption = this.employeeOptions.find(
            opt => opt.value === this.selectedEmployeeCode
        );

        if (selectedOption) {
            this.selectedEmployeeName = selectedOption.employeeName;
        } else {
            this.selectedEmployeeName = '';
        }
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
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadEmployees();
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