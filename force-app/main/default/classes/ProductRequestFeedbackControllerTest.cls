@isTest
public class ProductRequestFeedbackControllerTest {

    @testSetup
    static void setupTestData() {
        // 1. Create User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'standt', 
            Email = 'testuser123@example.com',
            EmailEncodingKey = 'UTF-8', 
            LastName = 'Testing', 
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', 
            ProfileId = p.Id, 
            MobilePhone = '1234567890',
            TimeZoneSidKey = 'America/Los_Angeles', 
            UserName = 'testuser123' + DateTime.now().getTime() + '@example.com'
        );
        insert testUser;

        // 2. Create Account & Contact
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'Test Contact', 
            AccountId = acc.Id, 
            Phone = '0987654321', 
            Email = 'contact@example.com'
        );
        insert con;

        // 3. Create Case
        Case testCase = new Case(
            AccountId = acc.Id, 
            ContactId = con.Id, 
            Complaint_Type__c = 'Hardware Issue' 
        );
        insert testCase;

        // 4. Create WorkOrder
        WorkOrder wo = new WorkOrder(
            CaseId = testCase.Id
        );
        insert wo;

        // 5. Create a standard Product2 record
        Product2 testProd = new Product2(
            Name = 'Standard Product',
            IsActive = true
        );
        insert testProd;
        
        // --- NEW FIX: Create Standard Pricebook Entry ---
        Id standardPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = testProd.Id,
            UnitPrice = 150.00,
            IsActive = true
        );
        insert pbe;
        // ------------------------------------------------
        
        // 6. Create Material Master record to drive Line Item formulas
        Material_Master__c matMaster = new Material_Master__c(
            Name = 'MAT-001',
            Material_Description__c = 'Test Material'
        );
        insert matMaster;

        // 7. Create ProductRequest
        ProductRequest pr = new ProductRequest(
            WorkOrderId = wo.Id,
            NeedByDate = System.today().addDays(5),
            ShipToStreet = '123 Main St',
            ShipToCity = 'Metropolis',
            ShipToState = 'NY',
            ShipToPostalCode = '10001',
            ShipToCountry = 'USA',
            Product_Request_Type__c = 'FOC' 
        );
        insert pr;

        // 8. Create ProductRequestLineItem
        ProductRequestLineItem prli = new ProductRequestLineItem(
            ParentId = pr.Id,
            Product2Id = testProd.Id,
            QuantityRequested = 2,
            QuantityUnitOfMeasure = 'Each',
            Price__c = 150.00,
            Material_Master__c = matMaster.Id 
        );
        insert prli;

        // Run as system context to avoid Mixed DML errors when inserting ServiceResource
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // 9. Create ServiceResource
            ServiceResource sr = new ServiceResource(
                Name = 'Test Technician',
                RelatedRecordId = testUser.Id,
                ResourceType = 'T',
                IsActive = true
            );
            insert sr;

            // 10. Create ResourcePreference
            ResourcePreference rp = new ResourcePreference(
                RelatedRecordId = wo.Id,
                ServiceResourceId = sr.Id,
                PreferenceType = 'Preferred'
            );
            insert rp;
        }
    }

    @isTest
    static void testControllerInitializationSuccess() {
        // Get the generated Product Request
        ProductRequest pr = [SELECT Id FROM ProductRequest LIMIT 1];

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(pr);
        ProductRequestFeedbackController controller = new ProductRequestFeedbackController(sc);
        Test.stopTest();

        // Assert Controller state
        System.assertNotEquals(null, controller.prRecord, 'ProductRequest record should be loaded');
        System.assertNotEquals(null, controller.woRecord, 'WorkOrder record should be loaded');
        System.assertEquals(1, controller.lineItemRows.size(), 'Should have one line item wrapper');
        System.assertEquals(1, controller.resourceInfoList.size(), 'Should have one resource info wrapper');
        
        // Assert Case details
        System.assertNotEquals(null, controller.caseNumber, 'Case Number should be populated');
        System.assertEquals('Test Account', controller.accountName, 'Account name should match');
        System.assertEquals('Test Contact', controller.contactName, 'Contact name should match');
        
        // Assert address formatting
        System.assertEquals('123 Main St, Metropolis NY 10001, USA', controller.shipToAddressText, 'Address should be formatted correctly');
    }

    @isTest
    static void testControllerInitializationNullId() {
        // Pass a new, uninserted ProductRequest (no Id)
        ProductRequest emptyPr = new ProductRequest();

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(emptyPr);
        ProductRequestFeedbackController controller = new ProductRequestFeedbackController(sc);
        Test.stopTest();

        // Verify it exited cleanly
        System.assertEquals(0, controller.prliList.size(), 'Lists should remain empty');
        System.assertEquals(null, controller.prRecord, 'prRecord should be null');
    }

    @isTest
    static void testSelectApproveAndReject() {
        ProductRequest pr = [SELECT Id FROM ProductRequest LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(pr);
        ProductRequestFeedbackController controller = new ProductRequestFeedbackController(sc);

        Test.startTest();
        // Test Approve
        controller.selectApprove();
        System.assertEquals('Approved', controller.feedbackStatus, 'Status should be Approved');
        System.assertEquals(true, controller.showRemarksBox, 'Remarks box should be shown');

        // Test Reject
        controller.selectReject();
        System.assertEquals('Rejected', controller.feedbackStatus, 'Status should be Rejected');
        System.assertEquals(true, controller.showRemarksBox, 'Remarks box should be shown');
        Test.stopTest();
    }

    @isTest
    static void testSaveFeedbackSuccess() {
        ProductRequest pr = [SELECT Id FROM ProductRequest LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(pr);
        ProductRequestFeedbackController controller = new ProductRequestFeedbackController(sc);

        Test.startTest();
        controller.selectApprove();
        controller.remarks = 'Great service!';
        PageReference result = controller.saveFeedback();
        Test.stopTest();

        System.assertEquals(null, result, 'PageReference should be null');
        System.assertEquals(true, controller.isSuccess, 'isSuccess should be true');
        System.assertEquals(false, controller.showRemarksBox, 'showRemarksBox should be false');

        // Verify record was created
        List<Customer_Product_Request__c> feedbackRecords = [SELECT Id, Remarks__c, Customar_Feedback__c FROM Customer_Product_Request__c];
        System.assertEquals(1, feedbackRecords.size(), 'One feedback record should be created');
        System.assertEquals('Great service!', feedbackRecords[0].Remarks__c, 'Remarks should match');
        System.assertEquals('Approved', feedbackRecords[0].Customar_Feedback__c, 'Status should match');
    }

    @isTest
    static void testSaveFeedbackBlankRemarks() {
        ProductRequest pr = [SELECT Id FROM ProductRequest LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(pr);
        ProductRequestFeedbackController controller = new ProductRequestFeedbackController(sc);

        Test.startTest();
        controller.selectApprove();
        controller.remarks = ''; // Blank remarks
        PageReference result = controller.saveFeedback();
        Test.stopTest();

        System.assertEquals(null, result, 'PageReference should be null');
        System.assertEquals(false, controller.isSuccess, 'isSuccess should remain false');
        
        // Assert page messages
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assert(messages.size() > 0, 'Should have an error message');
        System.assertEquals(ApexPages.Severity.ERROR, messages[0].getSeverity(), 'Severity should be ERROR');
    }
    
    @isTest
    static void testSaveFeedbackException() {
        ProductRequest pr = [SELECT Id FROM ProductRequest LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(pr);
        ProductRequestFeedbackController controller = new ProductRequestFeedbackController(sc);

        Test.startTest();
        controller.selectApprove();
        controller.remarks = 'Testing exception';
        
        controller.prRecord.Id = '0TSWG00000042BJ4AY'; 
        
        controller.saveFeedback();
        Test.stopTest();

    }
}