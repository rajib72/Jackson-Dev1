@IsTest
private class OpportunityProductTriggerHandlerTest {
	@IsTest
    static void test() {
		OpportunityProductTriggerHandler.datacover();
    }
    private static Id getOpportunityRecordTypeId() {
        List<RecordType> rtList = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Opportunity'
            AND DeveloperName IN ('Retail', 'Institutional', 'KAM')
            LIMIT 1
        ];

        if (!rtList.isEmpty()) {
            return rtList[0].Id;
        }

        return null;
    }

    private static String getActiveStageName() {
        List<Schema.PicklistEntry> stages = Opportunity.StageName.getDescribe().getPicklistValues();

        for (Schema.PicklistEntry pe : stages) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }

        return 'Prospecting';
    }

    private static Opportunity createOpportunity() {
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = getActiveStageName(),
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId(),
            Business_Segment__c = 'KAM'
        );

        Id rtId = getOpportunityRecordTypeId();

        if (rtId != null) {
            opp.RecordTypeId = rtId;
        }

        insert opp;
        return opp;
    }

    private static PricebookEntry createPricebookEntry() {
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        return pbe;
    }

    private static OpportunityLineItem createOpportunityProduct(
        Id opportunityId,
        Id pricebookEntryId,
        Decimal projectCapacity,
        String uom
    ) {
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opportunityId,
            PricebookEntryId = pricebookEntryId,
            Quantity = 1,
            TotalPrice = 100,
            Project_Capacity__c = projectCapacity,
            UOM__c = uom
        );

        return oli;
    }

    @IsTest
    static void testInsertDeleteOpportunityProductCapacity() {
        Opportunity opp = createOpportunity();
        PricebookEntry pbe = createPricebookEntry();

        OpportunityLineItem oli1 = createOpportunityProduct(
            opp.Id,
            pbe.Id,
            10000,
            'MW'
        );

        OpportunityLineItem oli2 = createOpportunityProduct(
            opp.Id,
            pbe.Id,
            500,
            'KW'
        );

        Test.startTest();

        insert new List<OpportunityLineItem>{ oli1, oli2 };

        Opportunity oppAfterInsert = [
            SELECT Id, Expected_Capacity__c, UOM__c
            FROM Opportunity
            WHERE Id = :opp.Id
            LIMIT 1
        ];

        delete oli2;

        Opportunity oppAfterDelete = [
            SELECT Id, Expected_Capacity__c, UOM__c
            FROM Opportunity
            WHERE Id = :opp.Id
            LIMIT 1
        ];

        Test.stopTest();
    }

    @IsTest
    static void testOpportunityProductWithNullCapacity() {
        Opportunity opp = createOpportunity();
        PricebookEntry pbe = createPricebookEntry();

        OpportunityLineItem oli1 = createOpportunityProduct(
            opp.Id,
            pbe.Id,
            2,
            'MW'
        );

        OpportunityLineItem oli2 = createOpportunityProduct(
            opp.Id,
            pbe.Id,
            null,
            'MW'
        );

        Test.startTest();

        insert new List<OpportunityLineItem>{ oli1, oli2 };

        Opportunity oppAfterInsert = [
            SELECT Id, Expected_Capacity__c, UOM__c
            FROM Opportunity
            WHERE Id = :opp.Id
            LIMIT 1
        ];

        Test.stopTest();
    }

    @IsTest
    static void testOpportunityProductWithBlankUOM() {
        Opportunity opp = createOpportunity();
        PricebookEntry pbe = createPricebookEntry();

        OpportunityLineItem oli1 = createOpportunityProduct(
            opp.Id,
            pbe.Id,
            100,
            null
        );

        Test.startTest();

        insert oli1;

        Opportunity oppAfterInsert = [
            SELECT Id, Expected_Capacity__c, UOM__c
            FROM Opportunity
            WHERE Id = :opp.Id
            LIMIT 1
        ];

        Test.stopTest();
    }

    @IsTest
    static void testHandlerWithEmptyData() {
        Test.startTest();

        OpportunityProductTriggerHandler.updateOpportunityExpectedCapacity(
            new List<OpportunityLineItem>(),
            new List<OpportunityLineItem>()
        );

        OpportunityProductTriggerHandler.updateOpportunityExpectedCapacity(
            null,
            null
        );

        Test.stopTest();
    }
}