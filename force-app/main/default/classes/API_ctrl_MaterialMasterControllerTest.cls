@IsTest
private class API_ctrl_MaterialMasterControllerTest {

    private class MockResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        MockResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    private static Map<String, Object> buildRow(
        String materialCode,
        String plant,
        String storageLocation,
        String salesOrg,
        String distributionChannel,
        String division,
        String materialDescription,
        String createdOn,
        String createdBy
    ) {
        return new Map<String, Object>{
            'MATERIAL_CODE' => materialCode,
            'MATERIAL_DESCRIPTION' => materialDescription,
            'CREATED_ON' => createdOn,
            'CREATED_BY' => createdBy,
            'MATERIAL_GROUP' => 'MG1',
            'MATERIAL_GROUP_DESCRIPTION' => 'Material Group 1',
            'UNIT_OF_MEASURE' => 'EA',
            'MATERIAL_TYPE' => 'MT1',
            'MATERIAL_TYPE_DESCRIPTION' => 'Material Type 1',
            'PLANT' => plant,
            'PLANT_DESCRIPTION' => 'Plant Desc',
            'STORAGE_LOCATION' => storageLocation,
            'STORAGE_LOCATION_DESCRIPTION' => 'Storage Desc',
            'SALES_ORG' => salesOrg,
            'DISTRIBUTION_CHANNEL' => distributionChannel,
            'DISTTRIBUTION_CHANNEL_DESC' => 'Dist Channel Desc',
            'DIVISION' => division,
            'DIVISION_DESCRIPTION' => 'Division Desc'
        };
    }

    private static String buildResponse(List<Map<String, Object>> rows) {
        return JSON.serialize(rows);
    }

    private static Material_Master__c seedMaterial(
        String materialCode,
        String plant,
        String storageLocation,
        String salesOrg,
        String distributionChannel,
        String division,
        String description
    ) {
        String uniqueKey =
            materialCode + '|' + plant + '|' + storageLocation + '|' +
            salesOrg + '|' + distributionChannel + '|' + division;

        Material_Master__c mm = new Material_Master__c(
            Name = materialCode,
            Unique_Key__c = uniqueKey,
            Created_By__c = 'Seed User',
            Created_On__c = '2026-06-01',
            Distribution_Channel__c = distributionChannel,
            Division__c = division,
            Material_Description__c = description,
            Material_Group__c = 'MG1',
            Material_Group_Description__c = 'Material Group 1',
            Material_Type__c = 'MT1',
            Material_Type_Description__c = 'Material Type 1',
            Plant__c = plant,
            Plant_Description__c = 'Plant Desc',
            Sales_Org__c = salesOrg,
            Storage_Location__c = storageLocation,
            Storage_Location_Description__c = 'Storage Desc',
            Unit_of_Measure__c = 'EA'
        );
        insert mm;
        return mm;
    }

    private static String makeLongString(Integer len) {
        String out = '';
        while (out.length() < len) {
            out += 'X';
        }
        return out;
    }

    @IsTest
    static void testValidation_DateRangeMissingDates() {
        Test.startTest();
        API_ctrl_MaterialMasterController.ResponseWrapper resp =
            API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster(
                'DateRange',
                null,
                null,
                null
            );
        Test.stopTest();


    }

    @IsTest
    static void testValidation_DateRangeInvalidOrder() {
        Test.startTest();
        API_ctrl_MaterialMasterController.ResponseWrapper resp =
            API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster(
                'DateRange',
                Date.today(),
                Date.today().addDays(-1),
                null
            );
        Test.stopTest();


    }

    @IsTest
    static void testValidation_MaterialCodeBlank() {
        Test.startTest();
        API_ctrl_MaterialMasterController.ResponseWrapper resp =
            API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster(
                'MaterialCode',
                null,
                null,
                '   '
            );
        Test.stopTest();


    }

