import { LightningElement, api, wire } from 'lwc';

import { CloseActionScreenEvent }
    from 'lightning/actions';

import { ShowToastEvent }
    from 'lightning/platformShowToastEvent';

import {
    getObjectInfo,
    getPicklistValues
} from 'lightning/uiObjectInfoApi';

import ASSET_WARRANTY_OBJECT
    from '@salesforce/schema/AssetWarranty';

import ASSET_OBJECT
    from '@salesforce/schema/Asset';

import ASSET_PRODUCT_PICKLIST
    from '@salesforce/schema/Asset.Product_2__c';

import ASSET_PRODUCT_CATEGORY_PICKLIST
    from '@salesforce/schema/Asset.Product_Categoriess__c';

import APPROVAL_STATUS_FIELD
    from '@salesforce/schema/AssetWarranty.Approval_Status__c';

import WARRANTY_TYPE_FIELD
    from '@salesforce/schema/AssetWarranty.WarrantyType';

import CUSTOM_WARRANTY_TYPE_FIELD
    from '@salesforce/schema/AssetWarranty.Type__c';

import getCaseContext
    from '@salesforce/apex/CaseAssetCreationController.getCaseContext';

import getProductWarrantyDetailsByName
    from '@salesforce/apex/CaseAssetCreationController.getProductWarrantyDetailsByName';

import createAssetBundle
    from '@salesforce/apex/CaseAssetCreationController.createAssetBundle';


export default class CaseAssetCreation extends LightningElement {

    _recordId;

    contextLoadedForRecordId;

    keyCounter = 0;

    isLoading = false;

    caseLoaded = false;

    caseContext = {};

    uploadedFileCount = 0;

    approvalStatusOptions = [];

    warrantyTypeOptions = [];

    customWarrantyTypeOptions = [];

    productOptions = [];

    productCategoryOptions = [];

    productCategoryPicklistData;


    /* =========================================================
       FORM
       ========================================================= */

    form = {

        productName: null,

        productCategory: null,

        productId: null,

        orderProductId: null,

        purchaseDate: null,

        installDate: null,

        invoiceNumber: '',

        invoiceDate: null,

        batchNumber: '',

        quantity: null,

        siteName: '',

        address: '',

        city: '',

        state: '',

        country: '',

        pinCode: '',

        dealerName: '',

        dealerPhone: '',

        dealerAddress: '',

        description: '',


        /*
         * Existing Asset warranty values.
         */

        productWarrantyDuration: null,

        performanceWarrantyDuration: null,

        assetProductWarrantyEndDate: null,

        assetPerformanceWarrantyEndDate: null,


        /*
         * Case Related Asset warranty values.
         */

        productWarrantyDurationUnit: null,

        warrantyStartDate: null,

        warrantyEndDate: null,

        warrantyStatus: 'Validation Required'
    };


    serials = [
        {
            key: 'serial-1',
            title: 'Serial Number 1',
            serialNumber: '',
            productWarrantyEndDate: null,
            performanceWarrantyEndDate: null,

            warranties: [
                {
                    key: 'warranty-1',
                    title: 'Warranty 1',

                    startDate: null,
                    endDate: null,
                    warrantyStatus: 'Validation Required',

                    approvalStatus: null,
                    warrantyType: null,
                    customWarrantyType: null,

                    transferable: false,

                    laborCovered: null,
                    partsCovered: null,
                    expensesCovered: null,

                    laborCoveredEndDate: null,
                    partsCoveredEndDate: null,
                    expensesCoveredEndDate: null,

                    exclusions: ''
                }
            ],

            hasWarranties: true
        }
    ];


    /* =========================================================
       RECORD ID
       ========================================================= */

    @api
    set recordId(value) {

        this._recordId = value;

        if (
            value &&
            value !== this.contextLoadedForRecordId
        ) {

            this.contextLoadedForRecordId = value;

            this.loadCaseContext();
        }
    }


