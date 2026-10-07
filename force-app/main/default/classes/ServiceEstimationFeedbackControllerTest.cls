@IsTest
public class ServiceEstimationFeedbackControllerTest {

    @testSetup
    static void setupTestData() {

        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id,
            Phone = '9876543210',
            Email = 'testcontact@example.com'
        );
        insert con;

        Case cs = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone',
            AccountId = acc.Id,
            ContactId = con.Id
        );

        /*
        If Complaint_Type__c is mandatory, add correct picklist value:
        cs.Complaint_Type__c = 'Your Value';
        */

        insert cs;

        WorkOrder wo = new WorkOrder(
            Subject = 'Test Work Order',
            CaseId = cs.Id,
            AccountId = acc.Id
        );

        /*
        Add required WorkOrder fields here if your org has validation rules.
        Example:
        wo.Final_Service_Estimation_Cost__c = 1000;
        */

        insert wo;

        Asset ast = new Asset(
            Name = 'Test Asset',
            AccountId = acc.Id
        );
        insert ast;

        WorkOrderLineItem woli = new WorkOrderLineItem(
            WorkOrderId = wo.Id,
            AssetId = ast.Id
        );

        /*
        If required:
        woli.Asset_Serial_No__c = 'SR-001';
        */

        insert woli;

        Service_Cost_Details__c cost = new Service_Cost_Details__c(
            Work_Order__c = wo.Id,
            Estimated_Cost__c = 500,
            Description__c = 'Test Cost Description'
        );

        /*
        If Cost_Type__c is mandatory:
        cost.Cost_Type__c = 'Your Value';
        */

        insert cost;

        // Extra coverage for ResourcePreference / ServiceResource logic
        User currentUser = [
            SELECT Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        ServiceResource sr = new ServiceResource(
            Name = 'Test Service Engineer',
            IsActive = true,
            ResourceType = 'T',
            RelatedRecordId = currentUser.Id
        );
        insert sr;

        ResourcePreference rp = new ResourcePreference(
            RelatedRecordId = wo.Id,
            ServiceResourceId = sr.Id,
            PreferenceType = 'Preferred'
        );
        insert rp;
    }

    @IsTest
    static void testConstructorDataLoad() {

        WorkOrder wo = [
            SELECT Id
            FROM WorkOrder
            LIMIT 1
        ];

        ApexPages.StandardController stdController = new ApexPages.StandardController(wo);

        Test.startTest();
        ServiceEstimationFeedbackController controller =
            new ServiceEstimationFeedbackController(stdController);
        Test.stopTest();

        System.assertNotEquals(null, controller.woRecord, 'Work Order should be loaded');
        System.assertEquals(wo.Id, controller.woRecord.Id, 'Work Order Id should match');

        System.assertNotEquals(null, controller.woliList, 'WOLI list should not be null');
        System.assertEquals(1, controller.woliList.size(), 'One Work Order Line Item should be loaded');

        System.assertNotEquals(null, controller.costDetails, 'Cost details should not be null');
        System.assertEquals(1, controller.costDetails.size(), 'One cost detail should be loaded');

        System.assertNotEquals(null, controller.resourceInfoList, 'Resource list should not be null');
        System.assertEquals(1, controller.resourceInfoList.size(), 'One resource should be loaded');
    }

    @IsTest
    static void testConstructorWithResourcePreference() {

        WorkOrder wo = [
            SELECT Id
            FROM WorkOrder
            LIMIT 1
        ];

        ApexPages.StandardController stdController = new ApexPages.StandardController(wo);

        Test.startTest();
        ServiceEstimationFeedbackController controller =
            new ServiceEstimationFeedbackController(stdController);
        Test.stopTest();

        System.assertNotEquals(null, controller.resourceInfoList, 'Resource list should not be null');
        System.assertEquals(1, controller.resourceInfoList.size(), 'One resource should be loaded');

        ServiceEstimationFeedbackController.ResourceInfoWrapper wrapper =
            controller.resourceInfoList[0];

        System.assertEquals('Test Service Engineer', wrapper.resourceName);
        System.assertEquals('T', wrapper.resourceType);
        System.assertNotEquals(null, wrapper.email, 'Email should be mapped from User');
    }

    @IsTest
    static void testSelectApprove() {

        WorkOrder wo = [
            SELECT Id
            FROM WorkOrder
            LIMIT 1
        ];

        ApexPages.StandardController stdController = new ApexPages.StandardController(wo);
        ServiceEstimationFeedbackController controller =
            new ServiceEstimationFeedbackController(stdController);

        Test.startTest();
        PageReference pageRef = controller.selectApprove();
        Test.stopTest();

        System.assertEquals(null, pageRef);
        System.assertEquals('Approved', controller.feedbackStatus);
        System.assertEquals(true, controller.showRemarksBox);
    }

    @IsTest
    static void testSelectReject() {

        WorkOrder wo = [
            SELECT Id
            FROM WorkOrder
            LIMIT 1
        ];

        ApexPages.StandardController stdController = new ApexPages.StandardController(wo);
        ServiceEstimationFeedbackController controller =
            new ServiceEstimationFeedbackController(stdController);

        Test.startTest();
        PageReference pageRef = controller.selectReject();
        Test.stopTest();

        System.assertEquals(null, pageRef);
        System.assertEquals('Rejected', controller.feedbackStatus);
        System.assertEquals(true, controller.showRemarksBox);
    }

    @IsTest
    static void testSaveFeedbackWithoutRemarks() {

        WorkOrder wo = [
            SELECT Id
            FROM WorkOrder
            LIMIT 1
        ];

        ApexPages.StandardController stdController = new ApexPages.StandardController(wo);
        ServiceEstimationFeedbackController controller =
            new ServiceEstimationFeedbackController(stdController);

        controller.feedbackStatus = 'Approved';
        controller.remarks = '';

        Test.startTest();
        PageReference pageRef = controller.saveFeedback();
        Test.stopTest();

        System.assertEquals(null, pageRef);

        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertEquals(1, messages.size());
        System.assertEquals(
            'Please provide your remarks before submitting.',
            messages[0].getSummary()
        );

        Integer feedbackCount = [
            SELECT COUNT()
            FROM Service_Estimation_Feedback__c
        ];

        System.assertEquals(0, feedbackCount, 'Feedback should not be inserted without remarks');
    }

    @IsTest
    static void testSaveApprovedFeedbackWithRemarks() {

        WorkOrder wo = [
            SELECT Id, CaseId
            FROM WorkOrder
            LIMIT 1
        ];

        ApexPages.StandardController stdController = new ApexPages.StandardController(wo);
        ServiceEstimationFeedbackController controller =
            new ServiceEstimationFeedbackController(stdController);

        controller.feedbackStatus = 'Approved';
        controller.remarks = 'Approved by customer';

        Test.startTest();
        PageReference pageRef = controller.saveFeedback();
        Test.stopTest();

        System.assertEquals(null, pageRef);
        System.assertEquals(true, controller.isSuccess);
        System.assertEquals(false, controller.showRemarksBox);

        Service_Estimation_Feedback__c feedback = [
            SELECT Id, Work_Order__c, Case__c, Customar_Feedback__c, Remarks__c
            FROM Service_Estimation_Feedback__c
            LIMIT 1
        ];

        System.assertEquals(wo.Id, feedback.Work_Order__c);
        System.assertEquals(wo.CaseId, feedback.Case__c);
        System.assertEquals('Approved', feedback.Customar_Feedback__c);
        System.assertEquals('Approved by customer', feedback.Remarks__c);
    }

    @IsTest
    static void testSaveRejectedFeedbackWithRemarks() {

        WorkOrder wo = [
            SELECT Id, CaseId
            FROM WorkOrder
            LIMIT 1
        ];

        ApexPages.StandardController stdController = new ApexPages.StandardController(wo);
        ServiceEstimationFeedbackController controller =
            new ServiceEstimationFeedbackController(stdController);

        controller.feedbackStatus = 'Rejected';
        controller.remarks = 'Rejected by customer';

        Test.startTest();
        PageReference pageRef = controller.saveFeedback();
        Test.stopTest();

        System.assertEquals(null, pageRef);
        System.assertEquals(true, controller.isSuccess);

        Service_Estimation_Feedback__c feedback = [
            SELECT Id, Work_Order__c, Case__c, Customar_Feedback__c, Remarks__c
            FROM Service_Estimation_Feedback__c
            WHERE Customar_Feedback__c = 'Rejected'
            LIMIT 1
        ];

        System.assertEquals(wo.Id, feedback.Work_Order__c);
        System.assertEquals(wo.CaseId, feedback.Case__c);
        System.assertEquals('Rejected', feedback.Customar_Feedback__c);
        System.assertEquals('Rejected by customer', feedback.Remarks__c);
    }

    @IsTest
    static void testConstructorWithoutRecordId() {

        WorkOrder wo = new WorkOrder();

        ApexPages.StandardController stdController = new ApexPages.StandardController(wo);

        Test.startTest();
        ServiceEstimationFeedbackController controller =
            new ServiceEstimationFeedbackController(stdController);
        Test.stopTest();

        System.assertEquals(false, controller.showRemarksBox);
        System.assertEquals(false, controller.isSuccess);
        System.assertNotEquals(null, controller.resourceInfoList);
    }
}