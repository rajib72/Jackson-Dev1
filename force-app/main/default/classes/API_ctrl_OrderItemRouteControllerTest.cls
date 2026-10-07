@IsTest
private class API_ctrl_OrderItemRouteControllerTest {

    private class SuccessMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);

            res.setBody(
                '{"ROUTE":[' +
                '{"ROUTE":"R001","ROUTE_DESCRIPTION":"Kolkata Route"},' +
                '{"ROUTE":"R002","ROUTE_DESCRIPTION":"Delhi Route"}' +
                ']}'
            );

            return res;
        }
    }

    private class EmptyMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);
            res.setBody('{}');

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

    private static OrderItem createOrderItemData() {

        Account acc = new Account(
            Name = 'Test Account',
            Company_Code__c = '2000 - JAKSONS ENGINEERS LIMITED'
        );
        insert acc;

        Material_Master__c mat = new Material_Master__c(
            Name = 'MAT001',
            Unique_Key__c = 'MAT001_ROUTE'
        );
        insert mat;

        Id standardPricebookId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Route Product',
            IsActive = true
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert ord;

        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100,
            Material_Master__c = mat.Id
        );

        insert oi;

        return oi;
    }

    @IsTest
    static void testGetRouteOptionsSuccess() {

        OrderItem oi = createOrderItemData();

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        Test.startTest();

        API_ctrl_OrderItemRouteController.getRouteOptions(
            oi.Id
        );

        Test.stopTest();
    }

    @IsTest
    static void testGetRouteOptionsEmptyResponse() {

        OrderItem oi = createOrderItemData();

        Test.setMock(
            HttpCalloutMock.class,
            new EmptyMock()
        );

        Test.startTest();

        API_ctrl_OrderItemRouteController.getRouteOptions(
            oi.Id
        );

        Test.stopTest();
    }

    @IsTest
    static void testGetRouteOptionsApiError() {

        OrderItem oi = createOrderItemData();

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMock()
        );

        Test.startTest();

        try {

            API_ctrl_OrderItemRouteController.getRouteOptions(
                oi.Id
            );

        } catch(Exception e) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testGetRouteOptionsNullId() {

        Test.startTest();

        try {

            API_ctrl_OrderItemRouteController.getRouteOptions(
                null
            );

        } catch(Exception e) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testSaveSelectedRouteSuccess() {

        OrderItem oi = createOrderItemData();

        Test.startTest();

        API_ctrl_OrderItemRouteController.saveSelectedRoute(
            oi.Id,
            'R001 | Kolkata Route'
        );

        Test.stopTest();
    }

    @IsTest
    static void testSaveSelectedRouteBlankValue() {

        OrderItem oi = createOrderItemData();

        Test.startTest();

        try {

            API_ctrl_OrderItemRouteController.saveSelectedRoute(
                oi.Id,
                ''
            );

        } catch(Exception e) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testSaveSelectedRouteNullId() {

        Test.startTest();

        try {

            API_ctrl_OrderItemRouteController.saveSelectedRoute(
                null,
                'R001'
            );

        } catch(Exception e) {

        }

        Test.stopTest();
    }
}