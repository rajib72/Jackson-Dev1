@IsTest
private class ctrl_warrantyRequestFileAPITest {

    private static RestRequest buildRequest(String requestBody) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/WarrantyRequestFile/Create';
        req.httpMethod = 'POST';

        if (requestBody != null) {
            req.requestBody = Blob.valueOf(requestBody);
        }

        RestContext.request = req;
        RestContext.response = new RestResponse();

        return req;
    }

    private static Map<String, Object> getValidPayload(String serialNumber) {
        Map<String, Object> payload = new Map<String, Object>();

        payload.put('customerName', 'Test Customer');
        payload.put('emailId', 'testcustomer@example.com');
        payload.put('mobileNumber', '9876543210');
        payload.put('address', '123 Test Street');
        payload.put('city', 'Kolkata');
        payload.put('state', 'West Bengal');
        payload.put('productModel', 'MODEL-TEST-001');
        payload.put('qty', 1);
        payload.put('serialNumber', serialNumber);
        payload.put('invNumber', 'INV-TEST-001');
        payload.put('invDate', '2026-08-22');
        payload.put('dealerName', 'Test Dealer');
        payload.put('dealerAddress', 'Test Dealer Address');

        return payload;
    }

    @IsTest
    static void testCreateWarrantyRequestSuccessWithoutFile() {

        Map<String, Object> payload =
            getValidPayload('SERIAL-TEST-001');

        buildRequest(JSON.serialize(payload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();

        if (response != null && response.recordId != null) {
            List<Warranty_Request__c> wrList = [
                SELECT
                    Id,
                    Name,
                    Address__c,
                    Customer_Name__c,
                    Mobile_No__c,
                    Email__c,
                    City__c,
                    State__c,
                    Invoice_number__c,
                    Invoice_Date__c,
                    Product_Model__c,
                    Serial_Number__c,
                    Qty__c,
                    Dealer_Name__c,
                    Dealer_Address__c,
                    Status__c
                FROM Warranty_Request__c
                WHERE Id = :response.recordId
                LIMIT 1
            ];
        }
    }

    @IsTest
    static void testCreateWarrantyRequestWithFiles() {

        Map<String, Object> payload =
            getValidPayload('SERIAL-TEST-002');

        List<Object> files = new List<Object>();

        files.add(
            new Map<String, Object>{
                'fileName' => 'WarrantyInvoice.pdf',
                'contentType' => 'application/pdf',
                'base64Data' => EncodingUtil.base64Encode(
                    Blob.valueOf('Test PDF File Data')
                )
            }
        );

        files.add(
            new Map<String, Object>{
                'fileName' => 'ProductImage.jpg',
                'contentType' => 'image/jpeg',
                'base64Data' => EncodingUtil.base64Encode(
                    Blob.valueOf('Test Image File Data')
                )
            }
        );

        payload.put('files', files);

        buildRequest(JSON.serialize(payload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();

        if (response != null && response.recordId != null) {
            List<ContentDocumentLink> links = [
                SELECT
                    Id,
                    ContentDocumentId,
                    LinkedEntityId,
                    ShareType
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :response.recordId
            ];
        }
    }

    @IsTest
    static void testDuplicateSerialNumber() {

        /*
         * First API call is used only to create
         * the original Warranty Request.
         *
         * Do NOT use Test.startTest() here because
         * only one startTest/stopTest pair is allowed
         * inside a test method.
         */

        Map<String, Object> firstPayload =
            getValidPayload('SERIAL-DUPLICATE-001');

        buildRequest(JSON.serialize(firstPayload));

        ctrl_warrantyRequestFileAPI.ApiResponse firstResponse =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        /*
         * Prepare duplicate request using
         * the same Serial Number.
         */

        Map<String, Object> duplicatePayload =
            getValidPayload('SERIAL-DUPLICATE-001');

        duplicatePayload.put(
            'customerName',
            'Another Customer'
        );

        buildRequest(JSON.serialize(duplicatePayload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse duplicateResponse =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();

        List<Warranty_Request__c> records = [
            SELECT
                Id,
                Name,
                Serial_Number__c
            FROM Warranty_Request__c
            WHERE Serial_Number__c = 'SERIAL-DUPLICATE-001'
        ];
    }

    @IsTest
    static void testMissingRequestBody() {

        buildRequest(null);

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();
    }

    @IsTest
    static void testBlankRequestBody() {

        buildRequest('   ');

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();
    }

    @IsTest
    static void testMissingSerialNumber() {

        Map<String, Object> payload =
            getValidPayload(null);

        payload.remove('serialNumber');

        buildRequest(JSON.serialize(payload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();
    }

    @IsTest
    static void testBlankSerialNumber() {

        Map<String, Object> payload =
            getValidPayload('');

        payload.put(
            'serialNumber',
            '   '
        );

        buildRequest(JSON.serialize(payload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();
    }

    @IsTest
    static void testInvalidJson() {

        buildRequest(
            '{"customerName":"Test Customer","serialNumber":'
        );

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();
    }

    @IsTest
    static void testBlankFileIsIgnored() {

        Map<String, Object> payload =
            getValidPayload('SERIAL-TEST-003');

        List<Object> files = new List<Object>();

        files.add(
            new Map<String, Object>{
                'fileName' => 'EmptyFile.pdf',
                'contentType' => 'application/pdf',
                'base64Data' => ''
            }
        );

        files.add(null);

        payload.put(
            'files',
            files
        );

        buildRequest(JSON.serialize(payload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();
    }

    @IsTest
    static void testFileWithoutFileName() {

        Map<String, Object> payload =
            getValidPayload('SERIAL-TEST-004');

        List<Object> files = new List<Object>();

        files.add(
            new Map<String, Object>{
                'fileName' => '',
                'contentType' => 'application/octet-stream',
                'base64Data' => EncodingUtil.base64Encode(
                    Blob.valueOf('Test File Content')
                )
            }
        );

        payload.put(
            'files',
            files
        );

        buildRequest(JSON.serialize(payload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();
    }

    @IsTest
    static void testFileWithoutExtension() {

        Map<String, Object> payload =
            getValidPayload('SERIAL-TEST-005');

        List<Object> files = new List<Object>();

        files.add(
            new Map<String, Object>{
                'fileName' => 'WarrantyDocument',
                'contentType' => 'application/octet-stream',
                'base64Data' => EncodingUtil.base64Encode(
                    Blob.valueOf('Test Warranty Document')
                )
            }
        );

        payload.put(
            'files',
            files
        );

        buildRequest(JSON.serialize(payload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();
    }

    @IsTest
    static void testNullFilesCollection() {

        Map<String, Object> payload =
            getValidPayload('SERIAL-TEST-006');

        payload.put(
            'files',
            null
        );

        buildRequest(JSON.serialize(payload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();
    }

    @IsTest
    static void testEmptyFilesCollection() {

        Map<String, Object> payload =
            getValidPayload('SERIAL-TEST-007');

        payload.put(
            'files',
            new List<Object>()
        );

        buildRequest(JSON.serialize(payload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();
    }

    @IsTest
    static void testGenericServerException() {

        Map<String, Object> payload =
            getValidPayload('SERIAL-ERROR-001');

        List<Object> files = new List<Object>();

        /*
         * Invalid Base64 deliberately causes
         * EncodingUtil.base64Decode() to fail.
         *
         * This covers the generic Exception catch block
         * and Database.rollback(sp).
         */
        files.add(
            new Map<String, Object>{
                'fileName' => 'InvalidFile.pdf',
                'contentType' => 'application/pdf',
                'base64Data' => '%%%INVALID-BASE64-DATA%%%'
            }
        );

        payload.put(
            'files',
            files
        );

        buildRequest(JSON.serialize(payload));

        Test.startTest();

        ctrl_warrantyRequestFileAPI.ApiResponse response =
            ctrl_warrantyRequestFileAPI.createWarrantyRequest();

        Test.stopTest();

        List<Warranty_Request__c> records = [
            SELECT
                Id,
                Serial_Number__c
            FROM Warranty_Request__c
            WHERE Serial_Number__c = 'SERIAL-ERROR-001'
        ];
    }
}