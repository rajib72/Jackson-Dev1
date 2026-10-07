@isTest
public class FeedbackFormPDFControllerTest {

    @testSetup
    static void setupData() {
        // 1. Create a Contact to satisfy potential flow requirements
        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com'
        );
        insert con;

        // 2. Create a Case
        // We populate SuppliedName to bypass the 'LastName' missing error in your Phone Flow
        Case c = new Case(
            Subject = 'Test Case for PDF',
            Status = 'New',
            Origin = 'Email',
            ContactId = con.Id,
            SuppliedName = 'John Doe' 
        );
        insert c;

        // 3. Create a Feedback Form linked to the Case
        Feedback_Form__c f = new Feedback_Form__c(
            Case__c = c.Id,
            Installation_Type__c = 'Commercial',
            Please_Enter_Your_Name__c = 'John Doe',
            Mobile_Number__c = '9876543210',
            State__c = 'Maharashtra'
        );
        insert f;
    }

    @isTest
    static void testControllerWithData() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // Set the Visualforce Page context
        // Ensure 'FeedbackFormPDF' matches your actual .page file name
        PageReference pdfPage = Page.FeedbackFormPDF; 
        Test.setCurrentPage(pdfPage);
        
        // Push the ID into the URL parameters
        ApexPages.currentPage().getParameters().put('id', c.Id);

        // Initialize the controller to run the constructor logic
        FeedbackFormPDFController controller = new FeedbackFormPDFController();
        Test.stopTest();

        // Optional: Verify variables are populated
        System.assertNotEquals(null, controller.caseRec, 'Case should be populated');
        System.assertEquals('Commercial', controller.feedback.Installation_Type__c);
    }

    @isTest
    static void testControllerWithoutFeedback() {
        // Create a Case that does NOT have a Feedback record
        Case c2 = new Case(
            Subject = 'No Feedback', 
            Origin = 'Email', 
            SuppliedName = 'No Feedback User'
        );
        insert c2;

        Test.startTest();
        Test.setCurrentPage(Page.FeedbackFormPDF);
        ApexPages.currentPage().getParameters().put('id', c2.Id);

        // This hits the 'else' branch: feedback = new Feedback_Form__c()
        FeedbackFormPDFController controller = new FeedbackFormPDFController();
        Test.stopTest();

        System.assertNotEquals(null, controller.feedback, 'Feedback should be initialized even if query is empty');
    }

    @isTest
    static void testControllerWithInvalidId() {
        Test.startTest();
        Test.setCurrentPage(Page.FeedbackFormPDF);
        
        // Pass a dummy ID to cover caseList.isEmpty() logic
        ApexPages.currentPage().getParameters().put('id', '500000000000000AAA');

        FeedbackFormPDFController controller = new FeedbackFormPDFController();
        Test.stopTest();
        
        System.assertEquals(null, controller.caseRec, 'Case record should be null for invalid ID');
    }
}