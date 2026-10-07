@isTest
public class SRTLeadProductControllerTest {

    @testSetup
    static void setupData() {

        // ✅ Create Lead
        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted'
        );
        insert ld;

        // ✅ Create Product Master Data
        if (Schema.getGlobalDescribe().containsKey('Salesforce_Product__c')) {

            List<SObject> prodList = new List<SObject>();

            // Solar
            SObject solar = Schema.getGlobalDescribe()
                .get('Salesforce_Product__c')
                .newSObject();

            solar.put('Product__c', 'Solar');
            solar.put('Module_Type__c', 'Type A');
            solar.put('Module_Technology__c', 'Tech1');
            solar.put('Sub_Module__c', 'Sub1');
            solar.put('Product_Category__c', 'SRT Sales Products');

            prodList.add(solar);

            // BESS
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
        SRTLeadProductController.getProductMasterRows();
        Test.stopTest();
    }

    // ---------------- SUCCESS - SOLAR ----------------
    @isTest
    static void testSaveLeadProduct_Solar() {

        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();

        SRTLeadProductController.saveLeadProduct(
            ld.Id,
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
    static void testSaveLeadProduct_BESS() {

        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();

        SRTLeadProductController.saveLeadProduct(
            ld.Id,
            'BESS',
            null,
            null,
            null,
            50,
            'KW'
        );

        Test.stopTest();
    }

    // ---------------- NULL LEAD ----------------
    @isTest
    static void testNullLead() {

        Test.startTest();
        try {
            SRTLeadProductController.saveLeadProduct(
                null,
                'Solar',
                'Type A',
                'Tech1',
                'Sub1',
                100,
                'KW'
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    // ---------------- EMPTY PRODUCT ----------------
    @isTest
    static void testEmptyProduct() {

        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();
        try {
            SRTLeadProductController.saveLeadProduct(
                ld.Id,
                '',
                'Type A',
                'Tech1',
                'Sub1',
                100,
                'KW'
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    // ---------------- INVALID CAPACITY ----------------
    @isTest
    static void testInvalidCapacity() {

        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();
        try {
            SRTLeadProductController.saveLeadProduct(
                ld.Id,
                'Solar',
                'Type A',
                'Tech1',
                'Sub1',
                0,
                'KW'
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    // ---------------- NO UOM ----------------
    @isTest
    static void testNoUOM() {

        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();
        try {
            SRTLeadProductController.saveLeadProduct(
                ld.Id,
                'Solar',
                'Type A',
                'Tech1',
                'Sub1',
                100,
                ''
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    // ---------------- SOLAR MISSING FIELDS ----------------
    @isTest
    static void testSolarMissingFields() {

        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();
        try {
            SRTLeadProductController.saveLeadProduct(
                ld.Id,
                'Solar',
                null,
                null,
                null,
                100,
                'KW'
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }
}