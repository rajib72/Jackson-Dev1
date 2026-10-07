@isTest
public class ReviseQuoteController_Test {

    @testSetup
    static void setupData() {

        // ---------------- ACCOUNT ----------------
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        // ---------------- CONTACT ----------------
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id
        );
        insert con;

        // ---------------- OPPORTUNITY ----------------
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            Business_Segment__c = 'Retail'
        );
        insert opp;

        // ---------------- PRODUCT ----------------
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'P001',
            IsActive = true
        );
        insert prod;

        // ---------------- STANDARD PRICEBOOK ----------------
        Id stdPbId = Test.getStandardPricebookId();

        Pricebook2 stdPb = new Pricebook2(
            Id = stdPbId,
            IsActive = true
        );
        update stdPb;

        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert stdPbe;

        // ---------------- CUSTOM PRICEBOOK ----------------
        Pricebook2 pb = new Pricebook2(
            Name = 'Test Pricebook',
            IsActive = true
        );
        insert pb;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb.Id,
            Product2Id = prod.Id,
            UnitPrice = 120,
            IsActive = true
        );
        insert pbe;

        // ---------------- MAP PRICEBOOK TO OPPORTUNITY ----------------
        opp.Pricebook2Id = pb.Id;
        update opp;

        // ---------------- OPPORTUNITY PRODUCT ----------------
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 120
        );
        insert oli;

        // ---------------- INCOTERMS ----------------
        IncoTerms__c inc = new IncoTerms__c(
            Name = 'FOB',
            Description__c = 'Test Incoterm'
        );
        insert inc;

        // ---------------- QUOTE ----------------
        Quote qt = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = pb.Id,
            Status = 'Draft',
            ContactId = con.Id,
            Business_Segment__c = 'Retail',
            ExpirationDate = Date.today().addDays(30)
        );
        insert qt;

        // ---------------- QUOTE LINE ITEM ----------------
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = qt.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 120,
            UOM__c = 'KW',
            IncoTerms__c = inc.Id,
            Opportunity_Product__c = oli.Id,
            Product_Capacity__c = 10,
            Module_Type__c = 'NON-DCR (ALMM)',
            Cell_Type__c = 'G12 R',
            Module_Technology__c = 'TOPCON',
            Product_Rating_BIN__c = '610',
            Product_Sub_Type__c = 'Glass to Glass [Topcon]',
            Warranty__c = 'With',
            Cable_Length__c = '600'
        );
        insert qli;
    }

    // ---------------- GET QUOTE DETAILS ----------------
    @isTest
    static void testGetQuoteDetails() {

        Quote qt = [
            SELECT Id
            FROM Quote
            LIMIT 1
        ];

        Test.startTest();
        Quote result = ReviseQuoteController.getQuoteDetails(qt.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Quote details should be returned.');
        System.assertEquals(qt.Id, result.Id, 'Returned Quote Id should match.');
    }

    // ---------------- GET ACCOUNT CONTACTS ----------------
    @isTest
    static void testGetAccountContacts() {

        Quote qt = [
            SELECT Id
            FROM Quote
            LIMIT 1
        ];

        Test.startTest();
        List<ReviseQuoteController.ContactOption> contacts =
            ReviseQuoteController.getAccountContacts(qt.Id);
        Test.stopTest();

        System.assertNotEquals(null, contacts, 'Contact options should not be null.');
        System.assertEquals(1, contacts.size(), 'One contact should be returned.');
    }

    // ---------------- GET QUOTE LINE ITEMS ----------------
    @isTest
    static void testGetQuoteLineItems() {

        Quote qt = [
            SELECT Id
            FROM Quote
            LIMIT 1
        ];

        Test.startTest();
        ReviseQuoteController.QuoteLineItemInitResponse response =
            ReviseQuoteController.getQuoteLineItems(qt.Id);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response should not be null.');
        System.assertNotEquals(null, response.lineItems, 'Line items should not be null.');
        System.assertEquals(1, response.lineItems.size(), 'One line item should be returned.');

        System.assertNotEquals(
            null,
            response.lineItems[0].opportunityProductId,
            'Opportunity Product Id should be mapped in wrapper.'
        );
    }

    // ---------------- CLONE QUOTE WITH LINE ITEMS ----------------
    @isTest
    static void testCloneQuote() {

        Quote oldQuote = [
            SELECT Id, OpportunityId, Pricebook2Id, AccountId
            FROM Quote
            LIMIT 1
        ];

        Quote newQuote = new Quote(
            OpportunityId = oldQuote.OpportunityId,
            Pricebook2Id = oldQuote.Pricebook2Id,
            Status = 'Draft',
            Business_Segment__c = 'Retail',
            ExpirationDate = Date.today().addDays(60)
        );

        List<QuoteLineItem> items = [
            SELECT Id,
                   PricebookEntryId,
                   UnitPrice,
                   UOM__c,
                   IncoTerms__c,
                   Opportunity_Product__c,
                   Product_Capacity__c,
                   Module_Type__c,
                   Cell_Type__c,
                   Module_Technology__c,
                   Product_Rating_BIN__c,
                   Product_Sub_Type__c,
                   Warranty__c,
                   Cable_Length__c
            FROM QuoteLineItem
            WHERE QuoteId = :oldQuote.Id
        ];

        Map<String, String> billing = new Map<String, String>{
            'street' => 'Street 1',
            'city' => 'Kolkata',
            'state' => 'WB',
            'postalCode' => '700001',
            'country' => 'India'
        };

        Map<String, String> shipping = new Map<String, String>{
            'street' => 'Street 2',
            'city' => 'Kolkata',
            'state' => 'WB',
            'postalCode' => '700002',
            'country' => 'India'
        };

        Test.startTest();
        Id newQuoteId = ReviseQuoteController.cloneQuoteAndItems(
            newQuote,
            items,
            oldQuote.Id,
            billing,
            shipping
        );
        Test.stopTest();

        System.assertNotEquals(null, newQuoteId, 'New revised Quote should be created.');

        Quote revisedQuote = [
            SELECT Id, Status, Parent_Quote__c, Version__c, OpportunityId,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
            FROM Quote
            WHERE Id = :newQuoteId
            LIMIT 1
        ];

        System.assertEquals('Draft', revisedQuote.Status, 'New Quote status should be Draft.');
        System.assertEquals(oldQuote.Id, revisedQuote.Parent_Quote__c, 'Parent Quote should be old Quote.');
        System.assertEquals(oldQuote.OpportunityId, revisedQuote.OpportunityId, 'Opportunity should be copied.');
        System.assertEquals('Street 1', revisedQuote.BillingStreet, 'Billing address should be updated.');
        System.assertEquals('Street 2', revisedQuote.ShippingStreet, 'Shipping address should be updated.');

        Quote oldQuoteAfterUpdate = [
            SELECT Id, Status
            FROM Quote
            WHERE Id = :oldQuote.Id
            LIMIT 1
        ];

        System.assertEquals('Denied', oldQuoteAfterUpdate.Status, 'Old Quote should be marked Denied.');

        List<QuoteLineItem> revisedItems = [
            SELECT Id,
                   QuoteId,
                   PricebookEntryId,
                   UnitPrice,
                   UOM__c,
                   IncoTerms__c,
                   Opportunity_Product__c,
                   Product_Capacity__c,
                   Module_Type__c,
                   Cell_Type__c,
                   Module_Technology__c,
                   Product_Rating_BIN__c,
                   Product_Sub_Type__c,
                   Warranty__c,
                   Cable_Length__c
            FROM QuoteLineItem
            WHERE QuoteId = :newQuoteId
        ];

        System.assertEquals(1, revisedItems.size(), 'One revised Quote Line Item should be created.');

        System.assertNotEquals(
            null,
            revisedItems[0].Opportunity_Product__c,
            'Opportunity Product should be copied to revised Quote Line Item.'
        );
    }

    // ---------------- CLONE QUOTE WITHOUT ADDRESS MAP ----------------
    @isTest
    static void testCloneQuoteWithoutAddressMap() {

        Quote oldQuote = [
            SELECT Id, OpportunityId, Pricebook2Id
            FROM Quote
            LIMIT 1
        ];

        Quote newQuote = new Quote(
            OpportunityId = oldQuote.OpportunityId,
            Pricebook2Id = oldQuote.Pricebook2Id,
            Status = 'Draft',
            Business_Segment__c = 'Retail',
            ExpirationDate = Date.today().addDays(60)
        );

        List<QuoteLineItem> items = [
            SELECT Id,
                   PricebookEntryId,
                   UnitPrice,
                   UOM__c,
                   IncoTerms__c,
                   Opportunity_Product__c,
                   Product_Capacity__c,
                   Module_Type__c,
                   Cell_Type__c,
                   Module_Technology__c,
                   Product_Rating_BIN__c,
                   Product_Sub_Type__c,
                   Warranty__c,
                   Cable_Length__c
            FROM QuoteLineItem
            WHERE QuoteId = :oldQuote.Id
        ];

        Test.startTest();
        Id newQuoteId = ReviseQuoteController.cloneQuoteAndItems(
            newQuote,
            items,
            oldQuote.Id,
            null,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, newQuoteId, 'New Quote should be created without address map.');
    }

    // ---------------- GET QUOTE LINE ITEMS NULL ERROR CASE ----------------
    @isTest
    static void testGetQuoteLineItemsNull() {

        Test.startTest();
        try {
            ReviseQuoteController.getQuoteLineItems(null);
            System.assert(false, 'Exception should be thrown when Quote Id is null.');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('Quote Id is required') ||
                e.getMessage().contains('Script-thrown exception'),
                'Expected Quote Id required exception.'
            );
        }
        Test.stopTest();
    }
}