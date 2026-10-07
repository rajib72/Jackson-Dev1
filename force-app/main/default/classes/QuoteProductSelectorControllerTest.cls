@isTest
public class QuoteProductSelectorControllerTest {

    @testSetup
    static void setupData() {

        // ---------------- ACCOUNT ----------------
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // ---------------- GET VALID PICKLIST VALUE ----------------
        Schema.DescribeFieldResult fieldResult = Opportunity.Business_Segment__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        String validSegment = picklistValues.isEmpty() ? null : picklistValues[0].getValue();

        // ---------------- OPPORTUNITY ----------------
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Business_Segment__c = validSegment
        );
        insert opp;

        // ---------------- PRICEBOOK ----------------
        Id stdPbId = Test.getStandardPricebookId();

        // ---------------- PRODUCT ----------------
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        // ---------------- PRICEBOOK ENTRY ----------------
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = stdPbId,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // ---------------- OPPORTUNITY LINE ITEM ----------------
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            Quantity = 10,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id,
            Project_Capacity__c = 5,
            UOM__c = 'KW',
            Product_Rating_BIN__c = '500'
        );
        insert oli;

        // ---------------- QUOTE ----------------
        Quote qt = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPbId,
            Status = 'Draft'
        );
        insert qt;
    }

    // ---------------- TEST INIT DATA ----------------
    @isTest
    static void testGetInitData() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        QuoteProductSelectorController.InitResponse res =
            QuoteProductSelectorController.getInitData(qt.Id);
        Test.stopTest();

       
    }

    // ---------------- TEST SAVE SUCCESS ----------------
    @isTest
    static void testSaveQuoteLineItems_Success() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];
        OpportunityLineItem oli = [SELECT Id, PricebookEntryId FROM OpportunityLineItem LIMIT 1];

        Map<String, Object> row = new Map<String, Object>{
            'opportunityLineItemId' => oli.Id,
            'pricebookEntryId' => oli.PricebookEntryId,
            'nos' => 2,
            'projectCapacity' => 5,
            'unitPrice' => 100,
            'total' => 500000,
            'gstAmount' => 50000,
            'grandTotal' => 550000,
            'uom' => 'KW'
        };

        String jsonInput = JSON.serialize(new List<Object>{ row });

        Test.startTest();
        QuoteProductSelectorController.saveQuoteLineItems(qt.Id, jsonInput);
        Test.stopTest();

        List<QuoteLineItem> qliList = [SELECT Id FROM QuoteLineItem];
        System.assert(qliList.size() > 0);
    }

    // ---------------- TEST NO ROWS SELECTED ----------------
    @isTest
    static void testSaveQuoteLineItems_NoRows() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        try {
            QuoteProductSelectorController.saveQuoteLineItems(qt.Id, null);
            
        } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }

    // ---------------- TEST ALREADY ADDED ----------------
    @isTest
    static void testSaveQuoteLineItems_AlreadyAdded() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];
        OpportunityLineItem oli = [SELECT Id, PricebookEntryId FROM OpportunityLineItem LIMIT 1];

        // Insert first time
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = qt.Id,
            PricebookEntryId = oli.PricebookEntryId,
            Quantity = 5,
            UnitPrice = 100,
            Opportunity_Product__c = oli.Id
        );
        insert qli;

        Map<String, Object> row = new Map<String, Object>{
            'opportunityLineItemId' => oli.Id,
            'pricebookEntryId' => oli.PricebookEntryId,
            'projectCapacity' => 5,
            'unitPrice' => 100
        };

        String jsonInput = JSON.serialize(new List<Object>{ row });

        Test.startTest();
        try {
            QuoteProductSelectorController.saveQuoteLineItems(qt.Id, jsonInput);
                    } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }

    // ---------------- TEST ERROR SCENARIO ----------------
    @isTest
    static void testSaveQuoteLineItems_Error() {
        Test.startTest();
        try {
            QuoteProductSelectorController.saveQuoteLineItems(null, null);
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }
    
    @isTest
static void testGetInitData_NullQuoteId() {
    Test.startTest();
    try {
        QuoteProductSelectorController.getInitData(null);
       
    } catch (AuraHandledException e) {
        
    }
    Test.stopTest();
}
    
  /*  @isTest
static void testGetInitData_NoOpportunity() {
    Id stdPbId = Test.getStandardPricebookId();

    Quote qt = new Quote(
        Name = 'No Opp Quote',
        Pricebook2Id = stdPbId,
        Status = 'Draft'
    );
    insert qt;

    Test.startTest();
    try {
        QuoteProductSelectorController.getInitData(qt.Id);
       
    } catch (AuraHandledException e) {
       
    }
    Test.stopTest();
}*/
    @isTest
static void testGetInitData_NoPricebook() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

    Quote qt = new Quote(
        Name = 'No PB Quote',
        OpportunityId = opp.Id,
        Status = 'Draft'
    );
    insert qt;

    Test.startTest();
    try {
        QuoteProductSelectorController.getInitData(qt.Id);
       
    } catch (AuraHandledException e) {
       
    }
    Test.stopTest();
}
    
    @isTest