    get recordId() {

        return this._recordId;
    }


    get hasSerials() {

        return this.serials.length > 0;
    }


    /* =========================================================
   ASSET PRODUCT / CATEGORY PICKLISTS
   ========================================================= */

    @wire(getObjectInfo, {
        objectApiName: ASSET_OBJECT
    })
    assetObjectInfo;


    get assetRecordTypeId() {

        return this.assetObjectInfo
            ?.data
            ?.defaultRecordTypeId;
    }


    @wire(getPicklistValues, {
        recordTypeId: '$assetRecordTypeId',
        fieldApiName: ASSET_PRODUCT_PICKLIST
    })
    wiredProductPicklist({ data, error }) {

        if (data) {

            this.productOptions =
                data.values.map(item => ({
                    label: item.label,
                    value: item.value
                }));

        } else if (error) {

            this.productOptions = [];
        }
    }


    @wire(getPicklistValues, {
        recordTypeId: '$assetRecordTypeId',
        fieldApiName: ASSET_PRODUCT_CATEGORY_PICKLIST
    })
    wiredProductCategoryPicklist({ data, error }) {

        if (data) {

            this.productCategoryPicklistData =
                data;


            /*
             * If Case Product has already loaded,
             * populate its dependent categories now.
             */
            this.populateProductCategoryOptions(
                this.form.productName
            );

        } else if (error) {

            this.productCategoryPicklistData =
                null;

            this.productCategoryOptions = [];
        }
    }


    get isProductCategoryDisabled() {

        return !this.form.productName;
    }

    /* =========================================================
       WARRANTY OBJECT
       ========================================================= */

    @wire(getObjectInfo, {
        objectApiName: ASSET_WARRANTY_OBJECT
    })
    assetWarrantyInfo;


    get assetWarrantyRecordTypeId() {

        return this.assetWarrantyInfo
            ?.data
            ?.defaultRecordTypeId;
    }


    @wire(getPicklistValues, {
        recordTypeId:
            '$assetWarrantyRecordTypeId',

        fieldApiName:
            APPROVAL_STATUS_FIELD
    })
    wiredApprovalStatus({ data }) {

        if (data) {

            this.approvalStatusOptions =
                data.values.map(item => ({
                    label: item.label,
                    value: item.value
                }));
        }
    }


    @wire(getPicklistValues, {
        recordTypeId:
            '$assetWarrantyRecordTypeId',

        fieldApiName:
            WARRANTY_TYPE_FIELD
    })
    wiredWarrantyType({ data }) {

        if (data) {

            this.warrantyTypeOptions =
                data.values.map(item => ({
                    label: item.label,
                    value: item.value
                }));
        }
    }


    @wire(getPicklistValues, {
        recordTypeId:
            '$assetWarrantyRecordTypeId',

        fieldApiName:
            CUSTOM_WARRANTY_TYPE_FIELD
    })
    wiredCustomWarrantyType({ data }) {

        if (data) {

            this.customWarrantyTypeOptions =
                data.values.map(item => ({
                    label: item.label,
                    value: item.value
                }));
        }
    }


    /* =========================================================
       CASE
       ========================================================= */

