@isTest
public class Ctrl_SiteSurveyForm_Test {

    @testSetup
    static void setupData() {

        // Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Contact
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id
        );
        insert con;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
             Business_Segment__c = 'Retail' // ✅ ADD THIS
        );
        insert opp;

        // ✅ ONLY use writeable fields
        Site_Survey__c survey = new Site_Survey__c(
            Customer_Name__c = acc.Id

        );
        insert survey;
    }

    @isTest
    static void testGetSiteSurveyDetails() {

        Site_Survey__c survey = [SELECT Id FROM Site_Survey__c LIMIT 1];

        Test.startTest();
        Ctrl_SiteSurveyForm.getSiteSurveyDetails(survey.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetContactsByAccount() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Ctrl_SiteSurveyForm.getContactsByAccount(acc.Id);
        Ctrl_SiteSurveyForm.getContactsByAccount(null);
        Test.stopTest();
    }

    @isTest
    static void testUploadFile() {

        Site_Survey__c survey = [SELECT Id FROM Site_Survey__c LIMIT 1];

        String fileName = 'TestFile.txt';
        String body = 'Test file content';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(body));

        Test.startTest();
        Ctrl_SiteSurveyForm.uploadFile(fileName, base64Data, survey.Id);
        Test.stopTest();
    }

    @isTest
    static void testMarkSurveyCompleted() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        Ctrl_SiteSurveyForm.markSurveyCompleted(opp.Id);
        Ctrl_SiteSurveyForm.markSurveyCompleted(null);
        Test.stopTest();
    }
}