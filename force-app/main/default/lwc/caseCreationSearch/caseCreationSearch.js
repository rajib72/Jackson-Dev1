import { LightningElement, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import searchAssetDetails from
    '@salesforce/apex/CaseCreationSearchController.searchAssetDetailsBySelection';

import getSearchSuggestions from
    '@salesforce/apex/CaseCreationSearchController.getSearchSuggestions';

import createCaseWithRelatedRecords from
    '@salesforce/apex/CaseCreationSearchController.createCaseWithRelatedRecords';

import createNewAccountContactAndCase from
    '@salesforce/apex/CaseCreationSearchController.createNewAccountContactAndCase';

import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import ACCOUNT_STATE from '@salesforce/schema/Account.State__c';
import CASE_OBJECT from '@salesforce/schema/Case';
import CASE_ACCOUNT_ID from '@salesforce/schema/Case.AccountId';
import CASE_CONTACT_ID from '@salesforce/schema/Case.ContactId';
import CASE_ASSET_ID from '@salesforce/schema/Case.AssetId';
//import CASE_SUBJECT from '@salesforce/schema/Case.Subject';
import CASE_PRODUCT from '@salesforce/schema/Case.Product__c';
import CASE_PRODUCT_CATEGORIES from '@salesforce/schema/Case.Product_Categories__c';
import CASE_ORIGIN from '@salesforce/schema/Case.Origin';
import CASE_SRT_STATUS from '@salesforce/schema/Case.SRT_Case_Status__c';
import CASE_PRIORITY from '@salesforce/schema/Case.Priority';
import CASE_DESCRIPTION from '@salesforce/schema/Case.Description';
import CASE_CUSTOMER_TYPE from '@salesforce/schema/Case.Customer_type__c';
import CASE_STOCK_TYPE from '@salesforce/schema/Case.Stock_type__c';

import CASE_COMPLAINT_TYPE_SRT from '@salesforce/schema/Case.Complaint_Type_SRT__c';
import CASE_COMPLAINT_SUB_TYPE_SRT from '@salesforce/schema/Case.Complaint_Sub_Type_SRT__c';
import CASE_COMPLAINT_REASON from '@salesforce/schema/Case.Complaint_Reason__c';
import CASE_FAILURE_CATEGORY from '@salesforce/schema/Case.Failure_Category__c';
import CASE_CLOSURE_REASON from '@salesforce/schema/Case.Closure_Reason__c';

const SEARCH_TYPE_SERIAL = 'SERIAL';
const SEARCH_TYPE_MOBILE = 'MOBILE';
const SEARCH_TYPE_CUSTOMER = 'CUSTOMER';
const SUGGESTION_DELAY = 300;

const CONTACT_COLUMNS = [
    {
        label: 'Contact Name',
        fieldName: 'contactUrl',
        type: 'url',
        initialWidth: 220,
        typeAttributes: {
            label: {
                fieldName: 'contactName'
            },
            target: '_blank'
        }
    },
    {
        label: 'Phone',
        fieldName: 'phone',
        type: 'phone',
        initialWidth: 150
    },
    {
        label: 'Mobile',
        fieldName: 'mobilePhone',
        type: 'phone',
        initialWidth: 150
    },
    {
        label: 'Email',
        fieldName: 'email',
        type: 'email',
        initialWidth: 220
    },
    {
        label: 'Title',
        fieldName: 'title',
        type: 'text',
        initialWidth: 180
    },
    {
        label: 'Department',
        fieldName: 'department',
        type: 'text',
        initialWidth: 180
    },
    {
        label: 'Mailing Address',
        fieldName: 'mailingAddress',
        type: 'text',
        initialWidth: 300,
        wrapText: true
    }
];

const ASSET_COLUMNS = [
    {
        label: 'Asset Name',
        fieldName: 'assetUrl',
        type: 'url',
        initialWidth: 220,
        typeAttributes: {
            label: {
                fieldName: 'assetName'
            },
            target: '_blank'
        }
    },
    {
        label: 'Product Name',
        fieldName: 'productName',
        type: 'text',
        initialWidth: 220
    },
    {
        label: 'Product Code',
        fieldName: 'productCode',
        type: 'text',
        initialWidth: 150
    },
    {
        label: 'Standard Serial Number',
        fieldName: 'standardSerialNumber',
        type: 'text',
        initialWidth: 190
    },
    {
        label: 'Status',
        fieldName: 'status',
        type: 'text',
        initialWidth: 130
    },
    {
        label: 'Warranty Status',
        fieldName: 'warrantyStatus',
        type: 'text',
        initialWidth: 160
    },
    {
        label: 'Invoice Number',
        fieldName: 'invoiceNumber',
        type: 'text',
        initialWidth: 160
    },
    {
        label: 'Purchase Date',
        fieldName: 'purchaseDate',
        type: 'date-local',
        initialWidth: 140,
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }
    }
];

const SERIAL_NUMBER_COLUMNS = [
    {
        label: 'Asset Serial No',
        fieldName: 'assetSerialNumberUrl',
        type: 'url',
        initialWidth: 220,
        typeAttributes: {
            label: {
                fieldName: 'serialNumber'
            },
            target: '_blank'
        }
    },
    {
        label: 'Asset Name',
        fieldName: 'assetName',
        type: 'text',
        initialWidth: 220
    },
    {
        label: 'Created Date',
        fieldName: 'createdDate',
        type: 'date',
        initialWidth: 180,
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    }
];

const WARRANTY_COLUMNS = [
    {
        label: 'Warranty Number',
        fieldName: 'assetWarrantyUrl',
        type: 'url',
        initialWidth: 190,
        typeAttributes: {
            label: {
                fieldName: 'assetWarrantyNumber'
            },
            target: '_blank'
        }
    },
    {
        label: 'Asset Name',
        fieldName: 'assetName',
        type: 'text',
        initialWidth: 200
    },
    {
        label: 'Serial No',
        fieldName: 'serialNumber',
        type: 'text',
        initialWidth: 160
    },
    {
        label: 'Warranty Type',
        fieldName: 'warrantyType',
        type: 'text',
        initialWidth: 160
    },
    {
        label: 'Type',
        fieldName: 'type',
        type: 'text',
        initialWidth: 140
    },
    {
        label: 'Start Date',
        fieldName: 'startDate',
        type: 'date-local',
        initialWidth: 130,
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }
    },
    {
        label: 'End Date',
        fieldName: 'endDate',
        type: 'date-local',
        initialWidth: 130,
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }
    },
    {
        label: 'Approval Status',
        fieldName: 'approvalStatus',
        type: 'text',
        initialWidth: 150
    },
    {
        label: 'Active',
        fieldName: 'active',
        type: 'boolean',
        initialWidth: 100
    },
    {
        label: 'Transferable',
        fieldName: 'transferable',
        type: 'boolean',
        initialWidth: 120
    },
    {
        label: 'Parts Covered',
        fieldName: 'partsCovered',
        type: 'number',
        initialWidth: 140,
        typeAttributes: {
            maximumFractionDigits: 2
        }
    },
    {
        label: 'Labor Covered',
        fieldName: 'laborCovered',
        type: 'number',
        initialWidth: 140,
        typeAttributes: {
            maximumFractionDigits: 2
        }
    },
    {
        label: 'Expenses Covered',
        fieldName: 'expensesCovered',
        type: 'number',
        initialWidth: 160,
        typeAttributes: {
            maximumFractionDigits: 2
        }
    }
];

export default class CaseCreationSearch extends LightningElement {

    contactColumns = CONTACT_COLUMNS;
    assetColumns = ASSET_COLUMNS;
    serialNumberColumns = SERIAL_NUMBER_COLUMNS;
    warrantyColumns = WARRANTY_COLUMNS;

    caseObjectApiName = CASE_OBJECT;

    //subjectField = CASE_SUBJECT;

    productField = CASE_PRODUCT;
    productCategoriesField = CASE_PRODUCT_CATEGORIES;
    originField = CASE_ORIGIN;
    statusField = CASE_SRT_STATUS;
    priorityField = CASE_PRIORITY;
    descriptionField = CASE_DESCRIPTION;

    complaintTypeSrtField = CASE_COMPLAINT_TYPE_SRT;
    complaintSubTypeSrtField = CASE_COMPLAINT_SUB_TYPE_SRT;
    complaintReasonField = CASE_COMPLAINT_REASON;
    failureCategoryField = CASE_FAILURE_CATEGORY;
    closureReasonField = CASE_CLOSURE_REASON;

