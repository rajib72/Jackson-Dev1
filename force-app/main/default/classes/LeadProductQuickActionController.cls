public without sharing class LeadProductQuickActionController {
    
    private static final String PRODUCT_OBJ = 'Salesforce_Product__c';
    private static final String LEAD_STATUS_WORKING = 'Working';
    private static final String STANDARD_PRODUCT_NAME = 'Standard Product';
    
    public class OptionData {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public OptionData(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    public class ProductMatrixRow {
        @AuraEnabled public String moduleType;
        @AuraEnabled public String cellType;
        @AuraEnabled public String moduleTechnology;
        @AuraEnabled public String productRatingBin;
        @AuraEnabled public String productSubType;
    }
    
    public class InitResponse {
        @AuraEnabled public List<ProductMatrixRow> productRows;
        @AuraEnabled public List<OptionData> warrantyOptions;
        @AuraEnabled public List<OptionData> cableLengthOptions;
    }
    
    @AuraEnabled(cacheable=true)
    public static InitResponse getInitData() {
        InitResponse res = new InitResponse();
        res.productRows = new List<ProductMatrixRow>();
        res.warrantyOptions = new List<OptionData>();
        res.cableLengthOptions = new List<OptionData>();
        
        if (!Schema.getGlobalDescribe().containsKey(PRODUCT_OBJ)) {
            throw new AuraHandledException('Object not found: ' + PRODUCT_OBJ);
        }
        
        String q =
            'SELECT Module_Type__c, Cell_Type__c, Module_Technology__c, ' +
            'Product_Rating_BIN__c, Product_Sub_Type__c ' +
            'FROM ' + PRODUCT_OBJ +
            ' WHERE Module_Type__c != null AND Product_Category__c = \'Solar Sales Products\'';
        
        List<SObject> productRecords = Database.query(q);
        
        Set<String> uniqueRows = new Set<String>();
        
        for (SObject rec : productRecords) {
            String moduleType = safeString((String) rec.get('Module_Type__c'));
            String cellType = safeString((String) rec.get('Cell_Type__c'));
            String moduleTechnology = safeString((String) rec.get('Module_Technology__c'));
            String productSubType = safeString((String) rec.get('Product_Sub_Type__c'));
            
            String productRatingBin = '';
            Object ratingObj = rec.get('Product_Rating_BIN__c');
            if (ratingObj != null) {
                productRatingBin = String.valueOf(ratingObj).trim();
            }
            
            String key = String.join(new List<String>{
                moduleType,
                    cellType,
                    moduleTechnology,
                    productRatingBin,
                    productSubType
                    }, '###');
            
            if (!uniqueRows.contains(key)) {
                uniqueRows.add(key);
                
                ProductMatrixRow row = new ProductMatrixRow();
                row.moduleType = moduleType;
                row.cellType = cellType;
                row.moduleTechnology = moduleTechnology;
                row.productRatingBin = productRatingBin;
                row.productSubType = productSubType;
                res.productRows.add(row);
            }
        }
        
        res.warrantyOptions = getPicklistOptions('Lead_Product__c', 'Warranty__c');
        res.cableLengthOptions = getPicklistOptions('Lead_Product__c', 'Cable_Length__c');
        
        return res;
    }
    
    @AuraEnabled
    public static Id createLeadProduct(
        Id leadId,
        String moduleType,
        String cellType,
        String moduleTechnology,
        String productRatingBin,
        String productSubType,
        String warranty,
        String cableLength,
        Decimal projectCapacity,
        String uom
    ) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required.');
        }
        
        if (String.isBlank(moduleType)) {
            throw new AuraHandledException('Module Type is required.');
        }
        if (String.isBlank(cellType)) {
            throw new AuraHandledException('Cell Type is required.');
        }
        if (String.isBlank(moduleTechnology)) {
            throw new AuraHandledException('Module Technology is required.');
        }
        if (String.isBlank(productRatingBin)) {
            throw new AuraHandledException('Product Rating BIN is required.');
        }
        if (String.isBlank(productSubType)) {
            throw new AuraHandledException('Product Sub Type is required.');
        }
        if (projectCapacity == null) {
            throw new AuraHandledException('Project Capacity is required.');
        }
        if (projectCapacity <= 0) {
            throw new AuraHandledException('Project Capacity must be greater than 0.');
        }
        if (String.isBlank(uom)) {
            throw new AuraHandledException('UOM is required.');
        }
        
        Savepoint sp = Database.setSavepoint();
        try {
            Id standardProductId = getStandardProduct2Id();
            
            Lead_Product__c lp = new Lead_Product__c();
            lp.Lead__c = leadId;
            lp.Module_Type__c = moduleType;
            lp.Cell_Type__c = cellType;
            lp.Module_Technology__c = moduleTechnology;
            lp.Product_Rating_BIN__c = productRatingBin;
            lp.Product_Sub_Type__c = productSubType;
            lp.Warranty__c = warranty;
            lp.Cable_Length__c = cableLength;
            
            // NEW FIELDS
            lp.Project_Capacity__c = projectCapacity;
            lp.UOM__c = uom;
            
            lp.Product__c = standardProductId;
            
            insert lp;
            
            Lead ld = new Lead(
                Id = leadId,
                Status = LEAD_STATUS_WORKING
            );
            update ld;
            
            return lp.Id;
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error while creating Lead Product: ' + e.getMessage());
        }
    }
    
    private static Id getStandardProduct2Id() {
        List<Product2> productList = [
            SELECT Id, Name, IsActive
            FROM Product2
            WHERE Name = :STANDARD_PRODUCT_NAME
            LIMIT 1
        ];
        
        if (productList.isEmpty()) {
            throw new AuraHandledException(
                'No standard product found in Product2 with Name = "' + STANDARD_PRODUCT_NAME + '".'
            );
        }
        
        return productList[0].Id;
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
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new OptionData(entry.getLabel(), entry.getValue()));
            }
        }
        
        return options;
    }
    
    private static String safeString(String value) {
        return value == null ? '' : value.trim();
    }
}