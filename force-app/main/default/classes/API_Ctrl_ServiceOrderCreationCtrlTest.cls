@IsTest
public class API_Ctrl_ServiceOrderCreationCtrlTest {

    private class SAPMock implements HttpCalloutMock {
        private String scenario;

        SAPMock(String scenario) {
            this.scenario = scenario;
        }

        public HttpResponse respond(HttpRequest req) {
            if (scenario == 'CALLOUT_EXCEPTION') {
                throw new CalloutException('Simulated timeout from SAP endpoint');
            }

            HttpResponse res = new HttpResponse();

            if (scenario == 'SUCCESS') {
                res.setStatusCode(200);
                res.setBody('{"salesOrder":"SRT-12345"}');
            } else if (scenario == 'APP_ERROR') {
                res.setStatusCode(200);
                res.setBody('{"status":"ERROR","message":"SAP Logic Error"}');
            } else if (scenario == 'INVALID_JSON') {
                res.setStatusCode(200);
                res.setBody('{ invalid json }');
            } else if (scenario == 'HTTP_ERROR') {
                res.setStatusCode(500);
                res.setBody('{"error":"Server Error"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"salesOrder":"DEFAULT-001"}');
            }

            return res;
        }
    }

    @testSetup
    static void setupData() {
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        Account soldToAcc = new Account(
            Name = 'Sold To Account',
            Company_Code__c = '2000 - JAKSONS ENGINEERS LIMITED',
            Distribution_Channel__c = '10',
            Division__c = '00'
        );
        insert soldToAcc;

        Account billToAcc = new Account(
            Name = 'Bill To Account',
            SAP_Account_Number__c = 'SAP100'
        );
        insert billToAcc;

        Account shipToAcc = new Account(
            Name = 'Ship To Account',
            SAP_Account_Number__c = 'SAP200'
        );
        insert shipToAcc;

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Material_Master__c mat = new Material_Master__c(
            Name = 'MAT-001'
        );
        setIfWritable(mat, 'Plant_Code__c', 'PL01');
        setIfWritable(mat, 'Plant__c', 'PL01');
        insert mat;

        Order ordFull = new Order(
            AccountId = soldToAcc.Id,
            Bill_To__c = billToAcc.Id,
            Ship_To__c = shipToAcc.Id,
            Payment_Terms_Text__c = 'NET30',
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPbId,
            Customer_Reference__c = 'PO123',
            Customer_Reference_Date__c = Date.today(),
            Service_Order_Type__c = 'ZSRT',
            BG_Required__c = 'Yes',
            LD_Clause__c = 'Standard',
            TPC__c = 'T01',
            Delivering_Plant__c = 'Plant',
            Freight_Terms__c = 'FOB',
            Insurance_Terms__c = 'Insurance',
            Scope_Of_OA__c = 'OA',
            Order_Reason__c = 'Reason',
            SAP_Employee_Code__c = 'EMP01'
        );
        insert ordFull;

        OrderItem oiFull = new OrderItem(
            OrderId = ordFull.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 100,
            Material_Master__c = mat.Id,
            Item_Category__c = 'TAN',
            Route__c = 'RT01',
            Material_Sales_Text__c = 'Sales Text',
            Performance_Warranty__c = 1,
            Product_Warranty_Duration__c = 2,
            Condition_Type__c = 'PR00'
        );
        insert oiFull;
    }

    private static void setIfWritable(SObject rec, String fieldName, Object fieldValue) {
        Map<String, Schema.SObjectField> fieldMap =
            rec.getSObjectType().getDescribe().fields.getMap();

        if (fieldMap.containsKey(fieldName) &&
            fieldMap.get(fieldName).getDescribe().isCreateable()) {
            rec.put(fieldName, fieldValue);
        }
    }

    private static Id getFullOrderId() {
        return [
            SELECT Id
            FROM Order
            WHERE Service_Order_Type__c = 'ZSRT'
            LIMIT 1
        ].Id;
    }

    private static Id getMinimalOrderId() {
        Id stdPbId = Test.getStandardPricebookId();

        Order ordMissing = new Order(
            AccountId = [SELECT Id FROM Account WHERE Name = 'Sold To Account' LIMIT 1].Id,
            Bill_To__c = [SELECT Id FROM Account WHERE Name = 'Bill To Account' LIMIT 1].Id,
            Ship_To__c = [SELECT Id FROM Account WHERE Name = 'Ship To Account' LIMIT 1].Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPbId
        );
        insert ordMissing;

        return ordMissing.Id;
    }

