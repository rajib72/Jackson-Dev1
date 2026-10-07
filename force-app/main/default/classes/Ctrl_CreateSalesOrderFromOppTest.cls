@IsTest
private class Ctrl_CreateSalesOrderFromOppTest {

    @TestSetup
    static void setupData() {
        Id pricebookId = Test.getStandardPricebookId();
        Pricebook2 standardPricebook = new Pricebook2(
            Id = pricebookId,
            IsActive = true
        );
        update standardPricebook;
        
        // Create Standard Product
        Product2 prod = new Product2(
            Name = 'Standard Product',
            ProductCode = 'STD001',
            IsActive = true
        );
        insert prod;

        // Create Pricebook Entry for Standard Pricebook
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
    }

    private static PricebookEntry getStandardPbe() {
        return [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :Test.getStandardPricebookId() AND IsActive = true LIMIT 1];
    }

    private static Account createAccount(String accName) {
        Account acc = new Account(
            Name = accName,
            Customer_Account_Group__c = 'ZDOM',
            Distribution_Channel__c = '10',
            Division__c = '01',
            SAP_Account_Number__c = 'SAP' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            BillingStreet = 'Billing Street',
            BillingCity = 'Kolkata',
            BillingState = 'WB',
            BillingPostalCode = '700001',
            BillingCountry = 'India',
            ShippingStreet = 'Shipping Street',
            ShippingCity = 'Kolkata',
            ShippingState = 'WB',
            ShippingPostalCode = '700001',
            ShippingCountry = 'India'
        );
        insert acc;
        return acc;
    }