    async loadCaseContext() {

        if (!this.recordId) {
            return;
        }

        this.isLoading = true;

        try {

            const result =
                await getCaseContext({
                    caseId: this.recordId
                });


            const productName =
                result?.Product__c ||
                null;


            const productCategory =
                result?.Product_Categories__c ||
                null;


            this.caseContext = {

                caseId:
                    result?.Id,

                caseNumber:
                    result?.CaseNumber,

                subject:
                    result?.Subject,

                accountId:
                    result?.AccountId,

                accountName:
                    result?.Account?.Name,

                contactId:
                    result?.ContactId,

                contactName:
                    result?.Contact?.Name,

                productName,

                productCategory
            };


            /*
             * Initially populate Product and Product Category
             * from the Case.
             *
             * They remain editable in the UI.
             */
            this.form = {

                ...this.form,

                productName,

                productCategory,

                productId:
                    null
            };


            /*
             * Populate dependent Product Category options
             * for the Product coming from Case.
             */
            this.populateProductCategoryOptions(
                productName
            );


            /*
             * Resolve Product2 Id and warranty information.
             */
            if (productName) {

                const warrantyResult =
                    await getProductWarrantyDetailsByName({
                        productName
                    });


                this.form = {

                    ...this.form,

                    productId:
                        warrantyResult?.productId ||
                        null,

                    productWarrantyDuration:
                        warrantyResult?.warrantyDuration ??
                        null,

                    productWarrantyDurationUnit:
                        warrantyResult?.warrantyDurationUnit ??
                        null
                };


                this.updateWarrantyCalculation(
                    this.form.invoiceDate
                );
            }


            this.caseLoaded = true;

        } catch (error) {

            this.showToast(
                'Unable to Load Case',
                this.getErrorMessage(error),
                'error'
            );

        } finally {

            this.isLoading = false;
        }
    }

    populateProductCategoryOptions(
        productName
    ) {

        let categoryOptions = [];


        if (
            productName &&
            this.productCategoryPicklistData
        ) {

            const controllerValues =
                this.productCategoryPicklistData
                    .controllerValues ||
                {};


            const controllingIndex =
                controllerValues[
                productName
                ];


            if (
                controllingIndex !==
                undefined
            ) {

                categoryOptions =
                    this.productCategoryPicklistData
                        .values
                        .filter(
                            item =>
                                item.validFor.includes(
                                    controllingIndex
                                )
                        )
                        .map(
                            item => ({
                                label:
                                    item.label,

                                value:
                                    item.value
                            })
                        );
            }
        }


        this.productCategoryOptions =
            categoryOptions;
    }


    /* =========================================================
   FILE UPLOAD
   ========================================================= */

    handleUploadFinished(event) {

        const uploadedFiles =
            event.detail.files || [];


        this.uploadedFileCount +=
            uploadedFiles.length;


        const fileNames =
            uploadedFiles
                .map(file => file.name)
                .join(', ');


        this.showToast(
            'Files Uploaded Successfully',
            uploadedFiles.length === 1
                ? `${fileNames} has been attached to the Case.`
                : `${uploadedFiles.length} files have been attached to the Case.`,
            'success'
        );
    }

    /* =========================================================
       COMMON ASSET FIELD
       ========================================================= */

    handleInputChange(event) {

        const fieldName =
            event.target.name;


        if (!fieldName) {
            return;
        }


        let value =
            event.target.type === 'checkbox'
                ? event.target.checked
                : event.target.value;


        if (value === '') {
            value = null;
        }


        this.form = {

            ...this.form,

            [fieldName]:
                value
        };


        /*
         * Invoice Date drives warranty calculation.
         */
        if (
            fieldName === 'invoiceDate'
        ) {

            this.updateWarrantyCalculation(
                value
            );
        }
    }


    /* =========================================================
       PRODUCT
       ========================================================= */

    async handleProductChange(event) {

        const productName =
            event.detail.value ||
            null;


        this.populateProductCategoryOptions(
            productName
        );


        this.form = {

            ...this.form,

            productName,

            /*
             * Product changed manually,
             * so clear old Product Category.
             */
            productCategory:
                null,

            productId:
                null,

            productWarrantyDuration:
                null,

            productWarrantyDurationUnit:
                null,

            warrantyStartDate:
                this.form.invoiceDate,

            warrantyEndDate:
                null,

            warrantyStatus:
                'Validation Required'
        };


        if (!productName) {

            this.updateWarrantyCalculation(
                this.form.invoiceDate
            );

            return;
        }


        this.isLoading = true;


        try {

            const result =
                await getProductWarrantyDetailsByName({
                    productName
                });


            this.form = {

                ...this.form,

                productId:
                    result?.productId ||
                    null,

                productWarrantyDuration:
                    result?.warrantyDuration ??
                    null,

                productWarrantyDurationUnit:
                    result?.warrantyDurationUnit ??
                    null
            };


            this.updateWarrantyCalculation(
                this.form.invoiceDate
            );


        } catch (error) {

            this.showToast(
                'Unable to Load Warranty',
                this.getErrorMessage(error),
                'error'
            );


        } finally {

            this.isLoading = false;
        }
    }

