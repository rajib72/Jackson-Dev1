@isTest
public class Ctrl_KAMQuotationPdfTest {

    @testSetup
    static void setupData() {

        // ---------------- ACCOUNT ----------------
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // ---------------- OPPORTUNITY ----------------
        Schema.DescribeFieldResult fieldResult =
            Opportunity.Business_Segment__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        String validOppValue = ple.isEmpty() ? null : ple[0].getValue();

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            Business_Segment__c = validOppValue
        );
        insert opp;

        // ---------------- CONTACT ----------------
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@test.com',
            AccountId = acc.Id
        );
        insert con;

        // ---------------- QUOTE (GLOBAL PICKLIST SAFE) ----------------
        Schema.DescribeFieldResult quoteField =
            Quote.Business_Segment__c.getDescribe();
        List<Schema.PicklistEntry> quotePle = quoteField.getPicklistValues();
        String validQuoteValue = quotePle.isEmpty() ? null : quotePle[0].getValue();
		Id stdPbId = Test.getStandardPricebookId(); 
        Quote qt = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            ContactId = con.Id,
            Pricebook2Id = stdPbId, // ✅ CRITICAL FIX
            Payment_Terms__c = '• Advance\n- On Delivery\n* After Installation',
            Limitation_of_Liability__c = '✓ Limited\n- No indirect damages',
            GST__c = '18%',
            Business_Segment__c = validQuoteValue
        );
        insert qt;

        // ---------------- PRODUCT + PRICEBOOK ----------------
     //   Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = stdPbId,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // ---------------- QUOTE LINE ITEM ----------------
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = qt.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100,

            
            Product_Capacity__c = 500,
        //    UOM__c = 'Nos',
           
           

            Product_Rating_BIN__c = '550',
            Module_Technology__c = 'Mono',
       //     Cable_Length__c = '10m',
            Product_Sub_Type__c = 'Type A',
            Module_Type__c = 'Module X'
        );
        insert qli;
    }

    // ✅ Constructor with data
    @isTest
    static void testConstructor_WithData() {

        Quote qt = [SELECT Id FROM Quote LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(qt);

        Test.startTest();
        Ctrl_KAMQuotationPdf ctrl = new Ctrl_KAMQuotationPdf(sc);
        Test.stopTest();
    }

    // ✅ Constructor with null Id
    @isTest
    static void testConstructor_NullId() {

        ApexPages.StandardController sc =
            new ApexPages.StandardController(new Quote());

        Test.startTest();
        Ctrl_KAMQuotationPdf ctrl = new Ctrl_KAMQuotationPdf(sc);
        Test.stopTest();
    }

    // ✅ splitLines coverage
    @isTest
    static void testSplitLines() {

        Quote qt = [SELECT Id FROM Quote LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(qt);
        Ctrl_KAMQuotationPdf ctrl = new Ctrl_KAMQuotationPdf(sc);

        Test.startTest();

        ctrl.splitLines('• Line1\n- Line2\n* Line3\n✓ Line4');
        ctrl.splitLines(null);
        ctrl.splitLines('');

        Test.stopTest();
    }

    // ✅ removeLeadingBullet coverage
    @isTest
    static void testRemoveLeadingBullet() {

        Quote qt = [SELECT Id FROM Quote LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(qt);
        Ctrl_KAMQuotationPdf ctrl = new Ctrl_KAMQuotationPdf(sc);

        Test.startTest();

        ctrl.removeLeadingBullet('• Test');
        ctrl.removeLeadingBullet('- Test');
        ctrl.removeLeadingBullet('* Test');
        ctrl.removeLeadingBullet('✓ Test');
        ctrl.removeLeadingBullet('Normal Text');

        Test.stopTest();
    }
    
    //Convert grand total in words
       @isTest
    static void testGrandTotalAndWords() {
 
        Quote qt = [SELECT Id FROM Quote LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(qt);
        Ctrl_KAMQuotationPdf ctrl = new Ctrl_KAMQuotationPdf(sc);
 
        Test.startTest();
 
        Decimal total = ctrl.getGrandTotal();
        String totalInWords = ctrl.getGrandTotalInWords();
 
        System.assertNotEquals(null, total, 'Grand total should not be null');
        System.assertNotEquals(null, totalInWords, 'Grand total in words should not be null');
        System.assert(totalInWords.contains('Rupees'), 'Words output should mention Rupees');
        System.assert(totalInWords.contains('Only'), 'Words output should end with Only');
 
        Test.stopTest();
    }
}