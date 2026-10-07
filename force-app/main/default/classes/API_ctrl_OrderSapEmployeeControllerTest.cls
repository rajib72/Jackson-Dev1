@IsTest
private class API_ctrl_OrderSapEmployeeControllerTest {

    private class SuccessMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);

            res.setBody(
                '{' +
                '"EMPLOYEE":[' +
                '{"EMPLOYEE":"EMP001","FIRST_NAME":"Rahul","LAST_NAME":"Sharma"},' +
                '{"EMPLOYEE":"EMP002","FIRST_NAME":"Amit","LAST_NAME":"Kumar"}' +
                ']' +
                '}'
            );

            return res;
        }
    }

    private class BlankResponseMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);
            res.setBody('');

            return res;
        }
    }

    private class EmptyEmployeeMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);
            res.setBody('{"EMPLOYEE":[]}');

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

    private static Order createOrderData() {

        Account acc = new Account(
            Name = 'Test Account',
            Company_Code__c = '2000 - JAKSONS ENGINEERS LIMITED'
        );
        insert acc;

        Id standardPricebookId = Test.getStandardPricebookId();

        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );

        insert ord;

        return ord;
    }

    @IsTest
    static void testFetchEmployeesSuccess() {

        Order ord = createOrderData();

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        Test.startTest();

        API_ctrl_OrderSapEmployeeController.fetchSapEmployees(
            ord.Id
        );

        Test.stopTest();
    }

    @IsTest
    static void testFetchEmployeesNullOrderId() {

        Test.startTest();

        try {

            API_ctrl_OrderSapEmployeeController.fetchSapEmployees(
                null
            );

        } catch (Exception ex) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testFetchEmployeesApiError() {

        Order ord = createOrderData();

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMock()
        );

        Test.startTest();

        try {

            API_ctrl_OrderSapEmployeeController.fetchSapEmployees(
                ord.Id
            );

        } catch (Exception ex) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testFetchEmployeesBlankResponse() {

        Order ord = createOrderData();

        Test.setMock(
            HttpCalloutMock.class,
            new BlankResponseMock()
        );

        Test.startTest();

        try {

            API_ctrl_OrderSapEmployeeController.fetchSapEmployees(
                ord.Id
            );

        } catch (Exception ex) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testFetchEmployeesNoEmployeeData() {

        Order ord = createOrderData();

        Test.setMock(
            HttpCalloutMock.class,
            new EmptyEmployeeMock()
        );

        Test.startTest();

        try {

            API_ctrl_OrderSapEmployeeController.fetchSapEmployees(
                ord.Id
            );

        } catch (Exception ex) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testSaveEmployeeSuccess() {

        Order ord = createOrderData();

        Test.startTest();

        API_ctrl_OrderSapEmployeeController.saveSelectedEmployee(
            ord.Id,
            'EMP001',
            'Rahul Sharma'
        );

        Test.stopTest();
    }

    @IsTest
    static void testSaveEmployeeNullOrderId() {

        Test.startTest();

        try {

            API_ctrl_OrderSapEmployeeController.saveSelectedEmployee(
                null,
                'EMP001',
                'Rahul Sharma'
            );

        } catch (Exception ex) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testSaveEmployeeBlankCode() {

        Order ord = createOrderData();

        Test.startTest();

        try {

            API_ctrl_OrderSapEmployeeController.saveSelectedEmployee(
                ord.Id,
                '',
                'Rahul Sharma'
            );

        } catch (Exception ex) {

        }

        Test.stopTest();
    }

    @IsTest
    static void testSaveEmployeeBlankName() {

        Order ord = createOrderData();

        Test.startTest();

        try {

            API_ctrl_OrderSapEmployeeController.saveSelectedEmployee(
                ord.Id,
                'EMP001',
                ''
            );

        } catch (Exception ex) {

        }

        Test.stopTest();
    }
}