    handleProductCategoryChange(event) {

        this.form = {

            ...this.form,

            productCategory:
                event.detail.value ||
                null
        };
    }


    /* =========================================================
       WARRANTY CALCULATION
       ========================================================= */

    updateWarrantyCalculation(invoiceDate) {

        const duration =
            this.form.productWarrantyDuration;

        const unit =
            this.form.productWarrantyDurationUnit;


        let endDate = null;

        let status =
            'Validation Required';


        /*
         * Warranty can only be calculated when:
         *
         * Invoice Date exists
         * Product warranty duration exists
         * Duration unit exists
         */
        if (
            invoiceDate &&
            duration !== null &&
            duration !== undefined &&
            duration !== '' &&
            unit
        ) {

            endDate =
                this.calculateWarrantyEndDate(
                    invoiceDate,
                    duration,
                    unit
                );


            if (endDate) {

                const today =
                    new Date();


                const todayString =
                    this.formatDateForComparison(
                        today
                    );


                status =
                    todayString <= endDate
                        ? 'Active'
                        : 'Expired';
            }
        }


        /*
         * Update default warranty information.
         */
        this.form = {

            ...this.form,

            warrantyStartDate:
                invoiceDate || null,

            warrantyEndDate:
                endDate,

            warrantyStatus:
                status
        };


        /*
         * IMPORTANT:
         *
         * Update EVERY warranty under EVERY serial.
         *
         * This means Warranty 1, Warranty 2,
         * Warranty 3 etc. all receive the same
         * calculated dates.
         */
        this.serials =
            this.serials.map(serial => {

                const warranties =
                    (serial.warranties || [])
                        .map(warranty => {

                            return {

                                ...warranty,

                                startDate:
                                    invoiceDate ||
                                    null,

                                endDate:
                                    endDate,

                                warrantyStatus:
                                    status
                            };
                        });


                return {

                    ...serial,

                    warranties,

                    hasWarranties:
                        warranties.length > 0
                };
            });
    }


    /* =========================================================
       CALCULATE WARRANTY END DATE
       ========================================================= */

    calculateWarrantyEndDate(
        startDate,
        duration,
        unit
    ) {

        if (
            !startDate ||
            duration === null ||
            duration === undefined ||
            !unit
        ) {

            return null;
        }


        const date =
            new Date(
                startDate + 'T00:00:00'
            );


        const numericDuration =
            Number(duration);


        if (
            Number.isNaN(
                numericDuration
            )
        ) {

            return null;
        }


        const normalizedUnit =
            String(unit)
                .trim()
                .toLowerCase();


        /*
         * Years
         */
        if (
            normalizedUnit === 'year' ||
            normalizedUnit === 'years' ||
            normalizedUnit === 'yr' ||
            normalizedUnit === 'yrs'
        ) {

            date.setFullYear(
                date.getFullYear() +
                numericDuration
            );


            /*
             * Months
             */
        } else if (
            normalizedUnit === 'month' ||
            normalizedUnit === 'months' ||
            normalizedUnit === 'mon' ||
            normalizedUnit === 'mons'
        ) {

            date.setMonth(
                date.getMonth() +
                numericDuration
            );


            /*
             * Days
             */
        } else if (
            normalizedUnit === 'day' ||
            normalizedUnit === 'days'
        ) {

            date.setDate(
                date.getDate() +
                numericDuration
            );


        } else {

            return null;
        }


        /*
         * Inclusive warranty calculation:
         *
         * Invoice Date:
         * 15-Jul-2026
         *
         * Duration:
         * 5 Years
         *
         * End Date:
         * 14-Jul-2031
         */
        date.setDate(
            date.getDate() - 1
        );


        return this.formatDateForComparison(
            date
        );
    }