    mobileNo = '';
    serialNumber = '';
    customerName = '';

    suggestionOptions = [];
    activeSuggestionField = null;
    selectedSuggestionId = null;
    selectedSuggestionType = null;
    selectedSuggestionLabel = null;
    isSuggestionLoading = false;
    suggestionErrorMessage = null;

    suggestionDebounceId = null;
    suggestionBlurId = null;
    latestSuggestionRequestId = 0;

    searchType = null;

    assetSerialNumber = null;
    selectedAssetSerialNumbers = [];
    account = null;
    asset = null;
    selectedContact = null;

    matchedContacts = [];
    contacts = [];
    assets = [];
    assetSerialNumbers = [];
    assetWarranties = [];

    isAccountSelected = false;
    selectedContactRows = [];
    selectedSerialRows = [];

    isSearchStep = true;
    isCaseFormStep = false;
    isNewCustomerCaseStep = false;

    newAccountName = '';
    newAccountPhone = '';
    newAccountMobile = '';
    newAccountEmail = '';
    newCustomerType = '';
    dealerName = '';
    dealerContactNo = '';
    newStockType = 'Sold';
    customerTypeOptions = [];
    stockTypeOptions = [];

    newBillingStreet = '';
    newBillingCity = '';
    newBillingState = '';
    stateOptions = [];
    newBillingPostalCode = '';
    newBillingCountry = '';

    newContactFirstName = '';
    newContactLastName = '';
    newContactPhone = '';
    newContactMobilePhone = '';
    newContactEmail = '';

    isLoading = false;
    isSaving = false;
    hasSearched = false;

    errorMessage = null;
    noResultMessage = null;

    /* Existing Customer -> Case Form */
    caseCustomerType = '';
    caseStockType = 'Sold';
    caseDealerName = '';
    caseDealerContactNo = '';

