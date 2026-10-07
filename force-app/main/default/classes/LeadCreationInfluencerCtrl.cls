public with sharing class LeadCreationInfluencerCtrl {

    public Lead leadRec { get; set; }

    public LeadCreationInfluencerCtrl() {
        leadRec = new Lead();
    }

    public void saveLead() {

        Boolean hasError = false;

        // Mobile Validation
        if (leadRec.MobilePhone != null && 
            !Pattern.matches('^[0-9]{1,14}$', leadRec.MobilePhone)) {

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Mobile number must contain only digits and be up to 14 digits.'
            ));
            hasError = true;
        }

        // Phone Validation
        if (leadRec.Phone != null && 
            !Pattern.matches('^[0-9]{1,14}$', leadRec.Phone)) {

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Phone number must contain only digits and be up to 14 digits.'
            ));
            hasError = true;
        }

        // Email Validation
        if (leadRec.Email != null && 
            !Pattern.matches('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$', leadRec.Email)) {

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Please enter a valid email address.'
            ));
            hasError = true;
        }

        // Postal Code Validation
        if (leadRec.PostalCode != null && 
            !Pattern.matches('^[0-9]+$', leadRec.PostalCode)) {

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Postal Code must contain only numbers.'
            ));
            hasError = true;
        }

        // Stop execution if validation failed
        if (hasError) {
            return;
        }

        try {
            leadRec.Company = 'Default Company';
            leadRec.LeadSource = 'IVR';
   		 	leadRec.Internal_Business_Team__c = 'Solar Sales';
            insert leadRec;

            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.CONFIRM,
                    'Thank you! Your Lead has been submitted successfully.'
                )
            );

            // Reset form
            leadRec = new Lead();

        } catch (Exception e) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    e.getMessage()
                )
            );
        }
    }
}