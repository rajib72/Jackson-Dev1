import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';

import JaksonLogo from '@salesforce/resourceUrl/JaksonLogo';

import getInitData from '@salesforce/apex/TermSheetQuickActionController.getInitData';
import createTermSheetAndLineItems from '@salesforce/apex/TermSheetQuickActionController.createTermSheetAndLineItems';
import updateChecklistAndUploadFiles from '@salesforce/apex/TermSheetQuickActionController.updateChecklistAndUploadFiles';

export default class TermSheetQuickAction extends NavigationMixin(LightningElement) {
    _recordId;
    hasLoaded = false;
    isRetail = false;

    showContactCustomerPopup = false;
    showCustomizeLogoPopup = false;
    showThirdPartyInsurancePopup = false;
    showPaymentTermPopup = false;
    showIncotermPopup = false;
    showConcealmentPeriodPopup = false;
    showLiquidityDamagePopup = false;
    isMobileView = false;

    jaksonLogo = JaksonLogo;

    @track isLoading = false;
    @track productRows = [];
    @track contactOptions = [];
    @track paymentTermOptions = [];
    @track incotermOptions = [];

    @track isChecklistStep = false;
    @track createdTermSheetId = '';

    otherPaymentTerm = '';
    otherIncoterm = '';
    otherLiquidityDamage = '';

    preparedBySaleRm = '';
    preparedBySaleRmDate = '';
    approvedBySalesHead = '';
    salesHeadApprovalDate = '';
    approvedByCommercialHead = '';
    commercialHeadApprovalDate = '';

    opportunityId = '';
    opportunityName = '';
    accountName = '';
    issueDate = '';

    termSheetName = '';
    docNo = '';
    revNo = '';
    displayIssueDate = '';

    customerId = '';
    totalOrderSizeInMW = '';
    endUserName = '';
    contactCustomerId = '';
    contactSitePerson = '';
    tenderContract = '';
    spareModulesRequired = '';

    frameThickness = '';
    mountingHolePitch = '';
    glassThickness = '';
    connector = '';
    moduleBOM = '';
    customizeLogo = '';
    packingModulesPerBox = '';
    currentBinningRequired = '';
    thirdPartyInsurance = '';
    anySpecialRequirement = '';
    cellMake = '';
    cellSize = '';

    paymentTermId = '';
    transportationMode = '';
    documentsThroughLC = '';
    customerScope = '';
    dispatchProcess = '';
    incotermId = '';
    deliveryLocation = '';
    deliverySchedule = '';
    concealmentPeriod = '';
    validityOfOffer = '';
    liquidityDamage = '';

    beforeShipmentFiles = [];
    afterShipmentFiles = [];

    psiQap = false;
    inpocessQap = false;
    rmQap = false;
    elAndVisualInspectionCriteria = false;
    bom = false;
    moduleDatasheet = false;
    reliabilityTestingPlan = false;

    psiQapFiles = [];
    inpocessQapFiles = [];
    rmQapFiles = [];
    elAndVisualInspectionCriteriaFiles = [];
    bomFiles = [];
    moduleDatasheetFiles = [];
    reliabilityTestingPlanFiles = [];

    yesNoOptions = [
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' }
    ];

    concealmentPeriodOptions = [
        { label: '30', value: '30' },
        { label: '45', value: '45' },
        { label: '60', value: '60' }
    ];

    @track liquidityDamageOptions = [];

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;

