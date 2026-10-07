public with sharing class SRTOpportunityProductController {
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
    public static Id saveOpportunityProduct(
        Id opportunityId,
        String product,
        String moduleType,
        String moduleTechnology,
        String subModule,
        Decimal projectCapacity,
        String uom
    ) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is missing.');
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
        
        Opportunity opp = [
            SELECT Id, Pricebook2Id
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        
        if (opp.Pricebook2Id == null) {
            throw new AuraHandledException('Please add a Price Book on the Opportunity first.');
        }
        
        // If you always use one standard product, keep this query.
        // Change 'Standard Product' if your product name is different.
        List<PricebookEntry> pbeList = [
            SELECT Id, UnitPrice, Product2Id, Product2.Name
            FROM PricebookEntry
            WHERE Pricebook2Id = :opp.Pricebook2Id
            AND IsActive = true
            AND Product2.IsActive = true
            AND Product2.Name = 'Standard Product'
            LIMIT 1
        ];
        
        if (pbeList.isEmpty()) {
            throw new AuraHandledException('No active Price Book Entry found for Standard Product in the Opportunity Price Book.');
        }
        
        PricebookEntry pbe = pbeList[0];
        
        OpportunityLineItem oli = new OpportunityLineItem();
        oli.OpportunityId = opportunityId;
        oli.PricebookEntryId = pbe.Id;
        oli.Quantity = 1;
        oli.UnitPrice = pbe.UnitPrice;
        
        // Custom fields on OpportunityLineItem
        oli.SRT_Product__c = selectedProduct;
        oli.Project_Capacity__c = projectCapacity;
        oli.UOM__c = uom;
        
        if (isSolar) {
            oli.Module_Type__c = moduleType;
            oli.Module_Technology__c = moduleTechnology;
            oli.Sub_Module__c = subModule;
        } else if (isBess) {
            oli.Module_Type__c = null;
            oli.Module_Technology__c = null;
            oli.Sub_Module__c = null;
        }
        
        insert oli;
        return oli.Id;
    }
}