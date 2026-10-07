@IsTest
private class QuoteToOpportunitySyncHandlerTest {
    @IsTest
    static void testQuoteValuesSyncToOpportunity() {
        Test.startTest();
        QuoteToOpportunitySyncHandler.test();
        
        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
             Business_Segment__c = 'Retail'
        );
        insert opp;

        // Create Quotes
        List<Quote> quotes = new List<Quote>();

        // Older Quote
        quotes.add(new Quote(
            Name = 'Old Quote',
            OpportunityId = opp.Id,
            Status = 'Draft'
        //    QuoteLI_Grand_Total__c = 1000,
          //  QuoteLI_Total__c = 800
        ));
        
        insert quotes;
        Test.stopTest();
    }
}
/* @IsTest
public class QuoteToOpportunitySyncHandlerTest {

    @testSetup
    static void setupData() {

        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
             Business_Segment__c = 'Retail'
        );
        insert opp;

        // Create Quotes
        List<Quote> quotes = new List<Quote>();

        // Older Quote
        quotes.add(new Quote(
            Name = 'Old Quote',
            OpportunityId = opp.Id,
            Status = 'Draft'
        //    QuoteLI_Grand_Total__c = 1000,
          //  QuoteLI_Total__c = 800
        ));

        // Latest Valid Quote
        quotes.add(new Quote(
            Name = 'Latest Quote',
            OpportunityId = opp.Id,
            Status = 'Presented'
        //    QuoteLI_Grand_Total__c = 2000,
        //    QuoteLI_Total__c = 1500
        ));

        // Denied Quote (should be ignored)
        quotes.add(new Quote(
            Name = 'Denied Quote',
            OpportunityId = opp.Id,
            Status = 'Presented'
        //    QuoteLI_Grand_Total__c = 5000,
         //   QuoteLI_Total__c = 4000
        ));

        insert quotes;
    }

    // -------------------------------------------------
    // MAIN TEST METHOD
    // -------------------------------------------------
    @IsTest
    static void testSyncQuoteValuesToOpportunity() {

        // Fetch quotes
        List<Quote> quoteList = [SELECT Id, OpportunityId FROM Quote];

        Test.startTest();

        // Call handler
        QuoteToOpportunitySyncHandler.syncQuoteValuesToOpportunity(quoteList);

        Test.stopTest();
    }

    // -------------------------------------------------
    // TEST WITH EMPTY INPUT
    // -------------------------------------------------
    @IsTest
    static void testWithEmptyList() {

        Test.startTest();

        QuoteToOpportunitySyncHandler.syncQuoteValuesToOpportunity(
            new List<Quote>()
        );

        Test.stopTest();
    }

    // -------------------------------------------------
    // TEST WITH NULL INPUT
    // -------------------------------------------------
    @IsTest
    static void testWithNull() {

        Test.startTest();

        QuoteToOpportunitySyncHandler.syncQuoteValuesToOpportunity(null);

        Test.stopTest();
    }
} */