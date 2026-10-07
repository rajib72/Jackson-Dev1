@IsTest
private class API_ctrl_OrderItemCategoryControllerTest {

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody(
                '{"ITEM_CATAGORY":[' +
                '{"ITEM_CATAGORY":"TANN"},' +
                '{"ITEM_CATAGORY":"TACN"}' +
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
        Unique_Key__c = 'MAT001_TEST'
    );
    insert mat;

    Id standardPricebookId = Test.getStandardPricebookId();

    Product2 prod = new Product2(
        Name = 'Test Product',
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
    static void testFetchItemCategoriesSuccess() {

        OrderItem oi = createOrderItemData();

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        Test.startTest();

        API_ctrl_OrderItemCategoryController.fetchItemCategories(
            oi.Id
        );

        Test.stopTest();
    }

    @IsTest
    static void testFetchItemCategoriesEmptyResponse() {

        OrderItem oi = createOrderItemData();

        Test.setMock(
            HttpCalloutMock.class,
            new EmptyMock()
        );

        Test.startTest();

        API_ctrl_OrderItemCategoryController.fetchItemCategories(
            oi.Id
        );

        Test.stopTest();
    }

    @IsTest
    static void testFetchItemCategoriesErrorResponse() {

        OrderItem oi = createOrderItemData();

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMock()
        );

        Test.startTest();

        API_ctrl_OrderItemCategoryController.fetchItemCategories(
            oi.Id
        );

        Test.stopTest();
    }

    @IsTest
    static void testFetchItemCategoriesNullId() {

        Test.startTest();

        try {
            API_ctrl_OrderItemCategoryController.fetchItemCategories(
                null
            );
        }
        catch (Exception ex) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testSaveItemCategorySuccess() {

        OrderItem oi = createOrderItemData();

        Test.startTest();

        API_ctrl_OrderItemCategoryController.saveItemCategory(
            oi.Id,
            'TANN'
        );

        Test.stopTest();
    }

    @IsTest
    static void testSaveItemCategoryBlankValue() {

        OrderItem oi = createOrderItemData();

        Test.startTest();

        try {

            API_ctrl_OrderItemCategoryController.saveItemCategory(
                oi.Id,
                ''
            );

        } catch (Exception ex) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testSaveItemCategoryNullId() {

        Test.startTest();

        try {

            API_ctrl_OrderItemCategoryController.saveItemCategory(
                null,
                'TANN'
            );

        } catch (Exception ex) {

        }

        Test.stopTest();
    }
}