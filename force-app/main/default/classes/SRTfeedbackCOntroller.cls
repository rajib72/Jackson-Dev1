public without sharing class SRTfeedbackCOntroller {

    //=========================================
    // Save Result Wrapper
    //=========================================
    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id recordId;
    }

    //=========================================
    // Case Wrapper
    //=========================================
    public class CaseWrapper {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public String contactPhone;
        @AuraEnabled public String contactEmail;
        @AuraEnabled public Boolean feedbackReceived;
       @AuraEnabled public String srtStatus;
    }

    //=========================================
    // Get Case Details
    //=========================================
    @AuraEnabled(cacheable=true)
    public static CaseWrapper getCaseDetails(Id caseId) {

        CaseWrapper cw = new CaseWrapper();

        if(caseId == null){
            return cw;
        }

        List<Case> caseList = [
            SELECT Id,
                   SRT_Case_No__c,
                   ContactId,
                   Contact.Name,
                   Contact.Phone,
                   Contact.Email,
                   Feedback_Received__c,
            SRT_Case_Status__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if(!caseList.isEmpty()){

            Case c = caseList[0];

            cw.caseId = c.Id;
            cw.caseNumber = c.SRT_Case_No__c;
            cw.contactId = c.ContactId;
            cw.contactName = c.Contact != null ? c.Contact.Name : '';
            cw.contactPhone = c.Contact != null ? c.Contact.Phone : '';
            cw.contactEmail = c.Contact != null ? c.Contact.Email : '';
            cw.feedbackReceived = c.Feedback_Received__c;
            cw.srtStatus = c.SRT_Case_Status__c;
        }

        return cw;
    }

    //=========================================
    // Save Feedback
    //=========================================
    @AuraEnabled
    public static SaveResult saveFeedback(

        Id caseId,
        Id contactId,
        String contactName,
        String contactPhone,

        Date serviceCompletionDate,

        String overallSatisfaction,
        String recommendJakson,
        String issueResolved,
        String engineerBehaviour,
        String responseExperience,

        String comments

    ){

        SaveResult result = new SaveResult();

        try{

            if(caseId == null){
                result.success = false;
                result.message = 'Case Id is required.';
                return result;
            }

            CaseWrapper cw = getCaseDetails(caseId);

            if(cw.caseId == null){
                result.success = false;
                result.message = 'Case not found.';
                return result;
            }

            if(cw.feedbackReceived){
                result.success = false;
                result.message = 'Feedback has already been submitted.';
                return result;
            }
            
            //-----------------------------------------
            // Update Contact Phone AND NAME (if changed)
            //-----------------------------------------

            if (contactId != null) {

    Contact con = new Contact(
        Id = contactId,
        Phone = contactPhone
    );

    if (String.isNotBlank(contactName)) {

        String fullName = contactName.trim();
        Integer lastSpaceIndex = fullName.lastIndexOf(' ');

        if (lastSpaceIndex > 0) {
            con.FirstName =
                fullName.substring(0, lastSpaceIndex).trim();

            con.LastName =
                fullName.substring(lastSpaceIndex + 1).trim();
        } else {
            con.FirstName = null;
            con.LastName = fullName;
        }
    }

    update con;
}

            //-----------------------------------------
            // Create Feedback Record
            //-----------------------------------------

            Feedback_Form__c feedback = new Feedback_Form__c();

            feedback.Case__c = caseId;

            feedback.Service_Completion_Date__c = serviceCompletionDate;

            feedback.Overall_Satisfaction_CSAT__c = overallSatisfaction;

            feedback.Would_you_recommend_Jakson_NPS__c = recommendJakson;

            feedback.Issue_resolved__c = issueResolved;

            feedback.Engineer_behaviour_professionalism__c = engineerBehaviour;

            feedback.Response_turnaround_experience__c = responseExperience;

            feedback.Comments__c = comments;

            insert feedback;

            //-----------------------------------------
            // Update Case
            //-----------------------------------------

            update new Case(

                Id = caseId,
                Feedback_Received__c = true,
                SRT_Case_Status__c = 'Feedback Completed'

            );
            result.success = true;
            result.recordId = feedback.Id;
            result.message = 'Feedback submitted successfully.';

            //-----------------------------------------
            // Send Email
            //-----------------------------------------

            // if(String.isNotBlank(cw.contactEmail)){

            //     Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

            //     email.setToAddresses(new List<String>{cw.contactEmail});

            //     email.setSubject('Thank You For Your Feedback');

            //     email.setPlainTextBody(

            //         'Dear ' + cw.contactName +

            //         '\n\nThank you for sharing your valuable feedback.' +

            //         '\n\nService Request Number : ' + cw.caseNumber +

            //         '\n\nWe appreciate the time you took to rate our service.' +

            //         '\n\nJakson SmartCare' +

            //         '\n1800-103-2600'

            //     );

            //     Messaging.sendEmail(
            //         new Messaging.SingleEmailMessage[]{email}
            //     );
            // }

            //-----------------------------------------
            // Success
            //-----------------------------------------

            result.success = true;
            result.recordId = feedback.Id;
            result.message = 'Feedback submitted successfully.';

        }
        catch(Exception e){

            result.success = false;
            result.message =
                e.getMessage() +
                ' (Line ' + e.getLineNumber() + ')';

        }

        return result;
    }

}