@isTest
public class CustomerProductRequestPDF_CtrlTest {

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

        // 4. Create WorkOrders
        WorkOrder wo1 = new WorkOrder(CaseId = testCase.Id);
        insert wo1;
        
        // Second WorkOrder for fallback testing
        WorkOrder wo2 = new WorkOrder(CaseId = testCase.Id); 
        insert wo2;

        // 5. Create a standard Product2 record (Name must be 'Standard Product' for the Flow)
        Product2 testProd = new Product2(
            Name = 'Standard Product',
            IsActive = true
        );
        insert testProd;
        
        // 6. Create Standard Pricebook Entry
        Id standardPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = testProd.Id,
            UnitPrice = 150.00,
            IsActive = true
        );
        insert pbe;
        
        // 7. Create Material Master record
        Material_Master__c matMaster = new Material_Master__c(
            Name = 'MAT-001',
            Material_Description__c = 'Test Material'
        );
        insert matMaster;

        // 8. Create Product Requests
        ProductRequest pr1 = new ProductRequest(
            WorkOrderId = wo1.Id,
            NeedByDate = System.today().addDays(5),
            ShipToStreet = '123 Main St',
            ShipToCity = 'Metropolis',
            ShipToState = 'NY',
            ShipToPostalCode = '10001',
            ShipToCountry = 'USA',
            Product_Request_Type__c = 'FOC' 
        );
        insert pr1;
        
        ProductRequest pr2 = new ProductRequest(
            WorkOrderId = wo2.Id,
            NeedByDate = System.today().addDays(5),
            ShipToStreet = '456 Side St',
            ShipToCity = 'Gotham',
            ShipToState = 'NY',
            ShipToPostalCode = '10002',
            ShipToCountry = 'USA',
            Product_Request_Type__c = 'FOC' 
        );
        insert pr2;

        // 9. Create ProductRequestLineItem for PR1
        ProductRequestLineItem prli = new ProductRequestLineItem(
            ParentId = pr1.Id,
            Product2Id = testProd.Id,
            QuantityRequested = 2,
            QuantityUnitOfMeasure = 'Each',
            Price__c = 150.00,
            Material_Master__c = matMaster.Id 
        );
        insert prli;
        
        // 10. Create Service Cost Details
        Service_Cost_Details__c scd = new Service_Cost_Details__c(
            Work_Order__c = wo1.Id,
            Estimated_Cost__c = 50.00,
            Description__c = 'Travel fee'
        );
        insert scd;

        // Run as system context to avoid Mixed DML errors when inserting ServiceResource
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // 11. Create ServiceResource
            ServiceResource sr = new ServiceResource(
                Name = 'Test Technician',
                RelatedRecordId = testUser.Id,
                ResourceType = 'T',
                IsActive = true
            );
            insert sr;

            // 12. Create ResourcePreference
            ResourcePreference rp = new ResourcePreference(
                RelatedRecordId = wo1.Id,
                ServiceResourceId = sr.Id,
                PreferenceType = 'Preferred'
            );
            insert rp;
        }
        
        // 13. Create Customer Product Requests
        // Standard scenario: Direct link to Product Request
        Customer_Product_Request__c cprStandard = new Customer_Product_Request__c(
            Product_Request__c = pr1.Id,
            Work_Order__c = wo1.Id,
            Case__c = testCase.Id,
            Customar_Feedback__c = 'Approved',
            Remarks__c = 'Looks good'
        );
        insert cprStandard;
        
        // Fallback scenario: Linked to WO, but PR field is empty
        Customer_Product_Request__c cprFallback = new Customer_Product_Request__c(
            Work_Order__c = wo2.Id,
            Case__c = testCase.Id,
            Customar_Feedback__c = 'Rejected'
        );
        insert cprFallback;
    }

    @isTest
    static void testStandardInitialization() {
        // Query the standard CPR that has a direct Product_Request__c link
        Customer_Product_Request__c cpr = [SELECT Id FROM Customer_Product_Request__c WHERE Customar_Feedback__c = 'Approved' LIMIT 1];
        
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(cpr);
        CustomerProductRequestPDF_Ctrl controller = new CustomerProductRequestPDF_Ctrl(sc);
        Test.stopTest();
        
        // Assertions for main records
        System.assertNotEquals(null, controller.cprRecord, 'CPR record should be loaded');
        System.assertNotEquals(null, controller.prRecord, 'ProductRequest record should be loaded');
        System.assertNotEquals(null, controller.woRecord, 'WorkOrder record should be loaded');
        
        // Assertions for related lists
        System.assertEquals(1, controller.lineItemRows.size(), 'Should have one line item row populated');
        System.assertEquals(1, controller.costDetails.size(), 'Should have one service cost detail loaded');
        System.assertEquals(1, controller.resourceInfoList.size(), 'Should have one resource info loaded');
        
        // Assertions for string fields & formatting
        System.assertEquals('123 Main St, Metropolis NY 10001, USA', controller.shipToAddressText, 'Address should be formatted correctly');
        System.assertEquals('Test Account', controller.accountName, 'Account name should be populated');
        System.assertEquals('Test Contact', controller.contactName, 'Contact name should be populated');
        System.assertEquals('Hardware Issue', controller.complaintType, 'Complaint type should match');
    }

    @isTest
    static void testFallbackInitialization() {
        // Query the fallback CPR that has NO direct Product_Request__c link
        Customer_Product_Request__c cpr = [SELECT Id FROM Customer_Product_Request__c WHERE Customar_Feedback__c = 'Rejected' LIMIT 1];
        
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(cpr);
        CustomerProductRequestPDF_Ctrl controller = new CustomerProductRequestPDF_Ctrl(sc);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, controller.cprRecord, 'CPR record should be loaded');
        
        // This is the key assert: The controller should have successfully found the ProductRequest
        // by traversing through the Work_Order__c, executing the fallback SOQL query.
        System.assertNotEquals(null, controller.prRecord, 'Fallback ProductRequest record should be loaded via WorkOrder');
        
        // Check formatting logic using the fallback data
        System.assertEquals('456 Side St, Gotham NY 10002, USA', controller.shipToAddressText, 'Address should be formatted from the fallback PR');
    }

    @isTest
    static void testNullInitialization() {
        // Pass a new, uninserted CPR record (so Id is null)
        Customer_Product_Request__c emptyCpr = new Customer_Product_Request__c();

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(emptyCpr);
        CustomerProductRequestPDF_Ctrl controller = new CustomerProductRequestPDF_Ctrl(sc);
        Test.stopTest();

        // The controller should hit the first 'if (cprId == null) { return; }' statement
        // meaning all the lists are initialized but empty, and prRecord/woRecord remain null.
        System.assertEquals(0, controller.prliList.size(), 'PRLI list should be empty');
        System.assertEquals(0, controller.lineItemRows.size(), 'Wrapper list should be empty');
        System.assertEquals(0, controller.resourceInfoList.size(), 'Resource list should be empty');
        System.assertEquals(0, controller.costDetails.size(), 'Cost list should be empty');
        
        System.assertEquals(null, controller.cprRecord, 'cprRecord should be null');
        System.assertEquals(null, controller.prRecord, 'prRecord should be null');
    }
}