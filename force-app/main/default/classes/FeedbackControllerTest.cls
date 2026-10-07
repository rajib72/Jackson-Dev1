@isTest
public class FeedbackControllerTest {

    @testSetup
    static void setupData() {
        // --------------------------
        // 1. Create a Contact 
        // --------------------------
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe', 
            Email = 'john.doe@test.com',
            MobilePhone = '9876543210'
        );
        insert testContact;

        // --------------------------
        // 2. Create a Case
        // --------------------------
        // FIX: We use Origin = 'Web' and ensure the ContactId is linked.
        // If your Flow still triggers, we must ensure the Case itself 
        // doesn't trigger the "Phone" logic.
        Case testCase = new Case(
            Subject = 'Test Case for Feedback',
            Status = 'New',
            Origin = 'Web', 
            ContactId = testContact.Id,
            Feedback_Received__c = false,
            SuppliedName = 'John Doe', // Sometimes used by Flows to parse LastName
            SuppliedEmail = 'john.doe@test.com'
        );
        insert testCase;
    }

    @isTest
    static void testGetCaseDetails() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        FeedbackController.CaseWrapper cw = FeedbackController.getCaseDetails(testCase.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetCaseNumber() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        String caseNumber = FeedbackController.getCaseNumber(testCase.Id);
        Test.stopTest();
    }

    @isTest
    static void testSaveFeedback() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Feedback_Form__c feedback = new Feedback_Form__c(
            Installation_Type__c = 'Commercial',
            Please_Enter_Your_Name__c = 'Test User',
            Mobile_Number__c = '9876543210',
            Case__c = testCase.Id // Ensure the lookup is set
        );

        Test.startTest();
        FeedbackController.SaveResult res = FeedbackController.saveFeedback(feedback, testCase.Id);
        Test.stopTest();
    }

    @isTest
    static void testSaveFeedback_NullFeedback() {
        Test.startTest();
        FeedbackController.SaveResult res = FeedbackController.saveFeedback(null, null);
        Test.stopTest();
    }

    @isTest
    static void testSaveFeedback_AlreadySubmitted() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        testCase.Feedback_Received__c = true;
        update testCase;

        Feedback_Form__c feedback = new Feedback_Form__c(
            Installation_Type__c = 'Residential',
            Please_Enter_Your_Name__c = 'Test User',
            Mobile_Number__c = '9876543210'
        );

        Test.startTest();
        FeedbackController.SaveResult res = FeedbackController.saveFeedback(feedback, testCase.Id);
        Test.stopTest();
    }

    @isTest
    static void testSaveFeedback_MissingInstallationType() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Feedback_Form__c feedback = new Feedback_Form__c(
            Please_Enter_Your_Name__c = 'Test User',
            Mobile_Number__c = '9876543210'
        );

        Test.startTest();
        FeedbackController.SaveResult res = FeedbackController.saveFeedback(feedback, testCase.Id);
        Test.stopTest();
    }
}