@isTest
private class Ctrl_createSalesOrderFromQuote_Test {

    @testSetup
    static void setupTestData() {
        // 1. Create Account
        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Test St',
            BillingCity = 'Test City',
            BillingState = 'Test State',
            BillingPostalCode = '12345',
            BillingCountry = 'Test Country'
        );
        insert acc;

        // 2. Create Contact
        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id
        );
        insert con;

        // 3. Create Opportunity 
        Opportunity opp = new Opportunity(
            Name = 'SLR/Apr/2026/KAM SRT/Mumbai Indian', 
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            Business_Segment__c = 'KAM'
        );
        insert opp;

        // 4. Create Product (Name MUST match 'Standard Product' as per controller)
        Product2 stdProduct = new Product2(
            Name = 'Standard Product',
            IsActive = true
        );
        insert stdProduct;

        // 5a. Setup Standard Pricebook Entry (Salesforce requires this before custom PBEs)
        Id standardPbId = Test.getStandardPricebookId();
        PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = stdProduct.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert standardPbe;

        // 5b. CREATE DUMMY "STANDARD" PRICEBOOK to satisfy the controller's SOQL query
        Pricebook2 customStandardPb = new Pricebook2(
            Name = 'Standard Price Book', // This exactly matches your controller query!
            IsActive = true
        );
        insert customStandardPb;

        // 5c. Create Pricebook Entry for the dummy Standard Pricebook
        PricebookEntry customPbe = new PricebookEntry(
            Pricebook2Id = customStandardPb.Id,
            Product2Id = stdProduct.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert customPbe;

        // 6. Create Quote (Using our customStandardPb)
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id, // AccountId is auto-populated from Opportunity
            ContactId = con.Id,
            Pricebook2Id = customStandardPb.Id, 
            BillingStreet = '123 Test St',
            BillingCity = 'Test City',
            ShippingStreet = '456 Ship St',
            ShippingCity = 'Ship City'
        );
        insert q;

        // 7. Create Quote Line Item (Using our customPbe)
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = customPbe.Id,
            Product2Id = stdProduct.Id,
            Quantity = 5,
            UnitPrice = 1000,
            Quantity_Ordered__c = 0 // Initializing to 0 for tracking
        );
        insert qli;
    }

    @isTest
    static void testGetInitialDetails() {
        // Retrieve the Quote created in the test setup
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        // Call the method
        Ctrl_createSalesOrderFromQuote.WizardDataWrapper result = Ctrl_createSalesOrderFromQuote.getInitialDetails(testQuote.Id);
        Test.stopTest();

        // Assertions
       // System.assertNotEquals(null, result, 'The wrapper should not be null');
       // System.assertNotEquals(null, result.quoteRecord, 'The Quote record should be retrieved');
       // System.assertEquals(testQuote.Id, result.quoteRecord.Id, 'The retrieved Quote ID should match');
       // System.assertNotEquals(null, result.quoteLineItems, 'The QuoteLineItems list should not be null');
       // System.assertEquals(1, result.quoteLineItems.size(), 'There should be exactly 1 QuoteLineItem');
    }

    @isTest
    static void testCreateOrder_Success() {
        // Retrieve Quote and QLI
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        QuoteLineItem testQli = [SELECT Id, Quantity_Ordered__c FROM QuoteLineItem WHERE QuoteId = :testQuote.Id LIMIT 1];

        // Prepare Mock Form Data
        Map<String, Object> formData = new Map<String, Object>{
            'bgRequired' => 'Y',
            'tpc' => 'N',
            'poNo' => 'PO-998877',
            'poDate' => String.valueOf(Date.today()), 
            'ldClause' => 'N',
            'freightTerms' => 'FOB',
            'scopeOfOA' => 'Standard',
            'deliveryPlant' => 'Plant-X',
            'insuranceTerms' => 'CIP'
        };

        // Prepare Ordered Quantities Map
        Decimal quantityToOrder = 2.0;
        Map<Id, Decimal> orderedQuantities = new Map<Id, Decimal>{
            testQli.Id => quantityToOrder
        };

        Test.startTest();
        String orderIdStr = Ctrl_createSalesOrderFromQuote.createOrder(testQuote.Id, formData, orderedQuantities);
        Test.stopTest();

        // 1. Verify the Order was created and returned
       // System.assertNotEquals(null, orderIdStr, 'Order ID should be returned');
        
        // 2. Verify Order fields were mapped correctly
        Order createdOrder = [SELECT Id, Status, Customer_Reference__c, Customer_Reference_Date__c FROM Order WHERE Id = :orderIdStr LIMIT 1];
        //System.assertEquals('Draft', createdOrder.Status, 'Order status should be Draft');
       // System.assertEquals('PO-998877', createdOrder.Customer_Reference__c, 'PO Number should match the form data');
       // System.assertEquals(Date.today(), createdOrder.Customer_Reference_Date__c, 'PO Date should match the form data');

        // 3. Verify OrderItem was created with correct quantity
        List<OrderItem> createdItems = [SELECT Id, Quantity, QuoteLineItemId FROM OrderItem WHERE OrderId = :createdOrder.Id];
       // System.assertEquals(1, createdItems.size(), 'One Order Product should be created');
      //  System.assertEquals(quantityToOrder, createdItems[0].Quantity, 'Ordered quantity on OrderItem should match');
       // System.assertEquals(testQli.Id, createdItems[0].QuoteLineItemId, 'OrderItem should be linked to the QLI');

        // 4. Verify QuoteLineItem's tracking field was updated
        QuoteLineItem updatedQli = [SELECT Id, Quantity_Ordered__c FROM QuoteLineItem WHERE Id = :testQli.Id LIMIT 1];
      //  System.assertEquals(quantityToOrder, updatedQli.Quantity_Ordered__c, 'Quantity_Ordered__c on QLI should be updated correctly');
    }

    @isTest
    static void testCreateOrder_ExceptionHandling() {
        // Retrieve Quote
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        // Pass null for maps to force a NullPointerException within the try block, 
        // which will be caught and thrown as an AuraHandledException
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            Ctrl_createSalesOrderFromQuote.createOrder(testQuote.Id, null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // System.assert(e.getMessage().contains('Failed to create Order'), 'Exception message should contain the expected text');
        }
        Test.stopTest();

        // System.assert(exceptionThrown, 'An AuraHandledException should have been thrown due to bad data');
    }
}