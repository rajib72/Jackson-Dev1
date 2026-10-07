@isTest
public class CaseAssetControllerTest {

    @testSetup
    static void setupData() {
        // 1. Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // 2. Create Case linked to Account
        Case c1 = new Case(Subject = 'Case With Account', AccountId = acc.Id);
        insert c1;

        // 3. Create Case without Account
        Case c2 = new Case(Subject = 'Case Without Account');
        insert c2;

        // 4. Create Assets linked to Account
        Asset a1 = new Asset(Name = 'Asset 1', SerialNumber = 'SN001', AccountId = acc.Id);
        Asset a2 = new Asset(Name = 'Asset 2', SerialNumber = 'SN002', AccountId = acc.Id);
        insert new List<Asset>{a1, a2};
    }

    @isTest
    static void testGetAssets() {
        Case cWithAcc = [SELECT Id FROM Case WHERE Subject = 'Case With Account' LIMIT 1];
        Case cWithoutAcc = [SELECT Id FROM Case WHERE Subject = 'Case Without Account' LIMIT 1];

        Test.startTest();
        // Case with Account should return assets
        List<Asset> assets = CaseAssetController.getAssets(cWithAcc.Id);
        System.assertEquals(2, assets.size(), 'Should return 2 assets linked to account');

        // Case without Account should return empty list
        List<Asset> emptyAssets = CaseAssetController.getAssets(cWithoutAcc.Id);
        System.assertEquals(0, emptyAssets.size(), 'Should return empty list for case without account');
        Test.stopTest();
    }

    @isTest
    static void testSaveCaseAssets() {
        Case cWithAcc = [SELECT Id, AccountId FROM Case WHERE Subject = 'Case With Account' LIMIT 1];
        List<Asset> assets = [SELECT Id FROM Asset WHERE AccountId = :cWithAcc.AccountId];

        List<Id> assetIds = new List<Id>();
        for (Asset a : assets) {
            assetIds.add(a.Id);
        }

        Test.startTest();
        CaseAssetController.saveCaseAssets(cWithAcc.Id, assetIds);
        Test.stopTest();

        // Verify Case_Related_Assets__c records were inserted
        List<Case_Related_Assets__c> related = [SELECT Id, Case__c, Asset__c 
                                                FROM Case_Related_Assets__c 
                                                WHERE Case__c = :cWithAcc.Id];
        System.assertEquals(assetIds.size(), related.size(), 'All assets should be linked to the case');
    }
}