    /* =========================================================
       DATE FORMAT
       ========================================================= */

    formatDateForComparison(date) {

        const year =
            date.getFullYear();


        const month =
            String(
                date.getMonth() + 1
            ).padStart(
                2,
                '0'
            );


        const day =
            String(
                date.getDate()
            ).padStart(
                2,
                '0'
            );


        return (
            `${year}-${month}-${day}`
        );
    }


    /* =========================================================
       ORDER PRODUCT
       ========================================================= */

    handleOrderProductChange(event) {

        this.form = {

            ...this.form,

            orderProductId:
                event.detail.recordId ||
                null
        };
    }


    /* =========================================================
       SERIAL NUMBER
       ========================================================= */

    handleAddSerial() {

        const serial = {

            key:
                this.generateKey(
                    'serial'
                ),

            title: '',

            serialNumber: '',

            productWarrantyEndDate:
                null,

            performanceWarrantyEndDate:
                null,

            warranties: [
                this.createWarranty()
            ],

            hasWarranties:
                true
        };


        this.serials =
            this.reindexSerials([
                ...this.serials,
                serial
            ]);


        /*
         * IMPORTANT:
         *
         * If Product + Invoice Date are already
         * available, immediately calculate the
         * warranty for the newly added serial.
         */
        this.updateWarrantyCalculation(
            this.form.invoiceDate
        );
    }


    handleRemoveSerial(event) {

        const serialKey =
            event.currentTarget.dataset.serialKey;


        this.serials =
            this.reindexSerials(
                this.serials.filter(
                    serial =>
                        serial.key !==
                        serialKey
                )
            );
    }


    handleSerialChange(event) {

        const serialKey =
            event.target.dataset.serialKey;

        const field =
            event.target.dataset.field;


        let value =
            event.target.value;


        if (value === '') {
            value = null;
        }


        this.serials =
            this.serials.map(
                serial => {

                    if (
                        serial.key !==
                        serialKey
                    ) {

                        return serial;
                    }


                    return {

                        ...serial,

                        [field]:
                            value
                    };
                }
            );
    }


    /* =========================================================
       WARRANTY
       ========================================================= */

    handleAddWarranty(event) {

        const serialKey =
            event.currentTarget.dataset.serialKey;


        this.serials =
            this.serials.map(
                serial => {

                    if (
                        serial.key !==
                        serialKey
                    ) {

                        return serial;
                    }


                    /*
                     * New warranty receives the
                     * current calculated values.
                     */
                    const newWarranty =
                        this.createWarranty();


                    newWarranty.startDate =
                        this.form.warrantyStartDate ||
                        null;


                    newWarranty.endDate =
                        this.form.warrantyEndDate ||
                        null;


                    newWarranty.warrantyStatus =
                        this.form.warrantyStatus ||
                        'Validation Required';


                    return {

                        ...serial,

                        warranties: [

                            ...serial.warranties,

                            newWarranty
                        ]
                    };
                }
            );


        this.serials =
            this.reindexSerials(
                this.serials
            );
    }


    handleRemoveWarranty(event) {

        const serialKey =
            event.currentTarget.dataset.serialKey;

        const warrantyKey =
            event.currentTarget.dataset.warrantyKey;


        this.serials =
            this.serials.map(
                serial => {

                    if (
                        serial.key !==
                        serialKey
                    ) {

                        return serial;
                    }


                    return {

                        ...serial,

                        warranties:
                            serial.warranties.filter(
                                warranty =>
                                    warranty.key !==
                                    warrantyKey
                            )
                    };
                }
            );


        this.serials =
            this.reindexSerials(
                this.serials
            );
    }


