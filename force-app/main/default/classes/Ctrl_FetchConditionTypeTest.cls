@IsTest
private class Ctrl_FetchConditionTypeTest {

    /*
     * SUCCESS MOCK
     */
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '[{"KSCHL":"PR00","VTEXT":"Base Price"}]'
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
            res.setBody('Internal Server Error');

            return res;
        }
    }

    /*
     * TEST DATA
     */
    private static OrderItem createOrderItemData() {

        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        Id stdPbId = Test.getStandardPricebookId();

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

        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPbId
        );

        insert ord;

        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        insert oi;

        return oi;
    }

    /*
     * SUCCESS TEST
     */
    @IsTest
    static void testFetchConditionTypesSuccess() {

        OrderItem oi = createOrderItemData();

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        Test.startTest();

        Ctrl_FetchConditionType.fetchConditionTypesFromSAP(
            oi.Id
        );

        Test.stopTest();
    }

    /*
     * ERROR RESPONSE TEST
     */
    @IsTest
    static void testFetchConditionTypesErrorResponse() {

        OrderItem oi = createOrderItemData();

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMock()
        );

        Test.startTest();

        try{
            Ctrl_FetchConditionType.fetchConditionTypesFromSAP(
                oi.Id
            );
        }catch(Exception e){
        }

        Test.stopTest();
    }

    /*
     * INVALID ID TEST
     */
    @IsTest
    static void testInvalidOrderItemId() {

        Test.startTest();

        try{
            Ctrl_FetchConditionType.fetchConditionTypesFromSAP(
                '802000000000000AAA'
            );
        }catch(Exception e){
        }

        Test.stopTest();
    }
}