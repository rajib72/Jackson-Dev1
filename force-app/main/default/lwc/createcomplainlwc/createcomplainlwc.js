import { LightningElement , track} from 'lwc';

export default class Createcomplainlwc extends LightningElement {
    customerName = '';
    serialNo = '';
    mobileNo = '';

    disableCustomerName = false;
    disableSerialNo = false;
    disableMobileNo = false;

    handleCustomerName(event) {
        this.customerName = event.target.value;

        if (this.customerName.trim()) {
            this.disableSerialNo = true;
            this.disableMobileNo = true;
        } else {
            this.enableAllFields();
        }
    }

    handleSerialNo(event) {
        this.serialNo = event.target.value;

        if (this.serialNo.trim()) {
            this.disableCustomerName = true;
            this.disableMobileNo = true;
        } else {
            this.enableAllFields();
        }
    }

    handleMobileNo(event) {
        this.mobileNo = event.target.value;

        if (this.mobileNo.trim()) {
            this.disableCustomerName = true;
            this.disableSerialNo = true;
        } else {
            this.enableAllFields();
        }
    }

    enableAllFields() {
        this.disableCustomerName = false;
        this.disableSerialNo = false;
        this.disableMobileNo = false;
    }

    handleSearch() {

        let searchType;
        let searchValue;

        if (this.customerName) {
            searchType = 'Customer Name';
            searchValue = this.customerName;
        } else if (this.serialNo) {
            searchType = 'Serial No';
            searchValue = this.serialNo;
        } else if (this.mobileNo) {
            searchType = 'Mobile No';
            searchValue = this.mobileNo;
        }

        console.log('Search Type:', searchType);
        console.log('Search Value:', searchValue);

        // Call Apex here
    }
}