    handleWarrantyChange(event) {

        const serialKey =
            event.target.dataset.serialKey;

        const warrantyKey =
            event.target.dataset.warrantyKey;

        const field =
            event.target.dataset.field;


        let value;


        if (
            event.target.type ===
            'checkbox'
        ) {

            value =
                event.target.checked;

        } else if (
            event.detail &&
            event.detail.value !==
            undefined
        ) {

            value =
                event.detail.value;

        } else {

            value =
                event.target.value;
        }


        if (value === '') {
            value = null;
        }


        this.serials =
            this.serials.map(
                serial => {

                    if (
                        serial.key !==
                        serialKey
                    ) {

                        return serial;
                    }


                    const warranties =
                        serial.warranties.map(
                            warranty => {

                                if (
                                    warranty.key !==
                                    warrantyKey
                                ) {

                                    return warranty;
                                }


                                return {

                                    ...warranty,

                                    [field]:
                                        value
                                };
                            }
                        );


                    return {

                        ...serial,

                        warranties
                    };
                }
            );
    }


    createWarranty() {

        return {

            key:
                this.generateKey(
                    'warranty'
                ),

            title: '',

            /*
             * These are automatically populated
             * from Invoice Date/Product.
             */
            startDate:
                this.form.warrantyStartDate ||
                null,

            endDate:
                this.form.warrantyEndDate ||
                null,

            warrantyStatus:
                this.form.warrantyStatus ||
                'Validation Required',

            approvalStatus: null,

            warrantyType: null,

            customWarrantyType: null,

            transferable: false,

            laborCovered: null,

            partsCovered: null,

            expensesCovered: null,

            laborCoveredEndDate: null,

            partsCoveredEndDate: null,

            expensesCoveredEndDate: null,

            exclusions: ''
        };
    }


    reindexSerials(serials) {

        return serials.map(
            (
                serial,
                serialIndex
            ) => {

                const warranties =
                    serial.warranties.map(
                        (
                            warranty,
                            warrantyIndex
                        ) => ({

                            ...warranty,

                            title:
                                `Warranty ${warrantyIndex + 1
                                }`
                        })
                    );


                return {

                    ...serial,

                    title:
                        `Serial Number ${serialIndex + 1
                        }`,

                    warranties,

                    hasWarranties:
                        warranties.length >
                        0
                };
            }
        );
    }


    generateKey(prefix) {

        this.keyCounter += 1;


        return (
            `${prefix}-` +
            `${Date.now()}-` +
            `${this.keyCounter}`
        );
    }


    /* =========================================================
       VALIDATION
       ========================================================= */

    validateForm() {

        const components = [

            ...this.template.querySelectorAll(
                'lightning-input, ' +
                'lightning-textarea, ' +
                'lightning-combobox'
            )
        ];


        let valid = true;


        components.forEach(
            component => {

                component.reportValidity();


                if (
                    !component.checkValidity()
                ) {

                    valid = false;
                }
            }
        );


        return valid;
    }


    validateSerials() {

        const serialNumbers =
            new Set();


        for (const serial of this.serials) {

            const serialNumber =
                this.cleanString(
                    serial.serialNumber
                );


            /*
             * Serial Number is OPTIONAL.
             * If blank, skip serial validation.
             */
            if (!serialNumber) {
                continue;
            }


            const normalized =
                serialNumber.toLowerCase();


            if (
                serialNumbers.has(
                    normalized
                )
            ) {

                this.showToast(
                    'Duplicate Serial Number',
                    `${serialNumber} has been added more than once.`,
                    'warning'
                );

                return false;
            }


            serialNumbers.add(
                normalized
            );


            for (
                const warranty of
                serial.warranties
            ) {

                if (
                    !warranty.startDate ||
                    !warranty.endDate
                ) {

                    this.showToast(
                        'Warranty Dates Required',
                        `${warranty.title} under ${serial.title} requires Start Date and End Date.`,
                        'warning'
                    );

                    return false;
                }


                if (
                    warranty.endDate <
                    warranty.startDate
                ) {

                    this.showToast(
                        'Invalid Warranty Dates',
                        `${warranty.title} under ${serial.title} has an End Date earlier than Start Date.`,
                        'warning'
                    );

                    return false;
                }
            }
        }


        return true;
    }


