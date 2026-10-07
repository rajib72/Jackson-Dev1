@isTest
public class API_Ctrl_BillingInformationTest {

    // -------------------------------
    // MOCK CLASS FOR HTTP CALLOUT
    // -------------------------------
    public class BillingInfoMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // Sample SAP response (List format as expected)
            String mockResponse = JSON.serialize(new List<Object>{
                new Map<String, Object>{
                    'BILLING_DOCUMENT' => '1001',
                    'BILLING_LINE_ITEM_NO' => '10',
                    'BILLING_DOCUMENT_DATE' => '20240101',
                    'BILLING_DOCUMENT_AMOUNT' => '5000',
                    'DELIVERY_NUMBER' => 'D001',
                    'SALES_ORDER_NO' => 'SO001'
                },
                new Map<String, Object>{
                    'BILLING_DOCUMENT' => '1002',
                    'BILLING_LINE_ITEM_NO' => '20',
                    'BILLING_DOCUMENT_DATE' => '20240102',
                    'BILLING_DOCUMENT_AMOUNT' => '7000',
                    'DELIVERY_NUMBER' => 'D002',
                    'SALES_ORDER_NO' => 'SO002'
                }
            });

            res.setBody(mockResponse);
            return res;
        }
    }

    // -------------------------------
    // TEST: DATE FILTER SUCCESS
    // -------------------------------
    @isTest
    static void testFetchBillingInfo_DateFilter() {

        Test.setMock(HttpCalloutMock.class, new BillingInfoMock());

        Test.startTest();

        API_Ctrl_BillingInformationController.BillingInfoResponse response =
            API_Ctrl_BillingInformationController.fetchBillingInformation(
                'DATE',
                Date.today().addDays(-5),
                Date.today(),
                null
            );

        Test.stopTest();
    }

    // -------------------------------
    // TEST: DELIVERY FILTER SUCCESS
    // -------------------------------
    @isTest
    static void testFetchBillingInfo_DeliveryFilter() {

        Test.setMock(HttpCalloutMock.class, new BillingInfoMock());

        Test.startTest();

        API_Ctrl_BillingInformationController.BillingInfoResponse response =
            API_Ctrl_BillingInformationController.fetchBillingInformation(
                'DELIVERY',
                null,
                null,
                'D001'
            );

        Test.stopTest();
    }

    // -------------------------------
    // TEST: INVALID FILTER TYPE
    // -------------------------------
    @isTest
    static void testInvalidFilterType() {

        Test.startTest();

        try {
            API_Ctrl_BillingInformationController.fetchBillingInformation(
                'INVALID',
                null,
                null,
                null
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    // -------------------------------
    // TEST: DATE VALIDATION FAILURE
    // -------------------------------
    @isTest
    static void testDateValidationFailure() {

        Test.startTest();

        try {
            API_Ctrl_BillingInformationController.fetchBillingInformation(
                'DATE',
                Date.today(),
                Date.today().addDays(-1),
                null
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    // -------------------------------
    // TEST: DELIVERY VALIDATION FAILURE
    // -------------------------------
    @isTest
    static void testDeliveryValidationFailure() {

        Test.startTest();

        try {
            API_Ctrl_BillingInformationController.fetchBillingInformation(
                'DELIVERY',
                null,
                null,
                null
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    // -------------------------------
    // MOCK FOR ERROR RESPONSE
    // -------------------------------
    public class BillingErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    // -------------------------------
    // TEST: API FAILURE (NON-200)
    // -------------------------------
    @isTest
    static void testApiFailure() {

        Test.setMock(HttpCalloutMock.class, new BillingErrorMock());

        Test.startTest();

        API_Ctrl_BillingInformationController.BillingInfoResponse response =
            API_Ctrl_BillingInformationController.fetchBillingInformation(
                'DELIVERY',
                null,
                null,
                'D001'
            );

        Test.stopTest();
    }
}