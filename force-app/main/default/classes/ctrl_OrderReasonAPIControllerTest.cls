@IsTest
private class ctrl_OrderReasonAPIControllerTest {

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"RESULT":{"item":[' +
                '{"ORDER_REASON":"001","DESCRIPTION":"Sales call"},' +
                '{"ORDER_REASON":"002","DESCRIPTION":"Trade fair sales activity"},' +
                '{"ORDER_REASON":"003","DESCRIPTION":"Television commercial"}' +
                ']}}'
            );
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private class BlankMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('');
            return res;
        }
    }

    @IsTest
    static void testInsertOrderReasons() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        ctrl_OrderReasonAPIController.SyncResponse result =
            ctrl_OrderReasonAPIController.syncOrderReasons();
        Test.stopTest();


    }

    @IsTest
    static void testUpdateOrderReasons() {
        insert new Order_Reason_Master__c(
            ORDER_REASON__c = '001',
            DESCRIPTION__c = 'Old Value'
        );

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        ctrl_OrderReasonAPIController.SyncResponse result =
            ctrl_OrderReasonAPIController.syncOrderReasons();
        Test.stopTest();

        
    }

    @IsTest
    static void testErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        try {
            ctrl_OrderReasonAPIController.syncOrderReasons();
            
        } catch (CalloutException e) {
            
        }
        Test.stopTest();
    }

    @IsTest
    static void testBlankResponse() {
        Test.setMock(HttpCalloutMock.class, new BlankMock());

        Test.startTest();
        ctrl_OrderReasonAPIController.SyncResponse result =
            ctrl_OrderReasonAPIController.syncOrderReasons();
        Test.stopTest();


    }
}