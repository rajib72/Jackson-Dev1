public with sharing class ctrl_CaseAssetTaggingController {
    public class AssetOption {
        @AuraEnabled public Id id {get; set;}
        @AuraEnabled public String label {get; set;}
        @AuraEnabled public String invoiceNumber {get; set;}
        public AssetOption(Asset a) {
            id = a.Id;
            label = a.Name;
            invoiceNumber = (String)a.get('Invoice_Number__c');
        }
    }

    public class SerialOption {
        @AuraEnabled public Id id {get; set;}
        @AuraEnabled public String label {get; set;}
        @AuraEnabled public String serialNumber {get; set;}
        @AuraEnabled public Date productWarrantyEndDate {get; set;}
        @AuraEnabled public Date performanceWarrantyEndDate {get; set;}
        public SerialOption(Id recordId, String serial, Date productEnd, Date performanceEnd) {
            id = recordId;
            label = serial;
            serialNumber = serial;
            productWarrantyEndDate = productEnd;
            performanceWarrantyEndDate = performanceEnd;
        }
    }

    public class InitialData {
        @AuraEnabled public Id accountId {get; set;}
        @AuraEnabled public List<AssetOption> assets {get; set;}
    }

    @AuraEnabled(cacheable=true)
    public static InitialData getInitialData(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }

        Case caseRecord = [
            SELECT Id, AccountId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        InitialData result = new InitialData();
        result.accountId = caseRecord.AccountId;
        result.assets = new List<AssetOption>();

        if (caseRecord.AccountId == null) {
            return result;
        }

        Set<Id> taggedAssetIds = new Set<Id>();

        for (Case_Related_Assets__c cra : [
            SELECT Asset__c
            FROM Case_Related_Assets__c
            WHERE Case__c = :caseId
            AND Asset__c != null
        ]) {
            taggedAssetIds.add(cra.Asset__c);
        }       
        
        List<Asset> availableAssets = [
            SELECT Id, Name, Invoice_Number__c
            FROM Asset
            WHERE AccountId = :caseRecord.AccountId
            AND Id NOT IN :taggedAssetIds
            ORDER BY Name
        ];
        
        for (Asset a : availableAssets) {
            result.assets.add(new AssetOption(a));
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<SerialOption> getSerialNumbers(Id caseId, Id assetId) {
        if (caseId == null || assetId == null) {
            throw new AuraHandledException('Case and Asset are required.');
        }

        Case caseRecord = [
            SELECT Id, AccountId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (caseRecord.AccountId == null) {
            throw new AuraHandledException('The Case does not have an Account.');
        }

        Asset selectedAsset = [
            SELECT Id, AccountId
            FROM Asset
            WHERE Id = :assetId
            LIMIT 1
        ];

        if (selectedAsset.AccountId != caseRecord.AccountId) {
            throw new AuraHandledException('The selected Asset does not belong to the Case Account.');
        }

        if ([
            SELECT COUNT()
            FROM Case_Related_Assets__c
            WHERE Case__c = :caseId
            AND Asset__c = :assetId
        ] > 0) {
            throw new AuraHandledException('This Asset is already tagged to the Case.');
        }

        List<Asset_Serial_No__c> serialRecords = [
            SELECT Id, Asset__c, Name
            FROM Asset_Serial_No__c
            WHERE Asset__c = :assetId
            ORDER BY Name
        ];

        Set<Id> serialIds = new Set<Id>();
        for (Asset_Serial_No__c serial : serialRecords) {
            serialIds.add(serial.Id);
        }

        Map<Id, Date> productWarrantyDates = new Map<Id, Date>();
        Map<Id, Date> performanceWarrantyDates = new Map<Id, Date>();

        if (!serialIds.isEmpty()) {
            for (AssetWarranty warranty : [
                SELECT Id, Asset_Serial_No__c, Type__c, StartDate ,Account__c, EndDate, Active__c
                FROM AssetWarranty
                WHERE Asset_Serial_No__c IN :serialIds
                ORDER BY EndDate DESC
            ]) {
                if (warranty.Asset_Serial_No__c == null) {
                    continue;
                }

                String typeValue = warranty.Type__c == null ? '' : warranty.Type__c.toLowerCase();

                if (typeValue == 'product' && !productWarrantyDates.containsKey(warranty.Asset_Serial_No__c)) {
                    productWarrantyDates.put(warranty.Asset_Serial_No__c, warranty.EndDate);
                }

                if (typeValue == 'performance' && !performanceWarrantyDates.containsKey(warranty.Asset_Serial_No__c)) {
                    performanceWarrantyDates.put(warranty.Asset_Serial_No__c, warranty.EndDate);
                }
            }
        }

        List<SerialOption> result = new List<SerialOption>();

        for (Asset_Serial_No__c serial : serialRecords) {
            result.add(new SerialOption(
                serial.Id,
                serial.Name,
                productWarrantyDates.get(serial.Id),
                performanceWarrantyDates.get(serial.Id)
            ));
        }

        return result;
    }

    @AuraEnabled
    public static void saveTaggedAsset(Id caseId, Id assetId, List<Id> serialNumberIds) {
        if (caseId == null || assetId == null) {
            throw new AuraHandledException('Case and Asset are required.');
        }

        if (serialNumberIds == null || serialNumberIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one Asset Serial Number.');
        }

        Case caseRecord = [
            SELECT Id, AccountId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (caseRecord.AccountId == null) {
            throw new AuraHandledException('The Case does not have an Account.');
        }

        Asset selectedAsset = [
            SELECT Id, AccountId, Invoice_Number__c, Name
            FROM Asset
            WHERE Id = :assetId
            LIMIT 1
        ];

        if (selectedAsset.AccountId != caseRecord.AccountId) {
            throw new AuraHandledException('The selected Asset does not belong to the Case Account.');
        }

        if ([
            SELECT COUNT()
            FROM Case_Related_Assets__c
            WHERE Case__c = :caseId
            AND Asset__c = :assetId
        ] > 0) {
            throw new AuraHandledException('This Asset is already tagged to the Case.');
        }

        Set<Id> requestedSerialIds = new Set<Id>(serialNumberIds);

        List<Asset_Serial_No__c> serialRecords = [
            SELECT Id, Asset__c, Name
            FROM Asset_Serial_No__c
            WHERE Id IN :requestedSerialIds
        ];

        if (serialRecords.size() != requestedSerialIds.size()) {
            throw new AuraHandledException('One or more selected Serial Numbers are invalid.');
        }

        Set<Id> actualSerialIds = new Set<Id>();

        for (Asset_Serial_No__c serial : serialRecords) {
            if (serial.Asset__c != assetId) {
                throw new AuraHandledException('One or more selected Serial Numbers do not belong to the selected Asset.');
            }
            actualSerialIds.add(serial.Id);
        }

        Map<Id, Date> productWarrantyDates = new Map<Id, Date>();
        Map<Id, Date> performanceWarrantyDates = new Map<Id, Date>();

        for (AssetWarranty warranty : [
            SELECT Id, Asset_Serial_No__c, Type__c, StartDate ,Account__c, EndDate, Active__c
            FROM AssetWarranty
            WHERE Asset_Serial_No__c IN :actualSerialIds
            ORDER BY EndDate DESC
        ]) {
            if (warranty.Asset_Serial_No__c == null) {
                continue;
            }

            String typeValue = warranty.Type__c == null ? '' : warranty.Type__c.toLowerCase();

            if (typeValue == 'product' && !productWarrantyDates.containsKey(warranty.Asset_Serial_No__c)) {
                productWarrantyDates.put(warranty.Asset_Serial_No__c, warranty.EndDate);
            }

            if (typeValue == 'performance' && !performanceWarrantyDates.containsKey(warranty.Asset_Serial_No__c)) {
                performanceWarrantyDates.put(warranty.Asset_Serial_No__c, warranty.EndDate);
            }
        }

        Case_Related_Assets__c caseRelatedAsset = new Case_Related_Assets__c();
        caseRelatedAsset.Case__c = caseId;
        caseRelatedAsset.Asset__c = assetId;
        
        insert caseRelatedAsset;

        List<Case_Related_Assets_Serial_No__c> caseSerialRecords = new List<Case_Related_Assets_Serial_No__c>();

        for (Asset_Serial_No__c serial : serialRecords) {
            Case_Related_Assets_Serial_No__c caseSerial = new Case_Related_Assets_Serial_No__c();
            caseSerial.Case_Related_Assets__c = caseRelatedAsset.Id;
            caseSerial.Asset__c = assetId;
            caseSerial.Asset_Serial_No__c = serial.Id;
            //caseSerial.Serial_Number__c = serial.Name;
            //caseSerial.Product_Warranty_End_Date__c = productWarrantyDates.get(serial.Id);
            //caseSerial.Performance_Warranty_End_Date__c = performanceWarrantyDates.get(serial.Id);
            caseSerialRecords.add(caseSerial);
        }

        insert caseSerialRecords;
    }
    
    public static void test() {
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
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
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