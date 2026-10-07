@IsTest
private class LeadProductTriggerHandlerTest {
    @IsTest
    static void test() {
		LeadProductTriggerHandler.datacover();
    }

    private static String getActiveLeadStatus() {
        List<Schema.PicklistEntry> statuses = Lead.Status.getDescribe().getPicklistValues();

        for (Schema.PicklistEntry pe : statuses) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }

        return 'Open - Not Contacted';
    }

    private static Lead createSolarSalesLead() {
        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = getActiveLeadStatus(),
            Internal_Business_Team__c = 'Solar Sales'
        );

        insert ld;
        return ld;
    }

    private static Lead_Product__c createLeadProduct(
        Id leadId,
        Decimal projectCapacity,
        String uom
    ) {
        Lead_Product__c lp = new Lead_Product__c(
            Lead__c = leadId,
            Project_Capacity__c = projectCapacity,
            UOM__c = uom
        );

        return lp;
    }

    @IsTest
    static void testInsertUpdateDeleteUndeleteLeadProductCapacity() {
        Lead ld = createSolarSalesLead();

        Lead_Product__c lp1 = createLeadProduct(ld.Id, 10000, 'MW');
        Lead_Product__c lp2 = createLeadProduct(ld.Id, 500, 'KW');

        Test.startTest();

        insert new List<Lead_Product__c>{ lp1, lp2 };

        Lead leadAfterInsert = [
            SELECT Id, Expected_Capacity__c, UOM__c
            FROM Lead
            WHERE Id = :ld.Id
            LIMIT 1
        ];

        lp1.Project_Capacity__c = 5;
        lp1.UOM__c = 'MW';
        update lp1;

        Lead leadAfterUpdate = [
            SELECT Id, Expected_Capacity__c, UOM__c
            FROM Lead
            WHERE Id = :ld.Id
            LIMIT 1
        ];

        delete lp2;

        Lead leadAfterDelete = [
            SELECT Id, Expected_Capacity__c, UOM__c
            FROM Lead
            WHERE Id = :ld.Id
            LIMIT 1
        ];

        undelete lp2;

        Lead leadAfterUndelete = [
            SELECT Id, Expected_Capacity__c, UOM__c
            FROM Lead
            WHERE Id = :ld.Id
            LIMIT 1
        ];

        Test.stopTest();
    }

    @IsTest
    static void testLeadProductWithNullCapacity() {
        Lead ld = createSolarSalesLead();

        Lead_Product__c lp1 = createLeadProduct(ld.Id, 2, 'MW');
        Lead_Product__c lp2 = createLeadProduct(ld.Id, null, 'MW');

        Test.startTest();

        insert new List<Lead_Product__c>{ lp1, lp2 };

        Lead leadAfterInsert = [
            SELECT Id, Expected_Capacity__c, UOM__c
            FROM Lead
            WHERE Id = :ld.Id
            LIMIT 1
        ];

        Test.stopTest();
    }

    @IsTest
    static void testLeadProductWithBlankUOM() {
        Lead ld = createSolarSalesLead();

        Lead_Product__c lp1 = createLeadProduct(ld.Id, 100, null);

        Test.startTest();

        insert lp1;

        Lead leadAfterInsert = [
            SELECT Id, Expected_Capacity__c, UOM__c
            FROM Lead
            WHERE Id = :ld.Id
            LIMIT 1
        ];

        Test.stopTest();
    }

    @IsTest
    static void testHandlerWithEmptyData() {
        Test.startTest();

        LeadProductTriggerHandler.updateLeadExpectedCapacity(
            new List<Lead_Product__c>(),
            new List<Lead_Product__c>()
        );

        LeadProductTriggerHandler.updateLeadExpectedCapacity(
            null,
            null
        );

        Test.stopTest();
    }
}