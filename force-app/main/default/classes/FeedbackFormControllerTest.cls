@isTest
public class FeedbackFormControllerTest {

    @testSetup
    static void setupData() {

        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
            BillingPostalCode = '999999'
        );
        insert acc;

        // Create Contact
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Phone = '9999999999',
            AccountId = acc.Id
        );
        insert con;

        // Create Case (minimal fields to avoid flow issues)
        Case c = new Case(
            Subject = 'Test Case',
            Origin = 'Email',
            Status = 'New',
            AccountId = acc.Id,
            ContactId = con.Id,
            SuppliedName = 'Test User'
        );
        insert c;
    }

    // ============================
    // Constructor Test
    // ============================
    @isTest
    static void testConstructor() {

        Case c = [SELECT Id FROM Case LIMIT 1];

        // Set VF page with parameter
        PageReference pageRef = Page.FeedbackFormPDF;
        pageRef.getParameters().put('id', c.Id);
        Test.setCurrentPage(pageRef);

        ApexPages.StandardController sc = new ApexPages.StandardController(c);

        Test.startTest();
        FeedbackFormController controller = new FeedbackFormController(sc);
        Test.stopTest();
    }

    // ============================
    // saveFeedback Test
    // ============================
    @isTest
    static void testSaveFeedback() {

        Case c = [SELECT Id FROM Case LIMIT 1];

        // Set VF page context
        PageReference pageRef = Page.FeedbackFormPDF;
        pageRef.getParameters().put('id', c.Id);
        Test.setCurrentPage(pageRef);

        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        FeedbackFormController controller = new FeedbackFormController(sc);

        // Set values (simulate UI input)
        controller.engineerHelp = 'Yes';
        controller.speedRating = 'Good';
        controller.enhanceProduct = 'Improve UI';
        controller.recommendRating = '5';

        Test.startTest();
        controller.saveFeedback();
        Test.stopTest();
    }

    // ============================
    // saveFeedback without Case
    // ============================
    @isTest
    static void testSaveFeedback_NoCase() {

        // No caseId passed
        PageReference pageRef = Page.FeedbackFormPDF;
        Test.setCurrentPage(pageRef);

        ApexPages.StandardController sc = new ApexPages.StandardController(new Case());
        FeedbackFormController controller = new FeedbackFormController(sc);

        controller.engineerHelp = 'No';
        controller.speedRating = 'Average';
        controller.enhanceProduct = 'None';
        controller.recommendRating = '3';

        Test.startTest();
        controller.saveFeedback();
        Test.stopTest();
    }
}