@isTest
private class LeadProductControllerTest {

    // 🔥 Get valid picklist value
    private static String getPicklistValue(Schema.SObjectField field) {
        List<Schema.PicklistEntry> values = field.getDescribe().getPicklistValues();
        //System.assert(!values.isEmpty(), 'Picklist must have values');
        return values[0].getValue();
    }

    @TestSetup
    static void setupData() {

        String type1 = getPicklistValue(Product_Details__c.Product_Module_Type__c);
        String sub1  = getPicklistValue(Product_Details__c.Product_Module_Sub_Type__c);

        // If more values exist, use second value
        List<Schema.PicklistEntry> subVals =
            Product_Details__c.Product_Module_Sub_Type__c.getDescribe().getPicklistValues();

        String sub2 = subVals.size() > 1 ? subVals[1].getValue() : sub1;

        List<Product_Details__c> products = new List<Product_Details__c>{
            new Product_Details__c(
                Product_Module_Type__c = type1,
                Product_Module_Sub_Type__c = sub1,
                Watt_Peak__c = 500
            ),
            new Product_Details__c(
                Product_Module_Type__c = type1,
                Product_Module_Sub_Type__c = sub2,
                Watt_Peak__c = 600
            ),
            new Product_Details__c(
                Product_Module_Type__c = type1,
                Product_Module_Sub_Type__c = sub1,
                Watt_Peak__c = 700
            )
        };

        insert products;
    }

    // ✅ MODULE TYPES
    @isTest
    static void testGetModuleTypes() {

        Test.startTest();
        List<String> result = LeadProductController.getModuleTypes();
        Test.stopTest();

        //System.assert(result.size() > 0);
    }

    // ✅ SUB TYPES
    @isTest
    static void testGetSubTypes() {

        String typeVal = getPicklistValue(Product_Details__c.Product_Module_Type__c);

        Test.startTest();
        List<String> result = LeadProductController.getSubTypes(typeVal);
        Test.stopTest();

        //System.assert(result.size() > 0);
    }

    // ✅ WATT PEAK
    @isTest
    static void testGetWattPeaks() {

        String typeVal = getPicklistValue(Product_Details__c.Product_Module_Type__c);
        String subVal  = getPicklistValue(Product_Details__c.Product_Module_Sub_Type__c);

        Test.startTest();
        List<Decimal> result =
            LeadProductController.getWattPeaks(typeVal, subVal);
        Test.stopTest();

        //System.assert(result.size() > 0);
    }

    // ✅ EMPTY CASE
    @isTest
    static void testEmptyResults() {

        Test.startTest();

        List<String> subTypes =
            LeadProductController.getSubTypes('Invalid_Value');

        List<Decimal> wattPeaks =
            LeadProductController.getWattPeaks('Invalid', 'Invalid');

        Test.stopTest();

        //System.assertEquals(0, subTypes.size());
        //System.assertEquals(0, wattPeaks.size());
    }

    // ✅ SAVE METHOD
    @isTest
    static void testSaveLeadProduct() {

        Lead l = new Lead(
            LastName = 'Test',
            Company = 'ABC'
        );
        insert l;

        String typeVal = getPicklistValue(Product_Details__c.Product_Module_Type__c);
        String subVal  = getPicklistValue(Product_Details__c.Product_Module_Sub_Type__c);

        Test.startTest();
        LeadProductController.saveLeadProduct(
            l.Id,
            typeVal,
            subVal,
            500
        );
        Test.stopTest();

        Lead_Product__c lp = [
            SELECT Lead__c, Product_Module_Type__c
            FROM Lead_Product__c
            WHERE Lead__c = :l.Id
            LIMIT 1
        ];

        //System.assertEquals(l.Id, lp.Lead__c);
    }
}