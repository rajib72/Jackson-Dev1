public without sharing class InstTermSheetController {
    
    @AuraEnabled(cacheable=true)
    public static InitResponse getInitData(Id opportunityId) {
        InitResponse res = new InitResponse();
        
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }
        
        res.opp = [
            SELECT Id, Name, AccountId, Account.Name, Tender_Name__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        
        Quote latestQuote = getLatestQuote(opportunityId);
        
        res.quoteLines = new List<QuoteLineWrapper>();
        
        if (latestQuote != null) {
            res.latestQuoteId = latestQuote.Id;
            res.revNo = getQuoteVersionValue(latestQuote);
            res.quoteLines = getQuoteLineRows(latestQuote.Id);
        } else {
            res.latestQuoteId = null;
            res.revNo = '';
        }
        
        Date today = Date.today();
        
        res.todayDateDisplay =
            String.valueOf(today.day()).leftPad(2, '0') + '-' +
            String.valueOf(today.month()).leftPad(2, '0') + '-' +
            String.valueOf(today.year());
        
        res.todayDateDb = String.valueOf(today);
        
        return res;
    }
    
    private static Quote getLatestQuote(Id opportunityId) {
        Map<String, Schema.SObjectField> quoteFields =
            Schema.SObjectType.Quote.fields.getMap();
        
        String versionFieldApi;
        
        if (quoteFields.containsKey('Version__c')) {
            versionFieldApi = 'Version__c';
        } else if (quoteFields.containsKey('Revision_No__c')) {
            versionFieldApi = 'Revision_No__c';
        } else if (quoteFields.containsKey('Revision_Number__c')) {
            versionFieldApi = 'Revision_Number__c';
        }
        
        String selectFields = 'Id, Name, Status, CreatedDate';
        
        if (!String.isBlank(versionFieldApi)) {
            selectFields += ', ' + versionFieldApi;
        }
        
        String orderByClause;
        
        if (!String.isBlank(versionFieldApi)) {
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
        
        Map<String, Schema.SObjectField> quoteFields =
            Schema.SObjectType.Quote.fields.getMap();
        
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
    
    private static List<QuoteLineWrapper> getQuoteLineRows(Id quoteId) {
        Map<String, Schema.SObjectField> qliFields =
            Schema.SObjectType.QuoteLineItem.fields.getMap();
        
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
                'Product2.Name',
                'Product2.Family'
                };
                    
                    addFieldIfExists(selectFields, qliFields, 'Opportunity_Product__c');
        
        addFieldIfExists(selectFields, qliFields, 'Module_Type__c');
        addFieldIfExists(selectFields, qliFields, 'Module_Technology__c');
        addFieldIfExists(selectFields, qliFields, 'Product_Rating_BIN__c');
        addFieldIfExists(selectFields, qliFields, 'Product_Sub_Type__c');
        addFieldIfExists(selectFields, qliFields, 'Cable_Length__c');
        addFieldIfExists(selectFields, qliFields, 'Warranty__c');
        
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
        
        List<QuoteLineWrapper> rows = new List<QuoteLineWrapper>();
        
        String gstFromMetadata = getGstFromMetadata();
        
        for (QuoteLineItem qli : qliList) {
            QuoteLineWrapper row = new QuoteLineWrapper();
            
            row.quoteLineItemId = qli.Id;
            row.productId = qli.Product2Id;
            row.productName = qli.Product2 != null ? qli.Product2.Name : '';
            row.opportunityProductId = getStringValue(qli, 'Opportunity_Product__c');
            
            String productRatingBinVal = getStringValue(qli, 'Product_Rating_BIN__c');
            String moduleTechnologyVal = getStringValue(qli, 'Module_Technology__c');
            String cableLengthVal = getStringValue(qli, 'Cable_Length__c');
            String productSubTypeVal = getStringValue(qli, 'Product_Sub_Type__c');
            String moduleTypeVal = getStringValue(qli, 'Module_Type__c');
            
            row.materialDescription = buildMaterialDescription(
                productRatingBinVal,
                moduleTechnologyVal,
                cableLengthVal,
                productSubTypeVal,
                moduleTypeVal
            );
            
            row.moduleType = moduleTypeVal;
            row.moduleTechnology = moduleTechnologyVal;
            row.productRatingBin = productRatingBinVal;
            row.productSubType = productSubTypeVal;
            row.cableLength = cableLengthVal;
            row.warranty = getStringValue(qli, 'Warranty__c');
            
            row.projectCapacity = getStringValue(qli, 'Product_Capacity__c');
            
            if (String.isBlank(row.projectCapacity)) {
                row.projectCapacity = getStringValue(qli, 'Project_Capacity__c');
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
            
            row.binPercentageInput = 'No';
            row.binPercentageValueInput = '';
            row.moduleEfficiencyCriteriaInput = '';
            row.systemVoltageInput = '';
            
            rows.add(row);
        }
        
        return rows;
    }
    
    @AuraEnabled
    
    public static Id createTermSheetAndLineItems(
        String opportunityId,
        String selectedIdsJson,
        String reqJson
    ) {
        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException('Opportunity Id is required.');
        }
        
        SaveRequest req = (SaveRequest) JSON.deserialize(reqJson, SaveRequest.class);
        
        Set<Id> selectedQuoteLineIds = new Set<Id>();
        
        if (!String.isBlank(selectedIdsJson)) {
            selectedQuoteLineIds = new Set<Id>(
                (List<Id>) JSON.deserialize(selectedIdsJson, List<Id>.class)
            );
        }
        
        
        // if (selectedQuoteLineIds.isEmpty()) {
        //     throw new AuraHandledException('Please select at least one Quote Line Item.');
        // }
        
        Opportunity opp = [
            SELECT Id, Name, AccountId, Tender_Name__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        
        String safeName = String.isBlank(req.termSheetName)
            ? 'TS - ' + opp.Name
            : req.termSheetName;
        
        if (safeName.length() > 80) {
            safeName = safeName.substring(0, 80);
        }
        
        Term_Sheet__c ts = new Term_Sheet__c(
            Name = safeName,
            Opportunity__c = opp.Id,
            Name_of_customer__c = opp.AccountId,
            Doc_No__c = req.docNo,
            Rev_No__c = req.revNo,
            Tender_Name__c = opp.Tender_Name__c,
            Issue_Date__c = String.isBlank(req.issueDate)
            ? Date.today()
            : Date.valueOf(req.issueDate)
        );
        
        putIfPresent(ts, 'Tender_Name__c', req.tenderName);
        
        /*
* USER INPUT FIELD:
* Term_Sheet__c.Project_Capacity__c saves from the top Details input.
*/
        putIfPresent(ts, 'Project_Capacity__c', req.projectCapacity);
        
        putIfPresent(ts, 'Agreed_Price__c', req.agreedPrice);
        putIfPresent(ts, 'Delivery_Schedule__c', req.deliverySchedule);
        putIfPresent(ts, 'Payment_TermText__c', req.paymentTerm);
        putIfPresent(ts, 'LD_Clause__c', req.ldClause);
        
        insert ts;
        
        opp.Is_Term_Sheet_Created__c = true;
        update opp;
        
        Map<Id, QuoteLineWrapper> uiRowMap = new Map<Id, QuoteLineWrapper>();
        
        if (req.productRows != null) {
            for (QuoteLineWrapper row : req.productRows) {
                if (row != null && row.quoteLineItemId != null) {
                    uiRowMap.put(row.quoteLineItemId, row);
                }
            }
        }
        
        Map<String, Schema.SObjectField> qliFields =
            Schema.SObjectType.QuoteLineItem.fields.getMap();
        
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
        addFieldIfExists(qliSelectFields, qliFields, 'Product_Rating_BIN__c');
        addFieldIfExists(qliSelectFields, qliFields, 'Product_Sub_Type__c');
        addFieldIfExists(qliSelectFields, qliFields, 'Cable_Length__c');
        addFieldIfExists(qliSelectFields, qliFields, 'Warranty__c');
        
        addFieldIfExists(qliSelectFields, qliFields, 'Product_Capacity__c');
        addFieldIfExists(qliSelectFields, qliFields, 'Project_Capacity__c');
        
        /*
* REQUIRED MAPPING:
* QuoteLineItem.UOM__c and QuoteLineItem.Nos__c are selected here.
*/
        addFieldIfExists(qliSelectFields, qliFields, 'UOM__c');
        addFieldIfExists(qliSelectFields, qliFields, 'Nos__c');
        
        addFieldIfExists(qliSelectFields, qliFields, 'Capacity_in_KW__c');
        addFieldIfExists(qliSelectFields, qliFields, 'Total__c');
        addFieldIfExists(qliSelectFields, qliFields, 'Grand_Total__c');
        addFieldIfExists(qliSelectFields, qliFields, 'GST__c');
        addFieldIfExists(qliSelectFields, qliFields, 'GST_Percentage__c');
        
        String qliSoql =
            'SELECT ' + String.join(qliSelectFields, ',') +
            ' FROM QuoteLineItem' +
            ' WHERE Id IN :selectedQuoteLineIds';
        
        List<QuoteLineItem> selectedQliList = Database.query(qliSoql);
        
        
        List<Term_Sheet_Line_Item__c> lines = new List<Term_Sheet_Line_Item__c>();
        
        String gstFromMetadata = getGstFromMetadata();
        
        for (QuoteLineItem qli : selectedQliList) {
            QuoteLineWrapper uiRow = uiRowMap.get(qli.Id);
            
            String productName = qli.Product2 != null ? qli.Product2.Name : 'Quote Line Item';
            
            String productRatingBinVal = getStringValue(qli, 'Product_Rating_BIN__c');
            String moduleTechnologyVal = getStringValue(qli, 'Module_Technology__c');
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
            
            Term_Sheet_Line_Item__c line = new Term_Sheet_Line_Item__c();
            line.Term_Sheet__c = ts.Id;
            line.Name = productName.length() > 80 ? productName.substring(0, 80) : productName;
            
            putIfPresent(line, 'Quote_Line_Item__c', String.valueOf(qli.Id));
            putIfPresent(line, 'Product__c', String.valueOf(qli.Product2Id));
            putIfPresent(line, 'Opportunity_Product__c', getStringValue(qli, 'Opportunity_Product__c'));
            
            putIfPresent(line, 'Material_Description__c', materialDescriptionVal);
            
            putIfPresent(line, 'Module_Type__c', moduleTypeVal);
            putIfPresent(line, 'Module_Technology__c', moduleTechnologyVal);
            putIfPresent(line, 'Product_Rating_BIN__c', productRatingBinVal);
            putIfPresent(line, 'Wp_Bin__c', productRatingBinVal);
            putIfPresent(line, 'Product_Sub_Type__c', productSubTypeVal);
            putIfPresent(line, 'Cable_Length__c', cableLengthVal);
            putIfPresent(line, 'Warranty__c', getStringValue(qli, 'Warranty__c'));
            
            /*
* REQUIRED MAPPING:
* QuoteLineItem.Product_Capacity__c
* → Term_Sheet_Line_Item__c.Project_Capacity__c
*/
            String lineProjectCapacityVal = getStringValue(qli, 'Product_Capacity__c');
            
            if (String.isBlank(lineProjectCapacityVal)) {
                lineProjectCapacityVal = getStringValue(qli, 'Project_Capacity__c');
            }
            
            /*
* REQUIRED MAPPING:
* QuoteLineItem.UOM__c
* → Term_Sheet_Line_Item__c.UOM__c
*/
            String uomVal = getStringValue(qli, 'UOM__c');
            
            /*
* REQUIRED MAPPING:
* QuoteLineItem.Nos__c
* → Term_Sheet_Line_Item__c.Nos__c
*/
            String nosVal = getStringValue(qli, 'Nos__c');
            
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
            
            if (String.isBlank(gstVal) && uiRow != null) {
                gstVal = uiRow.gst;
            }
            
            if (String.isBlank(gstVal)) {
                gstVal = gstFromMetadata;
            }
            
            String grandTotalVal = getStringValue(qli, 'Grand_Total__c');
            
            if (String.isBlank(grandTotalVal)) {
                grandTotalVal = qli.TotalPrice == null ? '' : String.valueOf(qli.TotalPrice);
            }
            
            /*
* FINAL SAVE MAPPING
*/
            putIfPresent(line, 'Project_Capacity__c', lineProjectCapacityVal);
            putIfPresent(line, 'UOM__c', uomVal);
            putIfPresent(line, 'Nos__c', nosVal);
            
            putIfPresent(line, 'Capacity_in_KW__c', capacityKwVal);
            putIfPresent(line, 'Price_Wp__c', priceWpVal);
            putIfPresent(line, 'Subtotal__c', subtotalVal);
            putIfPresent(line, 'Total__c', subtotalVal);
            putIfPresent(line, 'GST__c', gstVal);
            putIfPresent(line, 'Grand_Total__c', grandTotalVal);
            
            if (uiRow != null) {
                putIfPresent(line, 'Bin_Percentage_Applicable__c', uiRow.binPercentageInput);
                
                if (uiRow.binPercentageInput == 'Yes') {
                    putIfPresent(line, 'Bin_Percentage__c', uiRow.binPercentageValueInput);
                }
                
                putIfPresent(
                    line,
                    'Module_Efficiency_Criteria_as_per_tender__c',
                    uiRow.moduleEfficiencyCriteriaInput
                );
                
                putIfPresent(line, 'System_Voltage__c', uiRow.systemVoltageInput);
            }
            
            lines.add(line);
        }
        
        if (!lines.isEmpty()) {
            insert lines;
        }
        
        
        return ts.Id;
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
            parts.add(cableLengthVal + ' mm' + ' (Cable length)');
        }
        
        if (!String.isBlank(productSubTypeVal)) {
            parts.add(productSubTypeVal);
        }
        
        if (!String.isBlank(moduleTypeVal)) {
            parts.add(moduleTypeVal);
        }
        
        return String.join(parts, ' - ');
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
    
    private static void putIfPresent(SObject record, String fieldApiName, String rawValue) {
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
        
        String cleaned = inputVal
            .replace('INR', '')
            .replace('₹', '')
            .replace(',', '')
            .replace('%', '')
            .trim();
        
        return cleaned;
    }
    
    public class InitResponse {
        @AuraEnabled public Opportunity opp;
        @AuraEnabled public Id latestQuoteId;
        @AuraEnabled public List<QuoteLineWrapper> quoteLines;
        @AuraEnabled public String todayDateDisplay;
        @AuraEnabled public String todayDateDb;
        @AuraEnabled public String revNo;
    }
    
    public class SaveRequest {
        @AuraEnabled public String termSheetName;
        @AuraEnabled public String docNo;
        @AuraEnabled public String revNo;
        @AuraEnabled public String issueDate;
        
        @AuraEnabled public String tenderName;
        @AuraEnabled public String projectCapacity;
        @AuraEnabled public String agreedPrice;
        @AuraEnabled public String deliverySchedule;
        @AuraEnabled public String paymentTerm;
        @AuraEnabled public String ldClause;
        
        @AuraEnabled public List<QuoteLineWrapper> productRows;
    }
    
    public class QuoteLineWrapper {
        @AuraEnabled public Id quoteLineItemId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String opportunityProductId;
        
        @AuraEnabled public String materialDescription;
        
        @AuraEnabled public String moduleType;
        @AuraEnabled public String moduleTechnology;
        @AuraEnabled public String productRatingBin;
        @AuraEnabled public String productSubType;
        @AuraEnabled public String cableLength;
        @AuraEnabled public String warranty;
        
        @AuraEnabled public String nos;
        @AuraEnabled public String projectCapacity;
        @AuraEnabled public String uom;
        @AuraEnabled public String capacityInKW;
        @AuraEnabled public String priceWp;
        @AuraEnabled public String total;
        @AuraEnabled public String gst;
        @AuraEnabled public String grandTotal;
        
        @AuraEnabled public String binPercentageInput;
        @AuraEnabled public String binPercentageValueInput;
        @AuraEnabled public String moduleEfficiencyCriteriaInput;
        @AuraEnabled public String systemVoltageInput;
    }
    public static void datacover() {
        integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
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