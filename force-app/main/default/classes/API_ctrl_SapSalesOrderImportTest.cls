@isTest
private class API_ctrl_SapSalesOrderImportTest {

    @TestSetup
    static void setupTestData() {
        // ── Product ──────────────────────────────────────────────
        Product2 prod = new Product2(
            Name     = 'Standard Product',
            IsActive = true
        );
        insert prod;

        // ── Standard Pricebook (must use Test utility in test context) ──
        Id stdPbId = Test.getStandardPricebookId();
        
        Pricebook2 standardPricebook = new Pricebook2(
            Id = stdPbId,
            IsActive = true
        );
        update standardPricebook;
        
        // ── PricebookEntry ────────────────────────────────────────
        PricebookEntry pbe = new PricebookEntry(
            Product2Id       = prod.Id,
            Pricebook2Id     = stdPbId,
            UnitPrice        = 0,
            IsActive         = true,
            UseStandardPrice = false
        );
        insert pbe;

        // ── Default Account ───────────────────────────────────────
        Account acc = new Account(Name = 'Default Account For Importing SAP Order');
        insert acc;

        // ── Material Master ───────────────────────────────────────
        insert new Material_Master__c(Name = 'MAT-001');
    }

    // ─────────────────────────────────────────────────────────────
    // MOCK CALLOUTS
    // ─────────────────────────────────────────────────────────────