    private static Contact createContact(Id accId) {
        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = accId
        );
        insert con;
        return con;
    }

    private static Material_Master__c createMaterial() {
        String uniqueVal = String.valueOf(System.currentTimeMillis());
        Material_Master__c mat = new Material_Master__c(
            Name = 'MAT' + uniqueVal,
            Unique_Key__c = 'KEY' + uniqueVal,
            Plant__c = 'PL01',
            Distribution_Channel__c = '10',
            Division__c = '01',
            Sales_Org__c = '1000',
            Material_Description__c = 'Test Material'
        );
        insert mat;
        return mat;
    }

    private static Opportunity createOpportunity(Id accId, Id conId) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            AccountId = accId,
            Contact__c = conId,
            Business_Segment__c = 'Institutional',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert opp;
        return opp;
    }

    private static OpportunityLineItem createOppLine(Id oppId, Id pbeId, Id materialId) {
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = oppId,
            PricebookEntryId = pbeId,
            Quantity = 5,
            UnitPrice = 100,
            ServiceDate = Date.today(),
            Material_Master__c = materialId,
            Product_Warranty__c = 12,
            Performance_Warranty__c = 24
        );
        insert oli;
        return oli;
    }

    private static Quote createQuote(Id oppId, Id conId, Id billToId, Id shipToId) {
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = oppId,
            ContactId = conId,
            Status = 'Accepted',
            Pricebook2Id = Test.getStandardPricebookId(),
            Bill_To_Party__c = billToId,
            Ship_To_Party__c = shipToId,
            Business_Segment__c = 'Institutional'
        );
        insert q;
        return q;
    }

    private static QuoteLineItem createQuoteLine(Id quoteId, Id pbeId, Id materialId) {
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quoteId,
            PricebookEntryId = pbeId,
            Quantity = 10,
            UnitPrice = 100,
            ServiceDate = Date.today(),
            Material_Master__c = materialId,
            Product_Warranty__c = 12,
            Performance_Warranty__c = 24,
            Material_Sales_Text__c = 'Test Material',
            Quantity_Ordered__c = 0
        );
        insert qli;
        return qli;
    }

    private static Map<String, Object> getFormData() {
        Map<String, Object> formData = new Map<String, Object>();
        formData.put('bgRequired', 'Y');
        formData.put('tpc', 'Y');
        formData.put('poNo', 'PO123');
        formData.put('poDate', String.valueOf(Date.today()));
        formData.put('ldClause', 'Y');
        formData.put('freightTerms', 'FOB');
        formData.put('scopeOfOA', 'Scope');
        formData.put('insuranceTerms', 'Insurance');
        return formData;
    }

    // ========== getInitialDetails TESTS ==========
    
    @IsTest
    static void testGetInitialDetails() {
        Account acc = createAccount('Test Account');
        Contact con = createContact(acc.Id);
        Material_Master__c mat = createMaterial();
        PricebookEntry pbe = getStandardPbe();
        Opportunity opp = createOpportunity(acc.Id, con.Id);
        createOppLine(opp.Id, pbe.Id, mat.Id);

        Test.startTest();
        Ctrl_CreateSalesOrderFromOpp.getInitialDetails(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetInitialDetails_WithQuote() {
        Account acc = createAccount('Test Account 2');
        Contact con = createContact(acc.Id);
        Material_Master__c mat = createMaterial();
        PricebookEntry pbe = getStandardPbe();
        Opportunity opp = createOpportunity(acc.Id, con.Id);
        createOppLine(opp.Id, pbe.Id, mat.Id);
        
        Quote quote = createQuote(opp.Id, con.Id, acc.Id, acc.Id);
        createQuoteLine(quote.Id, pbe.Id, mat.Id);

        Test.startTest();
        Ctrl_CreateSalesOrderFromOpp.getInitialDetails(opp.Id);
        Test.stopTest();
    }

    // ========== getQuoteDetails TESTS ==========
    
    @IsTest
    static void testGetQuoteDetails() {
        Account billTo = createAccount('Bill To Account');
        Account shipTo = createAccount('Ship To Account');
        Contact con = createContact(billTo.Id);
        Material_Master__c mat = createMaterial();
        PricebookEntry pbe = getStandardPbe();
        Opportunity opp = createOpportunity(billTo.Id, con.Id);
        Quote q = createQuote(opp.Id, con.Id, billTo.Id, shipTo.Id);
        createQuoteLine(q.Id, pbe.Id, mat.Id);

        Test.startTest();
        Ctrl_CreateSalesOrderFromOpp.getQuoteDetails(q.Id);
        Test.stopTest();
    }

    // ========== createOrderFromQuote TESTS ==========
    
    @IsTest
static void testCreateOrderFromQuote() {

    Account billTo = createAccount('ACC3-Bill');
    Account shipTo = createAccount('ACC3-Ship');

    Contact con = createContact(billTo.Id);

    Material_Master__c mat = createMaterial();

    PricebookEntry pbe = getStandardPbe();

    Opportunity opp = createOpportunity(
        billTo.Id,
        con.Id
    );

    Quote q = createQuote(
        opp.Id,
        con.Id,
        billTo.Id,
        shipTo.Id
    );

    QuoteLineItem qli = createQuoteLine(
        q.Id,
        pbe.Id,
        mat.Id
    );

    Map<Id, Decimal> qtyMap = new Map<Id, Decimal>();
    qtyMap.put(qli.Id, 2);

    Test.startTest();

    try {

        String orderId = Ctrl_CreateSalesOrderFromOpp.createOrderFromQuote(
            q.Id,
            getFormData(),
            qtyMap
        );

        System.debug('QUOTE ORDER CREATED => ' + orderId);

    } catch (Exception e) {

        System.debug('QUOTE ERROR ===== ' + e.getMessage());
        throw e;
    }

    Test.stopTest();
}
    @IsTest
    static void testCreateOrderFromQuote_MultiItems() {
        Account billTo = createAccount('Bill To Multi');
        Account shipTo = createAccount('Ship To Multi');
        Contact con = createContact(billTo.Id);
        Material_Master__c mat1 = createMaterial();
        Material_Master__c mat2 = createMaterial();
        PricebookEntry pbe = getStandardPbe();
        Opportunity opp = createOpportunity(billTo.Id, con.Id);
        Quote q = createQuote(opp.Id, con.Id, billTo.Id, shipTo.Id);
        
        QuoteLineItem qli1 = createQuoteLine(q.Id, pbe.Id, mat1.Id);
        
        QuoteLineItem qli2 = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 200,
            ServiceDate = Date.today(),
            Material_Master__c = mat2.Id,
            Product_Warranty__c = 24,
            Performance_Warranty__c = 36,
            Material_Sales_Text__c = 'Test Material 2',
            Quantity_Ordered__c = 0
        );
        insert qli2;

        Map<Id, Decimal> qtyMap = new Map<Id, Decimal>();
        qtyMap.put(qli1.Id, 2);
        qtyMap.put(qli2.Id, 3);

        Test.startTest();
        Ctrl_CreateSalesOrderFromOpp.createOrderFromQuote(q.Id, getFormData(), qtyMap);
        Test.stopTest();
    }

    // ========== createOrderFromOpp TESTS ==========
    
    @IsTest
static void testCreateOrderFromOpp() {

    Account acc = createAccount('ACC4');

    Contact con = createContact(acc.Id);

    Material_Master__c mat = createMaterial();

    PricebookEntry pbe = getStandardPbe();

    Opportunity opp = createOpportunity(
        acc.Id,
        con.Id
    );

    OpportunityLineItem oli = createOppLine(
        opp.Id,
        pbe.Id,
        mat.Id
    );

    Map<Id, Decimal> qtyMap = new Map<Id, Decimal>();
    qtyMap.put(oli.Id, 3);

    Test.startTest();

    try {

        String orderId = Ctrl_CreateSalesOrderFromOpp.createOrderFromOpp(
            opp.Id,
            getFormData(),
            qtyMap
        );

        System.debug('OPP ORDER CREATED => ' + orderId);

    } catch (Exception e) {

        System.debug('OPP ERROR ===== ' + e.getMessage());
        throw e;
    }

    Test.stopTest();
}

    @IsTest
    static void testCreateOrderFromOpp_MultiItems() {
        Account acc = createAccount('Opportunity Account Multi');
        Contact con = createContact(acc.Id);
        Material_Master__c mat1 = createMaterial();
        Material_Master__c mat2 = createMaterial();
        PricebookEntry pbe = getStandardPbe();
        Opportunity opp = createOpportunity(acc.Id, con.Id);
        
        OpportunityLineItem oli1 = createOppLine(opp.Id, pbe.Id, mat1.Id);
        
        OpportunityLineItem oli2 = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 8,
            UnitPrice = 150,
            ServiceDate = Date.today(),
            Material_Master__c = mat2.Id,
            Product_Warranty__c = 24,
            Performance_Warranty__c = 36
        );
        insert oli2;

        Map<Id, Decimal> qtyMap = new Map<Id, Decimal>();
        qtyMap.put(oli1.Id, 2);
        qtyMap.put(oli2.Id, 4);

        Test.startTest();
        Ctrl_CreateSalesOrderFromOpp.createOrderFromOpp(opp.Id, getFormData(), qtyMap);
        Test.stopTest();
    }

    @IsTest
    static void testCreateOrderFromOpp_NullFormData() {
        Account acc = createAccount('Null Form Account');
        Contact con = createContact(acc.Id);
        Material_Master__c mat = createMaterial();
        PricebookEntry pbe = getStandardPbe();
        Opportunity opp = createOpportunity(acc.Id, con.Id);
        OpportunityLineItem oli = createOppLine(opp.Id, pbe.Id, mat.Id);

        Map<String, Object> nullFormData = new Map<String, Object>();
        nullFormData.put('bgRequired', null);
        nullFormData.put('tpc', null);
        nullFormData.put('poNo', null);
        nullFormData.put('poDate', null);
        nullFormData.put('ldClause', null);
        nullFormData.put('freightTerms', null);
        nullFormData.put('scopeOfOA', null);
        nullFormData.put('insuranceTerms', null);

        Map<Id, Decimal> qtyMap = new Map<Id, Decimal>();
        qtyMap.put(oli.Id, 2);

        Test.startTest();
        try{
            Ctrl_CreateSalesOrderFromOpp.createOrderFromOpp(opp.Id, nullFormData, qtyMap);
        } catch(Exception e) {
            
        }
        
        Test.stopTest();
    }

    // ========== Exception Tests ==========
    
    @IsTest
    static void testGetInitialDetails_Exception() {
        Test.startTest();
        try {
            Ctrl_CreateSalesOrderFromOpp.getInitialDetails('006000000000000AAA');
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetQuoteDetails_Exception() {
        Test.startTest();
        try {
            Ctrl_CreateSalesOrderFromOpp.getQuoteDetails('0Q0000000000000AAA');
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateOrderFromQuote_Exception() {
        Test.startTest();
        try {
            Ctrl_CreateSalesOrderFromOpp.createOrderFromQuote('0Q0000000000000AAA', getFormData(), new Map<Id, Decimal>());
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateOrderFromOpp_Exception() {
        Test.startTest();
        try {
            Ctrl_CreateSalesOrderFromOpp.createOrderFromOpp('006000000000000AAA', getFormData(), new Map<Id, Decimal>());
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateOrderFromQuote_EmptyItems() {
        Account billTo = createAccount('Empty Bill');
        Account shipTo = createAccount('Empty Ship');
        Contact con = createContact(billTo.Id);
        Opportunity opp = createOpportunity(billTo.Id, con.Id);
        Quote q = createQuote(opp.Id, con.Id, billTo.Id, shipTo.Id);

        Test.startTest();
        try {
            Ctrl_CreateSalesOrderFromOpp.createOrderFromQuote(q.Id, getFormData(), new Map<Id, Decimal>());
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateOrderFromOpp_EmptyItems() {
        Account acc = createAccount('Empty Opp');
        Contact con = createContact(acc.Id);
        Opportunity opp = createOpportunity(acc.Id, con.Id);

        Test.startTest();
        try {
            Ctrl_CreateSalesOrderFromOpp.createOrderFromOpp(opp.Id, getFormData(), new Map<Id, Decimal>());
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }
}