public class SRTFeedbackFormPDFController {

    public Case caseRecord {get;set;}
    public Feedback_Form__c feedbackRecord {get;set;}

    public SRTFeedbackFormPDFController() {

        Id caseId = ApexPages.currentPage().getParameters().get('id');

        if(caseId != null){

            caseRecord = [
                SELECT Id,
                       CaseNumber,
                       Subject,
                       Description,
                       CreatedDate,
                       ContactId,
                       Contact.Name,
                       Contact.MobilePhone,
                       Contact.Email,
                       AccountId,
                       Account.Name,
                       AssetId,
                       Asset.Name,
                       Asset.SerialNumber,
                       Asset.Product2.Name
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            List<Feedback_Form__c> feedbackList = [
                SELECT Id,
                       Case__c,
                       Service_Completion_Date__c,
                       Overall_Satisfaction_CSAT__c,
                       Would_you_recommend_Jakson_NPS__c,
                       Issue_resolved__c,
                       Engineer_behaviour_professionalism__c,
                       Response_turnaround_experience__c,
                       Comments__c
                FROM Feedback_Form__c
                WHERE Case__c = :caseId
                LIMIT 1
            ];

            if(!feedbackList.isEmpty()){
                feedbackRecord = feedbackList[0];
            }
        }
    }

}