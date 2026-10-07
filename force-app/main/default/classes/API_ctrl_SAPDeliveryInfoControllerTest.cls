@isTest
public class API_ctrl_SAPDeliveryInfoControllerTest {

    // ---------------- MOCK: SUCCESS ----------------
    public class MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            res.setBody('[{"DELIVERY_NO":"D001","DELIVERY_LINE_ITEM_NO":"10","SALES_ORDER_NO":"SO123","SALES_ORDER_LINE_ITEM":"20","DELIVERY_ITEM":"Item1","DELIVERY_ITEM_DESCRIPTION":"Test Item","DELIVERY_DATE":"20240101","DELIVERY_QUANTITY":"5","PLANT":"Plant1","STORAGE_LOCATION":"Loc1","NET_PRICE":"100","NET_VALUE":"500"}]');
            
            return res;
        }
    }

    // ---------------- MOCK: ERROR ----------------
    public class MockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Error');
            return res;
        }
    }

    // ---------------- MOCK: INVALID FORMAT ----------------
    public class MockInvalid implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"wrong":"format"}');
            return res;
        }
    }

    // ---------------- TEST: DATE ----------------
    @isTest
    static void testDate() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        API_ctrl_SAPDeliveryInfoController.getDeliveryInformation(
            'date',
            Date.today().addDays(-1),
            Date.today(),
            null
        );
        Test.stopTest();
    }

    // ---------------- TEST: SALES ORDER ----------------
    @isTest
    static void testSalesOrder() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        API_ctrl_SAPDeliveryInfoController.getDeliveryInformation(
            'salesOrder',
            null,
            null,
            'SO123'
        );
        Test.stopTest();
    }

    // ---------------- TEST: INVALID FILTER ----------------
    @isTest
    static void testInvalidFilter() {
        Test.startTest();
        try {
            API_ctrl_SAPDeliveryInfoController.getDeliveryInformation(
                'invalid',
                null,
                null,
                null
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- TEST: DATE RANGE ERROR ----------------
    @isTest
    static void testDateRangeError() {
        Test.startTest();
        try {
            API_ctrl_SAPDeliveryInfoController.getDeliveryInformation(
                'date',
                Date.today().addDays(-10),
                Date.today(),
                null
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- TEST: HTTP ERROR ----------------
    @isTest
    static void testHttpError() {
        Test.setMock(HttpCalloutMock.class, new MockError());

        Test.startTest();
        try {
            API_ctrl_SAPDeliveryInfoController.getDeliveryInformation(
                'date',
                Date.today().addDays(-1),
                Date.today(),
                null
            );
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ---------------- TEST: INVALID RESPONSE ----------------
    @isTest
    static void testInvalidResponse() {
        Test.setMock(HttpCalloutMock.class, new MockInvalid());

        Test.startTest();
        try {
            API_ctrl_SAPDeliveryInfoController.getDeliveryInformation(
                'date',
                Date.today().addDays(-1),
                Date.today(),
                null
            );
        } catch (Exception e) {}
        Test.stopTest();
    }
}