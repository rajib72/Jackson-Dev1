public without sharing class FeedbackController {

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id recordId;
    }

    // Wrapper to fetch Case details
    public class CaseWrapper {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String contactEmail;
        @AuraEnabled public Boolean feedbackReceived;
    }

    /**
     * Fetch Case details
     */
    public static CaseWrapper getCaseDetails(Id caseId){

        CaseWrapper cw = new CaseWrapper();

        List<Case> caseList = [
            SELECT Id, CaseNumber, Contact.Email, Feedback_Received__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if(!caseList.isEmpty()){

            Case c = caseList[0];

            cw.caseId = c.Id;
            cw.caseNumber = c.CaseNumber;
            cw.contactEmail = (c.Contact != null) ? c.Contact.Email : null;
            cw.feedbackReceived = c.Feedback_Received__c;
        }

        return cw;
    }


    @AuraEnabled(cacheable=true)
public static String getCaseNumber(Id caseId) {
    if(caseId == null) return null;

    Case c = [
        SELECT CaseNumber 
        FROM Case 
        WHERE Id = :caseId 
        LIMIT 1
    ];
    return c.CaseNumber;
}

    /**
     * Save Feedback and Send Email
     */
    @AuraEnabled
    public static SaveResult saveFeedback(Feedback_Form__c feedback, Id caseId){

        System.debug(LoggingLevel.ERROR,'Feedback Object Received: ' + JSON.serialize(feedback));

        SaveResult res = new SaveResult();

        try{

            if(feedback == null){
                res.success = false;
                res.message = 'No feedback data received.';
                return res;
            }

            if(String.isBlank(feedback.Installation_Type__c)){
                res.success = false;
                res.message = 'Installation Type is required.';
                return res;
            }

            if(caseId == null){
                res.success = false;
                res.message = 'Case Id is required.';
                return res;
            }

            // Fetch case details
            CaseWrapper cw = getCaseDetails(caseId);

            if(cw.caseId == null){
                res.success = false;
                res.message = 'Case not found.';
                return res;
            }

            // 🚫 Prevent duplicate feedback
            if(cw.feedbackReceived){
                res.success = false;
                res.message = 'Feedback has already been submitted for this case.';
                return res;
            }
            // ✅ IMPORTANT FIX (LINK FEEDBACK TO CASE)
             feedback.Case__c = caseId;

            // Save feedback record
            insert feedback;

            // Update Case to mark feedback received
            Case caseToUpdate = new Case(
                Id = caseId,
                Feedback_Received__c = true
            );

            update caseToUpdate;

            // Send email to Contact
            if(String.isNotBlank(cw.contactEmail)){

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

                mail.setToAddresses(new List<String>{cw.contactEmail});
                mail.setSubject('Thank you for your feedback - Case ' + cw.caseNumber);

                mail.setPlainTextBody(
                    'Dear Customer,' +
                    '\n\nThank you for providing your feedback for Case ' + cw.caseNumber +
                    '. Your feedback helps us improve our service.' +
                    '\n\nRegards,' +
                    '\nCustomer Support Team'
                );

                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
            }

            res.success = true;
            res.recordId = feedback.Id;
            res.message = 'Feedback saved successfully and email sent.';

        }
        catch(Exception e){

            System.debug('❌ Apex Error: ' + e.getMessage());

            res.success = false;
            res.message = e.getMessage() +
                          ' | Line: ' + e.getLineNumber();
        }

        return res;
    }
    

}