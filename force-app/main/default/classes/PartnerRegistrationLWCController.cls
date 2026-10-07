public without sharing class PartnerRegistrationLWCController {

    @AuraEnabled
    public static Id createRegistrationWithFiles(
        Registration_Details__c regRecord,
        List<String> docFiles,
        List<String> docFileNames,
        String signatureFile,
        String signatureFileName
    ) {

        if(regRecord.Partner__c == null){
            throw new AuraHandledException('Partner Id is required.');
        }
		regRecord.Name = regRecord.Full_Name__c;
        regRecord.Status__c = 'Submitted';
        regRecord.Form_Submitted_At__c = System.now();

        insert regRecord;

        List<ContentVersion> versions = new List<ContentVersion>();

        // 📁 Documents
        if(docFiles != null){
            for(Integer i=0; i<docFiles.size(); i++){
                versions.add(new ContentVersion(
                    Title = docFileNames[i],
                    PathOnClient = docFileNames[i],
                    VersionData = EncodingUtil.base64Decode(docFiles[i]),
                    FirstPublishLocationId = regRecord.Id
                ));
            }
        }

        // ✍ Signature
        if(signatureFile != null){
            versions.add(new ContentVersion(
                Title = signatureFileName,
                PathOnClient = signatureFileName,
                VersionData = EncodingUtil.base64Decode(signatureFile),
                FirstPublishLocationId = regRecord.Id
            ));
        }

        if(!versions.isEmpty()){
            insert versions;
        }

        return regRecord.Id;
    }
}