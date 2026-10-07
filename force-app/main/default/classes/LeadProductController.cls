public with sharing class LeadProductController {
    
    
    //  MODULE TYPES
    
    @AuraEnabled(cacheable=true)
    public static List<String> getModuleTypes() {
        
        Set<String> resultSet = new Set<String>();
        
        for (Product_Details__c pd : [
            SELECT Product_Module_Type__c
            FROM Product_Details__c
            WHERE Product_Module_Type__c != null
        ]) {
            resultSet.add(pd.Product_Module_Type__c);
        }
        
        return new List<String>(resultSet);
    }
    
    
    //SUB TYPES
    
    @AuraEnabled(cacheable=true)
    public static List<String> getSubTypes(String moduleType) {
        
        Set<String> resultSet = new Set<String>();
        
        for (Product_Details__c pd : [
            SELECT Product_Module_Sub_Type__c
            FROM Product_Details__c
            WHERE Product_Module_Type__c = :moduleType
            AND Product_Module_Sub_Type__c != null
        ]) {
            resultSet.add(pd.Product_Module_Sub_Type__c);
        }
        
        return new List<String>(resultSet);
    }
    
    
    //WATT PEAKS
    
    @AuraEnabled(cacheable=true)
    public static List<Decimal> getWattPeaks(
        String moduleType,
        String subType
    ) {
        
        Set<Decimal> resultSet = new Set<Decimal>();
        
        for (Product_Details__c pd : [
            SELECT Watt_Peak__c
            FROM Product_Details__c
            WHERE Product_Module_Type__c = :moduleType
            AND Product_Module_Sub_Type__c = :subType
            AND Watt_Peak__c != null
        ]) {
            resultSet.add(pd.Watt_Peak__c);
        }
        
        return new List<Decimal>(resultSet);
    }
    
    
    //SAVE LEAD PRODUCT
    
    @AuraEnabled
    public static void saveLeadProduct(
        Id leadId,
        String moduleType,
        String subType,
        Decimal wattPeak
    ) {
        
        Lead_Product__c lp = new Lead_Product__c();
        lp.Lead__c = leadId;
        lp.Product_Module_Type__c = moduleType;
        lp.Product_Module_Sub_Type__c = subType;
        lp.Watt_Peak__c = wattPeak;
        
        insert lp;
        
        // Update checkbox on Lead after Lead Product is created
        Lead ld = new Lead();
        ld.Id = leadId;
        ld.Lead_Product_Added__c = true; 
        
        update ld;
    }
}