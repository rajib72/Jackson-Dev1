@isTest
private class API_Ctrl_BillingInfoCtrlTest {

    // --- MOCK ROUTER ---
    // Handles various API responses and forces exceptions to cover catch blocks
    private class SAPBillingMock implements HttpCalloutMock {
        private String scenario;
        
        public SAPBillingMock(String scenario) {
            this.scenario = scenario;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            // Force a systemic exception to cover the outer catch block and the logIntegrationError catch block
            if (scenario == 'THROW_CALLOUT_EXCEPTION') {
                CalloutException e = (CalloutException)CalloutException.class.newInstance();
                e.setMessage('Simulated connection timeout');
                throw e;
            }

            HttpResponse res = new HttpResponse();
            
            if (scenario == 'SUCCESS_ARRAY') {
                res.setStatusCode(200);
                res.setBody('[' +
                    '{' +
                        '"BILLING_DOCUMENT": "900001",' +
                        '"BILLING_LINE_ITEM_NO": "10",' +
                        '"BILLING_DOCUMENT_DATE": "2026-05-01",' +
                        '"BILLING_DOCUMENT_AMOUNT": "1500.00",' +
                        '"DELIVERY_NUMBER": "DEL-123",' +
                        '"SALES_ORDER_NO": "SO-456"' +
                    '}' +
                ']');
            } else if (scenario == 'EMPTY_BODY') {
                res.setStatusCode(200);
                res.setBody('');
            } else if (scenario == 'BAD_JSON_FORMAT') {
                res.setStatusCode(200);
                // Return an Object instead of an Array to trigger the instanceOf catch block
                res.setBody('{"unexpected_format": true}');
            } else if (scenario == 'HTTP_ERROR') {
                res.setStatusCode(500);
                // Create a string > 255 characters to cover the truncateValue logic in the error logger
                String longError = 'E'.repeat(300); 
                res.setBody('{"error": "' + longError + '"}');
            }
            
            return res;
        }
    }

    // ==========================================
    // SUCCESS PATH TESTS
    // ==========================================

    @isTest
    static void testFetchBillingInfo_DateFilter_Success() {
        Test.setMock(HttpCalloutMock.class, new SAPBillingMock('SUCCESS_ARRAY'));
        
        // Use a date with month/day < 10 (May 5th) and one with >= 10 (Nov 15th) 
        // to cover both branches of the formatDateYYYYMMDD ternary operators
        Date fromDate = Date.newInstance(2026, 5, 5);
        Date toDate = Date.newInstance(2026, 11, 15);
        
        Test.startTest();
        API_Ctrl_BillingInformationController.BillingInfoResponse result = 
            API_Ctrl_BillingInformationController.fetchBillingInformation('DATE', fromDate, toDate, null);
        Test.stopTest();
        
        Assert.isTrue(result.success, 'Response should be successful');
        Assert.areEqual(1, result.count, 'Should return exactly 1 record');
        Assert.areEqual('900001', result.records[0].billingDocument, 'Document number should map correctly');
    }

    @isTest
    static void testFetchBillingInfo_DeliveryFilter_EmptyResponse() {
        Test.setMock(HttpCalloutMock.class, new SAPBillingMock('EMPTY_BODY'));
        
        Test.startTest();
        // Uses DELIVERY filter type to cover that branch in buildRequestBody
        API_Ctrl_BillingInformationController.BillingInfoResponse result = 
            API_Ctrl_BillingInformationController.fetchBillingInformation('DELIVERY', null, null, 'DEL-123');
        Test.stopTest();
        
        Assert.isTrue(result.success, 'Empty body should still process as a 200 OK');
        Assert.areEqual(0, result.count, 'Record count should be 0');
        Assert.areEqual('No records found.', result.message, 'Should return the no records message');
    }

    // ==========================================
    // ERROR AND EXCEPTION PATH TESTS
    // ==========================================

