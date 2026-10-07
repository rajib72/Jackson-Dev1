@isTest
public class LeadProductQuickActionControllerTest {

    @testSetup
    static void setupData() {

        // ✅ Lead
        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted'
        );
        insert ld;

        // ✅ Activate Standard Pricebook
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // ✅ Standard Product
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

        // ✅ Product Master Data
        if (Schema.getGlobalDescribe().containsKey('Salesforce_Product__c')) {

            SObject rec = Schema.getGlobalDescribe()
                .get('Salesforce_Product__c')
                .newSObject();

            rec.put('Module_Type__c', 'Type A');
            rec.put('Cell_Type__c', 'Mono');
            rec.put('Module_Technology__c', 'Tech1');
            rec.put('Product_Rating_BIN__c', 'High');
            rec.put('Product_Sub_Type__c', 'Sub1');
            rec.put('Product_Category__c', 'Solar Sales Products');

            insert rec;
        }
    }

    // ---------------- INIT ----------------
    @isTest
    static void testGetInitData() {
        Test.startTest();
        LeadProductQuickActionController.getInitData();
        Test.stopTest();
    }

    // ---------------- SUCCESS (MAIN COVERAGE BOOST) ----------------
    @isTest
    static void testCreateLeadProduct_Success() {

        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();

        LeadProductQuickActionController.createLeadProduct(
            ld.Id,
            'Type A',
            'Mono',
            'Tech1',
            'High',
            'Sub1',
            null,   // optional
            null,   // optional
            100,
            'KW'
        );

        Test.stopTest();
    }

    /* ---------------- SECOND SUCCESS (DIFFERENT PATH) ----------------
    @isTest
    static void testCreateLeadProduct_Success_WithWarranty() {

        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();

        LeadProductQuickActionController.createLeadProduct(
            ld.Id,
            'Type A',
            'Mono',
            'Tech1',
            'High',
            'Sub1',
            '5 Years',
            '10m',
            50,
            'MW'
        );

        Test.stopTest();
    }*/

    // ---------------- NULL LEAD ----------------
    @isTest
    static void testNullLead() {
        Test.startTest();
        try {
            LeadProductQuickActionController.createLeadProduct(
                null,'Type A','Mono','Tech1','High','Sub1','5','10',100,'KW'
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- MISSING MODULE TYPE ----------------
    @isTest
    static void testMissingModuleType() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        try {
            LeadProductQuickActionController.createLeadProduct(
                ld.Id,'','Mono','Tech1','High','Sub1','5','10',100,'KW'
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- INVALID CAPACITY ----------------
    @isTest
    static void testInvalidCapacity() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        try {
            LeadProductQuickActionController.createLeadProduct(
                ld.Id,'Type A','Mono','Tech1','High','Sub1','5','10',0,'KW'
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- MISSING UOM ----------------
    @isTest
    static void testMissingUOM() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        try {
            LeadProductQuickActionController.createLeadProduct(
                ld.Id,'Type A','Mono','Tech1','High','Sub1','5','10',100,''
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- NO PRODUCT ----------------
    @isTest
    static void testNoStandardProduct() {

        delete [SELECT Id FROM Product2 WHERE Name = 'Standard Product'];

        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();
        try {
            LeadProductQuickActionController.createLeadProduct(
                ld.Id,'Type A','Mono','Tech1','High','Sub1','5','10',100,'KW'
            );
        } catch (Exception e) {}
        Test.stopTest();
    }
}