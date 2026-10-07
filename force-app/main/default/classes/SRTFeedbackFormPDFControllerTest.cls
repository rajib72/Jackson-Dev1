@IsTest
private class SRTFeedbackFormPDFControllerTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;


        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Customer',
            AccountId = acc.Id,
            MobilePhone = '9876543210',
            Email = 'testcustomer@test.com'
        );
        insert con;


        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;


        Asset ast = new Asset(
            Name = 'Test Asset',
            AccountId = acc.Id,
            ContactId = con.Id,
            Product2Id = prod.Id,
            SerialNumber = 'TEST-SERIAL-001'
        );
        insert ast;


        Case caseRec = new Case(
            AccountId = acc.Id,
            ContactId = con.Id,
            AssetId = ast.Id,
            Subject = 'Test Feedback Case',
            Description = 'Test Case Description',
            Status = 'New',
            Origin = 'Phone'
        );
        insert caseRec;


        Feedback_Form__c feedback = new Feedback_Form__c(
            Case__c = caseRec.Id,
            Service_Completion_Date__c = Date.today()

            // Add values below if these fields are required
            // in your org.

            // Overall_Satisfaction_CSAT__c = 'Satisfied',
            // Would_you_recommend_Jakson_NPS__c = '10',
            // Issue_resolved__c = 'Yes',
            // Engineer_behaviour_professionalism__c = 'Excellent',
            // Response_turnaround_experience__c = 'Excellent',
            // Comments__c = 'Test feedback'
        );
        insert feedback;
    }


    @IsTest
    static void testControllerWithCaseAndFeedback() {

        Case caseRec = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Test Feedback Case'
            LIMIT 1
        ];


        PageReference pageRef =
            new PageReference('/apex/SRTFeedbackFormPDF');

        Test.setCurrentPage(pageRef);

        ApexPages.currentPage()
            .getParameters()
            .put(
                'id',
                caseRec.Id
            );


        Test.startTest();

        SRTFeedbackFormPDFController controller =
            new SRTFeedbackFormPDFController();

        Test.stopTest();


        // Access properties for coverage
        Case loadedCase =
            controller.caseRecord;

        Feedback_Form__c loadedFeedback =
            controller.feedbackRecord;
    }


    @IsTest
    static void testControllerWithoutId() {

        PageReference pageRef =
            new PageReference('/apex/SRTFeedbackFormPDF');

        Test.setCurrentPage(pageRef);


        Test.startTest();

        SRTFeedbackFormPDFController controller =
            new SRTFeedbackFormPDFController();

        Test.stopTest();


        // Access properties
        Case loadedCase =
            controller.caseRecord;

        Feedback_Form__c loadedFeedback =
            controller.feedbackRecord;
    }
}