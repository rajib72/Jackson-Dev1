public with sharing class Ctrl_AddSRTOrderDetails {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getIncoTerms() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        try {
            for (Incoterms_Master__c term : [SELECT INCOTERMS__c, IncoTerms_Details__c FROM Incoterms_Master__c LIMIT 1000]) {
                options.add(new Map<String, String>{
                    'label' => term.IncoTerms_Details__c,
                    'value' => term.INCOTERMS__c
                });
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching InCoTerms: ' + e.getMessage());
        }
        
        return options;
    }

    @AuraEnabled
    public static void updateOrderDetails(String recordId, String incoTerm, String salesOffice, String salesGroup) {
        List<Order> ordersToUpdate = [
            SELECT Id, InCoTerms__c, Sales_Office__c, Sales_Group__c 
            FROM Order 
            WHERE Id = :recordId 
            LIMIT 1
        ];
        
        if (!ordersToUpdate.isEmpty()) {
            try {
                ordersToUpdate[0].InCoTerms__c = incoTerm;
                ordersToUpdate[0].Sales_Office__c = salesOffice;
                ordersToUpdate[0].Sales_Group__c = salesGroup;
                update ordersToUpdate;
            } catch (Exception e) {
                throw new AuraHandledException('Failed to update Order: ' + e.getMessage());
            }
        } else {
            throw new AuraHandledException('No associated Order found for this record ID.');
        }
    }
}