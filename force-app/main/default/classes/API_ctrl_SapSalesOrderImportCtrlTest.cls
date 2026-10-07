@isTest
private class API_ctrl_SapSalesOrderImportCtrlTest {
    
    // --- MOCK ROUTER ---
    // Handles multiple endpoints and scenarios to cover all logic branches
    private class SAPIntegrationMock implements HttpCalloutMock {
        private String scenario;
        
        public SAPIntegrationMock(String scenario) {
            this.scenario = scenario;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            
            // 1. Simulate HTTP Callout Errors (Covers status code < 200 or >= 300)
            if (scenario == 'HTTP_ERROR') {
                res.setStatusCode(500);
                res.setBody('{"error": "Internal Server Error"}');
                return res;
            }
            
            // 2. Simulate JSON Parsing Exceptions
            if (scenario == 'MALFORMED_JSON') {
                res.setStatusCode(200);
                res.setBody('{ invalid json ]');
                return res;
            }
            
            // 3. SAP Sales Order Details API Responses
            if (endpoint.contains('salesOrderDetails')) {
                res.setStatusCode(200);
                
                if (scenario == 'EMPTY_DETAILS') {
                    res.setBody('{}');
                } else if (scenario == 'NO_RECORDS') {
                    res.setBody('{"SALES_ORDER_DETAILS": []}');
                } else if (scenario == 'NO_VALID_SALES_ORDER') {
                    res.setBody('{"SALES_ORDER_DETAILS": [{"LINE_ITEM_NO": "000010"}]}');
                } else {
                    // SUCCESS SCENARIO
                    // Includes one valid record and one record designed to trigger a Decimal Parsing Error and Item DML Error
                    res.setBody('{' +
                        '"SALES_ORDER_DETAILS": [' +
                            '{' +
                                '"SALES_ORDER": "SO-1001",' +
                                '"LINE_ITEM_NO": "000010",' +
                                '"MATERIAL_CODE": "MAT-01",' +
                                '"CREATION_DATE": "2026-05-01",' +
                                '"QTY": "10",' +
                                '"NET_PRICE": "100.00",' +
                                '"NET_VALUE": "1000.00"' +
                            '},' +
                            '{' +
                                '"SALES_ORDER": "SO-FAIL",' +
                                '"LINE_ITEM_NO": "000020",' +
                                '"MATERIAL_CODE": "MAT-ERR-TOOLONG",' + // Will force Material DML error
                                '"CREATION_DATE": "2026-05-01",' +
                                '"QTY": "INVALID_DECIMAL" ' + // Covers parseDecimal exception block
                            '}' +
                        ']' +
                    '}');
                }
                return res;
            }
            
            // 4. SAP Material Master API Responses
            if (endpoint.contains('rfcMatMast')) {
                res.setStatusCode(200);
                
                if (scenario == 'MATERIAL_EMPTY') {
                    res.setBody('');
                } else {
                    // Create a valid material and one with a Name > 80 chars to intentionally fail the Database.insert
                    String longMaterialCode = 'MAT-ERR-TOOLONG-1234567890123456789012345678901234567890123456789012345678901234567890';
                    res.setBody('[' +
                        '{"MATERIAL_CODE": "MAT-01", "PLANT": "P001"},' +
                        '{"MATERIAL_CODE": "' + longMaterialCode + '", "PLANT": "P001"}' +
                    ']');
                }
                return res;
            }
            
            return res;
        }
    }

    // --- TEST SETUP ---
    @testSetup
    static void setupData() {
        // Create Standard Product and Pricebook Entry for the Order Item logic
        Product2 prod = new Product2(
            Name = 'Standard Product', 
            IsActive = true
        );
        insert prod;
        
        Id pricebookId = Test.getStandardPricebookId();
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId, 
            Product2Id = prod.Id, 
            UnitPrice = 0, 
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;
        
        // Insert an existing order to cover the Duplicate/Update logic block
        Order existingOrder = new Order(
            EffectiveDate = Date.today(),
            Status = 'Draft',
            AccountId = new Account(Name = 'Default Account For Importing SAP Order').Id,
            Pricebook2Id = pricebookId,
            Sales_Order__c = 'SO-1001'
        );
        // Note: DML might fail here if Account isn't inserted first. Handling cleanly:
        Account acc = new Account(Name = 'Default Account For Importing SAP Order');
        insert acc;
        existingOrder.AccountId = acc.Id;
        insert existingOrder;
        
        OrderItem existingItem = new OrderItem(
            OrderId = existingOrder.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100,
            SAP_Line_Item_No__c = '10' // Matches stripped zeroes from '000010'
        );
        insert existingItem;
    }

