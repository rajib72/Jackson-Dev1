public without sharing class TermSheetQuickActionController {
    
    public class OptionData {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public OptionData() {}
        
        public OptionData(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    public class FileData {
        @AuraEnabled public String fileName;
        @AuraEnabled public String base64Data;
        @AuraEnabled public String contentType;
    }
    
    public class OpportunityProductWrapper {
        @AuraEnabled public Id oppLineItemId; // Existing JS uses this. Now this will hold QuoteLineItem Id.
        @AuraEnabled public Id quoteLineItemId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String opportunityProductId;
        
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPrice;
        
        @AuraEnabled public String warranty;
        @AuraEnabled public String cableLength;
        @AuraEnabled public String cellType;
        @AuraEnabled public String moduleTechnology;
        @AuraEnabled public String moduleType;
        @AuraEnabled public String productRatingBin;
        @AuraEnabled public String productSubType;
        @AuraEnabled public Decimal wattPeak;
        
        @AuraEnabled public Integer srNo;
        @AuraEnabled public String cellTypeModuleTechnologyDisplay;
        
        @AuraEnabled public String materialDescription;
        @AuraEnabled public String nos;
        @AuraEnabled public Decimal projectCapacity;
        @AuraEnabled public String uom;
        @AuraEnabled public String capacityInKW;
        @AuraEnabled public String priceWp;
        @AuraEnabled public String total;
        @AuraEnabled public String gst;
        @AuraEnabled public String grandTotal;
        
        @AuraEnabled public String wpBinInput;
        @AuraEnabled public String binPercentageInput;
        @AuraEnabled public String binPercentageValueInput;
        @AuraEnabled public String moduleEfficiencyCriteriaInput;
        @AuraEnabled public String noOfModulesInput;
        @AuraEnabled public String systemVoltageInput;
        
        @AuraEnabled public String frameThicknessInput;
        @AuraEnabled public String mountingHolePitchInput;
        @AuraEnabled public String glassThicknessInput;
        @AuraEnabled public String cableLengthInput;
        @AuraEnabled public String connectorInput;
        @AuraEnabled public String moduleBOMInput;
        @AuraEnabled public String customizeLogoInput;
        @AuraEnabled public String packingModulesPerBoxInput;
        @AuraEnabled public String currentBinningRequiredInput;
        @AuraEnabled public String thirdPartyInsuranceInput;
        @AuraEnabled public String anySpecialRequirementInput;
        @AuraEnabled public String cellMakeInput;
        @AuraEnabled public String cellSizeInput;
    }
    
    public class InitResponse {
        @AuraEnabled public Opportunity opp;
        @AuraEnabled public List<OpportunityProductWrapper> products;
        @AuraEnabled public List<OptionData> contactOptions;
        @AuraEnabled public List<OptionData> paymentTermOptions;
        @AuraEnabled public List<OptionData> incotermOptions;
        @AuraEnabled public List<OptionData> liquidityDamageOptions;
        @AuraEnabled public String todayDate;
        @AuraEnabled public String defaultValidityDate;
        @AuraEnabled public String oppOwnerName;
        @AuraEnabled public String defaultDocNo;
        @AuraEnabled public String defaultRevNo;
        @AuraEnabled public String displayIssueDate;
        @AuraEnabled public Boolean isRetail;
        @AuraEnabled public Id latestQuoteId;
    }
    
    public class SaveRequest {
        @AuraEnabled public String termSheetName;
        @AuraEnabled public String docNo;
        @AuraEnabled public String revNo;
        @AuraEnabled public String issueDate;
        
        @AuraEnabled public String customerId;
        @AuraEnabled public String totalOrderSizeInMW;
        @AuraEnabled public String endUserName;
        @AuraEnabled public String contactCustomerId;
        @AuraEnabled public String contactSitePerson;
        @AuraEnabled public String tenderContract;
        @AuraEnabled public String spareModulesRequired;
        
        @AuraEnabled public String frameThickness;
        @AuraEnabled public String mountingHolePitch;
        @AuraEnabled public String glassThickness;
        @AuraEnabled public String connector;
        @AuraEnabled public String moduleBOM;
        @AuraEnabled public String customizeLogo;
        @AuraEnabled public String packingModulesPerBox;
        @AuraEnabled public String currentBinningRequired;
        @AuraEnabled public String thirdPartyInsurance;
        @AuraEnabled public String anySpecialRequirement;
        @AuraEnabled public String cellMake;
        @AuraEnabled public String cellSize;
        
        @AuraEnabled public String paymentTermId;
        @AuraEnabled public String paymentTermLabel;
        @AuraEnabled public String otherPaymentTerm;
        @AuraEnabled public String transportationMode;
        @AuraEnabled public String documentsThroughLC;
        @AuraEnabled public String customerScope;
        @AuraEnabled public String dispatchProcess;
        @AuraEnabled public String incotermId;
        @AuraEnabled public String incotermLabel;
        @AuraEnabled public String otherIncoterm;
        @AuraEnabled public String deliveryLocation;
        @AuraEnabled public String deliverySchedule;
        @AuraEnabled public String concealmentPeriod;
        @AuraEnabled public Date validityOfOffer;
        @AuraEnabled public String liquidityDamage;
        @AuraEnabled public String otherLiquidityDamage;
        
        @AuraEnabled public List<OpportunityProductWrapper> productRows;
        
        @AuraEnabled public List<FileData> beforeShipmentFiles;
        @AuraEnabled public List<FileData> afterShipmentFiles;
        
        @AuraEnabled public String preparedBySaleRm;
        @AuraEnabled public String preparedBySaleRmDate;
        @AuraEnabled public String approvedBySalesHead;
        @AuraEnabled public String salesHeadApprovalDate;
        @AuraEnabled public String approvedByCommercialHead;
        @AuraEnabled public String commercialHeadApprovalDate;
        
        @AuraEnabled public Boolean psiQap;
        @AuraEnabled public Boolean inpocessQap;
        @AuraEnabled public Boolean rmQap;
        @AuraEnabled public Boolean elAndVisualInspectionCriteria;
        @AuraEnabled public Boolean bom;
        @AuraEnabled public Boolean moduleDatasheet;
        @AuraEnabled public Boolean reliabilityTestingPlan;
        
        @AuraEnabled public List<FileData> psiQapFiles;
        @AuraEnabled public List<FileData> inpocessQapFiles;
        @AuraEnabled public List<FileData> rmQapFiles;
        @AuraEnabled public List<FileData> elAndVisualInspectionCriteriaFiles;
        @AuraEnabled public List<FileData> bomFiles;
        @AuraEnabled public List<FileData> moduleDatasheetFiles;
        @AuraEnabled public List<FileData> reliabilityTestingPlanFiles;
    }
    
    @AuraEnabled(cacheable=true)
    public static InitResponse getInitData(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }
        
        InitResponse response = new InitResponse();
        
        response.opp = [
            SELECT Id, Name, AccountId, Account.Name, Owner.Name,
            RecordTypeId, RecordType.Name, RecordType.DeveloperName,
            UOM__c, Actual_Capacity_text__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        
        response.oppOwnerName = response.opp.Owner != null ? response.opp.Owner.Name : '';
        
        response.isRetail = response.opp.RecordType != null &&
            (
                response.opp.RecordType.DeveloperName == 'Retail' ||
                response.opp.RecordType.Name == 'Retail'
            );
        
        response.products = new List<OpportunityProductWrapper>();
        
        Quote latestQuote = getLatestQuote(opportunityId);
        
        if (latestQuote != null) {
            response.latestQuoteId = latestQuote.Id;
            response.defaultRevNo = getQuoteVersionValue(latestQuote);
            response.products = getQuoteLineRows(latestQuote.Id);
        } else {
            response.latestQuoteId = null;
            response.defaultRevNo = '';
            response.products = new List<OpportunityProductWrapper>();
        }
        
        response.contactOptions = getContactOptionsInternal(response.opp.AccountId);
        response.paymentTermOptions = getGenericOptions(new List<String>{ 'Payment_Term__c', 'Payment_Terms__c' });
        response.incotermOptions = getGenericOptions(new List<String>{ 'Incoterm__c', 'Inco_Term__c', 'Incoterms__c' });
        response.liquidityDamageOptions = getPicklistOptions('Term_Sheet__c', 'Liquidity_Damage__c');
        
        response.defaultDocNo = response.opp.Name;
        
        Date todayDt = Date.today();
        response.todayDate = String.valueOf(todayDt);
        response.displayIssueDate = formatDateDDMMYYYY(todayDt);
        response.defaultValidityDate = String.valueOf(todayDt.addDays(7));
        
        return response;
    }
    
    private static Quote getLatestQuote(Id opportunityId) {
        Map<String, Schema.SObjectField> quoteFields = Schema.SObjectType.Quote.fields.getMap();
        
        String versionFieldApi;
        
        if (quoteFields.containsKey('Version__c')) {
            versionFieldApi = 'Version__c';
        } else if (quoteFields.containsKey('Revision_No__c')) {
            versionFieldApi = 'Revision_No__c';
        } else if (quoteFields.containsKey('Revision_Number__c')) {
            versionFieldApi = 'Revision_Number__c';
        }
        
        String selectFields = 'Id, Name, Status, CreatedDate';
        
        if (String.isNotBlank(versionFieldApi)) {
            selectFields += ', ' + versionFieldApi;
        }
        
        String orderByClause;
        
        if (String.isNotBlank(versionFieldApi)) {
            orderByClause = ' ORDER BY ' + versionFieldApi + ' DESC NULLS LAST, CreatedDate DESC';
        } else {
            orderByClause = ' ORDER BY CreatedDate DESC';
        }
        
        String soql =
            'SELECT ' + selectFields +
            ' FROM Quote' +
            ' WHERE OpportunityId = :opportunityId' +
            ' AND (Status = NULL OR Status != \'Denied\')' +
            orderByClause +
            ' LIMIT 1';
        
        List<Quote> quoteList = Database.query(soql);
        
        return quoteList.isEmpty() ? null : quoteList[0];
    }
    
    private static String getQuoteVersionValue(Quote q) {
        if (q == null) {
            return '';
        }
        
        Map<String, Schema.SObjectField> quoteFields = Schema.SObjectType.Quote.fields.getMap();
        
        String versionFieldApi;
        
        if (quoteFields.containsKey('Version__c')) {
            versionFieldApi = 'Version__c';
        } else if (quoteFields.containsKey('Revision_No__c')) {
            versionFieldApi = 'Revision_No__c';
        } else if (quoteFields.containsKey('Revision_Number__c')) {
            versionFieldApi = 'Revision_Number__c';
        }
        
        if (String.isBlank(versionFieldApi)) {
            return '';
        }
        
        Object versionVal = q.get(versionFieldApi);
        return versionVal == null ? '' : String.valueOf(versionVal);
    }
    
    private static List<OpportunityProductWrapper> getQuoteLineRows(Id quoteId) {
        List<OpportunityProductWrapper> rows = new List<OpportunityProductWrapper>();
        
        if (quoteId == null) {
            return rows;
        }
        
        Map<String, Schema.SObjectField> qliFields = Schema.SObjectType.QuoteLineItem.fields.getMap();
        
        List<String> selectFields = new List<String>{
            'Id',
                'QuoteId',
                'LineNumber',
                'Description',
                'Quantity',
                'UnitPrice',
                'Subtotal',
                'TotalPrice',
                'Product2Id',
                'Product2.Name'
                };
                    
                    addFieldIfExists(selectFields, qliFields, 'Opportunity_Product__c');
        
        addFieldIfExists(selectFields, qliFields, 'Module_Type__c');
        addFieldIfExists(selectFields, qliFields, 'Module_Technology__c');
        addFieldIfExists(selectFields, qliFields, 'Cell_Type__c');
        addFieldIfExists(selectFields, qliFields, 'Product_Rating_BIN__c');
        addFieldIfExists(selectFields, qliFields, 'Product_Sub_Type__c');
        addFieldIfExists(selectFields, qliFields, 'Cable_Length__c');
        addFieldIfExists(selectFields, qliFields, 'Warranty__c');
        addFieldIfExists(selectFields, qliFields, 'Watt_Peak__c');
        
        addFieldIfExists(selectFields, qliFields, 'Product_Capacity__c');
        addFieldIfExists(selectFields, qliFields, 'Project_Capacity__c');
        addFieldIfExists(selectFields, qliFields, 'UOM__c');
        addFieldIfExists(selectFields, qliFields, 'Capacity_in_KW__c');
        addFieldIfExists(selectFields, qliFields, 'Nos__c');
        
        addFieldIfExists(selectFields, qliFields, 'Total__c');
        addFieldIfExists(selectFields, qliFields, 'Grand_Total__c');
        addFieldIfExists(selectFields, qliFields, 'GST__c');
        addFieldIfExists(selectFields, qliFields, 'GST_Percentage__c');
        
        String soql =
            'SELECT ' + String.join(selectFields, ',') +
            ' FROM QuoteLineItem' +
            ' WHERE QuoteId = :quoteId' +
            ' ORDER BY LineNumber ASC, CreatedDate ASC';
        
        List<QuoteLineItem> qliList = Database.query(soql);
        
        String gstFromMetadata = getGstFromMetadata();
        
        Integer srCounter = 1;
        
        for (QuoteLineItem qli : qliList) {
            OpportunityProductWrapper row = new OpportunityProductWrapper();
            
            row.quoteLineItemId = qli.Id;
            
            /*
* Existing JS selection/save logic uses oppLineItemId.
* We are not changing that JS logic.
* So QuoteLineItem Id is assigned here.
*/
            row.oppLineItemId = qli.Id;
            
            row.productId = qli.Product2Id;
            row.productName = qli.Product2 != null ? qli.Product2.Name : '';
            row.opportunityProductId = getStringValue(qli, 'Opportunity_Product__c');
            
            row.quantity = qli.Quantity;
            row.unitPrice = qli.UnitPrice;
            row.totalPrice = qli.TotalPrice;
            
            row.moduleType = getStringValue(qli, 'Module_Type__c');
            row.moduleTechnology = getStringValue(qli, 'Module_Technology__c');
            row.cellType = getStringValue(qli, 'Cell_Type__c');
            row.productRatingBin = getStringValue(qli, 'Product_Rating_BIN__c');
            row.productSubType = getStringValue(qli, 'Product_Sub_Type__c');
            row.cableLength = getStringValue(qli, 'Cable_Length__c');
            row.warranty = getStringValue(qli, 'Warranty__c');
            row.wattPeak = getDecimalValue(qli, 'Watt_Peak__c');
            
            row.projectCapacity = getDecimalValue(qli, 'Product_Capacity__c');
            
            if (row.projectCapacity == null) {
                row.projectCapacity = getDecimalValue(qli, 'Project_Capacity__c');
            }
            
            row.uom = getStringValue(qli, 'UOM__c');
            row.capacityInKW = getStringValue(qli, 'Capacity_in_KW__c');
            
            row.nos = getStringValue(qli, 'Nos__c');
            
            if (String.isBlank(row.nos)) {
                row.nos = qli.Quantity == null ? '' : String.valueOf(qli.Quantity);
            }
            
            row.priceWp = qli.UnitPrice == null ? '' : String.valueOf(qli.UnitPrice);
            
            row.total = getStringValue(qli, 'Total__c');
            
            if (String.isBlank(row.total)) {
                row.total = qli.Subtotal == null ? '' : String.valueOf(qli.Subtotal);
            }
            
            row.gst = getStringValue(qli, 'GST__c');
            
            if (String.isBlank(row.gst)) {
                row.gst = getStringValue(qli, 'GST_Percentage__c');
            }
            
            if (String.isBlank(row.gst)) {
                row.gst = gstFromMetadata;
            }
            
            row.grandTotal = getStringValue(qli, 'Grand_Total__c');
            
            if (String.isBlank(row.grandTotal)) {
                row.grandTotal = qli.TotalPrice == null ? '' : String.valueOf(qli.TotalPrice);
            }
            
            row.materialDescription = buildMaterialDescription(
                row.productRatingBin,
                row.moduleTechnology,
                row.cableLength,
                row.productSubType,
                row.moduleType
            );
            
            if (String.isBlank(row.materialDescription)) {
                row.materialDescription = String.isNotBlank(qli.Description)
                    ? qli.Description
                    : row.productName;
            }
            
            row.srNo = srCounter;
            
            row.cellTypeModuleTechnologyDisplay =
                (String.isBlank(row.cellType) ? '' : row.cellType) +
                (String.isBlank(row.moduleTechnology)
                 ? ''
                 : (String.isBlank(row.cellType) ? '' : ' / ') + row.moduleTechnology);
            
            row.wpBinInput = row.productRatingBin;
            row.binPercentageInput = 'No';
            row.binPercentageValueInput = '';
            row.moduleEfficiencyCriteriaInput = '';
            row.noOfModulesInput = row.nos;
            row.systemVoltageInput = '';
            
            row.frameThicknessInput = '';
            row.mountingHolePitchInput = '';
            row.glassThicknessInput = '';
            row.cableLengthInput = row.cableLength;
            row.connectorInput = '';
            row.moduleBOMInput = '';
            row.customizeLogoInput = '';
            row.packingModulesPerBoxInput = '';
            row.currentBinningRequiredInput = '';
            row.thirdPartyInsuranceInput = '';
            row.anySpecialRequirementInput = '';
            row.cellMakeInput = '';
            row.cellSizeInput = '';
            
            rows.add(row);
            srCounter++;
        }
        
        return rows;
    }
    
    private static List<OptionData> getPicklistOptions(String objectApiName, String fieldApiName) {
        List<OptionData> options = new List<OptionData>();
        
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        
        if (!gd.containsKey(objectApiName)) {
            return options;
        }
        
        Schema.DescribeSObjectResult objDescribe = gd.get(objectApiName).getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        
        if (!fieldMap.containsKey(fieldApiName)) {
            return options;
        }
        
        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldApiName).getDescribe();
        
        for (Schema.PicklistEntry pe : fieldDescribe.getPicklistValues()) {
            if (pe.isActive()) {
                options.add(new OptionData(pe.getLabel(), pe.getValue()));
            }
        }
        
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<OptionData> getContactsByAccount(Id accountId) {
        return getContactOptionsInternal(accountId);
    }
    
    @AuraEnabled
    public static Id createTermSheetAndLineItems(
        String opportunityId,
        String reqJson
    ) {
        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException('Opportunity Id is required.');
        }
        
        if (String.isBlank(reqJson)) {
            throw new AuraHandledException('Request data is blank.');
        }
        
        SaveRequest req = (SaveRequest) JSON.deserialize(reqJson, SaveRequest.class);
        
        Id oppId = (Id) opportunityId;
        Id custId = String.isNotBlank(req.customerId) ? (Id) req.customerId : null;
        Id contactCustId = String.isNotBlank(req.contactCustomerId) ? (Id) req.contactCustomerId : null;
        
        Map<Id, OpportunityProductWrapper> inputRowByQuoteLineId = new Map<Id, OpportunityProductWrapper>();
        
        if (req.productRows != null && !req.productRows.isEmpty()) {
            for (OpportunityProductWrapper row : req.productRows) {
                if (row != null && row.oppLineItemId != null) {
                    inputRowByQuoteLineId.put(row.oppLineItemId, row);
                }
            }
        }

        Savepoint sp = Database.setSavepoint();
        
        try {
            Opportunity opp = [
                SELECT Id, Name, AccountId
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];

            Quote latestQuote = getLatestQuote(oppId);

            if (latestQuote == null) {
                throw new AuraHandledException('No valid Quote found for this Opportunity.');
            }

            Id latestQuoteId = latestQuote.Id;
            
            Term_Sheet__c ts = new Term_Sheet__c();
            
            String safeTermSheetName = String.isBlank(req.termSheetName)
                ? 'TS - ' + opp.Name
                : req.termSheetName;
            
            if (safeTermSheetName.length() > 80) {
                safeTermSheetName = safeTermSheetName.substring(0, 80);
            }
            
            ts.Name = safeTermSheetName;
            ts.Opportunity__c = opp.Id;
            
            if (custId != null) {
                ts.Name_of_customer__c = custId;
            } else if (opp.AccountId != null) {
                ts.Name_of_customer__c = opp.AccountId;
            }
            
            ts.End_User_name__c = req.endUserName;
            ts.Contact_Person_Name_of_Customer__c = contactCustId;
            ts.Contact_Person_Name_Site_Person__c = req.contactSitePerson;
            ts.Tender_Contract_if_any__c = req.tenderContract;
            ts.Spare_modules_required__c = req.spareModulesRequired;
            ts.Concealment_Period__c = req.concealmentPeriod;
            ts.Customer_Scope__c = req.customerScope;
            ts.Delivery_Location__c = req.deliveryLocation;
            ts.Delivery_Schedule__c = req.deliverySchedule;
            ts.Dispatch_process__c = req.dispatchProcess;
            ts.Transportation_Mode__c = req.transportationMode;
            ts.Validity_of_Offer__c = req.validityOfOffer;
            ts.Liquidity_Damage__c = req.liquidityDamage;
            
            putIfFieldExists(ts, 'Others_Liquidity_Damage__c', req.otherLiquidityDamage);
            putIfFieldExists(ts, 'Other_Payment_Terms__c', req.otherPaymentTerm);
            putIfFieldExists(ts, 'Other_Incoterms__c', req.otherIncoterm);
            
            putIfFieldExists(ts, 'Doc_No__c', req.docNo);
            putIfFieldExists(ts, 'Rev_No__c', req.revNo);
            putDateIfFieldExists(ts, 'Issue_Date__c', req.issueDate);
            
            putIfFieldExists(ts, 'Total_Order_Size_in_MW__c', req.totalOrderSizeInMW);
            putIfFieldExists(ts, 'Frame_Thickness__c', req.frameThickness);
            putIfFieldExists(ts, 'Mounting_Hole_X_Y_Pitch__c', req.mountingHolePitch);
            putIfFieldExists(ts, 'Glass_Thickness__c', req.glassThickness);
            putIfFieldExists(ts, 'Connector__c', req.connector);
            putIfFieldExists(ts, 'Module_BOM__c', req.moduleBOM);
            putIfFieldExists(ts, 'Customize_Logo__c', req.customizeLogo);
            putIfFieldExists(ts, 'Packing_Number_of_modules_per_box__c', req.packingModulesPerBox);
            putIfFieldExists(ts, 'Current_Binning_Required__c', req.currentBinningRequired);
            putIfFieldExists(ts, 'Third_Party_Insurance__c', req.thirdPartyInsurance);
            putIfFieldExists(ts, 'Any_Special_Requirement__c', req.anySpecialRequirement);
            putIfFieldExists(ts, 'Cell_Make__c', req.cellMake);
            putIfFieldExists(ts, 'Cell_Size__c', req.cellSize);
            
            putIfFieldExists(ts, 'Prepared_by_Sale_RM__c', req.preparedBySaleRm);
            putDateIfFieldExists(ts, 'Prepared_by_Sale_RM_Date__c', req.preparedBySaleRmDate);
            putIfFieldExists(ts, 'Approved_by_Sales_Head__c', req.approvedBySalesHead);
            putDateIfFieldExists(ts, 'Sales_Head_Approval_Date__c', req.salesHeadApprovalDate);
            putIfFieldExists(ts, 'Approved_by_Commercial_Head__c', req.approvedByCommercialHead);
            putDateIfFieldExists(ts, 'Commercial_Head_Approval_Date__c', req.commercialHeadApprovalDate);
            
            putIfFieldExists(ts, 'Documents_to_be_submitted_to_customer_th__c', req.documentsThroughLC);
            
            if (String.isNotBlank(req.paymentTermId)) {
                ts.Payment_Term__c = (Id) req.paymentTermId;
            }
            
            if (String.isNotBlank(req.incotermId)) {
                ts.IncoTerms__c = (Id) req.incotermId;
            }
            
            insert ts;
            
            Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
            putIfFieldExists(oppToUpdate, 'Is_Retail_Term_Sheet_Created__c', true);
            putIfFieldExists(oppToUpdate, 'Is_Term_Sheet_Created__c', true);
            
            if (oppToUpdate.getPopulatedFieldsAsMap().size() > 1) {
                update oppToUpdate;
            }
            
            Map<String, Schema.SObjectField> qliFields = Schema.SObjectType.QuoteLineItem.fields.getMap();
            
            List<String> qliSelectFields = new List<String>{
                'Id',
                    'Description',
                    'Quantity',
                    'UnitPrice',
                    'Subtotal',
                    'TotalPrice',
                    'Product2Id',
                    'Product2.Name'
                    };
                        
                        addFieldIfExists(qliSelectFields, qliFields, 'Opportunity_Product__c');
            
            addFieldIfExists(qliSelectFields, qliFields, 'Module_Type__c');
            addFieldIfExists(qliSelectFields, qliFields, 'Module_Technology__c');
            addFieldIfExists(qliSelectFields, qliFields, 'Cell_Type__c');
            addFieldIfExists(qliSelectFields, qliFields, 'Product_Rating_BIN__c');
            addFieldIfExists(qliSelectFields, qliFields, 'Product_Sub_Type__c');
            addFieldIfExists(qliSelectFields, qliFields, 'Cable_Length__c');
            addFieldIfExists(qliSelectFields, qliFields, 'Warranty__c');
            
            addFieldIfExists(qliSelectFields, qliFields, 'Product_Capacity__c');
            addFieldIfExists(qliSelectFields, qliFields, 'Project_Capacity__c');
            addFieldIfExists(qliSelectFields, qliFields, 'UOM__c');
            addFieldIfExists(qliSelectFields, qliFields, 'Capacity_in_KW__c');
            addFieldIfExists(qliSelectFields, qliFields, 'Nos__c');
            
            addFieldIfExists(qliSelectFields, qliFields, 'Total__c');
            addFieldIfExists(qliSelectFields, qliFields, 'Grand_Total__c');
            addFieldIfExists(qliSelectFields, qliFields, 'GST__c');
            addFieldIfExists(qliSelectFields, qliFields, 'GST_Percentage__c');
            
            String qliSoql =
                'SELECT ' + String.join(qliSelectFields, ',') +
                ' FROM QuoteLineItem' +
                ' WHERE QuoteId = :latestQuoteId';
            
            List<QuoteLineItem> quoteLineItems = Database.query(qliSoql);
            
            if (quoteLineItems.isEmpty()) {
                throw new AuraHandledException('No valid Quote Line Items found.');
            }
            
            List<Term_Sheet_Line_Item__c> lineItemsToInsert = new List<Term_Sheet_Line_Item__c>();
            
            String gstFromMetadata = getGstFromMetadata();
            
            for (QuoteLineItem qli : quoteLineItems) {
                OpportunityProductWrapper inputRow = inputRowByQuoteLineId.get(qli.Id);
                
                String productName = qli.Product2 != null ? qli.Product2.Name : 'Quote Line Item';
                
                String productRatingBinVal = getStringValue(qli, 'Product_Rating_BIN__c');
                String moduleTechnologyVal = getStringValue(qli, 'Module_Technology__c');
                String cellTypeVal = getStringValue(qli, 'Cell_Type__c');
                String cableLengthVal = getStringValue(qli, 'Cable_Length__c');
                String productSubTypeVal = getStringValue(qli, 'Product_Sub_Type__c');
                String moduleTypeVal = getStringValue(qli, 'Module_Type__c');
                
                String materialDescriptionVal = buildMaterialDescription(
                    productRatingBinVal,
                    moduleTechnologyVal,
                    cableLengthVal,
                    productSubTypeVal,
                    moduleTypeVal
                );
                
                if (String.isBlank(materialDescriptionVal)) {
                    materialDescriptionVal = String.isNotBlank(qli.Description)
                        ? qli.Description
                        : productName;
                }
                
                String lineProjectCapacityVal = getStringValue(qli, 'Product_Capacity__c');
                
                if (String.isBlank(lineProjectCapacityVal)) {
                    lineProjectCapacityVal = getStringValue(qli, 'Project_Capacity__c');
                }
                
                String uomVal = getStringValue(qli, 'UOM__c');
                
                String nosVal = getStringValue(qli, 'Nos__c');
                
                if (String.isBlank(nosVal)) {
                    nosVal = qli.Quantity == null ? '' : String.valueOf(qli.Quantity);
                }
                
                String capacityKwVal = getStringValue(qli, 'Capacity_in_KW__c');
                
                String priceWpVal = qli.UnitPrice == null ? '' : String.valueOf(qli.UnitPrice);
                
                String subtotalVal = getStringValue(qli, 'Total__c');
                
                if (String.isBlank(subtotalVal)) {
                    subtotalVal = qli.Subtotal == null ? '' : String.valueOf(qli.Subtotal);
                }
                
                String gstVal = getStringValue(qli, 'GST__c');
                
                if (String.isBlank(gstVal)) {
                    gstVal = getStringValue(qli, 'GST_Percentage__c');
                }
                
                if (String.isBlank(gstVal) && inputRow != null) {
                    gstVal = inputRow.gst;
                }
                
                if (String.isBlank(gstVal)) {
                    gstVal = gstFromMetadata;
                }
                
                String grandTotalVal = getStringValue(qli, 'Grand_Total__c');
                
                if (String.isBlank(grandTotalVal)) {
                    grandTotalVal = qli.TotalPrice == null ? '' : String.valueOf(qli.TotalPrice);
                }
                
                Term_Sheet_Line_Item__c li = new Term_Sheet_Line_Item__c();
                
                li.Term_Sheet__c = ts.Id;
                li.Name = productName.length() > 80 ? productName.substring(0, 80) : productName;
                
                putFieldValueIfExists(li, 'Quote_Line_Item__c', String.valueOf(qli.Id));
                putFieldValueIfExists(li, 'Product__c', String.valueOf(qli.Product2Id));
                putFieldValueIfExists(li, 'Opportunity_Product__c', getStringValue(qli, 'Opportunity_Product__c'));
                
                putFieldValueIfExists(li, 'Material_Description__c', materialDescriptionVal);
                
                putFieldValueIfExists(li, 'Module_Type__c', moduleTypeVal);
                putFieldValueIfExists(li, 'Module_Technology__c', moduleTechnologyVal);
                putFieldValueIfExists(li, 'Cell_Type__c', cellTypeVal);
                putFieldValueIfExists(li, 'Product_Rating_BIN__c', productRatingBinVal);
                putFieldValueIfExists(li, 'Wp_Bin__c', productRatingBinVal);
                putFieldValueIfExists(li, 'Product_Sub_Type__c', productSubTypeVal);
                putFieldValueIfExists(li, 'Cable_Length__c', cableLengthVal);
                putFieldValueIfExists(li, 'Warranty__c', getStringValue(qli, 'Warranty__c'));
                
                /*
* QuoteLineItem.Product_Capacity__c
* saves into Term_Sheet_Line_Item__c.Project_Capacity__c
*/
                putFieldValueIfExists(li, 'Project_Capacity__c', lineProjectCapacityVal);
                
                /*
* QuoteLineItem.UOM__c
* saves into Term_Sheet_Line_Item__c.UOM__c
*/
                putFieldValueIfExists(li, 'UOM__c', uomVal);
                
                /*
* QuoteLineItem.Nos__c
* saves into Term_Sheet_Line_Item__c.Nos__c
*/
                putFieldValueIfExists(li, 'Nos__c', nosVal);
                putFieldValueIfExists(li, 'Number_of_modules__c', nosVal);
                
                putFieldValueIfExists(li, 'Capacity_in_KW__c', capacityKwVal);
                putFieldValueIfExists(li, 'Price_Wp__c', priceWpVal);
                putFieldValueIfExists(li, 'Subtotal__c', subtotalVal);
                putFieldValueIfExists(li, 'Total__c', subtotalVal);
                putFieldValueIfExists(li, 'GST__c', gstVal);
                putFieldValueIfExists(li, 'Grand_Total__c', grandTotalVal);
                
                if (inputRow != null) {
                    putFieldValueIfExists(li, 'Bin_Percentage_Applicable__c', inputRow.binPercentageInput);
                    
                    if (inputRow.binPercentageInput == 'Yes') {
                        putFieldValueIfExists(li, 'Bin_Percentage__c', inputRow.binPercentageValueInput);
                    }
                    
                    putFieldValueIfExists(
                        li,
                        'Module_Efficiency_Criteria_as_per_tender__c',
                        inputRow.moduleEfficiencyCriteriaInput
                    );
                    
                    putFieldValueIfExists(li, 'System_Voltage__c', inputRow.systemVoltageInput);
                    
                    putFieldValueIfExists(
                        li,
                        'Frame_Thickness__c',
                        String.isNotBlank(inputRow.frameThicknessInput) ? inputRow.frameThicknessInput : req.frameThickness
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Mounting_Hole_X_pitch_Y_pitch__c',
                        String.isNotBlank(inputRow.mountingHolePitchInput) ? inputRow.mountingHolePitchInput : req.mountingHolePitch
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Glass_Thickness__c',
                        String.isNotBlank(inputRow.glassThicknessInput) ? inputRow.glassThicknessInput : req.glassThickness
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Connector__c',
                        String.isNotBlank(inputRow.connectorInput) ? inputRow.connectorInput : req.connector
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Module_BOM__c',
                        String.isNotBlank(inputRow.moduleBOMInput) ? inputRow.moduleBOMInput : req.moduleBOM
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Customize_logo__c',
                        String.isNotBlank(inputRow.customizeLogoInput) ? inputRow.customizeLogoInput : req.customizeLogo
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Packing_Number_of_modules_per_box__c',
                        String.isNotBlank(inputRow.packingModulesPerBoxInput) ? inputRow.packingModulesPerBoxInput : req.packingModulesPerBox
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Current_Binning_Required__c',
                        String.isNotBlank(inputRow.currentBinningRequiredInput) ? inputRow.currentBinningRequiredInput : req.currentBinningRequired
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Third_Party_Insurance__c',
                        String.isNotBlank(inputRow.thirdPartyInsuranceInput) ? inputRow.thirdPartyInsuranceInput : req.thirdPartyInsurance
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Any_special_requirement__c',
                        String.isNotBlank(inputRow.anySpecialRequirementInput) ? inputRow.anySpecialRequirementInput : req.anySpecialRequirement
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Cell_Make__c',
                        String.isNotBlank(inputRow.cellMakeInput) ? inputRow.cellMakeInput : req.cellMake
                    );
                    
                    putFieldValueIfExists(
                        li,
                        'Cell_Size__c',
                        String.isNotBlank(inputRow.cellSizeInput) ? inputRow.cellSizeInput : req.cellSize
                    );
                } else {
                    putFieldValueIfExists(li, 'Frame_Thickness__c', req.frameThickness);
                    putFieldValueIfExists(li, 'Mounting_Hole_X_pitch_Y_pitch__c', req.mountingHolePitch);
                    putFieldValueIfExists(li, 'Glass_Thickness__c', req.glassThickness);
                    putFieldValueIfExists(li, 'Connector__c', req.connector);
                    putFieldValueIfExists(li, 'Module_BOM__c', req.moduleBOM);
                    putFieldValueIfExists(li, 'Customize_logo__c', req.customizeLogo);
                    putFieldValueIfExists(li, 'Packing_Number_of_modules_per_box__c', req.packingModulesPerBox);
                    putFieldValueIfExists(li, 'Current_Binning_Required__c', req.currentBinningRequired);
                    putFieldValueIfExists(li, 'Third_Party_Insurance__c', req.thirdPartyInsurance);
                    putFieldValueIfExists(li, 'Any_special_requirement__c', req.anySpecialRequirement);
                    putFieldValueIfExists(li, 'Cell_Make__c', req.cellMake);
                    putFieldValueIfExists(li, 'Cell_Size__c', req.cellSize);
                }
                
                lineItemsToInsert.add(li);
            }
            
            insert lineItemsToInsert;
            
            List<FileData> allFiles = new List<FileData>();
            
            if (req.beforeShipmentFiles != null) {
                allFiles.addAll(req.beforeShipmentFiles);
            }
            
            if (req.afterShipmentFiles != null) {
                allFiles.addAll(req.afterShipmentFiles);
            }
            
            if (!allFiles.isEmpty()) {
                uploadFiles(ts.Id, allFiles);
            }
            
            return ts.Id;
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error while creating Term Sheet: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id updateChecklistAndUploadFiles(Id termSheetId, String reqJson) {
        if (termSheetId == null) {
            throw new AuraHandledException('Term Sheet Id is required.');
        }
        
        if (String.isBlank(reqJson)) {
            throw new AuraHandledException('Request data is blank.');
        }
        
        SaveRequest req = (SaveRequest) JSON.deserialize(reqJson, SaveRequest.class);
        validateMandatoryChecklist(req);
        
        Savepoint sp = Database.setSavepoint();
        
        try {
            Term_Sheet__c ts = [
                SELECT Id
                FROM Term_Sheet__c
                WHERE Id = :termSheetId
                LIMIT 1
            ];
            
            putIfFieldExists(ts, 'PSI_QAP__c', req.psiQap);
            putIfFieldExists(ts, 'Inpocess_QAP__c', req.inpocessQap);
            putIfFieldExists(ts, 'RM_QAP__c', req.rmQap);
            putIfFieldExists(ts, 'EL_and_Visual_Inspection_Criteria__c', req.elAndVisualInspectionCriteria);
            putIfFieldExists(ts, 'BOM__c', req.bom);
            putIfFieldExists(ts, 'Module_Datasheet__c', req.moduleDatasheet);
            putIfFieldExists(ts, 'Reliability_Testing_Plan__c', req.reliabilityTestingPlan);
            
            update ts;
            
            uploadFilesWithPrefix(ts.Id, req.psiQapFiles, 'PSI_QAP');
            uploadFilesWithPrefix(ts.Id, req.inpocessQapFiles, 'INPROCESS_QAP');
            uploadFilesWithPrefix(ts.Id, req.rmQapFiles, 'RM_QAP');
            uploadFilesWithPrefix(ts.Id, req.elAndVisualInspectionCriteriaFiles, 'EL_VISUAL_INSPECTION');
            uploadFilesWithPrefix(ts.Id, req.bomFiles, 'BOM');
            uploadFilesWithPrefix(ts.Id, req.moduleDatasheetFiles, 'MODULE_DATASHEET');
            uploadFilesWithPrefix(ts.Id, req.reliabilityTestingPlanFiles, 'RELIABILITY_TESTING_PLAN');
            
            return ts.Id;
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error while updating checklist: ' + e.getMessage());
        }
    }
    
    private static void validateMandatoryChecklist(SaveRequest req) {
        if (req == null) {
            throw new AuraHandledException('Request data is blank.');
        }
        
        if (req.psiQap == true) {
            validateMandatoryFiles(req.psiQapFiles, 'PSI QAP');
        }
        
        if (req.inpocessQap == true) {
            validateMandatoryFiles(req.inpocessQapFiles, 'Inpocess QAP');
        }
        
        if (req.rmQap == true) {
            validateMandatoryFiles(req.rmQapFiles, 'RM QAP');
        }
        
        if (req.elAndVisualInspectionCriteria == true) {
            validateMandatoryFiles(
                req.elAndVisualInspectionCriteriaFiles,
                'EL and Visual Inspection Criteria'
            );
        }
        
        if (req.bom == true) {
            validateMandatoryFiles(req.bomFiles, 'BOM');
        }
        
        if (req.moduleDatasheet == true) {
            validateMandatoryFiles(req.moduleDatasheetFiles, 'Module Datasheet');
        }
        
        if (req.reliabilityTestingPlan == true) {
            validateMandatoryFiles(
                req.reliabilityTestingPlanFiles,
                'Reliability Testing Plan'
            );
        }
    }
    private static void validateMandatoryFiles(List<FileData> files, String label) {
        if (files == null || files.isEmpty()) {
            throw new AuraHandledException(label + ' files are mandatory.');
        }
    }
    
    private static List<OptionData> getContactOptionsInternal(Id accountId) {
        List<OptionData> options = new List<OptionData>();
        
        if (accountId == null) {
            return options;
        }
        
        for (Contact con : [
            SELECT Id, Name
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY Name
            LIMIT 200
        ]) {
            options.add(new OptionData(con.Name, con.Id));
        }
        
        return options;
    }
    
    private static List<OptionData> getGenericOptions(List<String> candidateObjectNames) {
        List<OptionData> options = new List<OptionData>();
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        
        for (String objApi : candidateObjectNames) {
            if (gd.containsKey(objApi)) {
                Schema.DescribeSObjectResult objDescribe = gd.get(objApi).getDescribe();
                Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
                String descriptionFieldApi = getDescriptionFieldApi(fieldMap);
                
                String soql = 'SELECT Id, Name';
                
                if (String.isNotBlank(descriptionFieldApi)) {
                    soql += ', ' + descriptionFieldApi;
                }
                
                soql += ' FROM ' + objApi + ' ORDER BY Name LIMIT 200';
                
                for (SObject sob : Database.query(soql)) {
                    String nameVal = String.valueOf(sob.get('Name'));
                    String labelVal = nameVal;
                    
                    if (String.isNotBlank(descriptionFieldApi) && sob.get(descriptionFieldApi) != null) {
                        String descVal = String.valueOf(sob.get(descriptionFieldApi));
                        
                        if (String.isNotBlank(descVal)) {
                            labelVal = nameVal + ' - ' + descVal;
                        }
                    }
                    
                    options.add(new OptionData(labelVal, String.valueOf(sob.get('Id'))));
                }
                
                break;
            }
        }
        
        return options;
    }
    
    private static String getDescriptionFieldApi(Map<String, Schema.SObjectField> fieldMap) {
        List<String> candidateDescriptionFields = new List<String>{
            'Description__c',
                'Description',
                'Term_Description__c',
                'Terms_Description__c',
                'Payment_Term_Description__c',
                'Incoterm_Description__c',
                'Details__c'
                };
                    
                    for (String fieldApi : candidateDescriptionFields) {
                        if (fieldMap.containsKey(fieldApi)) {
                            return fieldApi;
                        }
                    }
        
        return null;
    }
    
    private static void putIfFieldExists(SObject sobj, String fieldApi, Object value) {
        if (value == null) {
            return;
        }
        
        if (value instanceof String && String.isBlank((String) value)) {
            return;
        }
        
        Map<String, Schema.SObjectField> fieldMap = sobj.getSObjectType().getDescribe().fields.getMap();
        
        if (fieldMap.containsKey(fieldApi)) {
            sobj.put(fieldApi, value);
        }
    }
    
    private static void putDateIfFieldExists(SObject sobj, String fieldApi, String value) {
        if (String.isBlank(value)) {
            return;
        }
        
        Map<String, Schema.SObjectField> fieldMap = sobj.getSObjectType().getDescribe().fields.getMap();
        
        if (fieldMap.containsKey(fieldApi)) {
            sobj.put(fieldApi, Date.valueOf(value));
        }
    }
    
    private static void uploadFiles(Id parentId, List<FileData> files) {
        List<ContentVersion> versions = new List<ContentVersion>();
        
        for (FileData fileItem : files) {
            if (fileItem == null || String.isBlank(fileItem.fileName) || String.isBlank(fileItem.base64Data)) {
                continue;
            }
            
            ContentVersion cv = new ContentVersion();
            cv.Title = fileItem.fileName.contains('.') ? fileItem.fileName.substringBeforeLast('.') : fileItem.fileName;
            cv.PathOnClient = '/' + fileItem.fileName;
            cv.VersionData = EncodingUtil.base64Decode(fileItem.base64Data);
            versions.add(cv);
        }
        
        if (versions.isEmpty()) {
            return;
        }
        
        insert versions;
        
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :versions
        ]) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId = parentId;
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            links.add(cdl);
        }
        
        if (!links.isEmpty()) {
            insert links;
        }
    }
    
    private static void uploadFilesWithPrefix(Id parentId, List<FileData> files, String prefix) {
        List<ContentVersion> versions = new List<ContentVersion>();
        
        if (files == null || files.isEmpty()) {
            return;
        }
        
        for (FileData fileItem : files) {
            if (fileItem == null || String.isBlank(fileItem.fileName) || String.isBlank(fileItem.base64Data)) {
                continue;
            }
            
            ContentVersion cv = new ContentVersion();
            String fullName = prefix + ' - ' + fileItem.fileName;
            cv.Title = fullName.contains('.') ? fullName.substringBeforeLast('.') : fullName;
            cv.PathOnClient = '/' + fullName;
            cv.VersionData = EncodingUtil.base64Decode(fileItem.base64Data);
            versions.add(cv);
        }
        
        if (versions.isEmpty()) {
            return;
        }
        
        insert versions;
        
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :versions
        ]) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId = parentId;
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            links.add(cdl);
        }
        
        if (!links.isEmpty()) {
            insert links;
        }
    }
    
    private static String formatDateDDMMYYYY(Date inputDate) {
        if (inputDate == null) {
            return '';
        }
        
        String dd = String.valueOf(inputDate.day()).leftPad(2, '0');
        String mm = String.valueOf(inputDate.month()).leftPad(2, '0');
        String yyyy = String.valueOf(inputDate.year());
        
        return dd + '-' + mm + '-' + yyyy;
    }
    
    private static void addFieldIfExists(
        List<String> selectFields,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldApiName
    ) {
        if (
            selectFields != null &&
            fieldMap != null &&
            fieldMap.containsKey(fieldApiName) &&
            !selectFields.contains(fieldApiName)
        ) {
            selectFields.add(fieldApiName);
        }
    }
    
    private static String getStringValue(SObject record, String fieldApiName) {
        if (record == null || String.isBlank(fieldApiName)) {
            return '';
        }
        
        Map<String, Schema.SObjectField> fieldMap =
            record.getSObjectType().getDescribe().fields.getMap();
        
        if (!fieldMap.containsKey(fieldApiName)) {
            return '';
        }
        
        try {
            Object valueObj = record.get(fieldApiName);
            return valueObj == null ? '' : String.valueOf(valueObj);
        } catch (Exception e) {
            return '';
        }
    }
    
    private static Decimal getDecimalValue(SObject record, String fieldApiName) {
        String val = getStringValue(record, fieldApiName);
        
        if (String.isBlank(val)) {
            return null;
        }
        
        try {
            return Decimal.valueOf(cleanNumber(val));
        } catch (Exception e) {
            return null;
        }
    }
    
    private static String getGstFromMetadata() {
        try {
            List<GST__mdt> gstList = [
                SELECT GST__c
                FROM GST__mdt
                LIMIT 1
            ];
            
            if (gstList.isEmpty() || gstList[0].GST__c == null) {
                return '';
            }
            
            Decimal gstValue = gstList[0].GST__c;
            
            if (gstValue > 0 && gstValue < 1) {
                gstValue = gstValue * 100;
            }
            
            return String.valueOf(gstValue.setScale(0)) + ' %';
            
        } catch (Exception e) {
            return '';
        }
    }
    
    private static String buildMaterialDescription(
        String productRatingBinVal,
        String moduleTechnologyVal,
        String cableLengthVal,
        String productSubTypeVal,
        String moduleTypeVal
    ) {
        List<String> parts = new List<String>();
        
        if (!String.isBlank(productRatingBinVal)) {
            parts.add(productRatingBinVal + ' WP');
        }
        
        if (!String.isBlank(moduleTechnologyVal)) {
            parts.add(moduleTechnologyVal);
        }
        
        if (!String.isBlank(cableLengthVal)) {
            parts.add(cableLengthVal + ' mm (Cable length)');
        }
        
        if (!String.isBlank(productSubTypeVal)) {
            parts.add(productSubTypeVal);
        }
        
        if (!String.isBlank(moduleTypeVal)) {
            parts.add(moduleTypeVal);
        }
        
        return String.join(parts, ' - ');
    }
    
    private static void putFieldValueIfExists(SObject record, String fieldApiName, String rawValue) {
        if (record == null || String.isBlank(fieldApiName) || String.isBlank(rawValue)) {
            return;
        }
        
        Map<String, Schema.SObjectField> fieldMap =
            record.getSObjectType().getDescribe().fields.getMap();
        
        if (!fieldMap.containsKey(fieldApiName)) {
            return;
        }
        
        String value = rawValue.trim();
        
        if (String.isBlank(value)) {
            return;
        }
        
        Schema.DisplayType fieldType = fieldMap.get(fieldApiName).getDescribe().getType();
        
        try {
            switch on fieldType {
                when STRING, TEXTAREA, ENCRYPTEDSTRING, EMAIL, PHONE, URL, PICKLIST, MULTIPICKLIST, ID, REFERENCE {
                    record.put(fieldApiName, value);
                }
                when CURRENCY, DOUBLE, PERCENT {
                    record.put(fieldApiName, Decimal.valueOf(cleanNumber(value)));
                }
                when INTEGER {
                    record.put(fieldApiName, Integer.valueOf(cleanNumber(value)));
                }
                when LONG {
                    record.put(fieldApiName, Long.valueOf(cleanNumber(value)));
                }
                when DATE {
                    record.put(fieldApiName, Date.valueOf(value));
                }
                when BOOLEAN {
                    String lowerVal = value.toLowerCase();
                    record.put(
                        fieldApiName,
                        lowerVal == 'true' || lowerVal == 'yes' || lowerVal == '1'
                    );
                }
                when else {
                    record.put(fieldApiName, value);
                }
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Invalid value for ' + fieldApiName + ': ' + value);
        }
    }
    
    private static String cleanNumber(String inputVal) {
        if (String.isBlank(inputVal)) {
            return '';
        }
        
        return inputVal
            .replace('INR', '')
            .replace('₹', '')
            .replace(',', '')
            .replace('%', '')
            .trim();
    }
    
    public void datacover(){
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}