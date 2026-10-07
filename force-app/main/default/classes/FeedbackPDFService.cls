public with sharing class FeedbackPDFService {

    @AuraEnabled
    public static void generatePDF(Id caseId) {

        // 🔴 1. Delete OLD Feedback PDFs ONLY
        List<ContentDocumentLink> oldLinks = [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :caseId
        ];

        List<ContentDocument> docsToDelete = new List<ContentDocument>();

        for(ContentDocumentLink link : oldLinks){
            if(link.ContentDocument.Title != null && link.ContentDocument.Title.startsWith('Feedback_')){
                docsToDelete.add(new ContentDocument(Id = link.ContentDocumentId));
            }
        }

        if(!docsToDelete.isEmpty()){
            delete docsToDelete;
        }

        // 👉 2. Call VF page
        PageReference pdfPage = Page.FeedbackFormPDF;
        pdfPage.getParameters().put('id', caseId);

      //  Blob pdfBlob = pdfPage.getContentAsPDF();
        
        
        // Inside FeedbackPDFService.generatePDF
Blob pdfBlob;
if (Test.isRunningTest()) {
    pdfBlob = Blob.valueOf('Test Content');
} else {
    pdfBlob = pdfPage.getContentAsPDF();
}

        // 👉 3. Create File (Latest)
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Feedback_' + caseId; // important for filtering
        cv.PathOnClient = 'Feedback.pdf';
        cv.VersionData = pdfBlob;
        insert cv;

        // 👉 4. Link to Case
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = caseId;
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;
    }
}