    @IsTest
    static void testHttpNonSuccessResponse() {
        Test.setMock(HttpCalloutMock.class, new MockResponse(500, '{"error":"fail"}'));

        Test.startTest();
        API_ctrl_MaterialMasterController.ResponseWrapper resp =
            API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster(
                'DateRange',
                Date.today().addDays(-5),
                Date.today(),
                null
            );
        Test.stopTest();


    }

    @IsTest
    static void testEmptyResponseBody() {
        Test.setMock(HttpCalloutMock.class, new MockResponse(200, ''));

        Test.startTest();
        API_ctrl_MaterialMasterController.ResponseWrapper resp =
            API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster(
                'DateRange',
                Date.today().addDays(-5),
                Date.today(),
                null
            );
        Test.stopTest();


    }

    @IsTest
    static void testEmptySapArray() {
        Test.setMock(HttpCalloutMock.class, new MockResponse(200, '[]'));

        Test.startTest();
        API_ctrl_MaterialMasterController.ResponseWrapper resp =
            API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster(
                'DateRange',
                Date.today().addDays(-5),
                Date.today(),
                null
            );
        Test.stopTest();


    }

    @IsTest
    static void testCreateAndUpdateSuccess_DateRange() {
        Material_Master__c existing = seedMaterial(
            'MAT100',
            'PL01',
            'SL01',
            '1000',
            '10',
            '01',
            'Old Description'
        );

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            buildRow('MAT100', 'PL01', 'SL01', '1000', '10', '01', 'Updated Description', '2026-06-01', 'User A'),
            buildRow('MAT101', 'PL02', 'SL02', '1000', '10', '01', 'New Description', '2026-06-02', null)
        };

        Test.setMock(HttpCalloutMock.class, new MockResponse(200, buildResponse(rows)));

        Test.startTest();
        API_ctrl_MaterialMasterController.ResponseWrapper resp =
            API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster(
                'DateRange',
                Date.today().addDays(-5),
                Date.today(),
                null
            );
        Test.stopTest();



        Material_Master__c updated = [
            SELECT Id, Material_Description__c, Unique_Key__c
            FROM Material_Master__c
            WHERE Id = :existing.Id
            LIMIT 1
        ];
    }

    @IsTest
    static void testCreateSuccess_MaterialCodeFilter() {
        Test.setMock(
            HttpCalloutMock.class,
            new MockResponse(
                200,
                buildResponse(
                    new List<Map<String, Object>>{
                        buildRow('MAT200', 'PL10', 'SL10', '2000', '10', '02', 'Material 200', '2026-06-03', 'User B')
                    }
                )
            )
        );

        Test.startTest();
        API_ctrl_MaterialMasterController.ResponseWrapper resp =
            API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster(
                'MaterialCode',
                null,
                null,
                '  MAT200  '
            );
        Test.stopTest();


    }

    @IsTest
    static void testInsertDmlErrorOnLongMaterialCode() {
        String longCode = makeLongString(85);

        Test.setMock(
            HttpCalloutMock.class,
            new MockResponse(
                200,
                buildResponse(
                    new List<Map<String, Object>>{
                        buildRow(longCode, 'PL99', 'SL99', '3000', '10', '03', 'Too Long Name', '2026-06-04', 'User C')
                    }
                )
            )
        );

        Test.startTest();
        API_ctrl_MaterialMasterController.ResponseWrapper resp =
            API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster(
                'DateRange',
                Date.today().addDays(-5),
                Date.today(),
                null
            );
        Test.stopTest();


    }

    @IsTest
    static void testMalformedJsonReturnsCatchPath() {
        Test.setMock(HttpCalloutMock.class, new MockResponse(200, '{bad json'));

        Test.startTest();
        API_ctrl_MaterialMasterController.ResponseWrapper resp =
            API_ctrl_MaterialMasterController.fetchAndStoreMaterialMaster(
                'DateRange',
                Date.today().addDays(-5),
                Date.today(),
                null
            );
        Test.stopTest();

    }
}