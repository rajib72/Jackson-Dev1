@isTest
public class API_Ctrl_PostalPincodeControllerTest {

    // -----------------------------------
    // MOCK: SUCCESS RESPONSE
    // -----------------------------------
    public class PincodeSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            Map<String, Object> postOffice = new Map<String, Object>{
                'Name' => 'Test PO',
                'BranchType' => 'Sub Office',
                'DeliveryStatus' => 'Delivery',
                'Circle' => 'WB',
                'District' => 'Kolkata',
                'Division' => 'Division1',
                'Region' => 'Region1',
                'Block' => 'Block1',
                'State' => 'West Bengal',
                'Country' => 'India',
                'Pincode' => '700001'
            };

            Map<String, Object> responseMap = new Map<String, Object>{
                'Status' => 'Success',
                'Message' => 'Records Found',
                'PostOffice' => new List<Object>{ postOffice }
            };

            List<Object> outerList = new List<Object>{ responseMap };

            res.setBody(JSON.serialize(outerList));
            return res;
        }
    }

    // -----------------------------------
    // MOCK: HTTP ERROR
    // -----------------------------------
    public class PincodeErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            return res;
        }
    }

    // -----------------------------------
    // MOCK: INVALID JSON (EXCEPTION)
    // -----------------------------------
    public class PincodeExceptionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('INVALID_JSON');
            return res;
        }
    }

    // -----------------------------------
    // TEST: SUCCESS FLOW
    // -----------------------------------
    @isTest
    static void testGetPostOfficesSuccess() {
        Test.setMock(HttpCalloutMock.class, new PincodeSuccessMock());
        Test.startTest();
        API_Ctrl_PostalPincodeController.getPostOffices('700001');
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: BLANK PINCODE
    // -----------------------------------
    @isTest
    static void testBlankPincode() {
        Test.startTest();
        API_Ctrl_PostalPincodeController.getPostOffices('');
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: HTTP ERROR
    // -----------------------------------
    @isTest
    static void testHttpError() {
        Test.setMock(HttpCalloutMock.class, new PincodeErrorMock());
        Test.startTest();
        API_Ctrl_PostalPincodeController.getPostOffices('700001');
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: EXCEPTION FLOW
    // -----------------------------------
    @isTest
    static void testExceptionFlow() {
        Test.setMock(HttpCalloutMock.class, new PincodeExceptionMock());
        Test.startTest();
        API_Ctrl_PostalPincodeController.getPostOffices('700001');
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: UPDATE SERVICE APPOINTMENT
    // -----------------------------------
    @isTest
    static void testUpdateServiceAppointment() {
        WorkOrder wo = new WorkOrder(
            Subject = 'Test WO',
            Status = 'New'
        );
        insert wo;

        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id,
            EarliestStartTime = System.now(),
            DueDate = System.now().addDays(1),
            Status = 'None'
        );
        insert sa;

        Test.startTest();
        API_Ctrl_PostalPincodeController.updateServiceAppointmentFromSelection(
            sa.Id, 'WB', 'India', 'Kolkata'
        );
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: SERVICE APPOINTMENT NULL ID
    // -----------------------------------
    @isTest
    static void testServiceAppointmentNull() {
        Test.startTest();
        try {
            API_Ctrl_PostalPincodeController.updateServiceAppointmentFromSelection(null, 'WB', 'India', 'Kolkata');
        } catch (Exception e) {}
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: UPDATE LEAD
    // -----------------------------------
    @isTest
    static void testUpdateLead() {
        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Internal_Business_Team__c = 'Solar Sales',
            Business_Segment__c = 'Institutional' // Added to satisfy validation rule
        );
        insert ld;

        Test.startTest();
        API_Ctrl_PostalPincodeController.updateLeadFromSelection(
            ld.Id, 'WB', 'India', 'Kolkata'
        );
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: LEAD NULL ID
    // -----------------------------------
    @isTest
    static void testLeadNull() {
        Test.startTest();
        try {
            API_Ctrl_PostalPincodeController.updateLeadFromSelection(null, 'WB', 'India', 'Kolkata');
        } catch (Exception e) {}
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: ACCOUNT BILLING & SHIPPING
    // -----------------------------------
    @isTest
    static void testAccountBillingAndShipping() {
        Account acc = new Account(
            Name = 'Test Acc'
            //Business_Segment__c = 'Retail' // Added to satisfy validation rule
        );
        insert acc;

        Test.startTest();
        API_Ctrl_PostalPincodeController.updateAccountBillingFromSelection(acc.Id, 'WB', 'India', 'Kolkata');
        API_Ctrl_PostalPincodeController.updateAccountShippingFromSelection(acc.Id, 'WB', 'India', 'Kolkata');
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: ACCOUNT NULL ID
    // -----------------------------------
    @isTest
    static void testAccountNull() {
        Test.startTest();
        try {
            API_Ctrl_PostalPincodeController.updateAccountBillingFromSelection(null, 'WB', 'India', 'Kolkata');
        } catch (Exception e) {}

        try {
            API_Ctrl_PostalPincodeController.updateAccountShippingFromSelection(null, 'WB', 'India', 'Kolkata');
        } catch (Exception e) {}
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: QUOTE BILLING & SHIPPING
    // -----------------------------------
    @isTest
    static void testQuoteBillingAndShipping() {
        Account acc = new Account(
            Name = 'Test Acc'
            //Business_Segment__c = 'Retail' // Added to satisfy validation rule
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Internal_Business_Team__c = 'Solar Sales',
            Business_Segment__c = 'Institutional'
        );
        insert opp;

        Quote qt = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Business_Segment__c = 'Retail'
        );
        insert qt;

        Test.startTest();
        API_Ctrl_PostalPincodeController.updateQuoteBillingFromSelection(qt.Id, 'WB', 'India', 'Kolkata');
        API_Ctrl_PostalPincodeController.updateQuoteShippingFromSelection(qt.Id, 'WB', 'India', 'Kolkata');
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: QUOTE NULL ID
    // -----------------------------------
    @isTest
    static void testQuoteNull() {
        Test.startTest();
        try {
            API_Ctrl_PostalPincodeController.updateQuoteBillingFromSelection(null, 'WB', 'India', 'Kolkata');
        } catch (Exception e) {}

        try {
            API_Ctrl_PostalPincodeController.updateQuoteShippingFromSelection(null, 'WB', 'India', 'Kolkata');
        } catch (Exception e) {}
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: ASSET UPDATE
    // -----------------------------------
    @isTest
    static void testAssetUpdate() {
        // Create an Account first to satisfy the standard Asset requirement
        Account acc = new Account(
            Name = 'Asset Parent Account'
            //Business_Segment__c = 'Retail' 
        );
        insert acc;

        // Link the Asset to the new Account
        Asset ast = new Asset(
            Name = 'Test Asset',
            AccountId = acc.Id
        );
        insert ast;

        Test.startTest();
        API_Ctrl_PostalPincodeController.updateAssetFromSelection(ast.Id, 'WB', 'India', 'Kolkata');
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: ASSET NULL ID
    // -----------------------------------
    @isTest
    static void testAssetNull() {
        Test.startTest();
        try {
            API_Ctrl_PostalPincodeController.updateAssetFromSelection(null, 'WB', 'India', 'Kolkata');
        } catch (Exception e) {}
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: PRODUCT REQUEST UPDATE
    // -----------------------------------
    @isTest
    static void testProductRequestUpdate() {
        // Populate standard address components to pass the custom validation rule
        ProductRequest pr = new ProductRequest(
            ShipToStreet = '123 Test St',
            ShipToCity = 'Test City',
            ShipToState = 'West Bengal',
            ShipToPostalCode = '700001',
            ShipToCountry = 'India'
        );
        insert pr;

        Test.startTest();
        API_Ctrl_PostalPincodeController.updateProductRequestFromSelection(pr.Id, 'WB', 'India', 'Kolkata');
        Test.stopTest();
    }

    // -----------------------------------
    // TEST: PRODUCT REQUEST NULL ID
    // -----------------------------------
    @isTest
    static void testProductRequestNull() {
        Test.startTest();
        try {
            API_Ctrl_PostalPincodeController.updateProductRequestFromSelection(null, 'WB', 'India', 'Kolkata');
        } catch (Exception e) {}
        Test.stopTest();
    }
}