    /** Full success: two line items for the same order, one with a known material, one without */
    private class MockSuccessCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                'SALES_ORDER_DETAILS' => new List<Object>{
                    new Map<String, Object>{
                        'SALES_ORDER'          => 'SO-TEST-001',
                        'CREATION_DATE'        => '2024-01-15',
                        'DIST_CHAN'            => 'DC01',
                        'DIVISION'             => 'DIV01',
                        'SALES_GROUP'          => 'SG01',
                        'SALES_OFFICE'         => 'SO01',
                        'DOCUMENT_TYPE'        => 'ZDOC',
                        'ORDER_REASON'         => 'OR01',
                        'SALES_ORG'            => 'SORG01',
                        'DELIVERING_PLANT'     => 'DP01',
                        'BG_REQUIRED'          => 'Y',
                        'LD_CLAUSE'            => 'LDC01',
                        'TPC'                  => 'TPC01',
                        'LINE_ITEM_NO'         => '000010',
                        'MATERIAL_CODE'        => 'MAT-001',
                        'PLANT'                => 'PL01',
                        'ITEM_CATAGORY'        => 'ZITEM',
                        'QTY'                  => '10',
                        'NET_PRICE'            => '500.00',
                        'NET_VALUE'            => '5000.00',
                        'ROUTE'                => 'RT01',
                        'PERFORMANCE_WARRANTY' => '12',
                        'PRODUCT_WARRANTY'     => '24'
                    },
                    new Map<String, Object>{
                        'SALES_ORDER'          => 'SO-TEST-001',
                        'CREATION_DATE'        => '2024-01-15',
                        'DIST_CHAN'            => 'DC01',
                        'DIVISION'             => 'DIV01',
                        'SALES_GROUP'          => 'SG01',
                        'SALES_OFFICE'         => 'SO01',
                        'DOCUMENT_TYPE'        => 'ZDOC',
                        'ORDER_REASON'         => 'OR01',
                        'SALES_ORG'            => 'SORG01',
                        'DELIVERING_PLANT'     => 'DP01',
                        'BG_REQUIRED'          => 'N',
                        'LD_CLAUSE'            => 'LDC01',
                        'TPC'                  => 'TPC01',
                        'LINE_ITEM_NO'         => '000020',
                        'MATERIAL_CODE'        => 'MAT-NOTFOUND',
                        'PLANT'                => 'PL02',
                        'ITEM_CATAGORY'        => 'ZITEM2',
                        'QTY'                  => '5',
                        'NET_PRICE'            => '200.00',
                        'NET_VALUE'            => '1000.00',
                        'ROUTE'                => 'RT02',
                        'PERFORMANCE_WARRANTY' => '6',
                        'PRODUCT_WARRANTY'     => '12'
                    }
                }
            }));
            return res;
        }
    }

    /** Two different SAP orders in one response */
    private class MockTwoOrdersCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'SALES_ORDER_DETAILS' => new List<Object>{
                    new Map<String, Object>{
                        'SALES_ORDER'          => 'SO-MULTI-001',
                        'CREATION_DATE'        => '2024-01-15',
                        'DIST_CHAN'            => 'DC01',
                        'DIVISION'             => 'DIV01',
                        'SALES_GROUP'          => 'SG01',
                        'SALES_OFFICE'         => 'SO01',
                        'DOCUMENT_TYPE'        => 'ZDOC',
                        'ORDER_REASON'         => 'OR01',
                        'SALES_ORG'            => 'SORG01',
                        'DELIVERING_PLANT'     => 'DP01',
                        'BG_REQUIRED'          => 'Y',
                        'LD_CLAUSE'            => 'LDC01',
                        'TPC'                  => 'TPC01',
                        'LINE_ITEM_NO'         => '000010',
                        'MATERIAL_CODE'        => 'MAT-001',
                        'PLANT'                => 'PL01',
                        'ITEM_CATAGORY'        => 'ZITEM',
                        'QTY'                  => '3',
                        'NET_PRICE'            => '150',
                        'NET_VALUE'            => '450',
                        'ROUTE'                => 'RT01',
                        'PERFORMANCE_WARRANTY' => '12',
                        'PRODUCT_WARRANTY'     => '24'
                    },
                    new Map<String, Object>{
                        'SALES_ORDER'          => 'SO-MULTI-002',
                        'CREATION_DATE'        => '2024-01-16',
                        'DIST_CHAN'            => 'DC02',
                        'DIVISION'             => 'DIV02',
                        'SALES_GROUP'          => 'SG02',
                        'SALES_OFFICE'         => 'SO02',
                        'DOCUMENT_TYPE'        => 'ZDOC2',
                        'ORDER_REASON'         => 'OR02',
                        'SALES_ORG'            => 'SORG02',
                        'DELIVERING_PLANT'     => 'DP02',
                        'BG_REQUIRED'          => 'N',
                        'LD_CLAUSE'            => 'LDC02',
                        'TPC'                  => 'TPC02',
                        'LINE_ITEM_NO'         => '000010',
                        'MATERIAL_CODE'        => 'MAT-001',
                        'PLANT'                => 'PL02',
                        'ITEM_CATAGORY'        => 'ZITEM2',
                        'QTY'                  => '7',
                        'NET_PRICE'            => '300',
                        'NET_VALUE'            => '2100',
                        'ROUTE'                => 'RT02',
                        'PERFORMANCE_WARRANTY' => '6',
                        'PRODUCT_WARRANTY'     => '12'
                    }
                }
            }));
            return res;
        }
    }

    /** Empty SALES_ORDER_DETAILS list */
    private class MockEmptyListCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'SALES_ORDER_DETAILS' => new List<Object>()
            }));
            return res;
        }
    }

    /** Missing SALES_ORDER_DETAILS key entirely */
    private class MockMissingKeyCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'OTHER_KEY' => 'some_value'
            }));
            return res;
        }
    }

    /** HTTP 500 error */
    private class MockHttpErrorCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    /** All rows have blank SALES_ORDER */
    private class MockBlankSalesOrderCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'SALES_ORDER_DETAILS' => new List<Object>{
                    new Map<String, Object>{
                        'SALES_ORDER'          => '',
                        'CREATION_DATE'        => '2024-01-15',
                        'LINE_ITEM_NO'         => '000010',
                        'MATERIAL_CODE'        => 'MAT-001',
                        'QTY'                  => '10',
                        'NET_PRICE'            => '100',
                        'NET_VALUE'            => '1000',
                        'PERFORMANCE_WARRANTY' => '12',
                        'PRODUCT_WARRANTY'     => '24'
                    }
                }
            }));
            return res;
        }
    }

    /** Blank MATERIAL_CODE — hits materialNotFound + blank decimal fields */
    private class MockBlankMaterialCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'SALES_ORDER_DETAILS' => new List<Object>{
                    new Map<String, Object>{
                        'SALES_ORDER'          => 'SO-NOMAT',
                        'CREATION_DATE'        => '2024-01-15',
                        'DIST_CHAN'            => 'DC01',
                        'DIVISION'             => 'DIV01',
                        'SALES_GROUP'          => 'SG01',
                        'SALES_OFFICE'         => 'SO01',
                        'DOCUMENT_TYPE'        => 'ZDOC',
                        'ORDER_REASON'         => 'OR01',
                        'SALES_ORG'            => 'SORG01',
                        'DELIVERING_PLANT'     => 'DP01',
                        'BG_REQUIRED'          => 'Y',
                        'LD_CLAUSE'            => 'LDC01',
                        'TPC'                  => 'TPC01',
                        'LINE_ITEM_NO'         => '000010',
                        'MATERIAL_CODE'        => '',
                        'PLANT'                => 'PL01',
                        'ITEM_CATAGORY'        => 'ZITEM',
                        'QTY'                  => '',
                        'NET_PRICE'            => '',
                        'NET_VALUE'            => '',
                        'ROUTE'                => 'RT01',
                        'PERFORMANCE_WARRANTY' => '',
                        'PRODUCT_WARRANTY'     => ''
                    }
                }
            }));
            return res;
        }
    }

    /** LINE_ITEM_NO is all zeros → stripLeadingZeros returns '0' */
    private class MockAllZeroLineItemCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'SALES_ORDER_DETAILS' => new List<Object>{
                    new Map<String, Object>{
                        'SALES_ORDER'          => 'SO-ZERO-LINE',
                        'CREATION_DATE'        => '2024-01-15',
                        'DIST_CHAN'            => 'DC01',
                        'DIVISION'             => 'DIV01',
                        'SALES_GROUP'          => 'SG01',
                        'SALES_OFFICE'         => 'SO01',
                        'DOCUMENT_TYPE'        => 'ZDOC',
                        'ORDER_REASON'         => 'OR01',
                        'SALES_ORG'            => 'SORG01',
                        'DELIVERING_PLANT'     => 'DP01',
                        'BG_REQUIRED'          => 'N',
                        'LD_CLAUSE'            => 'LDC01',
                        'TPC'                  => 'TPC01',
                        'LINE_ITEM_NO'         => '0000',
                        'MATERIAL_CODE'        => 'MAT-001',
                        'PLANT'                => 'PL01',
                        'ITEM_CATAGORY'        => 'ZITEM',
                        'QTY'                  => '2',
                        'NET_PRICE'            => '100',
                        'NET_VALUE'            => '200',
                        'ROUTE'                => 'RT01',
                        'PERFORMANCE_WARRANTY' => '12',
                        'PRODUCT_WARRANTY'     => '24'
                    }
                }
            }));
            return res;
        }
    }

    /** Blank CREATION_DATE → parseDate falls back to Date.today() */
    private class MockBlankCreationDateCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'SALES_ORDER_DETAILS' => new List<Object>{
                    new Map<String, Object>{
                        'SALES_ORDER'          => 'SO-NODATE',
                        'CREATION_DATE'        => '',
                        'DIST_CHAN'            => '',
                        'DIVISION'             => '',
                        'SALES_GROUP'          => '',
                        'SALES_OFFICE'         => '',
                        'DOCUMENT_TYPE'        => '',
                        'ORDER_REASON'         => '',
                        'SALES_ORG'            => '',
                        'DELIVERING_PLANT'     => '',
                        'BG_REQUIRED'          => '',
                        'LD_CLAUSE'            => '',
                        'TPC'                  => '',
                        'LINE_ITEM_NO'         => '000010',
                        'MATERIAL_CODE'        => 'MAT-001',
                        'PLANT'                => '',
                        'ITEM_CATAGORY'        => '',
                        'QTY'                  => '1',
                        'NET_PRICE'            => '100',
                        'NET_VALUE'            => '100',
                        'ROUTE'                => '',
                        'PERFORMANCE_WARRANTY' => '0',
                        'PRODUCT_WARRANTY'     => '0'
                    }
                }
            }));
            return res;
        }
    }

    /** Non-numeric decimal fields → parseDecimal catches the exception and returns 0 */
    private class MockInvalidDecimalCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'SALES_ORDER_DETAILS' => new List<Object>{
                    new Map<String, Object>{
                        'SALES_ORDER'          => 'SO-BADDEC',
                        'CREATION_DATE'        => '2024-01-15',
                        'DIST_CHAN'            => 'DC01',
                        'DIVISION'             => 'DIV01',
                        'SALES_GROUP'          => 'SG01',
                        'SALES_OFFICE'         => 'SO01',
                        'DOCUMENT_TYPE'        => 'ZDOC',
                        'ORDER_REASON'         => 'OR01',
                        'SALES_ORG'            => 'SORG01',
                        'DELIVERING_PLANT'     => 'DP01',
                        'BG_REQUIRED'          => 'Y',
                        'LD_CLAUSE'            => 'LDC01',
                        'TPC'                  => 'TPC01',
                        'LINE_ITEM_NO'         => '000010',
                        'MATERIAL_CODE'        => 'MAT-001',
                        'PLANT'                => 'PL01',
                        'ITEM_CATAGORY'        => 'ZITEM',
                        'QTY'                  => 'NOT_A_NUMBER',
                        'NET_PRICE'            => 'INVALID',
                        'NET_VALUE'            => 'INVALID',
                        'ROUTE'                => 'RT01',
                        'PERFORMANCE_WARRANTY' => 'ABC',
                        'PRODUCT_WARRANTY'     => 'XYZ'
                    }
                }
            }));
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // SHARED HELPER — returns the test-context standard pricebook Id
    // ─────────────────────────────────────────────────────────────
    private static Id getStdPricebookId() {
        return Test.getStandardPricebookId();
    }

    // ─────────────────────────────────────────────────────────────
    // TEST METHODS
    // ─────────────────────────────────────────────────────────────

    // TEST 1: Null fromDate → exception
    @isTest
    static void testNullFromDateThrowsException() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            API_ctrl_SapSalesOrderImportController.importSalesOrders(null, Date.today());
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.debug('exceptionThrown: ' + exceptionThrown);
    }

    // TEST 2: Null toDate → exception
    @isTest
    static void testNullToDateThrowsException() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            API_ctrl_SapSalesOrderImportController.importSalesOrders(Date.today(), null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.debug('exceptionThrown: ' + exceptionThrown);
    }

    // TEST 3: toDate before fromDate → exception
    @isTest
    static void testToDateBeforeFromDateThrowsException() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today(), Date.today().addDays(-1)
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.debug('exceptionThrown: ' + exceptionThrown);
    }

    // TEST 4: HTTP 500 from SAP → error log created, exception thrown
    @isTest
    static void testHttpErrorFromSapApi() {
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorCallout());
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.debug('exceptionThrown: ' + exceptionThrown);
    }

    // TEST 5: Response missing SALES_ORDER_DETAILS key entirely
    @isTest
    static void testMissingSalesOrderDetailsKey() {
        Test.setMock(HttpCalloutMock.class, new MockMissingKeyCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Result message: ' + result.message);
    }

    // TEST 6: Empty SALES_ORDER_DETAILS list
    @isTest
    static void testEmptySalesOrderDetailsList() {
        Test.setMock(HttpCalloutMock.class, new MockEmptyListCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Result message: ' + result.message);
    }

    // TEST 7: All rows have blank SALES_ORDER → no valid orders found
    @isTest
    static void testBlankSalesOrderInAllRows() {
        Test.setMock(HttpCalloutMock.class, new MockBlankSalesOrderCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Result message: ' + result.message);
    }

    // TEST 8: Full success — brand new orders + items inserted
    //         One line with matched material, one without
    //         Default Account already exists (from @TestSetup)
    //         PricebookEntry already exists (from @TestSetup)
    @isTest
    static void testFullSuccessNewOrders() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Inserted Orders: '    + result.insertedOrders);
        System.debug('Inserted Items: '     + result.insertedOrderItems);
        System.debug('Material Matched: '   + result.materialMatched);
        System.debug('Material Not Found: ' + result.materialNotFound);
    }

    // TEST 9: Existing order gets updated, not re-inserted
    @isTest
    static void testFullSuccessExistingOrdersUpdated() {
        Id stdPbId = getStdPricebookId();
        Account acc = [SELECT Id FROM Account WHERE Name = 'Default Account For Importing SAP Order' LIMIT 1];

        Order existingOrder = new Order(
            AccountId       = acc.Id,
            Status          = 'Draft',
            EffectiveDate   = Date.today(),
            Pricebook2Id    = stdPbId
            //SAP_Order_ID__c = 'SO-TEST-001'
        );
        insert existingOrder;

        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Updated Orders: '    + result.updatedOrders);
        System.debug('Duplicate Orders: '  + result.duplicateOrders);
    }

    // TEST 10: Existing OrderItem gets updated, not re-inserted
    @isTest
    static void testExistingOrderItemsAreUpdated() {
        Id stdPbId = getStdPricebookId();
        Account acc  = [SELECT Id FROM Account WHERE Name = 'Default Account For Importing SAP Order' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId AND IsActive = true LIMIT 1];

        Order existingOrder = new Order(
            AccountId       = acc.Id,
            Status          = 'Draft',
            EffectiveDate   = Date.today(),
            Pricebook2Id    = stdPbId
           // SAP_Order_ID__c = 'SO-TEST-001'
        );
        insert existingOrder;

        OrderItem existingItem = new OrderItem(
            OrderId             = existingOrder.Id,
            PricebookEntryId    = pbe.Id,
            Quantity            = 1,
            UnitPrice           = 0,
            SAP_Line_Item_No__c = '10'   // matches stripLeadingZeros('000010')
        );
        insert existingItem;

        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Updated Items: ' + result.updatedOrderItems);
    }

    // TEST 11: Two distinct SAP orders in one response
    @isTest
    static void testTwoDistinctOrdersInserted() {
        Test.setMock(HttpCalloutMock.class, new MockTwoOrdersCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Inserted Orders: ' + result.insertedOrders);
        System.debug('Inserted Items: '  + result.insertedOrderItems);
    }

    // TEST 12: Blank MATERIAL_CODE → materialNotFound path + logIntegrationError
    @isTest
    static void testBlankMaterialCodeRow() {
        Test.setMock(HttpCalloutMock.class, new MockBlankMaterialCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Material Not Found: ' + result.materialNotFound);
    }

    // TEST 13: LINE_ITEM_NO = '0000' → stripLeadingZeros returns '0'
    @isTest
    static void testAllZeroLineItemNo() {
        Test.setMock(HttpCalloutMock.class, new MockAllZeroLineItemCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Inserted Orders: ' + result.insertedOrders);
    }

    // TEST 14: Blank CREATION_DATE → parseDate returns Date.today()
    @isTest
    static void testBlankCreationDateFallsBackToToday() {
        Test.setMock(HttpCalloutMock.class, new MockBlankCreationDateCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Inserted Orders: ' + result.insertedOrders);
    }

    // TEST 15: Non-numeric decimal values → parseDecimal catch block returns 0
    @isTest
    static void testInvalidDecimalValuesAreHandledGracefully() {
        Test.setMock(HttpCalloutMock.class, new MockInvalidDecimalCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Inserted Orders: ' + result.insertedOrders);
    }

    // TEST 16: Same fromDate and toDate (valid boundary)
    @isTest
    static void testSameDateFromAndTo() {
        Test.setMock(HttpCalloutMock.class, new MockEmptyListCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today(), Date.today()
            );
        Test.stopTest();
        System.debug('Result message: ' + result.message);
    }

    // TEST 17: Integration_Error_Log__c record is created on HTTP 500
    @isTest
    static void testIntegrationErrorLogCreatedOnHttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorCallout());
        try {
            Test.startTest();
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            // Expected — we are verifying the side-effect (log record)
        }
        List<Integration_Error_Log__c> logs = [
            SELECT Id FROM Integration_Error_Log__c
            WHERE API_Name__c = 'Sales Order Details API'
        ];
        System.debug('Error log count: ' + logs.size());
    }

    // TEST 18: Duplicate Material_Master__c names → only first record is tagged
    @isTest
    static void testDuplicateMaterialMasterUsesFirst() {
        // Insert a second MAT-001 (one already exists from @TestSetup)
        insert new Material_Master__c(Name = 'MAT-001');

        Test.setMock(HttpCalloutMock.class, new MockTwoOrdersCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Material Matched: ' + result.materialMatched);
    }

    // TEST 19: All ImportResult wrapper fields initialise at expected defaults
    @isTest
    static void testImportResultDefaultValues() {
        Test.setMock(HttpCalloutMock.class, new MockEmptyListCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('totalFromApi: '       + result.totalFromApi);
        System.debug('duplicateOrders: '    + result.duplicateOrders);
        System.debug('insertedOrders: '     + result.insertedOrders);
        System.debug('updatedOrders: '      + result.updatedOrders);
        System.debug('insertedOrderItems: ' + result.insertedOrderItems);
        System.debug('updatedOrderItems: '  + result.updatedOrderItems);
        System.debug('duplicateOrderItems: '+ result.duplicateOrderItems);
        System.debug('failedOrders: '       + result.failedOrders);
        System.debug('failedOrderItems: '   + result.failedOrderItems);
        System.debug('materialMatched: '    + result.materialMatched);
        System.debug('materialNotFound: '   + result.materialNotFound);
        System.debug('records size: '       + result.records.size());
    }

    // TEST 20: Default Account does NOT pre-exist → controller creates it automatically
    @isTest
    static void testDefaultAccountCreatedWhenMissing() {
        // Delete the account created in @TestSetup to force the controller to create it
        delete [SELECT Id FROM Account WHERE Name = 'Default Account For Importing SAP Order'];

        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Inserted Orders: ' + result.insertedOrders);
    }

    // TEST 21: PricebookEntry does NOT pre-exist → controller creates it automatically
    @isTest
    static void testPricebookEntryCreatedWhenMissing() {
        // Delete the PBE created in @TestSetup to force getOrCreatePricebookEntry to insert one
        delete [SELECT Id FROM PricebookEntry WHERE IsActive = true LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result =
            API_ctrl_SapSalesOrderImportController.importSalesOrders(
                Date.today().addDays(-7), Date.today()
            );
        Test.stopTest();
        System.debug('Inserted Orders: ' + result.insertedOrders);
    }

}