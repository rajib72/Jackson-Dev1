public without sharing class FeedbackFormController {
    public Case currentCase { get; set; }
    public Boolean isSuccess { get; set; }
    
    // Custom variables to FORCE the input fields to show up on the page
    public String installationType { get; set; }
    public String state { get; set; }
    public String engineerHelp { get; set; }
    public String speedRating { get; set; }
    public String enhanceProduct { get; set; }
    public String recommendRating { get; set; }

    public FeedbackFormController(ApexPages.StandardController controller) {
        isSuccess = false;
        
        // Fetch Case details using the ID from the URL
        String caseId = ApexPages.currentPage().getParameters().get('id');
        if (caseId != null) {
            currentCase = [SELECT Id, CaseNumber,States__c,CreatedDate,Customer_Persona__c, Account.Name, Contact.Name, ContactPhone FROM Case WHERE Id = :caseId LIMIT 1];
        }
    }

    public PageReference saveFeedback() {
        try {
            // 1. Initialize the new record
            Feedback_Form__c feedback = new Feedback_Form__c();
            
            // 2. Attach the Case data
            if (currentCase != null) {
                feedback.Case__c = currentCase.Id;
				feedback.State__c = currentCase.States__c;
				feedback.Date_of_Complint__c = currentCase.CreatedDate;
				feedback.Installation_Type__c = currentCase.Customer_Persona__c;
                feedback.Mobile_Number__c = currentCase.ContactPhone;
                feedback.Please_Enter_Your_Name__c = currentCase.Contact.Name;
            }
            
            // 3. Map our custom variables from the Visualforce page into the actual Salesforce fields
            //feedback.Installation_Type__c = installationType;
            //feedback.State__c = state;
            feedback.Did_our_Service_Engineer_help_resolve_yo__c = engineerHelp;
            feedback.How_would_you_rate_the_speed_of_issue_re__c = speedRating;
            feedback.How_can_we_enhance_our_product_or_servic__c = enhanceProduct;
            feedback.How_likely_are_you_to_recommend_us_to_a__c = recommendRating;

            // 4. Save to the database
            insert feedback;
            isSuccess = true;
            return null; 
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
}