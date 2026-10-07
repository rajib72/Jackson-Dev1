@IsTest
private class Ctrl_OrderPlantSelectionTest {

    /*
     * SUCCESS MOCK
     */
    private class SuccessMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody(
                '{' +
                    '"RESULT":{' +
                        '"item":[' +
                            '{' +
                                '"PLANT":"PL01",' +
                                '"DESCRIPTION":"Plant One"' +
                            '},' +
                            '{' +
                                '"PLANT":"PL02",' +
                                '"DESCRIPTION":"Plant Two"' +
                            '}' +
                        ']' +
                    '}' +
                '}'
            );

            return res;
        }
    }

    /*
     * EMPTY RESPONSE MOCK
     */
    private class EmptyMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody(
                '{' +
                    '"RESULT":{' +
                        '"item":[]' +
                    '}' +
                '}'
            );

            return res;
        }
    }

    /*
     * ERROR MOCK
     */
    private class ErrorMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('SAP Error');

            return res;
        }
    }

    /*
     * TEST DATA
     */
    private static Order createOrder() {

        Account acc = new Account(
            Name = 'Plant Test Account'
        );
        insert acc;

        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Delivering_Plant__c = 'OLDPLANT'
        );

        insert ord;

        return ord;
    }

    /*
     * SUCCESS FETCH
     */
    @IsTest
    static void testFetchPlantsSuccess() {

        Order ord = createOrder();

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        Test.startTest();

        Ctrl_OrderPlantSelection.fetchPlants(
            ord.Id
        );

        Test.stopTest();
    }

    /*
     * EMPTY RESPONSE
     */
    @IsTest
    static void testFetchPlantsEmptyResponse() {

        Order ord = createOrder();

        Test.setMock(
            HttpCalloutMock.class,
            new EmptyMock()
        );

        Test.startTest();

        Ctrl_OrderPlantSelection.fetchPlants(
            ord.Id
        );

        Test.stopTest();
    }

    /*
     * ERROR RESPONSE
     */
    @IsTest
    static void testFetchPlantsError() {

        Order ord = createOrder();

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMock()
        );

        try {

            Test.startTest();

            Ctrl_OrderPlantSelection.fetchPlants(
                ord.Id
            );

            Test.stopTest();

        } catch(Exception e) {
        }
    }

    /*
     * SAVE PLANT
     */
    @IsTest
    static void testSaveSelectedPlant() {

        Order ord = createOrder();

        Test.startTest();

        Ctrl_OrderPlantSelection.saveSelectedPlant(
            ord.Id,
            'PL99'
        );

        Test.stopTest();
    }

    /*
     * SAVE EXCEPTION
     */
    @IsTest
    static void testSaveSelectedPlantException() {

        try {

            Test.startTest();

            Ctrl_OrderPlantSelection.saveSelectedPlant(
                null,
                'PL99'
            );

            Test.stopTest();

        } catch(Exception e) {
        }
    }
}