        if (value && !this.hasLoaded) {
            this.hasLoaded = true;
            this.loadInitData();
        }
    }

    get selectedContactCustomerLabel() {
        return this.getSelectedLabel(this.contactOptions, this.contactCustomerId);
    }

    get selectedCustomizeLogoLabel() {
        return this.getSelectedLabel(this.yesNoOptions, this.customizeLogo);
    }

    get selectedThirdPartyInsuranceLabel() {
        return this.getSelectedLabel(this.yesNoOptions, this.thirdPartyInsurance);
    }

    get selectedPaymentTermLabel() {
        return this.getSelectedLabel(this.paymentTermOptions, this.paymentTermId);
    }
    get showOtherPaymentTermRow() {
        const label = (this.getSelectedLabel(this.paymentTermOptions, this.paymentTermId) || '').toLowerCase();
        return label.startsWith('other');
    }


    get selectedIncotermLabel() {
        return this.getSelectedLabel(this.incotermOptions, this.incotermId);
    }

    get showOtherIncotermRow() {
        const label = (this.getSelectedLabel(this.incotermOptions, this.incotermId) || '').toLowerCase();
        return label.startsWith('other');
    }

    get selectedConcealmentPeriodLabel() {
        return this.getSelectedLabel(this.concealmentPeriodOptions, this.concealmentPeriod);
    }

    get selectedLiquidityDamageLabel() {
        return this.getSelectedLabel(this.liquidityDamageOptions, this.liquidityDamage);
    }
    get showOtherLiquidityDamageRow() {
        return this.liquidityDamage === 'Others';
    }

    // =========================
    // Dynamic Serial Numbers
    // =========================

    // Customer Details
    get customerNameSrNo() {
        return 1;
    }

    get totalOrderSizeSrNo() {
        return this.customerNameSrNo + 1;
    }

    get endUserNameSrNo() {
        return this.totalOrderSizeSrNo + 1;
    }

    get contactCustomerSrNo() {
        return this.endUserNameSrNo + 1;
    }

    get contactSitePersonSrNo() {
        return this.contactCustomerSrNo + 1;
    }

    get tenderContractSrNo() {
        return this.contactSitePersonSrNo + 1;
    }

    get spareModulesRequiredSrNo() {
        return this.tenderContractSrNo + 1;
    }

    get lastCustomerSectionSrNo() {
        return this.isRetail ? this.tenderContractSrNo : this.spareModulesRequiredSrNo;
    }

    // Module Requirements
    // Hidden for retail:
    // frameThickness, mountingHolePitch, glassThickness, connector,
    // moduleBOM, customizeLogo, packingModulesPerBox,
    // currentBinningRequired, thirdPartyInsurance, cellMake, cellSize

    get frameThicknessSrNo() {
        return this.isRetail ? null : this.lastCustomerSectionSrNo + 1;
    }

    get mountingHolePitchSrNo() {
        return this.isRetail ? null : this.frameThicknessSrNo + 1;
    }

    get glassThicknessSrNo() {
        return this.isRetail ? null : this.mountingHolePitchSrNo + 1;
    }

    get connectorSrNo() {
        return this.isRetail ? null : this.glassThicknessSrNo + 1;
    }

    get moduleBOMSrNo() {
        return this.isRetail ? null : this.connectorSrNo + 1;
    }

    get customizeLogoSrNo() {
        return this.isRetail ? null : this.moduleBOMSrNo + 1;
    }

    get packingModulesPerBoxSrNo() {
        return this.isRetail ? null : this.customizeLogoSrNo + 1;
    }

    get currentBinningRequiredSrNo() {
        return this.isRetail ? null : this.packingModulesPerBoxSrNo + 1;
    }

    get thirdPartyInsuranceSrNo() {
        return this.isRetail ? null : this.currentBinningRequiredSrNo + 1;
    }

    // Visible in both retail and non-retail
    get anySpecialRequirementSrNo() {
        return this.isRetail
            ? this.lastCustomerSectionSrNo + 1
            : this.thirdPartyInsuranceSrNo + 1;
    }

    // Hidden for retail
    get cellMakeSrNo() {
        return this.isRetail ? null : this.anySpecialRequirementSrNo + 1;
    }

    get cellSizeSrNo() {
        return this.isRetail ? null : this.cellMakeSrNo + 1;
    }

    // Commercial Details
    get paymentTermsSrNo() {
        return this.isRetail
            ? this.anySpecialRequirementSrNo + 1
            : this.cellSizeSrNo + 1;
    }

    get otherPaymentTermsSrNo() {
        return this.paymentTermsSrNo + 1;
    }

    get beforeShipmentSrNo() {
        return this.paymentTermsSrNo + (this.showOtherPaymentTermRow ? 2 : 1);
    }

    get afterShipmentSrNo() {
        return this.beforeShipmentSrNo + 1;
    }

    get transportationModeSrNo() {
        return this.afterShipmentSrNo + 1;
    }

    get documentsThroughLCSrNo() {
        return this.transportationModeSrNo + 1;
    }

    get customerScopeSrNo() {
        return this.documentsThroughLCSrNo + 1;
    }

    get dispatchProcessSrNo() {
        return this.customerScopeSrNo + 1;
    }

    get incotermsSrNo() {
        return this.dispatchProcessSrNo + 1;
    }

    get otherIncotermSrNo() {
        return this.incotermsSrNo + 1;
    }

    get deliveryLocationSrNo() {
        return this.incotermsSrNo + (this.showOtherIncotermRow ? 2 : 1);
    }

    get validityOfOfferSrNo() {
        return this.deliveryLocationSrNo + 1;
    }

    get deliveryScheduleSrNo() {
        return this.validityOfOfferSrNo + 1;
    }

    get concealmentPeriodSrNo() {
        return this.deliveryScheduleSrNo + 1;
    }

    get liquidityDamageSrNo() {
        return this.concealmentPeriodSrNo + 1;
    }

    get otherLiquidityDamageSrNo() {
        return this.liquidityDamageSrNo + 1;
    }

    // Checklist Step
    get psiQapSrNo() {
        return 1;
    }

    get inpocessQapSrNo() {
        return this.psiQapSrNo + 1;
    }

    get rmQapSrNo() {
        return this.inpocessQapSrNo + 1;
    }

    get elAndVisualInspectionCriteriaSrNo() {
        return this.rmQapSrNo + 1;
    }

    get bomSrNo() {
        return this.elAndVisualInspectionCriteriaSrNo + 1;
    }

    get moduleDatasheetSrNo() {
        return this.bomSrNo + 1;
    }

    get reliabilityTestingPlanSrNo() {
        return this.moduleDatasheetSrNo + 1;
    }

    updateFormFactor() {
        this.isMobileView = window.innerWidth <= 768;
    }

    connectedCallback() {
        this.updateFormFactor();
        this._resizeHandler = this.updateFormFactor.bind(this);
        window.addEventListener('resize', this._resizeHandler);
    }

    disconnectedCallback() {
        if (this._resizeHandler) {
            window.removeEventListener('resize', this._resizeHandler);
        }
    }

    openContactCustomerPopup() {
        this.showContactCustomerPopup = true;
    }
    closeContactCustomerPopup() {
        this.showContactCustomerPopup = false;
    }
    handleContactCustomerSelect(event) {
        this.contactCustomerId = event.currentTarget.dataset.value;
        this.showContactCustomerPopup = false;
    }

    openCustomizeLogoPopup() {
        this.showCustomizeLogoPopup = true;
    }
    closeCustomizeLogoPopup() {
        this.showCustomizeLogoPopup = false;
    }
    handleCustomizeLogoSelect(event) {
        this.customizeLogo = event.currentTarget.dataset.value;
        this.showCustomizeLogoPopup = false;
    }

    openThirdPartyInsurancePopup() {
        this.showThirdPartyInsurancePopup = true;
    }
    closeThirdPartyInsurancePopup() {
        this.showThirdPartyInsurancePopup = false;
    }
    handleThirdPartyInsuranceSelect(event) {
        this.thirdPartyInsurance = event.currentTarget.dataset.value;
        this.showThirdPartyInsurancePopup = false;
    }

    openPaymentTermPopup() {
        this.showPaymentTermPopup = true;
    }
    closePaymentTermPopup() {
        this.showPaymentTermPopup = false;
    }
    handlePaymentTermSelect(event) {
        this.paymentTermId = event.currentTarget.dataset.value;
        this.showPaymentTermPopup = false;

        if (!this.showOtherPaymentTermRow) {
            this.otherPaymentTerm = '';
        }
    }

    openIncotermPopup() {
        this.showIncotermPopup = true;
    }
    closeIncotermPopup() {
        this.showIncotermPopup = false;
    }
    handleIncotermSelect(event) {
        this.incotermId = event.currentTarget.dataset.value;
        this.showIncotermPopup = false;

        if (!this.showOtherIncotermRow) {
            this.otherIncoterm = '';
        }
    }

    openConcealmentPeriodPopup() {
        this.showConcealmentPeriodPopup = true;
    }
    closeConcealmentPeriodPopup() {
        this.showConcealmentPeriodPopup = false;
    }
    handleConcealmentPeriodSelect(event) {
        this.concealmentPeriod = event.currentTarget.dataset.value;
        this.showConcealmentPeriodPopup = false;
    }

    openLiquidityDamagePopup() {
        this.showLiquidityDamagePopup = true;
    }

    closeLiquidityDamagePopup() {
        this.showLiquidityDamagePopup = false;
    }

    handleLiquidityDamageSelect(event) {
        this.liquidityDamage = event.currentTarget.dataset.value;
        this.showLiquidityDamagePopup = false;

        if (this.liquidityDamage !== 'Others') {
            this.otherLiquidityDamage = '';
        }
    }
    renderedCallback() {
        if (this._modalStyleAdded) {
            return;
        }
        this._modalStyleAdded = true;

        const style = document.createElement('style');
        style.innerText = `
        .slds-modal__container {
            width: 95vw !important;
            max-width: 95vw !important;
            height: 95vh !important;
        }

        .slds-modal__header {
            border-bottom: none !important;
            padding: 0 !important;
            min-height: 0 !important;
        }

        .slds-modal__content {
            height: auto !important;
            max-height: none !important;
            overflow: hidden !important;
            padding: 0 !important;
        }

        .slds-modal__close,
        button.slds-button.slds-button_icon.slds-modal__close,
        .slds-modal__header .slds-modal__close,
        .slds-modal button[title="Close"],
        .slds-modal button[title="Cancel and close"] {
            display: none !important;
        }
    `;
        document.head.appendChild(style);
    }
    get beforeShipmentFileNames() {
        return this.beforeShipmentFiles?.length
            ? this.beforeShipmentFiles.map(file => file.fileName).join(', ')
            : '';
    }

    get afterShipmentFileNames() {
        return this.afterShipmentFiles?.length
            ? this.afterShipmentFiles.map(file => file.fileName).join(', ')
            : '';
    }

    get psiQapFileNames() {
        return this.psiQapFiles?.length ? this.psiQapFiles.map(file => file.fileName).join(', ') : '';
    }

    get inpocessQapFileNames() {
        return this.inpocessQapFiles?.length ? this.inpocessQapFiles.map(file => file.fileName).join(', ') : '';
    }

    get rmQapFileNames() {
        return this.rmQapFiles?.length ? this.rmQapFiles.map(file => file.fileName).join(', ') : '';
    }

    get elAndVisualInspectionCriteriaFileNames() {
        return this.elAndVisualInspectionCriteriaFiles?.length
            ? this.elAndVisualInspectionCriteriaFiles.map(file => file.fileName).join(', ')
            : '';
    }

    get bomFileNames() {
        return this.bomFiles?.length ? this.bomFiles.map(file => file.fileName).join(', ') : '';
    }

    get moduleDatasheetFileNames() {
        return this.moduleDatasheetFiles?.length
            ? this.moduleDatasheetFiles.map(file => file.fileName).join(', ')
            : '';
    }

    get reliabilityTestingPlanFileNames() {
        return this.reliabilityTestingPlanFiles?.length
            ? this.reliabilityTestingPlanFiles.map(file => file.fileName).join(', ')
            : '';
    }

    get isFirstStep() {
        return !this.isChecklistStep;
    }

    get isSecondStep() {
        return this.isChecklistStep;
    }
    get showNonRetailProductColumns() {
        return !this.isRetail;
    }

    async loadInitData() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;
        try {
            const result = await getInitData({ opportunityId: this.recordId });

            this.productRows = (result.products || []).map((row, index) => {
                const binApplicable = row.binPercentageInput || '';
                return {
                    ...row,
                    srNo: row.srNo || (index + 1),
                    cellTypeModuleTechnologyDisplay:
                        row.cellTypeModuleTechnologyDisplay ||
                        [row.cellType, row.moduleTechnology].filter(Boolean).join(' / '),

                    wpBinInput: row.wpBinInput || row.productRatingBin || '',
                    binPercentageInput: binApplicable,
                    binPercentageValueInput: row.binPercentageValueInput || '',
                    showBinPercentageValue: binApplicable === 'Yes',

                    moduleEfficiencyCriteriaInput: row.moduleEfficiencyCriteriaInput || '',
                    noOfModulesInput: row.noOfModulesInput || `${row.projectCapacity ?? ''} ${row.uom ?? ''}`.trim(),
                    systemVoltageInput: row.systemVoltageInput || '',

                    frameThicknessInput: row.frameThicknessInput || '',
                    mountingHolePitchInput: row.mountingHolePitchInput || '',
                    glassThicknessInput: row.glassThicknessInput || '',
                    cableLengthInput: row.cableLengthInput || row.cableLength || '',
                    connectorInput: row.connectorInput || '',
                    moduleBOMInput: row.moduleBOMInput || '',
                    customizeLogoInput: row.customizeLogoInput || '',
                    packingModulesPerBoxInput: row.packingModulesPerBoxInput || '',
                    currentBinningRequiredInput: row.currentBinningRequiredInput || '',
                    thirdPartyInsuranceInput: row.thirdPartyInsuranceInput || '',
                    anySpecialRequirementInput: row.anySpecialRequirementInput || '',
                    cellMakeInput: row.cellMakeInput || '',
                    cellSizeInput: row.cellSizeInput || ''
                };
            });

            if (result.opp) {
                this.opportunityId = result.opp.Id;
                this.opportunityName = result.opp.Name;
                this.termSheetName = 'TS - ' + result.opp.Name;
                this.customerId = result.opp.AccountId || '';
                this.accountName = result.opp.Account ? result.opp.Account.Name : '';
                this.preparedBySaleRm = result.oppOwnerName || '';

                // const actualCapacityKW = parseFloat(result.opp.Actual_Capacity_text__c || 0);

                // this.totalOrderSizeInMW = actualCapacityKW
                //     ? (actualCapacityKW / 1000).toFixed(3)
                //     : '';
                // Convert Actual capacity in KW to MW calculation 

                const actualCapacityKW = parseFloat(
                    String(result.opp.Actual_Capacity_text__c || '0')
                    .replace(/,/g, '')
                    );
                    
                this.totalOrderSizeInMW = Number.isFinite(actualCapacityKW)
                    ? (actualCapacityKW / 1000).toFixed(3)
                    : '';
           
            }

            this.contactOptions = result.contactOptions || [];
            this.paymentTermOptions = result.paymentTermOptions || [];
            this.incotermOptions = result.incotermOptions || [];
            this.liquidityDamageOptions = result.liquidityDamageOptions || [];
            this.isRetail = result.isRetail || false;

            this.docNo = result.defaultDocNo || '';
            this.revNo = result.defaultRevNo || '';
            this.issueDate = result.todayDate || '';
            this.displayIssueDate = result.displayIssueDate || '';

            this.issueDate = result.todayDate || '';
            this.validityOfOffer = result.defaultValidityDate || '';
            this.preparedBySaleRmDate = result.todayDate || '';
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.detail?.value ?? event.target.value;

        if (field === 'liquidityDamage' && this.liquidityDamage !== 'Others') {
            this.otherLiquidityDamage = '';
        }

        if (field === 'paymentTermId' && !this.showOtherPaymentTermRow) {
            this.otherPaymentTerm = '';
        }

        if (field === 'incotermId' && !this.showOtherIncotermRow) {
            this.otherIncoterm = '';
        }
    }

    handleChecklistCheckboxChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.checked;
    }

    async handleChecklistFiles(event) {
        const field = event.target.dataset.field;
        const newFiles = await this.readFiles(event.target.files);
        this[field] = [...(this[field] || []), ...newFiles];
        event.target.value = null;
    }

    handleProductRowChange(event) {
        const rowId = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = event.detail?.value ?? event.target.value;

        this.productRows = this.productRows.map(row => {
            if (row.oppLineItemId === rowId) {
                const updatedRow = {
                    ...row,
                    [field]: value
                };

                if (field === 'binPercentageInput') {
                    updatedRow.showBinPercentageValue = value === 'Yes';

                    if (value !== 'Yes') {
                        updatedRow.binPercentageValueInput = '';
                    }
                }

                return updatedRow;
            }

            return row;
        });
    }
    async handleBeforeShipmentFiles(event) {
        const newFiles = await this.readFiles(event.target.files);
        this.beforeShipmentFiles = [...this.beforeShipmentFiles, ...newFiles];
        event.target.value = null;
    }

    async handleAfterShipmentFiles(event) {
        const newFiles = await this.readFiles(event.target.files);
        this.afterShipmentFiles = [...this.afterShipmentFiles, ...newFiles];
        event.target.value = null;
    }

    async readFiles(fileList) {
        const files = Array.from(fileList || []);
        const filePromises = files.map(file => this.readSingleFile(file));
        return Promise.all(filePromises);
    }

    readSingleFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                resolve({
                    fileName: file.name,
                    base64Data: base64,
                    contentType: file.type
                });
            };

            reader.onerror = () => reject(new Error('File read failed: ' + file.name));
            reader.readAsDataURL(file);
        });
    }

    getSelectedLabel(options, value) {
        const match = (options || []).find(opt => opt.value === value);
        return match ? match.label : '';
    }

    syncVisibleBinPercentageValues() {
        const inputs = this.template.querySelectorAll(
            'lightning-input[data-field="binPercentageValueInput"]'
        );

        if (!inputs || !inputs.length) {
            return;
        }

        const latestMap = new Map();

        inputs.forEach(input => {
            const rowId = input.dataset.id;
            latestMap.set(rowId, input.value || '');
        });

        this.productRows = this.productRows.map(row => {
            if (latestMap.has(row.oppLineItemId)) {
                return {
                    ...row,
                    binPercentageValueInput: latestMap.get(row.oppLineItemId)
                };
            }

            return row;
        });
    }

    validateMandatoryChecklistSection() {
        const checklist = [
            { checked: this.psiQap, files: this.psiQapFiles, label: 'PSI QAP' },
            { checked: this.inpocessQap, files: this.inpocessQapFiles, label: 'Inpocess QAP' },
            { checked: this.rmQap, files: this.rmQapFiles, label: 'RM QAP' },
            { checked: this.elAndVisualInspectionCriteria, files: this.elAndVisualInspectionCriteriaFiles, label: 'EL and Visual Inspection Criteria' },
            { checked: this.bom, files: this.bomFiles, label: 'BOM' },
            { checked: this.moduleDatasheet, files: this.moduleDatasheetFiles, label: 'Module Datasheet' },
            { checked: this.reliabilityTestingPlan, files: this.reliabilityTestingPlanFiles, label: 'Reliability Testing Plan' }
        ];

        for (const item of checklist) {
            if (item.checked && (!item.files || !item.files.length)) {
                this.showToast('Error', `${item.label} file upload is mandatory because checkbox is checked.`, 'error');
                return false;
            }
        }

        return true;
    }

    isBlank(value) {
        return value === null || value === undefined || String(value).trim() === '';
    }

    validateMandatoryFirstStep() {
        const requiredFields = [
            { value: this.totalOrderSizeInMW, label: 'Total Order size in MW' },
            { value: this.endUserName, label: 'End User name' },
            { value: this.contactCustomerId, label: 'Contact Person Name of customer' },
            { value: this.contactSitePerson, label: 'Contact Person Name (Site Person)' },
            { value: this.tenderContract, label: 'Tender/Contract' },
            { value: this.anySpecialRequirement, label: 'Any special requirement' },
            { value: this.paymentTermId, label: 'Payment terms' },
            { value: this.transportationMode, label: 'Transportation Mode' },
            { value: this.documentsThroughLC, label: 'Documents to be submitted through LC' },
            { value: this.customerScope, label: 'Customer Scope' },
            { value: this.dispatchProcess, label: 'Dispatch process' },
            { value: this.incotermId, label: 'Incoterms' },
            { value: this.deliveryLocation, label: 'Delivery Location' },
            { value: this.validityOfOffer, label: 'Validity of Offer' },
            { value: this.deliverySchedule, label: 'Delivery Schedule' },
            { value: this.concealmentPeriod, label: 'Concealment Period' },
            { value: this.liquidityDamage, label: 'Liquidity Damage' }
        ];

        if (!this.isRetail) {
            requiredFields.push(
                { value: this.spareModulesRequired, label: 'Spare modules required' },
                { value: this.frameThickness, label: 'Frame Thickness' },
                { value: this.mountingHolePitch, label: 'Mounting Hole X pitch / Y pitch' },
                { value: this.glassThickness, label: 'Glass Thickness' },
                { value: this.connector, label: 'Connector' },
                { value: this.moduleBOM, label: 'Module BOM' },
                { value: this.customizeLogo, label: 'Customize logo' },
                { value: this.packingModulesPerBox, label: 'Packing' },
                { value: this.currentBinningRequired, label: 'Current Binning Required' },
                { value: this.thirdPartyInsurance, label: 'Third Party Insurance' },
                { value: this.cellMake, label: 'Cell Make' },
                { value: this.cellSize, label: 'Cell Size' }
            );
        }

        if (this.showOtherPaymentTermRow) {
            requiredFields.push({ value: this.otherPaymentTerm, label: 'Other Payment Terms' });
        }

        if (this.showOtherIncotermRow) {
            requiredFields.push({ value: this.otherIncoterm, label: 'Other Incoterms' });
        }

        if (this.liquidityDamage === 'Others') {
            requiredFields.push({ value: this.otherLiquidityDamage, label: 'Others Liquidity Damage' });
        }

        for (const field of requiredFields) {
            if (this.isBlank(field.value)) {
                this.showToast('Error', `${field.label} is mandatory.`, 'error');
                return false;
            }
        }

        return true;
    }

    validateProductRows(productRows) {
        if (this.isRetail) {
            return true;
        }

        for (const row of productRows) {
            if (this.isBlank(row.binPercentageInput)) {
                this.showToast('Error', 'Bin Percentage Applicable is mandatory for all line items.', 'error');
                return false;
            }

            if (row.binPercentageInput === 'Yes' && this.isBlank(row.binPercentageValueInput)) {
                this.showToast('Error', 'Please enter Bin Percentage where Bin Percentage Applicable is Yes.', 'error');
                return false;
            }

            if (this.isBlank(row.moduleEfficiencyCriteriaInput)) {
                this.showToast('Error', 'Module Efficiency as per Tender is mandatory for all line items.', 'error');
                return false;
            }

            if (this.isBlank(row.systemVoltageInput)) {
                this.showToast('Error', 'System Voltage is mandatory for all line items.', 'error');
                return false;
            }
        }

        return true;
    }

    async handleSave() {
        if (!this.recordId) {
            this.showToast('Error', 'Opportunity Id is missing.', 'error');
            return;
        }
        if (!this.productRows || this.productRows.length === 0) {
            this.showToast('Error', 'No Quote Line Items found.', 'error');
            return;
        }
        if (!this.validateMandatoryFirstStep()) {
            return;
        }

        if (this.showOtherPaymentTermRow && (!this.otherPaymentTerm || !this.otherPaymentTerm.trim())) {
            this.showToast('Error', 'Please enter Other Payment Terms.', 'error');
            return;
        }

        if (this.showOtherIncotermRow && (!this.otherIncoterm || !this.otherIncoterm.trim())) {
            this.showToast('Error', 'Please enter Other Incoterms.', 'error');
            return;
        }

        if (this.liquidityDamage === 'Others' && (!this.otherLiquidityDamage || !this.otherLiquidityDamage.trim())) {
            this.showToast('Error', 'Please enter Others Liquidity Damage.', 'error');
            return;
        }

        const binInputs = this.template.querySelectorAll('lightning-input[data-field="binPercentageValueInput"]');
        let allValid = true;

        if (binInputs && binInputs.length) {
            binInputs.forEach(input => {
                const rowId = input.dataset.id;
                const rowData = this.productRows.find(row => row.oppLineItemId === rowId);

                if (rowData && rowData.binPercentageInput === 'Yes') {
                    input.required = true;

                    if (!input.value || !input.value.trim()) {
                        input.reportValidity();
                        this.showToast('Error', 'Bin Percentage is mandatory when Yes is selected.', 'error');
                        allValid = false;
                    }
                }
            });
        }

        if (!allValid) {
            return;
        }



        this.syncVisibleBinPercentageValues();

        if (!this.validateProductRows(this.productRows)) {
            return;
        }

        const invalidBinRow = this.productRows.find(
            row =>
                row.binPercentageInput === 'Yes' &&
                (!row.binPercentageValueInput || !row.binPercentageValueInput.trim())
        );

        if (invalidBinRow) {
            this.showToast('Error', 'Please enter Bin Percentage where Bin Percentage Applicable is Yes.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const reqPayload = {
                termSheetName: this.termSheetName,
                docNo: this.docNo,
                revNo: this.revNo,
                customerId: this.customerId,
                totalOrderSizeInMW: this.totalOrderSizeInMW,
                endUserName: this.endUserName,
                contactCustomerId: this.contactCustomerId,
                contactSitePerson: this.contactSitePerson,
                tenderContract: this.tenderContract,
                spareModulesRequired: this.spareModulesRequired,

                frameThickness: this.frameThickness,
                mountingHolePitch: this.mountingHolePitch,
                glassThickness: this.glassThickness,
                connector: this.connector,
                moduleBOM: this.moduleBOM,
                customizeLogo: this.customizeLogo,
                packingModulesPerBox: this.packingModulesPerBox,
                currentBinningRequired: this.currentBinningRequired,
                thirdPartyInsurance: this.thirdPartyInsurance,
                anySpecialRequirement: this.anySpecialRequirement,
                cellMake: this.cellMake,
                cellSize: this.cellSize,

                paymentTermId: this.paymentTermId,
                paymentTermLabel: this.getSelectedLabel(this.paymentTermOptions, this.paymentTermId),
                otherPaymentTerm: this.otherPaymentTerm,
                transportationMode: this.transportationMode,
                documentsThroughLC: this.documentsThroughLC,
                customerScope: this.customerScope,
                dispatchProcess: this.dispatchProcess,
                incotermId: this.incotermId,
                incotermLabel: this.getSelectedLabel(this.incotermOptions, this.incotermId),
                otherIncoterm: this.otherIncoterm,
                deliveryLocation: this.deliveryLocation,
                deliverySchedule: this.deliverySchedule,
                concealmentPeriod: this.concealmentPeriod,
                validityOfOffer: this.validityOfOffer,
                liquidityDamage: this.liquidityDamage,
                otherLiquidityDamage: this.otherLiquidityDamage,

                productRows: this.productRows,
                beforeShipmentFiles: this.beforeShipmentFiles,
                afterShipmentFiles: this.afterShipmentFiles,
                issueDate: this.issueDate,

                preparedBySaleRm: this.preparedBySaleRm,
                preparedBySaleRmDate: this.preparedBySaleRmDate,
                approvedBySalesHead: this.approvedBySalesHead,
                salesHeadApprovalDate: this.salesHeadApprovalDate,
                approvedByCommercialHead: this.approvedByCommercialHead,
                commercialHeadApprovalDate: this.commercialHeadApprovalDate
            };

            const termSheetId = await createTermSheetAndLineItems({
                opportunityId: this.recordId,
                reqJson: JSON.stringify(reqPayload)
            });

            if (this.isRetail) {
                this.showToast('Success', 'Retail Term Sheet created successfully.', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: termSheetId,
                        objectApiName: 'Term_Sheet__c',
                        actionName: 'view'
                    }
                });
            } else {
                this.createdTermSheetId = termSheetId;
                this.isChecklistStep = true;
                this.showToast('Success', 'Term Sheet created successfully. Please complete checklist and upload files.', 'success');
            }
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleChecklistSave() {
        if (!this.createdTermSheetId) {
            this.showToast('Error', 'Term Sheet Id is missing.', 'error');
            return;
        }

        if (!this.validateMandatoryChecklistSection()) {
            return;
        }

        this.isLoading = true;
        try {
            const reqPayload = {
                psiQap: this.psiQap,
                inpocessQap: this.inpocessQap,
                rmQap: this.rmQap,
                elAndVisualInspectionCriteria: this.elAndVisualInspectionCriteria,
                bom: this.bom,
                moduleDatasheet: this.moduleDatasheet,
                reliabilityTestingPlan: this.reliabilityTestingPlan,

                psiQapFiles: this.psiQapFiles,
                inpocessQapFiles: this.inpocessQapFiles,
                rmQapFiles: this.rmQapFiles,
                elAndVisualInspectionCriteriaFiles: this.elAndVisualInspectionCriteriaFiles,
                bomFiles: this.bomFiles,
                moduleDatasheetFiles: this.moduleDatasheetFiles,
                reliabilityTestingPlanFiles: this.reliabilityTestingPlanFiles
            };

            await updateChecklistAndUploadFiles({
                termSheetId: this.createdTermSheetId,
                reqJson: JSON.stringify(reqPayload)
            });

            this.showToast('Success', 'Checklist updated and files uploaded successfully.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.createdTermSheetId,
                    objectApiName: 'Term_Sheet__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToFirstStep() {
        this.isChecklistStep = false;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
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
        if (Array.isArray(error?.body)) {
            return error.body.map(item => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }
}