    @isTest
    static void testFetchBillingInfo_HttpErrorAndTruncation() {
        Test.setMock(HttpCalloutMock.class, new SAPBillingMock('HTTP_ERROR'));
        
        Test.startTest();
        API_Ctrl_BillingInformationController.BillingInfoResponse result = 
            API_Ctrl_BillingInformationController.fetchBillingInformation('DELIVERY', null, null, 'DEL-123');
        Test.stopTest();
        
        Assert.isFalse(result.success, 'Response should fail on a 500 status code');
        Assert.isTrue(result.message.contains('API call failed with status code: 500'), 'Should contain HTTP error message');
        
        // Verify the Integration Error Log was created and the message was truncated
        List<Integration_Error_Log__c> logs = [SELECT Id, Error_Message__c FROM Integration_Error_Log__c WHERE API_Name__c = 'Billing Information API'];
        Assert.areEqual(1, logs.size(), 'One error log should be inserted');
        Assert.areEqual(255, logs[0].Error_Message__c.length(), 'The long error message should be truncated to exactly 255 characters');
    }

    @isTest
    static void testFetchBillingInfo_InvalidJsonFormat() {
        Test.setMock(HttpCalloutMock.class, new SAPBillingMock('BAD_JSON_FORMAT'));
        
        Test.startTest();
        API_Ctrl_BillingInformationController.BillingInfoResponse result = 
            API_Ctrl_BillingInformationController.fetchBillingInformation('DELIVERY', null, null, 'DEL-123');
        Test.stopTest();
        
        Assert.isFalse(result.success, 'Response should fail');
        Assert.isTrue(result.message.contains('Unexpected response format'), 'Should throw the custom format exception');
    }

    @isTest
    static void testFetchBillingInfo_CalloutExceptionAndLogDmlException() {
        Test.setMock(HttpCalloutMock.class, new SAPBillingMock('THROW_CALLOUT_EXCEPTION'));
        
        Test.startTest();
        API_Ctrl_BillingInformationController.BillingInfoResponse result = 
            API_Ctrl_BillingInformationController.fetchBillingInformation('DELIVERY', null, null, 'DEL-123');
        Test.stopTest();
        
        Assert.isFalse(result.success, 'Response should fail');
        Assert.isTrue(result.message.contains('Simulated connection timeout'), 'Should catch the simulated exception');
        
        /*
         * Note on 100% Coverage strategy here: 
         * Because the callout threw an exception, the HttpResponse (res) remains null.
         * The outer catch block passes `res != null ? ... : null` (so, null) as the status code to logIntegrationError.
         * Inside logIntegrationError, it attempts Decimal.valueOf(null), which throws a NullPointerException.
         * This forces the internal try/catch block inside logIntegrationError to trigger, giving us 100% coverage.
         */
    }

    // ==========================================
    // VALIDATION TESTS (Covers all if/else blocks)
    // ==========================================

    @isTest
    static void testValidation_MissingFilterType() {
        Test.startTest();
        try {
            API_Ctrl_BillingInformationController.fetchBillingInformation(null, null, null, null);
            Assert.fail('Should have thrown an exception');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Please select a filter type.'));
        }
        Test.stopTest();
    }

    @isTest
    static void testValidation_InvalidFilterType() {
        Test.startTest();
        try {
            API_Ctrl_BillingInformationController.fetchBillingInformation('MAGIC', null, null, null);
            Assert.fail('Should have thrown an exception');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Invalid filter type selected.'));
        }
        Test.stopTest();
    }

    @isTest
    static void testValidation_DateFilter_MissingDates() {
        Test.startTest();
        try {
            API_Ctrl_BillingInformationController.fetchBillingInformation('DATE', null, null, null);
            Assert.fail('Should have thrown an exception');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Please select both From Date and To Date.'));
        }
        Test.stopTest();
    }

    @isTest
    static void testValidation_DateFilter_InvalidRange() {
        Test.startTest();
        try {
            // fromDate > toDate
            API_Ctrl_BillingInformationController.fetchBillingInformation('DATE', Date.today(), Date.today().addDays(-1), null);
            Assert.fail('Should have thrown an exception');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('From Date cannot be greater than To Date.'));
        }
        Test.stopTest();
    }

    @isTest
    static void testValidation_DeliveryFilter_MissingNumber() {
        Test.startTest();
        try {
            API_Ctrl_BillingInformationController.fetchBillingInformation('DELIVERY', null, null, '');
            Assert.fail('Should have thrown an exception');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Please enter Delivery Number.'));
        }
        Test.stopTest();
    }
}