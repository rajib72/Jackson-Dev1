public class CaseAssetController {
    @AuraEnabled(cacheable=true)
    public static List<Asset> getAssets(Id caseId) {
        Case c = [SELECT Id, AccountId FROM Case WHERE Id = :caseId LIMIT 1];
        
        if (c.AccountId == null) {
            return new List<Asset>();
        }
 
        return [
            SELECT Id, Name, SerialNumber 
            FROM Asset 
            WHERE AccountId = :c.AccountId
        ];
    }
 
    @AuraEnabled
    public static void saveCaseAssets(Id caseId, List<Id> assetIds) {
        List<Case_Related_Assets__c> records = new List<Case_Related_Assets__c>();
 
        for (Id assetId : assetIds) {
            records.add(new Case_Related_Assets__c(
                Case__c = caseId,
                Asset__c = assetId
            ));
        }
 
        insert records;
    }

}