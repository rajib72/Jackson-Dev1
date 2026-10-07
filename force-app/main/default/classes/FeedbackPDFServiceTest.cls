@isTest
public class FeedbackPDFServiceTest {

    @testSetup
    static void setupData() {

        // 1. Contact
        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com'
        );
        insert con;

        // 2. Case (SAFE Origin to avoid Flow)
        Case c = new Case(
            Subject = 'PDF Service Test',
            Origin = 'Email', // ✅ FIXED
            ContactId = con.Id,
            SuppliedName = 'John Doe'
        );
        insert c;

        // 3. OLD Feedback File
        ContentVersion cvOld = new ContentVersion(
            Title = 'Feedback_' + c.Id,
            PathOnClient = 'OldFeedback.pdf',
            VersionData = Blob.valueOf('Old Content'),
            IsMajorVersion = true
        );
        insert cvOld;

        Id conDocId = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cvOld.Id
        ].ContentDocumentId;

        insert new ContentDocumentLink(
            LinkedEntityId = c.Id,
            ContentDocumentId = conDocId,
            ShareType = 'V'
        );

        // 4. OTHER FILE (should not delete)
        ContentVersion cvOther = new ContentVersion(
            Title = 'Other_Document',
            PathOnClient = 'Other.pdf',
            VersionData = Blob.valueOf('Keep this')
        );
        insert cvOther;
    }

    @isTest
    static void testGeneratePDF_FullProcess() {

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.setCurrentPage(Page.FeedbackFormPDF);

        Test.startTest();
        FeedbackPDFService.generatePDF(c.Id);
        Test.stopTest();
    }

    @isTest
    static void testGeneratePDF_NoExistingFiles() {

        Case c2 = new Case(
            Subject = 'Clean Case',
            Origin = 'Email', // ✅ FIXED
            SuppliedName = 'Clean User'
        );
        insert c2;

        Test.startTest();
        FeedbackPDFService.generatePDF(c2.Id);
        Test.stopTest();
    }
}