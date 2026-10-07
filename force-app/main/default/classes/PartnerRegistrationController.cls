public without sharing class PartnerRegistrationController {

    public Registration_Details__c reg {get; set;}
    public Blob uploadedFile {get; set;}
    public String fileName {get; set;}
    public String partnerId {get; set;}

    public PartnerRegistrationController() {

        reg = new Registration_Details__c();

        partnerId = ApexPages.currentPage().getParameters().get('partnerId');

        if(partnerId != null){
            reg.Partner__c = partnerId;

            try{
                Partner__c p = [SELECT Salesperson__c 
                                FROM Partner__c 
                                WHERE Id = :partnerId 
                                LIMIT 1];

                reg.Salesperson__c = p.Salesperson__c;
            } catch(Exception e){
                System.debug('Partner not found');
            }
        }
    }

    public PageReference saveRegistration(){

        try{
			reg.Name = reg.Full_Name__c;
            reg.Status__c = 'Pending';
            reg.Form_Submitted_At__c = System.now();

            insert reg;

            if(uploadedFile != null){

                ContentVersion cv = new ContentVersion();
                cv.Title = fileName;
                cv.PathOnClient = fileName;
                cv.VersionData = uploadedFile;
                cv.FirstPublishLocationId = reg.Id; // IMPORTANT LINE
                insert cv;
            }

        ApexPages.addMessage(
            new ApexPages.Message(
                ApexPages.Severity.CONFIRM,
                'Registration submitted successfully.'
            )
        );
        return null;

        } catch(Exception e){

            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Error while submitting form: ' + e.getMessage()
                )
            );

            return null;
        }
    }
}