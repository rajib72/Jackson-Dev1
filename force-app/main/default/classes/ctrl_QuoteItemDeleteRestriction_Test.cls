@IsTest
public class ctrl_QuoteItemDeleteRestriction_Test {

    @IsTest
    static void testControllerMessageAndBack() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            Business_Segment__c = 'Institutional',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Quote quoteRec = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId
        );
        insert quoteRec;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quoteRec.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert qli;

        Test.startTest();

        ApexPages.StandardController sc = new ApexPages.StandardController(qli);
        ctrl_QuoteItemDeleteRestriction ctrl =
            new ctrl_QuoteItemDeleteRestriction(sc);

        PageReference pageRef = ctrl.goBack();

        Test.stopTest();

        System.assertNotEquals(null, pageRef);
        System.assert(pageRef.getUrl().contains(quoteRec.Id));
        System.assertEquals(true, pageRef.getRedirect());
    }
}