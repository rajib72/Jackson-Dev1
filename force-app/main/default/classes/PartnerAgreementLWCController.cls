public without sharing class PartnerAgreementLWCController {
    
    
	@AuraEnabled(cacheable=true)
public static List<String> getAgreementTypeValues() {

    List<String> values = new List<String>();

    for (Schema.PicklistEntry entry :
        Agreement_Details__c.Agreement_Type__c.getDescribe().getPicklistValues()) {

        if (entry.isActive()) {
            values.add(entry.getValue());
        }
    }

    return values;
}
    @AuraEnabled
    public static Id createAgreementWithFiles(
        Agreement_Details__c agrRecord,
        List<String> docFiles,
        List<String> docFileNames,
        String signatureFile,
        String signatureFileName
    ) {

        // Validate partner
        if (agrRecord.Partner__c == null) {
            throw new AuraHandledException('Partner Id is required.');
        }

        // Ensure the Name is set (Agreement Details Name)
        if (String.isBlank(agrRecord.Name)) {
            agrRecord.Name = 'Agreement - ' + String.valueOf(System.now());
        }

        // Set default status/signed
        agrRecord.Agreement_Status__c = 'Signed';
        agrRecord.Agreement_Signed__c = true;
        agrRecord.Approved_At__c = System.now();

        insert agrRecord;

        List<ContentVersion> versions = new List<ContentVersion>();

        // Documents (optional)
        if (docFiles != null && docFiles.size() > 0) {
            for (Integer i = 0; i < docFiles.size(); i++) {
                versions.add(new ContentVersion(
                    Title = docFileNames.size() > i ? docFileNames[i] : ('doc-' + i),
                    PathOnClient = docFileNames.size() > i ? docFileNames[i] : ('doc-' + i),
                    VersionData = EncodingUtil.base64Decode(docFiles[i]),
                    FirstPublishLocationId = agrRecord.Id
                ));
            }
        }

        // Signature (required by UI)
        if (signatureFile != null) {
            versions.add(new ContentVersion(
                Title = signatureFileName != null ? signatureFileName : 'signature',
                PathOnClient = signatureFileName != null ? signatureFileName : 'signature',
                VersionData = EncodingUtil.base64Decode(signatureFile),
                FirstPublishLocationId = agrRecord.Id
            ));
        }

        if (!versions.isEmpty()) {
            insert versions;
        }

        return agrRecord.Id;
    }
}