    /* =========================================================
       SAVE
       ========================================================= */

    async handleSave() {

        /*
         * Validate the normal form first.
         */
        if (!this.validateForm()) {

            this.showToast(
                'Required Information',
                'Please complete all required fields.',
                'warning'
            );


            return;
        }


        /*
         * Product is mandatory.
         */
        if (!this.form.productName) {

            this.showToast(
                'Product Required',
                'Please select a Product.',
                'warning'
            );

            return;
        }


        if (!this.form.productCategory) {

            this.showToast(
                'Product Category Required',
                'Please select a Product Category.',
                'warning'
            );

            return;
        }

        /*
         * Invoice Date is mandatory.
         */
        if (!this.form.invoiceDate) {

            this.showToast(
                'Invoice Date Required',
                'Please enter Invoice Date.',
                'warning'
            );


            return;
        }


        /*
         * =====================================================
         * IMPORTANT FIX
         *
         * Calculate warranty information BEFORE
         * validateSerials().
         *
         * Previously validation was happening first,
         * which caused:
         *
         * "Warranty Dates Required"
         *
         * even though the dates could be calculated.
         * =====================================================
         */
        this.updateWarrantyCalculation(
            this.form.invoiceDate
        );


        /*
         * Now validate the serials/warranties.
         */
        if (!this.validateSerials()) {
            return;
        }



        /*
 * =====================================================
 * ATTACHMENT REQUIRED
 * Asset must NOT be created without an attachment.
 * =====================================================
 */
        if (
            !this.uploadedFileCount ||
            this.uploadedFileCount < 1
        ) {

            this.showToast(
                'Attachment Required',
                'Please upload at least one attachment before saving the Asset.',
                'warning'
            );

            return;
        }



        this.isLoading = true;


        try {

            const requestData = {




                productName:
                    this.cleanString(
                        this.form.productName
                    ),


                productCategory:
                    this.cleanString(
                        this.form.productCategory
                    ),


                productId:
                    this.form.productId ||
                    null,


                orderProductId:
                    this.form.orderProductId ||
                    null,


                purchaseDate:
                    this.form.purchaseDate ||
                    null,


                installDate:
                    this.form.installDate ||
                    null,


                invoiceNumber:
                    this.cleanString(
                        this.form.invoiceNumber
                    ),


                invoiceDate:
                    this.form.invoiceDate ||
                    null,


                batchNumber:
                    this.cleanString(
                        this.form.batchNumber
                    ),


                quantity:
                    this.toNumberOrNull(
                        this.form.quantity
                    ),


                siteName:
                    this.cleanString(
                        this.form.siteName
                    ),


                address:
                    this.cleanString(
                        this.form.address
                    ),


                city:
                    this.cleanString(
                        this.form.city
                    ),


                state:
                    this.cleanString(
                        this.form.state
                    ),


                country:
                    this.cleanString(
                        this.form.country
                    ),


                pinCode:
                    this.cleanString(
                        this.form.pinCode
                    ),


                dealerName:
                    this.cleanString(
                        this.form.dealerName
                    ),


                dealerPhone:
                    this.cleanString(
                        this.form.dealerPhone
                    ),


                dealerAddress:
                    this.cleanString(
                        this.form.dealerAddress
                    ),


                description:
                    this.cleanString(
                        this.form.description
                    ),


                /*
                 * Existing warranty values.
                 *
                 * These remain in the request because
                 * they are part of the existing controller
                 * contract.
                 */
                productWarrantyDuration:
                    this.toNumberOrNull(
                        this.form.productWarrantyDuration
                    ),


                performanceWarrantyDuration:
                    this.toNumberOrNull(
                        this.form.performanceWarrantyDuration
                    ),


                assetProductWarrantyEndDate:
                    this.form.assetProductWarrantyEndDate ||
                    null,


                assetPerformanceWarrantyEndDate:
                    this.form.assetPerformanceWarrantyEndDate ||
                    null,


                serials:
                    this.serials
                        .filter(
                            serial =>
                                !!this.cleanString(
                                    serial.serialNumber
                                )
                        )
                        .map(
                            serial => ({

                                serialNumber:
                                    this.cleanString(
                                        serial.serialNumber
                                    ),


                                productWarrantyEndDate:
                                    serial.productWarrantyEndDate ||
                                    null,


                                performanceWarrantyEndDate:
                                    serial.performanceWarrantyEndDate ||
                                    null,


                                warranties:
                                    serial.warranties.map(
                                        warranty => ({

                                            /*
                                             * Automatically
                                             * calculated dates.
                                             */
                                            startDate:
                                                warranty.startDate ||
                                                null,


                                            endDate:
                                                warranty.endDate ||
                                                null,


                                            approvalStatus:
                                                warranty.approvalStatus ||
                                                null,


                                            warrantyType:
                                                warranty.warrantyType ||
                                                null,


                                            customWarrantyType:
                                                warranty.customWarrantyType ||
                                                null,


                                            transferable:
                                                warranty.transferable ===
                                                true,


                                            laborCovered:
                                                this.toNumberOrNull(
                                                    warranty.laborCovered
                                                ),


                                            partsCovered:
                                                this.toNumberOrNull(
                                                    warranty.partsCovered
                                                ),


                                            expensesCovered:
                                                this.toNumberOrNull(
                                                    warranty.expensesCovered
                                                ),


                                            laborCoveredEndDate:
                                                warranty.laborCoveredEndDate ||
                                                null,


                                            partsCoveredEndDate:
                                                warranty.partsCoveredEndDate ||
                                                null,


                                            expensesCoveredEndDate:
                                                warranty.expensesCoveredEndDate ||
                                                null,


                                            exclusions:
                                                this.cleanString(
                                                    warranty.exclusions
                                                )
                                        })
                                    )
                            })
                        )
            };


            const resultJson =
                await createAssetBundle({

                    caseId:
                        this.recordId,

                    requestJson:
                        JSON.stringify(
                            requestData
                        )
                });


            const result =
                JSON.parse(
                    resultJson
                );


            this.showToast(
                'Asset Created Successfully',
                result.message,
                'success'
            );


            this.dispatchEvent(
                new CloseActionScreenEvent()
            );


            await this.delay(300);


            window.location.replace(
                `/lightning/r/Case/${this.recordId}/view`
            );


        } catch (error) {

            this.showToast(
                'Unable to Create Asset',
                this.getErrorMessage(error),
                'error'
            );


        } finally {

            this.isLoading = false;
        }
    }


    /* =========================================================
       HELPERS
       ========================================================= */

    handleCancel() {

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }


    cleanString(value) {

        if (
            value === undefined ||
            value === null
        ) {

            return null;
        }


        const result =
            String(value).trim();


        return result || null;
    }


    toNumberOrNull(value) {

        if (
            value === undefined ||
            value === null ||
            value === ''
        ) {

            return null;
        }


        const numberValue =
            Number(value);


        return Number.isNaN(
            numberValue
        )
            ? null
            : numberValue;
    }


    delay(milliseconds) {

        return new Promise(
            resolve => {

                setTimeout(
                    resolve,
                    milliseconds
                );
            }
        );
    }


    showToast(
        title,
        message,
        variant
    ) {

        this.dispatchEvent(
            new ShowToastEvent({

                title,

                message,

                variant
            })
        );
    }


    getErrorMessage(error) {

        if (
            error?.body?.message
        ) {

            return error.body.message;
        }


        if (error?.message) {

            return error.message;
        }


        return (
            'An unexpected error occurred.'
        );
    }
}