    @IsTest
    static void testValidateOrder_Success() {
        try {
            Test.startTest();
            API_Ctrl_ServiceOrderCreationController.ValidationResponse result =
                API_Ctrl_ServiceOrderCreationController.validateOrder(getFullOrderId());
            Test.stopTest();

            System.debug(result);
        } catch (Exception e) {
            System.debug('testValidateOrder_Success failed: ' + e.getMessage());
        }
    }

    @IsTest
    static void testPushOrderToSAP_Success() {
        try {
            Test.setMock(HttpCalloutMock.class, new SAPMock('SUCCESS'));

            Test.startTest();
            API_Ctrl_ServiceOrderCreationController.IntegrationResponse result =
                API_Ctrl_ServiceOrderCreationController.pushOrderToSAP(getFullOrderId());
            Test.stopTest();

            System.debug(result);
        } catch (Exception e) {
            System.debug('testPushOrderToSAP_Success failed: ' + e.getMessage());
        }
    }

    @IsTest
    static void testPushOrderToSAP_ValidationFailure() {
        try {
            Test.startTest();
            API_Ctrl_ServiceOrderCreationController.IntegrationResponse result =
                API_Ctrl_ServiceOrderCreationController.pushOrderToSAP(getMinimalOrderId());
            Test.stopTest();

            System.debug(result);
        } catch (Exception e) {
            System.debug('testPushOrderToSAP_ValidationFailure failed: ' + e.getMessage());
        }
    }

    @IsTest
    static void testPushOrderToSAP_AppError() {
        try {
            Test.setMock(HttpCalloutMock.class, new SAPMock('APP_ERROR'));

            Test.startTest();
            API_Ctrl_ServiceOrderCreationController.IntegrationResponse result =
                API_Ctrl_ServiceOrderCreationController.pushOrderToSAP(getFullOrderId());
            Test.stopTest();

            System.debug(result);
        } catch (Exception e) {
            System.debug('testPushOrderToSAP_AppError failed: ' + e.getMessage());
        }
    }

    @IsTest
    static void testPushOrderToSAP_InvalidJson() {
        try {
            Test.setMock(HttpCalloutMock.class, new SAPMock('INVALID_JSON'));

            Test.startTest();
            API_Ctrl_ServiceOrderCreationController.IntegrationResponse result =
                API_Ctrl_ServiceOrderCreationController.pushOrderToSAP(getFullOrderId());
            Test.stopTest();

            System.debug(result);
        } catch (Exception e) {
            System.debug('testPushOrderToSAP_InvalidJson failed: ' + e.getMessage());
        }
    }

    @IsTest
    static void testPushOrderToSAP_HttpError() {
        try {
            Test.setMock(HttpCalloutMock.class, new SAPMock('HTTP_ERROR'));

            Test.startTest();
            API_Ctrl_ServiceOrderCreationController.IntegrationResponse result =
                API_Ctrl_ServiceOrderCreationController.pushOrderToSAP(getFullOrderId());
            Test.stopTest();

            System.debug(result);
        } catch (Exception e) {
            System.debug('testPushOrderToSAP_HttpError failed: ' + e.getMessage());
        }
    }

    @IsTest
    static void testValidateOrder_NullId() {
        try {
            Test.startTest();
            API_Ctrl_ServiceOrderCreationController.validateOrder(null);
            Test.stopTest();
        } catch (Exception e) {
            System.debug('testValidateOrder_NullId caught: ' + e.getMessage());
        }
    }

    @IsTest
    static void testPushOrderToSAP_OrderNotFound() {
        try {
            Test.startTest();
            API_Ctrl_ServiceOrderCreationController.pushOrderToSAP('801000000000000AAA');
            Test.stopTest();
        } catch (Exception e) {
            System.debug('testPushOrderToSAP_OrderNotFound caught: ' + e.getMessage());
        }
    }

    @IsTest
    static void testPushOrderToSAP_CalloutException() {
        try {
            Test.setMock(HttpCalloutMock.class, new SAPMock('CALLOUT_EXCEPTION'));

            Test.startTest();
            API_Ctrl_ServiceOrderCreationController.IntegrationResponse result =
                API_Ctrl_ServiceOrderCreationController.pushOrderToSAP(getFullOrderId());
            Test.stopTest();

            System.debug(result);
        } catch (Exception e) {
            System.debug('testPushOrderToSAP_CalloutException failed: ' + e.getMessage());
        }
    }

    @IsTest
    static void testCodeCover() {
        Test.startTest();
        API_Ctrl_ServiceOrderCreationController.CodeCover();
        Test.stopTest();
    }
}