    @wire(getObjectInfo, {
        objectApiName: CASE_OBJECT
    })
    caseObjectInfo;

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$accountObjectInfo.data.defaultRecordTypeId',
        fieldApiName: ACCOUNT_STATE
    })
    wiredAccountStateValues({ data, error }) {
        if (data) {
            this.stateOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        } else if (error) {
            console.error('Error loading Account State values:', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId',
        fieldApiName: CASE_CUSTOMER_TYPE
    })
    wiredCustomerTypeValues({ data, error }) {
        if (data) {
            this.customerTypeOptions =
                data.values.map((item) => ({
                    label: item.label,
                    value: item.value
                }));
        } else if (error) {
            console.error(
                'Error loading Customer Type values:',
                error
            );
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId',
        fieldApiName: CASE_STOCK_TYPE
    })
    wiredStockTypeValues({ data, error }) {
        if (data) {
            this.stockTypeOptions =
                data.values.map((item) => ({
                    label: item.label,
                    value: item.value
                }));
        } else if (error) {
            console.error(
                'Error loading Stock Type values:',
                error
            );
        }
    }

    get isNewCustomerDealer() {
        return this.newCustomerType === 'Dealer';
    }

    get isExistingCaseDealer() {
        return this.caseCustomerType === 'Dealer';
    }

    get isStockTypeDisabled() {
        return this.newCustomerType !== 'Dealer';
    }

    get isExistingCaseStockTypeDisabled() {
        return this.caseCustomerType !== 'Dealer';
    }

    disconnectedCallback() {
        this.invalidateSuggestionRequests();

        if (this.suggestionBlurId) {
            clearTimeout(this.suggestionBlurId);
        }
    }

    handleInputChange(event) {

        const fieldName =
            event.target.name;

        let fieldValue =
            event.target.value || '';


        /*
         * Phone / Mobile Number Search
         * Allow digits only and maximum 10 digits.
         */
        if (fieldName === 'mobileNo') {

            fieldValue = fieldValue
                .replace(/\D/g, '')
                .slice(0, 10);

            event.target.value =
                fieldValue;

            event.target.setCustomValidity('');


            if (
                fieldValue &&
                fieldValue.length !== 10
            ) {

                event.target.setCustomValidity(
                    'Phone / Mobile Number must contain exactly 10 digits.'
                );
            }


            event.target.reportValidity();
        }


        this.updateSearchField(
            fieldName,
            fieldValue
        );


        this.clearSelectedSuggestion();

        this.invalidateSuggestionRequests();

        this.clearSuggestionDisplay();


        if (this.hasSearched) {

            this.clearSearchResponse();

            this.hasSearched = false;
        }


        const searchTerm =
            this.getTrimmedValue(
                fieldValue
            );


        if (!searchTerm) {
            return;
        }


        this.activeSuggestionField =
            fieldName;


        this.scheduleSuggestionSearch(
            fieldName,
            searchTerm
        );
    }

    handleExistingCaseInputChange(event) {

        const fieldName =
            event.target?.name;

        if (!fieldName) {
            return;
        }


        let value =
            event.target.value || '';


        /*
         * Dealer Contact No.
         * Keep numeric and maximum 10 digits.
         */
        if (fieldName === 'caseDealerContactNo') {

            value = value
                .replace(/\D/g, '')
                .slice(0, 10);

            event.target.value = value;

            event.target.setCustomValidity('');

            if (value && value.length !== 10) {

                event.target.setCustomValidity(
                    'Dealer Contact Number must contain exactly 10 digits.'
                );
            }

            event.target.reportValidity();
        }


        this[fieldName] = value;


        /*
         * Same Customer Type / Stock Type
         * behavior as New Customer form.
         */
        if (fieldName === 'caseCustomerType') {

            if (value === 'Dealer') {

                this.caseStockType = '';

                // Dealer Contact No. must be entered manually
                this.caseDealerContactNo = '';

            } else if (value) {

                this.caseStockType = 'Sold';
                this.caseDealerName = '';
                this.caseDealerContactNo = '';

            } else {

                this.caseStockType = '';
                this.caseDealerName = '';
                this.caseDealerContactNo = '';
            }
        }
    }

    updateSearchField(fieldName, fieldValue) {
        switch (fieldName) {
            case 'mobileNo':
                this.mobileNo = fieldValue;

                if (this.getTrimmedValue(fieldValue)) {
                    this.serialNumber = '';
                    this.customerName = '';
                }
                break;

            case 'serialNumber':
                this.serialNumber = fieldValue;

                if (this.getTrimmedValue(fieldValue)) {
                    this.mobileNo = '';
                    this.customerName = '';
                }
                break;

            case 'customerName':
                this.customerName = fieldValue;

                if (this.getTrimmedValue(fieldValue)) {
                    this.mobileNo = '';
                    this.serialNumber = '';
                }
                break;

            default:
                break;
        }
    }

    handleInputFocus(event) {
        const fieldName =
            event.target.name;

        const searchType =
            this.getSearchTypeForField(fieldName);

        if (
            !searchType ||
            (
                this.selectedSuggestionId &&
                this.selectedSuggestionType === searchType
            )
        ) {
            return;
        }

        const searchTerm =
            this.getTrimmedValue(
                this.getSearchFieldValue(fieldName)
            );

        if (!searchTerm) {
            return;
        }

        this.invalidateSuggestionRequests();
        this.clearSuggestionDisplay();

        this.activeSuggestionField =
            fieldName;

        this.scheduleSuggestionSearch(
            fieldName,
            searchTerm
        );
    }

    handleInputBlur() {
        if (this.suggestionBlurId) {
            clearTimeout(this.suggestionBlurId);
        }

        this.suggestionBlurId =
            setTimeout(() => {
                this.closeSuggestionPanel();
            }, 200);
    }

    handleSuggestionMouseDown(event) {
        /*
            * Select during mousedown, before lightning-input blur can
            * close the dropdown. This makes one click select reliably.
            */
        event.preventDefault();

        if (this.suggestionBlurId) {
            clearTimeout(this.suggestionBlurId);
            this.suggestionBlurId = null;
        }

        this.handleSuggestionSelect(event);
    }

    handleSuggestionSelect(event) {
        const fieldName =
            this.activeSuggestionField;

        const recordId =
            event.currentTarget.dataset.recordId;

        const searchType =
            event.currentTarget.dataset.searchType;

        const selectedValue =
            event.currentTarget.dataset.value || '';

        const selectedLabel =
            event.currentTarget.dataset.label ||
            selectedValue;

        if (
            !fieldName ||
            !recordId ||
            !searchType
        ) {
            return;
        }

        this.updateSearchField(
            fieldName,
            selectedValue
        );

        this.selectedSuggestionId =
            recordId;

        this.selectedSuggestionType =
            searchType;

        this.selectedSuggestionLabel =
            selectedLabel;

        this.invalidateSuggestionRequests();
        this.closeSuggestionPanel();

        if (this.hasSearched) {
            this.clearSearchResponse();
            this.hasSearched = false;
        }
    }

    handleKeyDown(event) {
        if (event.key === 'Escape') {
            this.closeSuggestionPanel();
            return;
        }

        if (
            event.key === 'Enter' &&
            !this.isSearchDisabled
        ) {
            event.preventDefault();
            this.handleSearch();
        }
    }

    scheduleSuggestionSearch(
        fieldName,
        searchTerm
    ) {
        this.suggestionDebounceId =
            setTimeout(() => {
                this.loadSuggestions(
                    fieldName,
                    searchTerm
                );
            }, SUGGESTION_DELAY);
    }

    async loadSuggestions(
        fieldName,
        searchTerm
    ) {
        const searchType =
            this.getSearchTypeForField(fieldName);

        if (!searchType || !searchTerm) {
            return;
        }

        const requestId =
            ++this.latestSuggestionRequestId;

        this.isSuggestionLoading = true;
        this.suggestionErrorMessage = null;
        this.suggestionOptions = [];

        try {
            const suggestionRecords =
                await getSearchSuggestions({
                    searchType,
                    searchTerm
                });

            if (
                requestId !==
                this.latestSuggestionRequestId
            ) {
                return;
            }

            const currentSearchTerm =
                this.getTrimmedValue(
                    this.getSearchFieldValue(
                        fieldName
                    )
                );

            if (
                currentSearchTerm !== searchTerm ||
                this.activeSuggestionField !== fieldName
            ) {
                return;
            }

            this.suggestionOptions =
                (suggestionRecords || []).map(
                    (suggestionRecord) => ({
                        ...suggestionRecord,
                        iconName:
                            suggestionRecord.iconName ||
                            this.getDefaultSuggestionIcon(
                                searchType
                            )
                    })
                );

        } catch (error) {
            if (
                requestId !==
                this.latestSuggestionRequestId
            ) {
                return;
            }

            this.suggestionErrorMessage =
                this.getErrorMessage(error);

            this.suggestionOptions = [];

        } finally {
            if (
                requestId ===
                this.latestSuggestionRequestId
            ) {
                this.isSuggestionLoading = false;
            }
        }
    }

    getSearchTypeForField(fieldName) {
        switch (fieldName) {
            case 'mobileNo':
                return SEARCH_TYPE_MOBILE;

            case 'serialNumber':
                return SEARCH_TYPE_SERIAL;

            case 'customerName':
                return SEARCH_TYPE_CUSTOMER;

            default:
                return null;
        }
    }

    getSearchFieldValue(fieldName) {
        switch (fieldName) {
            case 'mobileNo':
                return this.mobileNo;

            case 'serialNumber':
                return this.serialNumber;

            case 'customerName':
                return this.customerName;

            default:
                return '';
        }
    }

    getDefaultSuggestionIcon(searchType) {
        if (searchType === SEARCH_TYPE_MOBILE) {
            return 'standard:contact';
        }

        if (searchType === SEARCH_TYPE_CUSTOMER) {
            return 'standard:account';
        }

        return 'standard:asset_object';
    }

    clearSelectedSuggestion() {
        this.selectedSuggestionId = null;
        this.selectedSuggestionType = null;
        this.selectedSuggestionLabel = null;
    }

    invalidateSuggestionRequests() {
        this.latestSuggestionRequestId += 1;

        if (this.suggestionDebounceId) {
            clearTimeout(this.suggestionDebounceId);
            this.suggestionDebounceId = null;
        }
    }

    clearSuggestionDisplay() {
        this.suggestionOptions = [];
        this.isSuggestionLoading = false;
        this.suggestionErrorMessage = null;
        this.activeSuggestionField = null;
    }

    closeSuggestionPanel() {
        if (this.suggestionBlurId) {
            clearTimeout(this.suggestionBlurId);
            this.suggestionBlurId = null;
        }

        this.clearSuggestionDisplay();
    }

    resetSuggestionState() {
        this.invalidateSuggestionRequests();
        this.closeSuggestionPanel();
        this.clearSelectedSuggestion();
    }

    async handleSearch() {
        const normalizedMobileNo =
            this.getTrimmedValue(this.mobileNo);

        if (normalizedMobileNo) {

            const phoneDigits =
                normalizedMobileNo
                    .replace(/\D/g, '');


            if (phoneDigits.length !== 10) {

                this.showToast(
                    'Invalid Phone Number',
                    'Phone / Mobile Number must contain exactly 10 digits.',
                    'warning'
                );

                return;
            }
        }

        const normalizedSerialNumber =
            this.getTrimmedValue(this.serialNumber);

        const normalizedCustomerName =
            this.getTrimmedValue(this.customerName);

        if (
            !normalizedMobileNo &&
            !normalizedSerialNumber &&
            !normalizedCustomerName
        ) {
            this.showToast(
                'Search Value Required',
                'Enter a Phone / Mobile Number, Asset Serial Number, or Customer Name before searching.',
                'warning'
            );
            return;
        }

        /*
            * Customer Name must come from an existing Account suggestion.
            * Phone/Mobile and Serial Number can be searched as exact typed
            * values so a true not-found response can offer the create flow.
            */
        if (
            normalizedCustomerName &&
            !this.hasSelectedSuggestion
        ) {
            this.showToast(
                'Select a Search Suggestion',
                'Select an existing Customer Name from the suggestion list. If the customer does not exist, search using Phone / Mobile Number instead.',
                'warning'
            );
            return;
        }

        this.mobileNo = normalizedMobileNo;
        this.serialNumber = normalizedSerialNumber;
        this.customerName = normalizedCustomerName;

        this.closeSuggestionPanel();

        this.isLoading = true;
        this.hasSearched = false;

        this.clearSearchResponse();

        try {
            const result = await searchAssetDetails({
                mobileNo: normalizedMobileNo,
                serialNumber: normalizedSerialNumber,
                customerName: normalizedCustomerName,
                selectedRecordId:
                    this.hasSelectedSuggestion
                        ? this.selectedSuggestionId
                        : null
            });

            if (!result || !result.found) {
                this.searchType =
                    result?.searchType ||
                    (
                        normalizedMobileNo
                            ? SEARCH_TYPE_MOBILE
                            : (
                                normalizedCustomerName
                                    ? SEARCH_TYPE_CUSTOMER
                                    : SEARCH_TYPE_SERIAL
                            )
                    );

                this.noResultMessage =
                    result?.message ||
                    'No matching records were found.';

                return;
            }

            this.searchType =
                result.searchType ||
                (
                    normalizedMobileNo
                        ? SEARCH_TYPE_MOBILE
                        : (
                            normalizedCustomerName
                                ? SEARCH_TYPE_CUSTOMER
                                : SEARCH_TYPE_SERIAL
                        )
                );

            this.account =
                result.account || null;

            this.isAccountSelected =
                Boolean(this.account?.accountId);

            this.matchedContacts =
                this.prepareContacts(
                    result.matchedContacts || []
                );

            this.contacts =
                this.prepareContacts(
                    result.contacts || []
                );

            this.assets =
                this.prepareAssets(
                    result.assets ||
                    (
                        result.asset
                            ? [result.asset]
                            : []
                    )
                );

            this.assetSerialNumbers =
                this.prepareAssetSerialNumbers(
                    result.assetSerialNumbers ||
                    (
                        result.assetSerialNumber
                            ? [result.assetSerialNumber]
                            : []
                    )
                );

            this.assetWarranties =
                this.prepareAssetWarranties(
                    result.assetWarranties || []
                );

            if (this.isSerialSearchResult) {
                const serialSearchRecord =
                    this.assetSerialNumbers.find(
                        (serialRecord) =>
                            serialRecord.assetSerialNumberId ===
                            result.assetSerialNumber
                                ?.assetSerialNumberId
                    ) ||
                    result.assetSerialNumber ||
                    null;

                if (!serialSearchRecord) {
                    throw new Error(
                        'The serial-number search returned incomplete Asset Serial Number information.'
                    );
                }

                this.selectAssetSerialNumbers(
                    [serialSearchRecord]
                );

                if (!this.asset) {
                    throw new Error(
                        'The selected Asset Serial Number is not linked to an accessible Asset.'
                    );
                }

            } else if (
                this.isAccountBasedSearchResult &&
                this.assetSerialNumbers.length === 1
            ) {
                this.selectAssetSerialNumbers(
                    [this.assetSerialNumbers[0]]
                );
            }

            const selectableContacts =
                this.isMobileSearchResult
                    ? this.matchedContacts
                    : this.contacts;

            if (selectableContacts.length === 1) {
                this.selectContact(
                    selectableContacts[0]
                );
            }

        } catch (error) {
            this.errorMessage =
                this.getErrorMessage(error);

        } finally {
            this.isLoading = false;
            this.hasSearched = true;
        }
    }

    handleAccountSelection(event) {
        this.isAccountSelected =
            Boolean(event.target.checked);
    }

    handleSelectionControlClick(event) {
        event.stopPropagation();
    }

    handleRecordLinkClick(event) {
        event.stopPropagation();
    }

    handleContactCardClick(event) {
        if (this.isLoading) {
            return;
        }

        const contactId =
            event.currentTarget?.dataset?.contactId;

        if (!contactId) {
            return;
        }

        const contactRecord =
            this.matchedContacts.find(
                (currentContact) =>
                    currentContact.contactId ===
                    contactId
            ) ||
            this.contacts.find(
                (currentContact) =>
                    currentContact.contactId ===
                    contactId
            );

        if (!contactRecord) {
            return;
        }

        if (
            this.selectedContact?.contactId ===
            contactId
        ) {
            this.clearSelectedContact();
            return;
        }

        this.selectContact(contactRecord);
    }

    handleContactCardSelection(event) {
        const contactId =
            event.target?.dataset?.contactId ||
            event.currentTarget?.dataset?.contactId;

        const isChecked =
            Boolean(event.target?.checked);

        if (!contactId) {
            return;
        }

        if (!isChecked) {
            if (
                this.selectedContact?.contactId ===
                contactId
            ) {
                this.clearSelectedContact();
            }
            return;
        }

        const contactRecord =
            this.matchedContacts.find(
                (currentContact) =>
                    currentContact.contactId ===
                    contactId
            ) ||
            this.contacts.find(
                (currentContact) =>
                    currentContact.contactId ===
                    contactId
            );

        if (contactRecord) {
            this.selectContact(
                contactRecord
            );
        }
    }

    selectContact(contactRecord) {
        this.selectedContact =
            contactRecord || null;

        const selectedContactId =
            contactRecord?.contactId || null;

        this.selectedContactRows =
            selectedContactId
                ? [selectedContactId]
                : [];

        this.updateContactSelectionState(
            selectedContactId
        );
    }

    clearSelectedContact() {
        this.selectedContact = null;
        this.selectedContactRows = [];

        this.updateContactSelectionState(
            null
        );
    }

    updateContactSelectionState(
        selectedContactId
    ) {
        const updateContactRecord =
            (contactRecord) => {
                const isSelected =
                    Boolean(
                        selectedContactId &&
                        contactRecord.contactId ===
                        selectedContactId
                    );

                return {
                    ...contactRecord,
                    isSelected,
                    cardClass: isSelected
                        ? 'selected-item-summary contact-summary-card contact-summary-card_selected'
                        : 'selected-item-summary contact-summary-card'
                };
            };

        this.matchedContacts =
            this.matchedContacts.map(
                updateContactRecord
            );

        this.contacts =
            this.contacts.map(
                updateContactRecord
            );
    }

    handleCombinedAssetSerialCardClick(event) {
        if (this.isLoading) {
            return;
        }

        const assetSerialNumberId =
            event.currentTarget?.dataset?.serialId;

        if (!assetSerialNumberId) {
            return;
        }

        const serialRecord =
            this.assetSerialNumbers.find(
                (currentSerialRecord) =>
                    currentSerialRecord
                        .assetSerialNumberId ===
                    assetSerialNumberId
            );

        if (!serialRecord) {
            return;
        }

        const alreadySelected =
            this.selectedAssetSerialNumbers.some(
                (selectedSerialRecord) =>
                    selectedSerialRecord
                        .assetSerialNumberId ===
                    assetSerialNumberId
            );

        if (alreadySelected) {
            const remainingSerialRecords =
                this.selectedAssetSerialNumbers.filter(
                    (selectedSerialRecord) =>
                        selectedSerialRecord
                            .assetSerialNumberId !==
                        assetSerialNumberId
                );

            if (remainingSerialRecords.length === 0) {
                this.clearSelectedSerialNumbers();
                return;
            }

            this.selectAssetSerialNumbers(
                remainingSerialRecords
            );
            return;
        }

        this.selectAssetSerialNumbers([
            ...this.selectedAssetSerialNumbers,
            serialRecord
        ]);
    }

    handleCombinedAssetSerialSelection(event) {
        const assetSerialNumberId =
            event.target?.dataset?.serialId ||
            event.currentTarget?.dataset?.serialId;

        const isChecked =
            Boolean(event.target?.checked);

        if (!assetSerialNumberId) {
            return;
        }

        const serialRecord =
            this.assetSerialNumbers.find(
                (currentSerialRecord) =>
                    currentSerialRecord
                        .assetSerialNumberId ===
                    assetSerialNumberId
            );

        if (!serialRecord) {
            return;
        }

        if (!isChecked) {
            const remainingSerialRecords =
                this.selectedAssetSerialNumbers.filter(
                    (selectedSerialRecord) =>
                        selectedSerialRecord
                            .assetSerialNumberId !==
                        assetSerialNumberId
                );

            if (remainingSerialRecords.length === 0) {
                this.clearSelectedSerialNumbers();
                return;
            }

            this.selectAssetSerialNumbers(
                remainingSerialRecords
            );
            return;
        }

        const alreadySelected =
            this.selectedAssetSerialNumbers.some(
                (selectedSerialRecord) =>
                    selectedSerialRecord
                        .assetSerialNumberId ===
                    assetSerialNumberId
            );

        if (alreadySelected) {
            return;
        }

        this.selectAssetSerialNumbers([
            ...this.selectedAssetSerialNumbers,
            serialRecord
        ]);
    }

    handleSerialNumberSelection(event) {
        const selectedRows =
            event.detail?.selectedRows || [];

        if (selectedRows.length === 0) {
            this.clearSelectedSerialNumbers();
            return;
        }

        this.selectAssetSerialNumbers(
            selectedRows
        );
    }

    handleSerialNumberCheckboxChange(event) {
        if (!event.target.checked) {
            this.clearSelectedSerialNumbers();
            return;
        }

        const serialSearchRecord =
            this.assetSerialNumbers[0] || null;

        if (serialSearchRecord) {
            this.selectAssetSerialNumbers(
                [serialSearchRecord]
            );
        }
    }

    selectAssetSerialNumbers(serialRecords) {
        const validSerialRecords =
            Array.isArray(serialRecords)
                ? serialRecords.filter(
                    (serialRecord) =>
                        serialRecord
                            ?.assetSerialNumberId
                )
                : [];

        if (validSerialRecords.length === 0) {
            this.clearSelectedSerialNumbers();
            return;
        }

        const uniqueSerialRecords = [];
        const processedSerialIds = new Set();

        validSerialRecords.forEach(
            (serialRecord) => {
                if (
                    processedSerialIds.has(
                        serialRecord
                            .assetSerialNumberId
                    )
                ) {
                    return;
                }

                processedSerialIds.add(
                    serialRecord
                        .assetSerialNumberId
                );

                uniqueSerialRecords.push(
                    serialRecord
                );
            }
        );

        this.selectedAssetSerialNumbers =
            uniqueSerialRecords;

        /*
            * The standard Case object supports one AssetId. The first selected
            * serial number supplies Case.AssetId. All selected Asset and Serial
            * Number IDs remain available in the casecreated event.
            */
        this.assetSerialNumber =
            uniqueSerialRecords[0] || null;

        this.selectedSerialRows =
            uniqueSerialRecords.map(
                (serialRecord) =>
                    serialRecord
                        .assetSerialNumberId
            );

        const caseAssetId =
            this.assetSerialNumber?.assetId;

        this.asset =
            caseAssetId
                ? (
                    this.assets.find(
                        (assetRecord) =>
                            assetRecord.assetId ===
                            caseAssetId
                    ) || null
                )
                : null;
    }

    clearSelectedSerialNumbers() {
        this.assetSerialNumber = null;
        this.selectedAssetSerialNumbers = [];
        this.asset = null;
        this.selectedSerialRows = [];
    }

    prepareContacts(contactRecords) {
        return contactRecords.map((contactRecord) => ({
            ...contactRecord,

            contactUrl: contactRecord.contactId
                ? `/lightning/r/Contact/${contactRecord.contactId}/view`
                : null,

            isSelected: false,

            cardClass:
                'selected-item-summary contact-summary-card'
        }));
    }

    prepareAssets(assetRecords) {
        return assetRecords.map((assetRecord) => ({
            ...assetRecord,

            assetUrl: assetRecord.assetId
                ? `/lightning/r/Asset/${assetRecord.assetId}/view`
                : null
        }));
    }

    prepareAssetSerialNumbers(serialRecords) {
        const assetNamesById =
            new Map(
                this.assets.map(
                    (assetRecord) => [
                        assetRecord.assetId,
                        assetRecord.assetName
                    ]
                )
            );

        return serialRecords.map((serialRecord) => ({
            ...serialRecord,

            assetName:
                serialRecord.assetName ||
                assetNamesById.get(
                    serialRecord.assetId
                ) ||
                '',

            assetSerialNumberUrl:
                serialRecord.assetSerialNumberId
                    ? `/lightning/r/Asset_Serial_No__c/${serialRecord.assetSerialNumberId}/view`
                    : null
        }));
    }

    prepareAssetWarranties(warrantyRecords) {
        const assetNamesById =
            new Map(
                this.assets.map(
                    (assetRecord) => [
                        assetRecord.assetId,
                        assetRecord.assetName
                    ]
                )
            );

        const serialNamesById =
            new Map(
                this.assetSerialNumbers.map(
                    (serialRecord) => [
                        serialRecord.assetSerialNumberId,
                        serialRecord.serialNumber
                    ]
                )
            );

        return warrantyRecords.map((warrantyRecord) => ({
            ...warrantyRecord,

            assetName:
                warrantyRecord.assetName ||
                assetNamesById.get(
                    warrantyRecord.assetId
                ) ||
                '',

            serialNumber:
                warrantyRecord.serialNumber ||
                serialNamesById.get(
                    warrantyRecord.assetSerialNumberId
                ) ||
                '',

            assetWarrantyUrl:
                warrantyRecord.assetWarrantyId
                    ? `/lightning/r/AssetWarranty/${warrantyRecord.assetWarrantyId}/view`
                    : null
        }));
    }

    handleNext() {
        if (
            !this.isAccountSelected ||
            !this.account?.accountId
        ) {
            this.showToast(
                'Account Required',
                'Select the Account before continuing.',
                'warning'
            );
            return;
        }

        this.isSearchStep = false;
        this.isCaseFormStep = true;

        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    }

    handleBack() {
        if (this.isSaving) {
            return;
        }

        this.isCaseFormStep = false;
        this.isSearchStep = true;

        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    }

    async handleCaseSubmit(event) {
        event.preventDefault();

        if (
            !this.isAccountSelected ||
            !this.account?.accountId
        ) {
            this.showToast(
                'Account Required',
                'The selected Account could not be identified.',
                'error'
            );
            return;
        }

        if (!this.validateExistingCaseInputs()) {

            this.showToast(
                'Required Information Missing',
                'Complete the required Case fields before saving.',
                'warning'
            );

            return;
        }

        const fields = {
            ...event.detail.fields
        };

        const selectedRecords =
            this.selectedAssetSerialCards.map(
                (selectedCard) => ({
                    assetId:
                        selectedCard.assetId,
                    assetSerialNumberId:
                        selectedCard
                            .assetSerialNumberId,
                    assetWarrantyIds:
                        (selectedCard.cardWarranties || [])
                            .map(
                                (warrantyRecord) =>
                                    warrantyRecord
                                        .assetWarrantyId
                            )
                            .filter(Boolean)
                })
            );

        this.isSaving = true;

        try {
            const saveResult =
                await createCaseWithRelatedRecords({
                    request: {
                        product:
                            fields[
                            CASE_PRODUCT.fieldApiName
                            ],

                        productCategory:
                            fields[
                            CASE_PRODUCT_CATEGORIES.fieldApiName
                            ],

                        origin:
                            fields[
                            CASE_ORIGIN.fieldApiName
                            ],

                        srtCaseStatus:
                            'New',

                        priority:
                            fields[
                            CASE_PRIORITY.fieldApiName
                            ],

                        description:
                            fields[
                            CASE_DESCRIPTION.fieldApiName
                            ],

                        customerType:
                            this.getTrimmedValue(
                                this.caseCustomerType
                            ),

                        stockType:
                            this.getTrimmedValue(
                                this.caseStockType
                            ),

                        dealerName:
                            this.getTrimmedValue(
                                this.caseDealerName
                            ),

                        dealerContactNo:
                            this.getTrimmedValue(
                                this.caseDealerContactNo
                            ),

                        complaintTypeSrt:
                            fields[
                            CASE_COMPLAINT_TYPE_SRT.fieldApiName
                            ],

                        complaintSubTypeSrt:
                            fields[
                            CASE_COMPLAINT_SUB_TYPE_SRT.fieldApiName
                            ],

                        complaintReason:
                            fields[
                            CASE_COMPLAINT_REASON.fieldApiName
                            ],

                        // failureCategory:
                        //     fields[
                        //     CASE_FAILURE_CATEGORY.fieldApiName
                        //     ],

                        // closureReason:
                        //     fields[
                        //     CASE_CLOSURE_REASON.fieldApiName
                        //     ],

                        accountId:
                            this.account.accountId,

                        contactId:
                            this.selectedContact?.contactId,

                        selectedRecords
                    }
                });

            this.isSaving = false;

            const displayCaseNumber =
                saveResult?.srtCaseNumber ||
                saveResult?.caseNumber ||
                '';

            this.showToast(
                'Case Created',
                `Case ${displayCaseNumber} and its related records were created successfully.`.trim(),
                'success'
            );

            this.dispatchEvent(
                new CustomEvent('casecreated', {
                    detail: {
                        caseId:
                            saveResult?.caseId,
                        caseNumber:
                            saveResult?.caseNumber,
                        srtCaseNumber:
                            saveResult?.srtCaseNumber,
                        accountId:
                            this.account?.accountId,
                        contactId:
                            this.selectedContact
                                ?.contactId,
                        assetIds:
                            this.selectedAssetIds,
                        assetSerialNumberIds:
                            this.selectedAssetSerialNumbers
                                .map(
                                    (serialRecord) =>
                                        serialRecord
                                            .assetSerialNumberId
                                ),
                        serialNumbers:
                            this.selectedAssetSerialNumbers
                                .map(
                                    (serialRecord) =>
                                        serialRecord
                                            .serialNumber
                                ),
                        relatedAssetCount:
                            saveResult
                                ?.relatedAssetCount,
                        relatedSerialNumberCount:
                            saveResult
                                ?.relatedSerialNumberCount,
                        relatedWarrantyCount:
                            saveResult
                                ?.relatedWarrantyCount
                    }
                })
            );

            const createdCaseId =
                saveResult?.caseId;

            if (!createdCaseId) {
                throw new Error(
                    'The Case was created, but its record Id was not returned.'
                );
            }

            /*
                * Full-window navigation forces the Lightning application and
                * this component to reload completely after successful save.
                */
            window.location.assign(
                `/lightning/r/Case/${createdCaseId}/view`
            );

        } catch (error) {
            this.isSaving = false;

            this.showToast(
                'Case Creation Failed',
                this.getErrorMessage(error),
                'error'
            );
        }
    }


    /*handleOpenNewCustomerCase() {
        if (
            !this.isMobileSearchResult &&
            !this.isSerialSearchResult
        ) {
            return;
        }
    
        this.closeSuggestionPanel();
        this.resetNewCustomerCaseForm();
    
        if (this.isMobileSearchResult) {
            this.newContactPhone =
                this.mobileNo;
        }
    
        this.isSearchStep = false;
        this.isCaseFormStep = false;
        this.isNewCustomerCaseStep = true;
    
        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    }*/

    handleOpenNewCustomerCase() {

        if (
            !this.isMobileSearchResult &&
            !this.isSerialSearchResult
        ) {
            return;
        }

        /*
         * Save searched phone before resetting
         * the New Customer form.
         */
        const searchedMobileNumber =
            this.isMobileSearchResult
                ? this.getTrimmedValue(
                    this.mobileNo
                )
                : '';


        this.closeSuggestionPanel();

        this.resetNewCustomerCaseForm();


        /*
         * If the user searched using Phone / Mobile No
         * and no existing Contact was found,
         * populate that searched number into
         * Account Details -> Mobile Number.
         */
        if (searchedMobileNumber) {

            // Account Details -> Mobile Number
            this.newAccountPhone =
                searchedMobileNumber;

            // The primary number is also the new Contact's Phone.
            this.newContactPhone = searchedMobileNumber;
        }


        this.isSearchStep = false;

        this.isCaseFormStep = false;

        this.isNewCustomerCaseStep = true;


        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    }

    handleNewCustomerInputChange(event) {
        const fieldName =
            event.target?.name;

        if (!fieldName) {
            return;
        }
        let value = event.target.value || '';

        const mobileFields = [
            'newAccountPhone',
            'newAccountMobile',
            'dealerContactNo'
        ];

        if (mobileFields.includes(fieldName)) {
            value = value
                .replace(/\D/g, '')
                .slice(0, 10);

            event.target.value = value;
            event.target.setCustomValidity('');

            if (value && value.length !== 10) {

                const errorMessage =
                    fieldName === 'dealerContactNo'
                        ? 'Dealer Contact Number must contain exactly 10 digits.'
                        : 'Mobile Number must contain exactly 10 digits.';

                event.target.setCustomValidity(
                    errorMessage
                );
            }

            event.target.reportValidity();
        }

        // Pincode - digits only and exactly 6 digits
        if (fieldName === 'newBillingPostalCode') {
            value = value
                .replace(/\D/g, '')
                .slice(0, 6);

            event.target.value = value;
            event.target.setCustomValidity('');

            if (value && value.length !== 6) {
                event.target.setCustomValidity(
                    'Pincode must contain exactly 6 digits.'
                );
            }

            event.target.reportValidity();
        }

        this[fieldName] = value;

        // Always mirror the primary Account number to Contact.Phone.
        if (fieldName === 'newAccountPhone') {
            this.newContactPhone = value;
        }



        if (fieldName === 'newCustomerType') {

            if (value === 'Dealer') {

                this.newStockType = '';

                // Dealer Contact No. is optional and manually entered
                this.dealerContactNo = '';

            } else if (value) {

                // Customer and Installer are always Sold
                this.newStockType = 'Sold';

                // Dealer fields are not applicable
                this.dealerName = '';
                this.dealerContactNo = '';

            } else {

                this.newStockType = '';
                this.dealerName = '';
                this.dealerContactNo = '';
            }
        }
    }

    handleBackFromNewCustomerCase() {
        if (this.isSaving) {
            return;
        }

        this.isNewCustomerCaseStep = false;
        this.isCaseFormStep = false;
        this.isSearchStep = true;

        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    }

    resetNewCustomerCaseForm() {
        this.newAccountName = '';
        this.newAccountPhone = '';
        this.newAccountMobile = '';
        this.newAccountEmail = '';
        this.newBuildingStreet = '';
        this.newDistrict = '';

        this.newBillingCity = '';
        this.newBillingState = '';
        this.newBillingPostalCode = '';

        this.newContactFirstName = '';
        this.newContactLastName = '';
        this.newContactPhone = '';
        this.newContactMobilePhone = '';
        this.newContactEmail = '';
        this.newCustomerType = '';
        this.dealerName = '';
        this.dealerContactNo = '';
        this.newStockType = 'Sold';

    }

    validateNewCustomerInputs() {
        const inputRecords =
            [
                ...this.template.querySelectorAll(
                    '[data-new-customer-input]'
                )
            ];

        return inputRecords.reduce(
            (allValid, inputRecord) => {
                inputRecord.reportValidity();

                return (
                    allValid &&
                    inputRecord.checkValidity()
                );
            },
            true
        );
    }

    validateExistingCaseInputs() {

        const inputRecords = [
            ...this.template.querySelectorAll(
                '[data-existing-case-input]'
            )
        ];

        return inputRecords.reduce(
            (allValid, inputRecord) => {

                inputRecord.reportValidity();

                return (
                    allValid &&
                    inputRecord.checkValidity()
                );
            },
            true
        );
    }

    async handleNewCustomerCaseSubmit(event) {

        event.preventDefault();

        if (!this.validateNewCustomerInputs()) {

            this.showToast(
                'Required Information Missing',
                'Complete the required Account and Contact fields before saving.',
                'warning'
            );

            return;
        }

        // Required even when the corresponding HTML field is not marked required.
        // This is the number saved in both Account.Phone and Contact.Phone.
        const primaryMobile = this.getTrimmedValue(this.newAccountPhone);
        if (!/^[6-9]\d{9}$/.test(primaryMobile)) {
            this.showToast(
                'Primary Mobile Number Required',
                'Enter a valid 10-digit primary mobile number before creating the customer and Case.',
                'warning'
            );
            return;
        }

        const fields = {
            ...event.detail.fields
        };


        this.isSaving = true;


        try {

            const saveResult =
                await createNewAccountContactAndCase({

                    request: {

                        /* ===============================
                           ACCOUNT
                           =============================== */

                        accountName:
                            this.getTrimmedValue(
                                this.newAccountName
                            ),

                        accountPhone:
                            this.getTrimmedValue(
                                this.newAccountPhone
                            ),

                        accountMobile:
                            this.getTrimmedValue(
                                this.newAccountMobile
                            ),

                        accountEmail:
                            this.getTrimmedValue(
                                this.newAccountEmail
                            ),


                        /* ===============================
                           CASE CUSTOMER DETAILS
                           =============================== */

                        customerType:
                            this.getTrimmedValue(
                                this.newCustomerType
                            ),

                        stockType:
                            this.getTrimmedValue(
                                this.newStockType
                            ),


                        /* ===============================
                           DEALER DETAILS
                           =============================== */

                        dealerName:
                            this.getTrimmedValue(
                                this.dealerName
                            ),

                        dealerContactNo:
                            this.getTrimmedValue(
                                this.dealerContactNo
                            ),


                        /* ===============================
                           BILLING ADDRESS
                           =============================== */

                        buildingStreet:
                            this.getTrimmedValue(
                                this.newBuildingStreet
                            ),

                        district:
                            this.getTrimmedValue(
                                this.newDistrict
                            ),

                        billingCity:
                            this.getTrimmedValue(
                                this.newBillingCity
                            ),

                        billingState:
                            this.getTrimmedValue(
                                this.newBillingState
                            ),

                        billingPostalCode:
                            this.getTrimmedValue(
                                this.newBillingPostalCode
                            ),


                        /* ===============================
                           CONTACT
                           =============================== */

                        contactFirstName:
                            this.getTrimmedValue(
                                this.newContactFirstName
                            ),

                        contactLastName:
                            this.getTrimmedValue(
                                this.newContactLastName
                            ),

                        // Same primary mobile number for the new Contact.
                        contactPhone:
                            this.getTrimmedValue(
                                this.newAccountPhone
                            ),

                        contactMobilePhone:
                            this.getTrimmedValue(
                                this.newContactMobilePhone
                            ),


                        /* ===============================
                           CASE
                           =============================== */

                        product:
                            fields[
                            CASE_PRODUCT.fieldApiName
                            ],

                        productCategory:
                            fields[
                            CASE_PRODUCT_CATEGORIES.fieldApiName
                            ],

                        origin:
                            fields[
                            CASE_ORIGIN.fieldApiName
                            ],

                        srtCaseStatus:
                            fields[
                            CASE_SRT_STATUS.fieldApiName
                            ],

                        priority:
                            fields[
                            CASE_PRIORITY.fieldApiName
                            ],

                        description:
                            fields[
                            CASE_DESCRIPTION.fieldApiName
                            ],

                        complaintTypeSrt:
                            fields[
                            CASE_COMPLAINT_TYPE_SRT.fieldApiName
                            ],

                        complaintSubTypeSrt:
                            fields[
                            CASE_COMPLAINT_SUB_TYPE_SRT.fieldApiName
                            ],

                        complaintReason:
                            fields[
                            CASE_COMPLAINT_REASON.fieldApiName
                            ],

                        failureCategory:
                            fields[
                            CASE_FAILURE_CATEGORY.fieldApiName
                            ],

                        closureReason:
                            fields[
                            CASE_CLOSURE_REASON.fieldApiName
                            ]
                    }
                });


            const createdCaseId =
                saveResult?.caseId;


            if (!createdCaseId) {

                throw new Error(
                    'The records were created, but the Case Id was not returned.'
                );
            }


            const displayCaseNumber =
                saveResult?.srtCaseNumber ||
                saveResult?.caseNumber ||
                '';


            this.showToast(
                'Customer and Case Created',
                `Account, Contact and Case ${displayCaseNumber} were created successfully.`.trim(),
                'success'
            );


            window.location.assign(
                `/lightning/r/Case/${createdCaseId}/view`
            );


        } catch (error) {

            this.isSaving = false;


            this.showToast(
                'Creation Failed',
                this.getErrorMessage(error),
                'error'
            );
        }
    }
    handleReset() {
        if (this.isLoading || this.isSaving) {
            return;
        }

        this.mobileNo = '';
        this.serialNumber = '';
        this.customerName = '';

        this.resetSuggestionState();
        this.clearSearchResponse();

        this.hasSearched = false;
    }

    clearSearchResponse() {
        this.searchType = null;

        this.assetSerialNumber = null;
        this.selectedAssetSerialNumbers = [];
        this.account = null;
        this.asset = null;
        this.selectedContact = null;

        this.matchedContacts = [];
        this.contacts = [];
        this.assets = [];
        this.assetSerialNumbers = [];
        this.assetWarranties = [];

        this.isAccountSelected = false;
        this.selectedContactRows = [];
        this.selectedSerialRows = [];

        this.errorMessage = null;
        this.noResultMessage = null;

        this.caseCustomerType = '';
        this.caseStockType = 'Sold';
        this.caseDealerName = '';
        this.caseDealerContactNo = '';
    }

    resetCompleteComponent() {
        this.mobileNo = '';
        this.serialNumber = '';
        this.customerName = '';

        this.resetSuggestionState();
        this.clearSearchResponse();

        this.isLoading = false;
        this.isSaving = false;
        this.hasSearched = false;

        this.isCaseFormStep = false;
        this.isNewCustomerCaseStep = false;
        this.isSearchStep = true;

        this.resetNewCustomerCaseForm();
    }

    getTrimmedValue(value) {
        return value
            ? value.trim()
            : '';
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

    getErrorMessage(error) {
        if (Array.isArray(error?.body)) {
            return error.body
                .map((item) => item.message)
                .filter(Boolean)
                .join(', ');
        }

        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred while searching customer and Asset details.';
    }

    getRecordFormErrorMessage(event) {
        const fieldErrors =
            event.detail?.output?.fieldErrors;

        if (fieldErrors) {
            const messages = [];

            Object.keys(fieldErrors).forEach(
                (fieldName) => {
                    fieldErrors[fieldName].forEach(
                        (fieldError) => {
                            if (fieldError.message) {
                                messages.push(
                                    fieldError.message
                                );
                            }
                        }
                    );
                }
            );

            if (messages.length > 0) {
                return messages.join(', ');
            }
        }

        return (
            event.detail?.detail ||
            event.detail?.message ||
            'The Case could not be created.'
        );
    }

    get isMobileSearchDisabled() {
        return (
            this.isLoading ||
            Boolean(
                this.getTrimmedValue(
                    this.serialNumber
                ) ||
                this.getTrimmedValue(
                    this.customerName
                )
            )
        );
    }

    get isSerialSearchDisabled() {
        return (
            this.isLoading ||
            Boolean(
                this.getTrimmedValue(
                    this.mobileNo
                ) ||
                this.getTrimmedValue(
                    this.customerName
                )
            )
        );
    }

    get isCustomerSearchDisabled() {
        return (
            this.isLoading ||
            Boolean(
                this.getTrimmedValue(
                    this.mobileNo
                ) ||
                this.getTrimmedValue(
                    this.serialNumber
                )
            )
        );
    }

    get isSearchDisabled() {

        if (
            this.isLoading ||
            this.isSuggestionLoading
        ) {
            return true;
        }


        const currentSearchType =
            this.currentPopulatedSearchType;


        if (!currentSearchType) {
            return true;
        }


        /*
         * Phone / Mobile Number must
         * contain exactly 10 digits.
         */
        if (
            currentSearchType ===
            SEARCH_TYPE_MOBILE
        ) {

            const phoneDigits =
                (this.mobileNo || '')
                    .replace(/\D/g, '');


            return phoneDigits.length !== 10;
        }


        if (
            currentSearchType ===
            SEARCH_TYPE_CUSTOMER
        ) {
            return !this.hasSelectedSuggestion;
        }


        return false;
    }

    get currentPopulatedSearchType() {
        if (this.getTrimmedValue(this.mobileNo)) {
            return SEARCH_TYPE_MOBILE;
        }

        if (this.getTrimmedValue(this.customerName)) {
            return SEARCH_TYPE_CUSTOMER;
        }

        if (this.getTrimmedValue(this.serialNumber)) {
            return SEARCH_TYPE_SERIAL;
        }

        return null;
    }

    get hasSelectedSuggestion() {
        return Boolean(
            this.selectedSuggestionId &&
            this.selectedSuggestionType &&
            this.selectedSuggestionType ===
            this.currentPopulatedSearchType
        );
    }

    get isMobileSuggestionSelected() {
        return (
            this.hasSelectedSuggestion &&
            this.selectedSuggestionType ===
            SEARCH_TYPE_MOBILE
        );
    }

    get isSerialSuggestionSelected() {
        return (
            this.hasSelectedSuggestion &&
            this.selectedSuggestionType ===
            SEARCH_TYPE_SERIAL
        );
    }

    get isCustomerSuggestionSelected() {
        return (
            this.hasSelectedSuggestion &&
            this.selectedSuggestionType ===
            SEARCH_TYPE_CUSTOMER
        );
    }

    get showMobileSuggestionPanel() {
        return (
            this.activeSuggestionField ===
            'mobileNo' &&
            this.hasSuggestionPanelContent
        );
    }

    get showSerialSuggestionPanel() {
        return (
            this.activeSuggestionField ===
            'serialNumber' &&
            this.hasSuggestionPanelContent
        );
    }

    get showCustomerSuggestionPanel() {
        return (
            this.activeSuggestionField ===
            'customerName' &&
            this.hasSuggestionPanelContent
        );
    }

    get hasSuggestionPanelContent() {
        return Boolean(
            this.isSuggestionLoading ||
            this.suggestionErrorMessage ||
            this.suggestionOptions.length > 0 ||
            this.activeSuggestionField
        );
    }

    get hasSuggestionOptions() {
        return (
            Array.isArray(this.suggestionOptions) &&
            this.suggestionOptions.length > 0
        );
    }

    get showSuggestionEmptyState() {
        return (
            !this.isSuggestionLoading &&
            !this.suggestionErrorMessage &&
            !this.hasSuggestionOptions &&
            Boolean(this.activeSuggestionField)
        );
    }

    get isSerialSearchResult() {
        return this.searchType === SEARCH_TYPE_SERIAL;
    }

    get isMobileSearchResult() {
        return this.searchType === SEARCH_TYPE_MOBILE;
    }

    get isCustomerSearchResult() {
        return this.searchType === SEARCH_TYPE_CUSTOMER;
    }

    get isAccountBasedSearchResult() {
        return (
            this.isMobileSearchResult ||
            this.isCustomerSearchResult
        );
    }

    get resultTitle() {
        if (this.isMobileSearchResult) {
            return 'Phone / Mobile Number Search Result';
        }

        if (this.isCustomerSearchResult) {
            return 'Customer Name Search Result';
        }

        return 'Asset Search Result';
    }

    get searchCriteriaText() {
        if (this.isMobileSearchResult) {
            return `Phone / Mobile No: ${this.mobileNo}`;
        }

        if (this.isCustomerSearchResult) {
            return `Customer Name: ${this.customerName}`;
        }

        if (this.isSerialSearchResult) {
            return `Serial No: ${this.assetSerialNumber?.serialNumber || this.serialNumber}`;
        }

        return '';
    }

    get resultCountText() {
        if (this.isAccountBasedSearchResult) {
            return `${this.assetCount} Asset(s)`;
        }

        return 'Asset Found';
    }

    get loadingAlternativeText() {
        if (this.getTrimmedValue(this.mobileNo)) {
            return 'Searching Contact Phone / Mobile Number';
        }

        if (this.getTrimmedValue(this.customerName)) {
            return 'Searching Customer Name';
        }

        return 'Searching Asset Serial Number';
    }

    get loadingMessage() {
        if (
            this.getTrimmedValue(this.mobileNo) ||
            this.getTrimmedValue(this.customerName)
        ) {
            return 'Please wait, customer and related Asset details are being searched...';
        }

        return 'Please wait, Asset details are being searched...';
    }

    get hasResults() {
        if (this.isAccountBasedSearchResult) {
            return Boolean(this.account);
        }

        if (this.isSerialSearchResult) {
            return Boolean(this.asset);
        }

        return false;
    }

    get showNoResults() {
        return (
            this.hasSearched &&
            !this.isLoading &&
            !this.hasResults &&
            !this.errorMessage &&
            Boolean(this.noResultMessage)
        );
    }

    get showCreateNewCustomerCaseButton() {
        return (
            this.showNoResults &&
            (
                this.isMobileSearchResult ||
                this.isSerialSearchResult
            )
        );
    }

    get showSearchError() {
        return (
            this.hasSearched &&
            !this.isLoading &&
            Boolean(this.errorMessage)
        );
    }

    get hasMatchedContacts() {
        return (
            Array.isArray(this.matchedContacts) &&
            this.matchedContacts.length > 0
        );
    }

    get hasContacts() {
        return (
            Array.isArray(this.contacts) &&
            this.contacts.length > 0
        );
    }

    get hasAssets() {
        return (
            Array.isArray(this.assets) &&
            this.assets.length > 0
        );
    }

    get hasAssetSerialNumbers() {
        return (
            Array.isArray(this.assetSerialNumbers) &&
            this.assetSerialNumbers.length > 0
        );
    }

    get hasAssetWarranties() {
        return (
            Array.isArray(this.assetWarranties) &&
            this.assetWarranties.length > 0
        );
    }

    get combinedAssetSerialCards() {
        const assetsById =
            new Map(
                this.assets.map(
                    (assetRecord) => [
                        assetRecord.assetId,
                        assetRecord
                    ]
                )
            );

        const warrantiesByAssetId =
            new Map();

        const warrantiesBySerialId =
            new Map();

        this.assetWarranties.forEach(
            (warrantyRecord) => {
                const assetId =
                    warrantyRecord.assetId;

                const assetSerialNumberId =
                    warrantyRecord
                        .assetSerialNumberId;

                /*
                    * Add only true Asset-level warranties to the Asset bucket.
                    * A warranty that already has Asset_Serial_No__c must appear
                    * only inside that exact serial-number card.
                    */
                if (
                    assetId &&
                    !assetSerialNumberId
                ) {
                    if (
                        !warrantiesByAssetId.has(
                            assetId
                        )
                    ) {
                        warrantiesByAssetId.set(
                            assetId,
                            []
                        );
                    }

                    warrantiesByAssetId.get(assetId)
                        .push(warrantyRecord);
                }

                if (assetSerialNumberId) {
                    if (
                        !warrantiesBySerialId.has(
                            assetSerialNumberId
                        )
                    ) {
                        warrantiesBySerialId.set(
                            assetSerialNumberId,
                            []
                        );
                    }

                    warrantiesBySerialId
                        .get(assetSerialNumberId)
                        .push(warrantyRecord);
                }
            }
        );

        const selectedSerialIds =
            new Set(
                this.selectedAssetSerialNumbers.map(
                    (serialRecord) =>
                        serialRecord
                            .assetSerialNumberId
                )
            );

        return this.assetSerialNumbers.map(
            (serialRecord) => {
                const assetRecord =
                    assetsById.get(
                        serialRecord.assetId
                    ) || {};

                const assetLevelWarranties =
                    warrantiesByAssetId.get(
                        serialRecord.assetId
                    ) || [];

                const serialLevelWarranties =
                    warrantiesBySerialId.get(
                        serialRecord
                            .assetSerialNumberId
                    ) || [];

                const relatedWarranties = [];
                const processedWarrantyIds =
                    new Set();

                [
                    ...assetLevelWarranties,
                    ...serialLevelWarranties
                ].forEach(
                    (warrantyRecord) => {
                        const warrantyId =
                            warrantyRecord
                                .assetWarrantyId;

                        if (
                            warrantyId &&
                            processedWarrantyIds.has(
                                warrantyId
                            )
                        ) {
                            return;
                        }

                        if (warrantyId) {
                            processedWarrantyIds.add(
                                warrantyId
                            );
                        }

                        relatedWarranties.push(
                            warrantyRecord
                        );
                    }
                );

                const isSelected =
                    selectedSerialIds.has(
                        serialRecord
                            .assetSerialNumberId
                    );

                return {
                    ...assetRecord,
                    ...serialRecord,

                    isSelected,

                    cardClass: isSelected
                        ? 'asset-serial-card asset-serial-card_selected'
                        : 'asset-serial-card',

                    assetUrl:
                        assetRecord.assetId
                            ? `/lightning/r/Asset/${assetRecord.assetId}/view`
                            : null,

                    assetSerialNumberUrl:
                        serialRecord.assetSerialNumberId
                            ? `/lightning/r/Asset_Serial_No__c/${serialRecord.assetSerialNumberId}/view`
                            : null,

                    cardWarranties:
                        relatedWarranties,

                    hasCardWarranties:
                        relatedWarranties.length > 0,

                    warrantyCount:
                        relatedWarranties.length
                };
            }
        );
    }

    get hasCombinedAssetSerialCards() {
        return (
            Array.isArray(
                this.combinedAssetSerialCards
            ) &&
            this.combinedAssetSerialCards.length > 0
        );
    }

    get selectedAssetSerialCards() {
        return this.combinedAssetSerialCards
            .filter(
                (combinedRecord) =>
                    combinedRecord.isSelected
            )
            .map(
                (combinedRecord) => ({
                    ...combinedRecord,
                    cardClass:
                        'asset-serial-card asset-serial-card_selected asset-serial-card_review'
                })
            );
    }

    get hasSelectedAssetSerialCards() {
        return (
            Array.isArray(
                this.selectedAssetSerialCards
            ) &&
            this.selectedAssetSerialCards.length > 0
        );
    }

    get hasSelectedAssetSerialNumber() {
        return Boolean(
            this.selectedAssetSerialNumbers.length > 0 &&
            this.asset?.assetId
        );
    }

    get isAssetSerialNumberSelected() {
        return Boolean(
            this.assetSerialNumber?.assetSerialNumberId &&
            this.selectedSerialRows.includes(
                this.assetSerialNumber
                    .assetSerialNumberId
            )
        );
    }

    get selectedAssetName() {
        return this.asset?.assetName || '';
    }

    get selectedAssetIds() {
        return [
            ...new Set(
                this.selectedAssetSerialNumbers
                    .map(
                        (serialRecord) =>
                            serialRecord.assetId
                    )
                    .filter(Boolean)
            )
        ];
    }

    get selectedAssetCount() {
        return this.selectedAssetIds.length;
    }

    get selectedAssetNamesText() {
        const assetNamesById =
            new Map(
                this.assets.map(
                    (assetRecord) => [
                        assetRecord.assetId,
                        assetRecord.assetName
                    ]
                )
            );

        const selectedAssetNames =
            this.selectedAssetIds
                .map(
                    (assetId) =>
                        assetNamesById.get(assetId)
                )
                .filter(Boolean);

        return selectedAssetNames.length > 0
            ? selectedAssetNames.join(', ')
            : '—';
    }

    get selectedAssetSerialNumberCount() {
        return this.selectedAssetSerialNumbers.length;
    }

    get selectedAssetSerialNumbersText() {
        const selectedSerialNumbers =
            this.selectedAssetSerialNumbers
                .map(
                    (serialRecord) =>
                        serialRecord.serialNumber
                )
                .filter(Boolean);

        return selectedSerialNumbers.length > 0
            ? selectedSerialNumbers.join(', ')
            : '—';
    }

    get selectedContactName() {
        return (
            this.selectedContact?.contactName ||
            '—'
        );
    }

    get matchedContactCount() {
        return this.matchedContacts.length;
    }

    get contactCount() {
        return this.contacts.length;
    }

    get assetCount() {
        return this.assets.length;
    }

    get serialNumberCount() {
        return this.assetSerialNumbers.length;
    }

    get warrantyCount() {
        return this.assetWarranties.length;
    }

    get isNextDisabled() {
        return (
            this.isLoading ||
            !this.isAccountSelected ||
            !this.account?.accountId
        );
    }
}