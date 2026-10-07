public with sharing class FeedbackFormPDFController {

    public Case caseRec { get; set; }
    public Feedback_Form__c feedback { get; set; }

    public FeedbackFormPDFController() {

        Id caseId = ApexPages.currentPage().getParameters().get('id');

        // Case Query (safe)
        List<Case> caseList = [
            SELECT Id, CaseNumber
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (!caseList.isEmpty()) {
            caseRec = caseList[0];
        }

        // Feedback Query (SAFE)
        List<Feedback_Form__c> feedbackList = [
            SELECT Installation_Type__c,
                   Other__c,
                   Please_Enter_Your_Name__c,
                   State__c,
                   Mobile_Number__c,
                   Did_our_Service_Engineer_help_resolve_yo__c,
                   How_would_you_rate_the_speed_of_issue_re__c,
                   How_likely_are_you_to_recommend_us_to_a__c,
                   How_can_we_enhance_our_product_or_servic__c
            FROM Feedback_Form__c
            WHERE Case__c = :caseId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!feedbackList.isEmpty()) {
            feedback = feedbackList[0];
        } else {
            feedback = new Feedback_Form__c(); // prevents null crash
        }
    }
}