static void testMWCalculationBranch() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Id stdPbId = Test.getStandardPricebookId();

    Product2 prod = new Product2(Name = 'MW Product', IsActive = true);
    insert prod;

    PricebookEntry pbe = new PricebookEntry(
        Product2Id = prod.Id,
        Pricebook2Id = stdPbId,
        UnitPrice = 200,
        IsActive = true
    );
    insert pbe;

    OpportunityLineItem oli = new OpportunityLineItem(
        OpportunityId = opp.Id,
        Quantity = 1,
        UnitPrice = 200,
        PricebookEntryId = pbe.Id,
        Project_Capacity__c = 2,
        UOM__c = 'MW',
        Product_Rating_BIN__c = '1000'
    );
    insert oli;

    Quote qt = [SELECT Id FROM Quote LIMIT 1];

    Test.startTest();
    QuoteProductSelectorController.getInitData(qt.Id);
    Test.stopTest();
}
    
    @isTest
static void testInvalidRatingBin() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Id stdPbId = Test.getStandardPricebookId();

    Product2 prod = new Product2(Name = 'Invalid BIN', IsActive = true);
    insert prod;

    PricebookEntry pbe = new PricebookEntry(
        Product2Id = prod.Id,
        Pricebook2Id = stdPbId,
        UnitPrice = 100,
        IsActive = true
    );
    insert pbe;

    OpportunityLineItem oli = new OpportunityLineItem(
        OpportunityId = opp.Id,
        Quantity = 1,
        UnitPrice = 100,
        PricebookEntryId = pbe.Id,
        Project_Capacity__c = 5,
        UOM__c = 'KW',
        Product_Rating_BIN__c = 'INVALID' // 🔥 important
    );
    insert oli;

    Quote qt = [SELECT Id FROM Quote LIMIT 1];

    Test.startTest();
    QuoteProductSelectorController.getInitData(qt.Id);
    Test.stopTest();
}
    
    @isTest
static void testSaveQuoteLineItems_MissingPBE() {
    Quote qt = [SELECT Id FROM Quote LIMIT 1];
    OpportunityLineItem oli = [SELECT Id FROM OpportunityLineItem LIMIT 1];

    Map<String, Object> row = new Map<String, Object>{
        'opportunityLineItemId' => oli.Id,
        'pricebookEntryId' => null, // 🔥 trigger error
        'projectCapacity' => 5,
        'unitPrice' => 100
    };

    String jsonInput = JSON.serialize(new List<Object>{ row });

    Test.startTest();
    try {
        QuoteProductSelectorController.saveQuoteLineItems(qt.Id, jsonInput);
       
    } catch (AuraHandledException e) {
       
    }
    Test.stopTest();
}
    
    @isTest
static void testSaveQuoteLineItems_InvalidCapacity() {
    Quote qt = [SELECT Id FROM Quote LIMIT 1];
    OpportunityLineItem oli = [SELECT Id, PricebookEntryId FROM OpportunityLineItem LIMIT 1];

    Map<String, Object> row = new Map<String, Object>{
        'opportunityLineItemId' => oli.Id,
        'pricebookEntryId' => oli.PricebookEntryId,
        'projectCapacity' => 0, // 🔥 invalid
        'unitPrice' => 100
    };

    String jsonInput = JSON.serialize(new List<Object>{ row });

    Test.startTest();
    try {
        QuoteProductSelectorController.saveQuoteLineItems(qt.Id, jsonInput);
        
    } catch (AuraHandledException e) {
        
    }
    Test.stopTest();
}
    
    @isTest
static void testSaveQuoteLineItems_NegativePrice() {
    Quote qt = [SELECT Id FROM Quote LIMIT 1];
    OpportunityLineItem oli = [SELECT Id, PricebookEntryId FROM OpportunityLineItem LIMIT 1];

    Map<String, Object> row = new Map<String, Object>{
        'opportunityLineItemId' => oli.Id,
        'pricebookEntryId' => oli.PricebookEntryId,
        'projectCapacity' => 5,
        'unitPrice' => -10 // 🔥 invalid
    };

    String jsonInput = JSON.serialize(new List<Object>{ row });

    Test.startTest();
    try {
        QuoteProductSelectorController.saveQuoteLineItems(qt.Id, jsonInput);
       
    } catch (AuraHandledException e) {
     
    }
    Test.stopTest();
}
}