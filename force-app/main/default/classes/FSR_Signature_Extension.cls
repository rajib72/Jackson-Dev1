public class FSR_Signature_Extension {
    public Id customerSigId { get; set; }
    public Id engineerSigId { get; set; }

    public FSR_Signature_Extension(ApexPages.StandardController stdController) {
        Id recordId = stdController.getId();
        
        if (recordId != null) {
            List<ContentDocumentLink> links = [SELECT ContentDocumentId 
                                               FROM ContentDocumentLink 
                                               WHERE LinkedEntityId = :recordId];
            
            Set<Id> cdIds = new Set<Id>();
            for(ContentDocumentLink cdl : links) {
                cdIds.add(cdl.ContentDocumentId);
            }

            if (!cdIds.isEmpty()) {
                // We just need the ID and Title now. No heavy file data!
                List<ContentVersion> files = [SELECT Id, Title 
                                              FROM ContentVersion 
                                              WHERE ContentDocumentId IN :cdIds 
                                              AND IsLatest = true];

                for(ContentVersion file : files) {
                    String titleLower = file.Title.toLowerCase();
                    
                    if(titleLower.contains('customer_signature')) {
                        customerSigId = file.Id;
                        system.debug('@@@URI: ' + titleLower + ' -- ' + customerSigId);
                    } else if(titleLower.contains('engineer_signature')) {
                        engineerSigId = file.Id;
                        system.debug('@@@URI: ' + titleLower + ' -- ' + engineerSigId);
                    }
                }
            }
        }
    }
}