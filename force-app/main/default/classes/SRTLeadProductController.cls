public with sharing class SRTLeadProductController {
    public class ProductMatrixRow {
        @AuraEnabled public String product;
        @AuraEnabled public String moduleType;
        @AuraEnabled public String moduleTechnology;
        @AuraEnabled public String subModule;
        
        public ProductMatrixRow(String product, String moduleType, String moduleTechnology, String subModule) {
            this.product = product;
            this.moduleType = moduleType;
            this.moduleTechnology = moduleTechnology;
            this.subModule = subModule;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ProductMatrixRow> getProductMasterRows() {
        List<ProductMatrixRow> result = new List<ProductMatrixRow>();
        
        for (Salesforce_Product__c p : [
            SELECT Product__c,
            Module_Type__c,
            Module_Technology__c,
            Sub_Module__c,
            Product_Category__c
            FROM Salesforce_Product__c
            WHERE Product__c != null
            AND Product_Category__c = 'SRT Sales Products'
            ORDER BY Product__c, Module_Type__c, Module_Technology__c, Sub_Module__c
        ]) {
            result.add(new ProductMatrixRow(
                p.Product__c,
                p.Module_Type__c,
                p.Module_Technology__c,
                p.Sub_Module__c
            ));
        }
        
        return result;
    }
    
    @AuraEnabled
    public static Id saveLeadProduct(
        Id leadId,
        String product,
        String moduleType,
        String moduleTechnology,
        String subModule,
        Decimal projectCapacity,
        String uom
    ) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is missing.');
        }
        if (String.isBlank(product)) {
            throw new AuraHandledException('Please select Product.');
        }
        if (projectCapacity == null || projectCapacity <= 0) {
            throw new AuraHandledException('Project Capacity must be greater than 0.');
        }
        if (String.isBlank(uom)) {
            throw new AuraHandledException('Please select UOM.');
        }
        
        String selectedProduct = product.trim();
        Boolean isSolar = selectedProduct.equalsIgnoreCase('Solar');
        Boolean isBess  = selectedProduct.equalsIgnoreCase('BESS');
        
        if (isSolar) {
            if (String.isBlank(moduleType)) {
                throw new AuraHandledException('Please select Module Type.');
            }
            if (String.isBlank(moduleTechnology)) {
                throw new AuraHandledException('Please select Module Technology.');
            }
        }
        
        Lead_Product__c lp = new Lead_Product__c();
        lp.Lead__c = leadId;
        lp.SRT_Product__c = selectedProduct;
        lp.Project_Capacity__c = projectCapacity;
        lp.UOM__c = uom;
        
        if (isSolar) {
            lp.Module_Type__c = moduleType;
            lp.Module_Technology__c = moduleTechnology;
            lp.Sub_Module__c = subModule;
        } else if (isBess) {
            lp.Module_Type__c = null;
            lp.Module_Technology__c = null;
            lp.Sub_Module__c = null;
        }
        
        insert lp;
        
        // Update Lead status after Lead Product creation
        Lead ld = new Lead(
            Id = leadId
            // For standard Lead Status field:
            , Status = 'Working'
            
        );
        update ld;
        
        return lp.Id;
    }
}