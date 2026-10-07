@IsTest
private class QuotePdfFileServiceTest {

    @IsTest
    static void testGenerateAndSaveQuotePdf() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            Business_Segment__c = 'Institutional',
            CloseDate = Date.today().addDays(10)
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id
        );
        insert q;

        Test.startTest();
        Id contentVersionId = QuotePdfFileService.generateAndSaveQuotePdf(q.Id);
        Test.stopTest();

        System.assertNotEquals(null, contentVersionId, 'ContentVersion Id should be returned');

        ContentVersion cv = [
            SELECT Id, Title, PathOnClient
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];

        System.assertEquals('Quote_Test Quote', cv.Title);
        System.assertEquals('Quote_Test Quote.pdf', cv.PathOnClient);
    }

    @IsTest
    static void testGenerateAndSaveQuotePdf_NullQuoteId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            QuotePdfFileService.generateAndSaveQuotePdf(null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should have been thrown for null Quote Id');
    }
}