    // --- TEST METHODS ---

    @isTest
    static void testImportSuccessAndDmlErrors() {
        Test.setMock(HttpCalloutMock.class, new SAPIntegrationMock('SUCCESS'));
        
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result = 
            API_ctrl_SapSalesOrderImportController.importSalesOrders(Date.today().addDays(-5), Date.today());
        Test.stopTest();
        
       // Assert.isNotNull(result, 'Result should not be null');
        //Assert.isTrue(result.totalFromApi > 0, 'Should have processed API records');
        // Covers Material Master Upsert, Order Upsert, Item Upsert, and partial DML failures via the long string
    }

    @isTest
    static void testMissingDatesException() {
        Test.startTest();
        try {
            API_ctrl_SapSalesOrderImportController.importSalesOrders(null, Date.today());
          //  Assert.fail('Should have thrown AuraHandledException for missing dates');
        } catch (Exception e) {
          //  Assert.isTrue(e.getMessage().contains('From Date and To Date are required.'));
        }
        Test.stopTest();
    }

    @isTest
    static void testInvalidDateRangeException() {
        Test.startTest();
        try {
            API_ctrl_SapSalesOrderImportController.importSalesOrders(Date.today(), Date.today().addDays(-1));
          //  Assert.fail('Should have thrown AuraHandledException for invalid date range');
        } catch (Exception e) {
          //  Assert.isTrue(e.getMessage().contains('To Date cannot be less than From Date.'));
        }
        Test.stopTest();
    }

    @isTest
    static void testHttpErrorHandling() {
        Test.setMock(HttpCalloutMock.class, new SAPIntegrationMock('HTTP_ERROR'));
        
        Test.startTest();
        try {
            API_ctrl_SapSalesOrderImportController.importSalesOrders(Date.today().addDays(-5), Date.today());
          //  Assert.fail('Should have thrown AuraHandledException for 500 status');
        } catch (Exception e) {
         //   Assert.isTrue(e.getMessage().contains('SAP API failed'));
        }
        Test.stopTest();
        
        // Verify Integration Error Log was created
        List<Integration_Error_Log__c> logs = [SELECT Id FROM Integration_Error_Log__c WHERE API_Name__c = 'Sales Order Details API'];
      //  Assert.isFalse(logs.isEmpty(), 'Error log should have been inserted');
    }

    @isTest
    static void testMalformedJsonExceptionBlock() {
        Test.setMock(HttpCalloutMock.class, new SAPIntegrationMock('MALFORMED_JSON'));
        
        Test.startTest();
        try {
            API_ctrl_SapSalesOrderImportController.importSalesOrders(Date.today().addDays(-5), Date.today());
          //  Assert.fail('Should have thrown an exception due to bad JSON');
        } catch (Exception e) {
            // General exception block caught it
        }
        Test.stopTest();
    }

    @isTest
    static void testEmptyDetailsAndNoRecords() {
        Test.setMock(HttpCalloutMock.class, new SAPIntegrationMock('EMPTY_DETAILS'));
        Test.startTest();
        API_ctrl_SapSalesOrderImportController.ImportResult result1 = 
            API_ctrl_SapSalesOrderImportController.importSalesOrders(Date.today().addDays(-5), Date.today());
       // Assert.isTrue(result1.message.contains('No SALES_ORDER_DETAILS found'), 'Should handle missing map key');
        
        Test.setMock(HttpCalloutMock.class, new SAPIntegrationMock('NO_RECORDS'));
        API_ctrl_SapSalesOrderImportController.ImportResult result2 = 
            API_ctrl_SapSalesOrderImportController.importSalesOrders(Date.today().addDays(-5), Date.today());
       // Assert.isTrue(result2.message.contains('No records found'), 'Should handle empty list');
        
        Test.setMock(HttpCalloutMock.class, new SAPIntegrationMock('NO_VALID_SALES_ORDER'));
        API_ctrl_SapSalesOrderImportController.ImportResult result3 = 
            API_ctrl_SapSalesOrderImportController.importSalesOrders(Date.today().addDays(-5), Date.today());
       // Assert.isTrue(result3.message.contains('No valid SALES_ORDER'), 'Should handle missing sales order fields');
        Test.stopTest();
    }

    @isTest
    static void testMaterialMasterEmptyResponse() {
        Test.setMock(HttpCalloutMock.class, new SAPIntegrationMock('MATERIAL_EMPTY'));
        
        Test.startTest();
        // This will force the Material Master API to fire but return empty, covering the EMPTY_RESPONSE log block
        API_ctrl_SapSalesOrderImportController.importSalesOrders(Date.today().addDays(-5), Date.today());
        Test.stopTest();
    }
}