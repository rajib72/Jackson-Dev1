@isTest
public class SRTOpportunityProductControllerTest {

    @testSetup
    static void setupData() {

        // ✅ Activate Standard Pricebook
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // ✅ Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // ✅ Product
        Product2 prod = new Product2(
            Name = 'Standard Product',
            IsActive = true
        );
        insert prod;

        // ✅ Pricebook Entry (CRITICAL)
        insert new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );

        // ✅ Opportunity WITH Pricebook
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Pricebook2Id = stdPbId,
             Business_Segment__c = 'Retail' // ✅ ADD THIS
        );
        insert opp;

        // ✅ Opportunity WITHOUT Pricebook (for negative test)
        Opportunity oppNoPb = new Opportunity(
            Name = 'No PB Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
             Business_Segment__c = 'Retail' // ✅ ADD THIS
        );
        insert oppNoPb;

        // ✅ Product Master Data
        if (Schema.getGlobalDescribe().containsKey('Salesforce_Product__c')) {

            List<SObject> prodList = new List<SObject>();

            SObject solar = Schema.getGlobalDescribe()
                .get('Salesforce_Product__c')
                .newSObject();

            solar.put('Product__c', 'Solar');
            solar.put('Module_Type__c', 'Type A');
            solar.put('Module_Technology__c', 'Tech1');
            solar.put('Sub_Module__c', 'Sub1');
            solar.put('Product_Category__c', 'SRT Sales Products');

            prodList.add(solar);

            SObject bess = Schema.getGlobalDescribe()
                .get('Salesforce_Product__c')
                .newSObject();

            bess.put('Product__c', 'BESS');
            bess.put('Module_Type__c', 'Type B');
            bess.put('Module_Technology__c', 'Tech2');
            bess.put('Sub_Module__c', 'Sub2');
            bess.put('Product_Category__c', 'SRT Sales Products');

            prodList.add(bess);

            insert prodList;
        }
    }

    // ---------------- GET DATA ----------------
    @isTest
    static void testGetProductMasterRows() {

        Test.startTest();
        SRTOpportunityProductController.getProductMasterRows();
        Test.stopTest();
    }

    // ---------------- SUCCESS - SOLAR ----------------
    @isTest
    static void testSaveOpportunityProduct_Solar() {

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Pricebook2Id != null LIMIT 1];

        Test.startTest();

        SRTOpportunityProductController.saveOpportunityProduct(
            opp.Id,
            'Solar',
            'Type A',
            'Tech1',
            'Sub1',
            100,
            'KW'
        );

        Test.stopTest();
    }

    // ---------------- SUCCESS - BESS ----------------
    @isTest
    static void testSaveOpportunityProduct_BESS() {

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Pricebook2Id != null LIMIT 1];

        Test.startTest();

        SRTOpportunityProductController.saveOpportunityProduct(
            opp.Id,
            'BESS',
            null,
            null,
            null,
            50,
            'MW'
        );

        Test.stopTest();
    }

    // ---------------- NULL OPPORTUNITY ----------------
    @isTest
    static void testNullOpportunity() {

        Test.startTest();
        try {
            SRTOpportunityProductController.saveOpportunityProduct(
                null,
                'Solar',
                'Type A',
                'Tech1',
                'Sub1',
                100,
                'KW'
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- NO PRODUCT ----------------
    @isTest
    static void testNoProduct() {

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Pricebook2Id != null LIMIT 1];

        Test.startTest();
        try {
            SRTOpportunityProductController.saveOpportunityProduct(
                opp.Id,
                '',
                'Type A',
                'Tech1',
                'Sub1',
                100,
                'KW'
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- INVALID CAPACITY ----------------
    @isTest
    static void testInvalidCapacity() {

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Pricebook2Id != null LIMIT 1];

        Test.startTest();
        try {
            SRTOpportunityProductController.saveOpportunityProduct(
                opp.Id,
                'Solar',
                'Type A',
                'Tech1',
                'Sub1',
                0,
                'KW'
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- NO UOM ----------------
    @isTest
    static void testNoUOM() {

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Pricebook2Id != null LIMIT 1];

        Test.startTest();
        try {
            SRTOpportunityProductController.saveOpportunityProduct(
                opp.Id,
                'Solar',
                'Type A',
                'Tech1',
                'Sub1',
                100,
                ''
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- NO PRICEBOOK ----------------
    @isTest
    static void testNoPricebook() {

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Pricebook2Id = null LIMIT 1];

        Test.startTest();
        try {
            SRTOpportunityProductController.saveOpportunityProduct(
                opp.Id,
                'Solar',
                'Type A',
                'Tech1',
                'Sub1',
                100,
                'KW'
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- SOLAR MISSING FIELDS ----------------
    @isTest
    static void testSolarMissingFields() {

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Pricebook2Id != null LIMIT 1];

        Test.startTest();
        try {
            SRTOpportunityProductController.saveOpportunityProduct(
                opp.Id,
                'Solar',
                null,
                null,
                null,
                100,
                'KW'
            );
        } catch (Exception e) {}
        Test.stopTest();
    }
}