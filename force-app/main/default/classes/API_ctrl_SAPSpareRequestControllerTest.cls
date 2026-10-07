@isTest
public class API_ctrl_SAPSpareRequestControllerTest {

    // ---------------- MOCK SUCCESS ----------------
    public class MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            res.setBody(
                '[{' +
                '"MATERIAL_CODE":"MAT001",' +
                '"MATERIAL_DESCRIPTION":"Test Material",' +
                '"PLANT":"P1",' +
                '"PLANT_DESCRIPTION":"Plant 1",' +
                '"STORAGE_LOCATION":"SL1",' +
                '"STORAGE_LOCATION_DESCRIPTION":"Loc 1",' +
                '"UOM":"EA",' +
                '"BATCH_NUMBER":"B1",' +
                '"QUANTITY":"10",' +
                '"STANDARD_PRICE":"100"' +
                '}]'
            );

            return res;
        }
    }

    // ---------------- MOCK ERROR ----------------
    public class MockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Error');
            return res;
        }
    }

    // ---------------- MOCK EMPTY RESPONSE ----------------
    public class MockEmptyResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('');
            return res;
        }
    }

    // ---------------- MOCK INVALID DECIMAL ----------------
    public class MockInvalidDecimal implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody(
                '[{' +
                '"MATERIAL_CODE":"MAT001",' +
                '"MATERIAL_DESCRIPTION":"Test Material",' +
                '"PLANT":"P1",' +
                '"PLANT_DESCRIPTION":"Plant 1",' +
                '"STORAGE_LOCATION":"SL1",' +
                '"STORAGE_LOCATION_DESCRIPTION":"Loc 1",' +
                '"UOM":"EA",' +
                '"BATCH_NUMBER":"B1",' +
                '"QUANTITY":"ABC",' +
                '"STANDARD_PRICE":"XYZ"' +
                '}]'
            );

            return res;
        }
    }

    // ---------------- MOCK BAD JSON ----------------
    public class MockBadJson implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{INVALID JSON');
            return res;
        }
    }

    // ---------------- TEST SUCCESS ----------------
    @isTest
    static void testFetchSuccess() {

        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        API_ctrl_SAPSpareRequestController.fetchSpareRequestData('MAT001');
        Test.stopTest();
    }

    // ---------------- TEST BLANK MATERIAL ----------------
    @isTest
    static void testBlankMaterialCode() {

        Test.startTest();

        try {
            API_ctrl_SAPSpareRequestController.fetchSpareRequestData(null);
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    // ---------------- TEST HTTP ERROR ----------------
    @isTest
    static void testFetchHttpError() {

        Test.setMock(HttpCalloutMock.class, new MockError());

        Test.startTest();

        try {
            API_ctrl_SAPSpareRequestController.fetchSpareRequestData('MAT001');
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    // ---------------- TEST EMPTY RESPONSE ----------------
    @isTest
    static void testEmptyResponse() {

        Test.setMock(HttpCalloutMock.class, new MockEmptyResponse());

        Test.startTest();
        API_ctrl_SAPSpareRequestController.fetchSpareRequestData('MAT001');
        Test.stopTest();
    }

    // ---------------- TEST INVALID DECIMAL ----------------
    @isTest
    static void testInvalidDecimalResponse() {

        Test.setMock(HttpCalloutMock.class, new MockInvalidDecimal());

        Test.startTest();
        API_ctrl_SAPSpareRequestController.fetchSpareRequestData('MAT001');
        Test.stopTest();
    }

    // ---------------- TEST INVALID JSON ----------------
    @isTest
    static void testBadJsonResponse() {

        Test.setMock(HttpCalloutMock.class, new MockBadJson());

        Test.startTest();

        try {
            API_ctrl_SAPSpareRequestController.fetchSpareRequestData('MAT001');
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    // ---------------- TEST UPDATE PRICE NULL ID ----------------
    @isTest
    static void testUpdatePriceNullId() {

        Test.startTest();

        try {
            API_ctrl_SAPSpareRequestController.updateSelectedPrice(
                null,
                100
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    // ---------------- TEST UPDATE PRICE NULL VALUE ----------------
    @isTest
    static void testUpdatePriceNullValue() {

        Test.startTest();

        try {
            API_ctrl_SAPSpareRequestController.updateSelectedPrice(
                Id.valueOf('08k000000000001AAA'),
                null
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    // ---------------- TEST UPDATE PRICE INVALID RECORD ----------------
    @isTest
    static void testUpdatePriceInvalidRecord() {

        Test.startTest();

        try {
            API_ctrl_SAPSpareRequestController.updateSelectedPrice(
                Id.valueOf('08k000000000001AAA'),
                100
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }
}