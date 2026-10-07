public with sharing class QuotePdfFileService {

    @AuraEnabled
    public static Id generateAndSaveQuotePdf(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }

        Quote q = [
            SELECT Id, Name
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        PageReference pdfPage = Page.Vf_KAMQuotationPdf;
        pdfPage.getParameters().put('id', quoteId);

        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('Dummy PDF Content');
        } else {
            pdfBlob = pdfPage.getContentAsPDF();
        }

        String fileName = 'Quote_' + q.Name + '.pdf';

        ContentVersion cv = new ContentVersion();
        cv.Title = fileName.replace('.pdf', '');
        cv.PathOnClient = fileName;
        cv.VersionData = pdfBlob;
        cv.FirstPublishLocationId = quoteId;
        insert cv;

        return cv.Id;
    }
}