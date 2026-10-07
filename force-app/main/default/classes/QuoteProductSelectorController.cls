public with sharing class QuoteProductSelectorController {
    
    // Label = Project Capacity, API Name = Product_Capacity__c
    private static final String QLI_PROJECT_CAPACITY_FIELD = 'Product_Capacity__c';
    private static final String QLI_GST_AMOUNT_FIELD = 'GST_Amount__c';
    private static final String QLI_UOM_FIELD_API = 'UOM__c';
    
    public class IncotermOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public IncotermOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    public class UomOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public UomOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    public class ProductRow {
        @AuraEnabled public Id opportunityLineItemId;
        @AuraEnabled public Id product2Id;
        @AuraEnabled public Id pricebookEntryId;
        
        @AuraEnabled public Decimal nos;
        @AuraEnabled public Decimal projectCapacity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal total;
        @AuraEnabled public Decimal gstPercent;
        @AuraEnabled public Decimal gstAmount;
        @AuraEnabled public Decimal grandTotal;
        
        @AuraEnabled public String uom;
        
        @AuraEnabled public String moduleType;
        @AuraEnabled public String cellType;
        @AuraEnabled public String moduleTechnology;
        @AuraEnabled public String productRatingBin;
        @AuraEnabled public String productSubType;
        @AuraEnabled public String warranty;
        @AuraEnabled public String cableLength;
        
        @AuraEnabled public Boolean alreadyAdded;
        @AuraEnabled public Boolean missingPricebookEntry;
    }
    
    public class InitResponse {
        @AuraEnabled public List<ProductRow> productRows;
        @AuraEnabled public List<IncotermOption> incotermOptions;
        @AuraEnabled public List<UomOption> uomOptions;
    }
    
    @AuraEnabled(cacheable=true)
    public static InitResponse getInitData(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        
        Quote qt = [
            SELECT Id, OpportunityId, Pricebook2Id
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        if (qt.OpportunityId == null) {
            throw new AuraHandledException('This Quote is not linked with an Opportunity.');
        }
        
        if (qt.Pricebook2Id == null) {
            throw new AuraHandledException('Please set Price Book on Quote first.');
        }
        
        Decimal gstPercent = getGstPercent();
        
        List<OpportunityLineItem> oliList = [
            SELECT Id,
            OpportunityId,
            Quantity,
            UnitPrice,
            TotalPrice,
            PricebookEntryId,
            PricebookEntry.Product2Id,
            Module_Type__c,
            Cell_Type__c,
            Module_Technology__c,
            Product_Rating_BIN__c,
            Product_Sub_Type__c,
            Warranty__c,
            Cable_Length__c,
            Project_Capacity__c,
            UOM__c
            FROM OpportunityLineItem
            WHERE OpportunityId = :qt.OpportunityId
            ORDER BY CreatedDate ASC
        ];
        
        Set<Id> productIds = new Set<Id>();
        Set<Id> oliIds = new Set<Id>();
        
        for (OpportunityLineItem oli : oliList) {
            oliIds.add(oli.Id);
            if (oli.PricebookEntry != null && oli.PricebookEntry.Product2Id != null) {
                productIds.add(oli.PricebookEntry.Product2Id);
            }
        }
        
        Map<Id, PricebookEntry> quotePbeByProductId = new Map<Id, PricebookEntry>();
        if (!productIds.isEmpty()) {
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id, Pricebook2Id, IsActive
                FROM PricebookEntry
                WHERE Pricebook2Id = :qt.Pricebook2Id
                AND Product2Id IN :productIds
                AND IsActive = true
            ]) {
                if (!quotePbeByProductId.containsKey(pbe.Product2Id)) {
                    quotePbeByProductId.put(pbe.Product2Id, pbe);
                }
            }
        }
        
        /*Set<Id> alreadyAddedOliIds = new Set<Id>();
if (!oliIds.isEmpty()) {
for (QuoteLineItem qli : [
SELECT Id, Opportunity_Product__c
FROM QuoteLineItem
WHERE QuoteId = :quoteId
AND Opportunity_Product__c IN :oliIds
]) {
if (qli.Opportunity_Product__c != null) {
alreadyAddedOliIds.add(qli.Opportunity_Product__c);
}
}
}*/
        Map<Id, QuoteLineItem> existingQliByOliId = new Map<Id, QuoteLineItem>();
        
        if (!oliIds.isEmpty()) {
            for (QuoteLineItem qli : [
                SELECT Id,
                Opportunity_Product__c,
                Quantity,
                UnitPrice,
                Product_Capacity__c,
                UOM__c,
                Module_Type__c,
                Cell_Type__c,
                Module_Technology__c,
                Product_Rating_BIN__c,
                Product_Sub_Type__c,
                Warranty__c,
                Cable_Length__c
                FROM QuoteLineItem
                WHERE QuoteId = :quoteId
                AND Opportunity_Product__c IN :oliIds
            ]) {
                if (qli.Opportunity_Product__c != null) {
                    existingQliByOliId.put(qli.Opportunity_Product__c, qli);
                }
            }
        }
        
        List<ProductRow> rows = new List<ProductRow>();
        
        /*for (OpportunityLineItem oli : oliList) {
ProductRow row = new ProductRow();
row.opportunityLineItemId = oli.Id;
row.product2Id = oli.PricebookEntry != null ? oli.PricebookEntry.Product2Id : null;
row.projectCapacity = oli.Project_Capacity__c;
row.unitPrice = oli.UnitPrice;
row.uom = oli.UOM__c;*/
        for (OpportunityLineItem oli : oliList) {
            ProductRow row = new ProductRow();
            QuoteLineItem existingQli = existingQliByOliId.get(oli.Id);
            
            row.opportunityLineItemId = oli.Id;
            row.product2Id = oli.PricebookEntry != null ? oli.PricebookEntry.Product2Id : null;
            
            if (existingQli != null) {
                row.projectCapacity = existingQli.Product_Capacity__c != null
                    ? existingQli.Product_Capacity__c
                    : existingQli.Quantity;
                
                row.unitPrice = existingQli.UnitPrice;
                row.uom = existingQli.UOM__c;
                
                row.moduleType = existingQli.Module_Type__c;
                row.cellType = existingQli.Cell_Type__c;
                row.moduleTechnology = existingQli.Module_Technology__c;
                row.productRatingBin = existingQli.Product_Rating_BIN__c;
                row.productSubType = existingQli.Product_Sub_Type__c;
                row.warranty = String.valueOf(existingQli.Warranty__c);
                row.cableLength = String.valueOf(existingQli.Cable_Length__c);
                
                row.alreadyAdded = true;
            } else {
                row.projectCapacity = oli.Project_Capacity__c;
                row.unitPrice = oli.UnitPrice;
                row.uom = oli.UOM__c;
                
                row.moduleType = oli.Module_Type__c;
                row.cellType = oli.Cell_Type__c;
                row.moduleTechnology = oli.Module_Technology__c;
                row.productRatingBin = oli.Product_Rating_BIN__c;
                row.productSubType = oli.Product_Sub_Type__c;
                row.warranty = String.valueOf(oli.Warranty__c);
                row.cableLength = String.valueOf(oli.Cable_Length__c);
                
                row.alreadyAdded = false;
            }
            
            /*// Only for UI display. These are not written to QLI if they are formula fields.
row.nos = calculateNos(oli.Project_Capacity__c, oli.Product_Rating_BIN__c, oli.UOM__c);
row.total = calculateTotal(oli.Project_Capacity__c, oli.UnitPrice, oli.UOM__c);
row.gstPercent = gstPercent;
row.gstAmount = row.total == null ? null : (row.total * gstPercent);
row.grandTotal = row.total == null ? null : (row.total + (row.total * gstPercent));

row.moduleType = oli.Module_Type__c;
row.cellType = oli.Cell_Type__c;
row.moduleTechnology = oli.Module_Technology__c;
row.productRatingBin = oli.Product_Rating_BIN__c;
row.productSubType = oli.Product_Sub_Type__c;
row.warranty = String.valueOf(oli.Warranty__c);
row.cableLength = String.valueOf(oli.Cable_Length__c);

row.alreadyAdded = alreadyAddedOliIds.contains(oli.Id);

if (row.product2Id != null && quotePbeByProductId.containsKey(row.product2Id)) {
row.pricebookEntryId = quotePbeByProductId.get(row.product2Id).Id;
row.missingPricebookEntry = false;
} else {
row.pricebookEntryId = null;
row.missingPricebookEntry = true;
}

rows.add(row);
}*/
            row.nos = calculateNos(row.projectCapacity, row.productRatingBin, row.uom);
            row.total = calculateTotal(row.projectCapacity, row.unitPrice, row.uom);
            row.gstPercent = gstPercent;
            row.gstAmount = row.total == null ? null : row.total * gstPercent;
            row.grandTotal = row.total == null ? null : row.total + row.gstAmount;
            
            if (row.product2Id != null && quotePbeByProductId.containsKey(row.product2Id)) {
                row.pricebookEntryId = quotePbeByProductId.get(row.product2Id).Id;
                row.missingPricebookEntry = false;
            } else {
                row.pricebookEntryId = null;
                row.missingPricebookEntry = true;
            }
            
            rows.add(row);
        }
        
        InitResponse response = new InitResponse();
        response.productRows = rows;
        response.incotermOptions = new List<IncotermOption>();
        response.uomOptions = new List<UomOption>();
        return response;
    }
    
    @AuraEnabled
    public static void saveQuoteLineItems(Id quoteId, String selectedRowsJson) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        
        if (String.isBlank(selectedRowsJson)) {
            throw new AuraHandledException('No rows selected for save.');
        }
        
        Quote qt = [
            SELECT Id, Pricebook2Id
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        if (qt.Pricebook2Id == null) {
            throw new AuraHandledException('Quote Price Book is missing.');
        }
        
        List<Object> rawRows = (List<Object>) JSON.deserializeUntyped(selectedRowsJson);
        if (rawRows == null || rawRows.isEmpty()) {
            throw new AuraHandledException('No rows selected for save.');
        }
        
        Set<Id> incomingOliIds = new Set<Id>();
        List<Map<String, Object>> parsedRows = new List<Map<String, Object>>();
        
        for (Object rowObj : rawRows) {
            Map<String, Object> row = (Map<String, Object>) rowObj;
            parsedRows.add(row);
            
            String oliIdStr = stringValue(row.get('opportunityLineItemId'));
            if (String.isBlank(oliIdStr)) {
                throw new AuraHandledException('Opportunity Product is missing.');
            }
            incomingOliIds.add((Id) oliIdStr);
        }
        
        Set<Id> existingOliIds = new Set<Id>();
        if (!incomingOliIds.isEmpty()) {
            for (QuoteLineItem qli : [
                SELECT Id, Opportunity_Product__c
                FROM QuoteLineItem
                WHERE QuoteId = :quoteId
                AND Opportunity_Product__c IN :incomingOliIds
            ]) {
                if (qli.Opportunity_Product__c != null) {
                    existingOliIds.add(qli.Opportunity_Product__c);
                }
            }
        }
        
        List<QuoteLineItem> qliToInsert = new List<QuoteLineItem>();
        
        for (Map<String, Object> row : parsedRows) {
            Id opportunityLineItemId = (Id) stringValue(row.get('opportunityLineItemId'));
            if (existingOliIds.contains(opportunityLineItemId)) {
                continue;
            }
            
            Id pricebookEntryId = (Id) stringValue(row.get('pricebookEntryId'));
            Decimal projectCapacity = decimalValue(row.get('projectCapacity'));
            Decimal nos = decimalValue(row.get('nos'));//CR 
            Decimal unitPrice = decimalValue(row.get('unitPrice'));
            Decimal gstAmount = decimalValue(row.get('gstAmount'));
            String uom = stringValue(row.get('uom'));
            
            if (pricebookEntryId == null) {
                throw new AuraHandledException('Price Book Entry missing for one or more selected rows.');
            }
            
            if (projectCapacity == null || projectCapacity <= 0) {
                throw new AuraHandledException('Project Capacity must be greater than zero.');
            }
            
            if (unitPrice == null || unitPrice < 0) {
                throw new AuraHandledException('Sales Price cannot be blank or negative.');
            }
            if (nos == null || nos <= 0) {
                throw new AuraHandledException(
                    'Nos must be greater than zero.'
                );
            }
            
            QuoteLineItem qli = new QuoteLineItem();
            qli.QuoteId = quoteId;
            qli.PricebookEntryId = pricebookEntryId;
            
            // Standard Salesforce fields
            qli.Quantity = nos;
            qli.UnitPrice = unitPrice;
            
            // Link back to Opportunity Product
            qli.Opportunity_Product__c = opportunityLineItemId;
            
            // Save the editable custom field whose LABEL is Project Capacity
            // API name is Product_Capacity__c
            if (hasField('QuoteLineItem', QLI_PROJECT_CAPACITY_FIELD)) {
                qli.put(QLI_PROJECT_CAPACITY_FIELD, projectCapacity);
            }
            
            // Keep only if GST_Amount__c is editable (not formula)
            if (hasField('QuoteLineItem', QLI_GST_AMOUNT_FIELD)) {
                qli.put(QLI_GST_AMOUNT_FIELD, gstAmount);
            }
            
            if (hasField('QuoteLineItem', QLI_UOM_FIELD_API)) {
                qli.put(QLI_UOM_FIELD_API, uom);
            }
            
            qli.Module_Type__c = stringValue(row.get('moduleType'));
            qli.Cell_Type__c = stringValue(row.get('cellType'));
            qli.Module_Technology__c = stringValue(row.get('moduleTechnology'));
            qli.Product_Rating_BIN__c = stringValue(row.get('productRatingBin'));
            qli.Product_Sub_Type__c = stringValue(row.get('productSubType'));
            qli.Warranty__c = stringValue(row.get('warranty'));
            qli.Cable_Length__c = stringValue(row.get('cableLength'));
            
            qliToInsert.add(qli);
        }
        
        if (qliToInsert.isEmpty()) {
            throw new AuraHandledException('Selected rows are already added in this Quote.');
        }
        
        insert qliToInsert;
    }
    
    private static Decimal calculateNos(Decimal projectCapacity, String productRatingBin, String uom) {
        if (projectCapacity == null || String.isBlank(uom) || String.isBlank(productRatingBin)) {
            return null;
        }
        
        Decimal ratingBin;
        try {
            ratingBin = Decimal.valueOf(productRatingBin);
        } catch (Exception e) {
            return null;
        }
        
        if (ratingBin <= 0) {
            return null;
        }
        
        if (uom == 'KW') {
            return projectCapacity * (1000 / ratingBin);
        } else if (uom == 'MW') {
            return projectCapacity * (1000000 / ratingBin);
        }
        
        return null;
    }
    
    private static Decimal calculateTotal(Decimal projectCapacity, Decimal unitPrice, String uom) {
        if (projectCapacity == null || unitPrice == null || String.isBlank(uom)) {
            return null;
        }
        
        if (uom == 'KW') {
            return projectCapacity * unitPrice * 1000;
        } else if (uom == 'MW') {
            return projectCapacity * unitPrice * 1000000;
        }
        return null;
    }
    
    private static Decimal getGstPercent() {
        List<GST__mdt> gstList = [
            SELECT DeveloperName, GST__c
            FROM GST__mdt
            WHERE DeveloperName = 'JAKSON_GST'
            LIMIT 1
        ];
        
        if (!gstList.isEmpty() && gstList[0].GST__c != null) {
            return gstList[0].GST__c;
        }
        return 0;
    }
    
    private static String stringValue(Object val) {
        return val == null ? null : String.valueOf(val);
    }
    
    private static Decimal decimalValue(Object val) {
        if (val == null || String.isBlank(String.valueOf(val))) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(val));
    }
    
    private static Boolean hasField(String objectApiName, String fieldApiName) {
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
        if (objType == null) {
            return false;
        }
        return objType.getDescribe().fields.getMap().containsKey(fieldApiName);
    }
}