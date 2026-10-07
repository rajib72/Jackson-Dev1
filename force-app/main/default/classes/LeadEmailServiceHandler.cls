global class LeadEmailServiceHandler implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        try {
            
            String senderName = !String.isBlank(email.fromName) ? email.fromName :
            (!String.isBlank(email.fromAddress) ? email.fromAddress : 'Email Lead');
                String senderEmail = email.fromAddress;
            String emailBody = String.isBlank(email.plainTextBody) ? email.htmlBody : email.plainTextBody;
            String emailSubject = email.subject;
            
            
            
            // Create a new Lead record
            Lead newLead = new Lead();
            newLead.LastName = senderName;                      
            newLead.Email = senderEmail;
            newLead.Company = senderName;
            newLead.LeadSource = 'Email';
            newLead.Email_Subject__c = emailSubject;
            newLead.Email_Body__c = emailBody;
            newLead.Email_Body_Rich_Text__c = emailBody;
            
            insert newLead;
            System.debug('✅ Lead Created with ID: ' + newLead.Id);
            
            //File attachment
            /* -------------------------
               Save Binary Attachments (Files)
            --------------------------*/
            List<ContentVersion> contentVersions = new List<ContentVersion>();

            if (email.binaryAttachments != null && !email.binaryAttachments.isEmpty()) {
                for (Messaging.InboundEmail.BinaryAttachment bAttachment : email.binaryAttachments) {
                    ContentVersion cv = new ContentVersion();
                    cv.Title = bAttachment.fileName;
                    cv.PathOnClient = '/' + bAttachment.fileName;
                    cv.VersionData = bAttachment.body;
                    cv.FirstPublishLocationId = newLead.Id; // 👈 Appears in Files
                    contentVersions.add(cv);
                }
            }

            /* -------------------------
               Save Text Attachments (Files)
            --------------------------*/
            if (email.textAttachments != null && !email.textAttachments.isEmpty()) {
                for (Messaging.InboundEmail.TextAttachment tAttachment : email.textAttachments) {
                    ContentVersion cv = new ContentVersion();
                    cv.Title = tAttachment.fileName;
                    cv.PathOnClient = '/' + tAttachment.fileName;
                    cv.VersionData = Blob.valueOf(tAttachment.body);
                    cv.FirstPublishLocationId = newLead.Id;
                    contentVersions.add(cv);
                }
            }

            if (!contentVersions.isEmpty()) {
                insert contentVersions;
                System.debug('✅ Files saved to Lead Files related list.');
            }

            result.success = true;

        } catch (Exception e) {
            result.success = false;
            result.message = 'Error: ' + e.getMessage();
            System.debug('❌ Exception: ' + e.getMessage());
        }

        return result;
    }
    
    global class CustomException extends Exception {}
}