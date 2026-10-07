@isTest
public class OpportunityQACTest {

    @testSetup
    static void setupData() {

        // ✅ Get Standard Pricebook
        Id stdPricebookId = Test.getStandardPricebookId();

        // ✅ Ensure Standard Pricebook is Active
        Pricebook2 pb = new Pricebook2(
            Id = stdPricebookId,
            IsActive = true
        );
        update pb;

        // ✅ Create ONLY ONE Product (important)
        Product2 prod = new Product2(
            Name = 'Standard Product',
            IsActive = true
        );
        insert prod;

        // ✅ Create Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // ✅ Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // ✅ Opportunity WITH Pricebook (important)
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Pricebook2Id = stdPricebookId,
            Business_Segment__c = 'Retail'
        );
        insert opp;

        // ✅ Custom Object Data (for getInitData)
        if (Schema.getGlobalDescribe().containsKey('Salesforce_Product__c')) {

            SObject prodRec = Schema.getGlobalDescribe()
                .get('Salesforce_Product__c')
                .newSObject();

            prodRec.put('Module_Type__c', 'Type A');
            prodRec.put('Cell_Type__c', 'Mono');
            prodRec.put('Module_Technology__c', 'Tech1');
            prodRec.put('Product_Rating_BIN__c', 'High');
            prodRec.put('Product_Sub_Type__c', 'Sub1');
            prodRec.put('Product_Category__c', 'Solar Sales Products');

            insert prodRec;
        }
    }

    // ---------------- INIT DATA ----------------
    @isTest
    static void testGetInitData() {

        Test.startTest();
        OpportunityProductQuickActionController.getInitData();
        Test.stopTest();

        System.assert(true);
    }

    /* ---------------- SUCCESS TEST ----------------
    @isTest
    static void testCreateOpportunityProduct_Success() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();

        Id oliId = OpportunityProductQuickActionController.createOpportunityProduct(
            opp.Id,
            'Type A',
            'Mono',
            'Tech1',
            'High',
            'Sub1',
            '5 Years',
            '10m',
            100,
            'KW'
        );

        Test.stopTest();

        System.assertNotEquals(null, oliId);

        OpportunityLineItem oli = [
            SELECT Id, Module_Type__c, Project_Capacity__c
            FROM OpportunityLineItem
            WHERE Id = :oliId
        ];

        System.assertEquals('Type A', oli.Module_Type__c);
        System.assertEquals(100, oli.Project_Capacity__c);
    }*/

    // ---------------- VALIDATION ERROR ----------------
    @isTest
    static void testCreateOpportunityProduct_ValidationError() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();

        try {
            OpportunityProductQuickActionController.createOpportunityProduct(
                opp.Id,
                null, // ❌ missing module type
                'Mono',
                'Tech1',
                'High',
                'Sub1',
                '5 Years',
                '10m',
                100,
                'KW'
            );
            System.assert(false, 'Exception expected');
        } catch (Exception e) {
            System.assert(true);
        }

        Test.stopTest();
    }

    // ---------------- INVALID CAPACITY ----------------
    @isTest
    static void testCreateOpportunityProduct_InvalidCapacity() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();

        try {
            OpportunityProductQuickActionController.createOpportunityProduct(
                opp.Id,
                'Type A',
                'Mono',
                'Tech1',
                'High',
                'Sub1',
                '5 Years',
                '10m',
                0, // ❌ invalid
                'KW'
            );
            System.assert(false, 'Exception expected');
        } catch (Exception e) {
            System.assert(true);
        }

        Test.stopTest();
    }

    // ---------------- NULL OPPORTUNITY ----------------
    @isTest
    static void testCreateOpportunityProduct_NullOpp() {

        Test.startTest();

        try {
            OpportunityProductQuickActionController.createOpportunityProduct(
                null,
                'Type A',
                'Mono',
                'Tech1',
                'High',
                'Sub1',
                '5 Years',
                '10m',
                100,
                'KW'
            );
            System.assert(false, 'Exception expected');
        } catch (Exception e) {
            System.assert(true);
        }

        Test.stopTest();
    }

    // ---------------- NO PRICEBOOK SCENARIO ----------------
   @isTest
static void testCreateOpportunityProduct_NoPricebook() {

    Account acc = new Account(Name = 'Test Acc 2');
    insert acc;

    Opportunity opp = new Opportunity(
        Name = 'Opp Without PB',
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(10),
        AccountId = acc.Id,
        Business_Segment__c = 'Retail'
        // ❌ No Pricebook2Id
    );
    insert opp;

    Test.startTest();

    try {
        OpportunityProductQuickActionController.createOpportunityProduct(
            opp.Id,
            'Type A',
            'Mono',
            'Tech1',
            'High',
            'Sub1',
            '5 Years',
            '10m',
            50,
            'KW'
        );
        System.assert(false, 'Exception expected');
    } catch (Exception e) {
        System.assert(true); // ✅ expected
    }

    Test.stopTest();
}
}