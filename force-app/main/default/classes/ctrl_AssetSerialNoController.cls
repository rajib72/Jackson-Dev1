public with sharing class ctrl_AssetSerialNoController {

    @AuraEnabled(cacheable=true)
    public static List<Asset_Serial_No__c> getSerialNumbers(Id assetId) {
        if (assetId == null) {
            return new List<Asset_Serial_No__c>();
        }

        return [
            SELECT Id, Name, Asset__c
            FROM Asset_Serial_No__c
            WHERE Asset__c = :assetId
            ORDER BY CreatedDate ASC
        ];
    }

    @AuraEnabled
    public static void saveSerialNumbers(Id assetId, List<Asset_Serial_No__c> serialList) {
        if (assetId == null) {
            throw new AuraHandledException('Asset Id is missing.');
        }

        if (serialList == null || serialList.isEmpty()) {
            return;
        }

        List<Asset_Serial_No__c> recordsToUpsert = new List<Asset_Serial_No__c>();

        for (Asset_Serial_No__c serialRec : serialList) {
            if (String.isBlank(serialRec.Name)) {
                continue;
            }

            serialRec.Asset__c = assetId;
            recordsToUpsert.add(serialRec);
        }

        if (!recordsToUpsert.isEmpty()) {
            upsert recordsToUpsert;
        }
    }

    @AuraEnabled
    public static void deleteSerialNumber(Id serialId) {
        if (serialId == null) {
            throw new AuraHandledException('Serial record Id is missing.');
        }

        Asset_Serial_No__c serialRec = [
            SELECT Id
            FROM Asset_Serial_No__c
            WHERE Id = :serialId
            LIMIT 1
        ];

        delete serialRec;
    }
}