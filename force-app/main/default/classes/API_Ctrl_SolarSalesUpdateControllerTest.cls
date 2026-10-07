@IsTest
private class API_Ctrl_SolarSalesUpdateControllerTest {

    /*
     * SUCCESS MOCK
     */
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"MESSAGE":"Sales Order Updated Successfully"}'
            );
            return res;
        }
    }

    /*
     * SUCCESS MOCK WITHOUT MESSAGE
     */
    private class SuccessWithoutMessageMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}');
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
     * COMMON TEST DATA
     */
    private static Order createOrderData(Boolean withSapOrder) {

        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Solar Product',
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
            Pricebook2Id = stdPbId,

            Sales_Order__c = withSapOrder ? 'SO10001' : null,

            Customer_Reference__c = 'PO123',
            Customer_Reference_Date__c = Date.today(),

            SAP_Employee_Code__c = 'EMP001',
            //COMP_CODE__c = '2000',
            Delivering_Plant__c = 'PL01',

            BG_Required__c = 'Y',
            LD_Clause__c = 'Y',
            TPC__c = 'Y'

           // Payment_Terms__c = 'PT01'
        );
        insert ord;

        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100,

            //Plant_Code__c = 'PL01',
            Item_Category__c = 'TANN',
            Material_Sales_Text__c = 'Solar Panel',

            Performance_Warranty__c = 10,
            Product_Warranty_Duration__c = 5,

            Condition_Type__c = 'PB00'
        );

        insert oi;

        return ord;
    }

    /*
     * SUCCESS TEST
     */
    @IsTest
    static void testUpdateOrderInSAPSuccess() {

        Order ord = createOrderData(true);

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        Test.startTest();

        API_Ctrl_SolarSalesUpdateController.updateOrderInSAP(
            ord.Id
        );

        Test.stopTest();
    }

    /*
     * SUCCESS WITHOUT MESSAGE
     */
    @IsTest
    static void testUpdateOrderInSAPWithoutMessage() {

        Order ord = createOrderData(true);

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessWithoutMessageMock()
        );

        Test.startTest();

        API_Ctrl_SolarSalesUpdateController.updateOrderInSAP(
            ord.Id
        );

        Test.stopTest();
    }

    /*
     * ERROR RESPONSE
     */
    @IsTest
    static void testUpdateOrderInSAPErrorResponse() {

        Order ord = createOrderData(true);

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMock()
        );

        Test.startTest();

        API_Ctrl_SolarSalesUpdateController.updateOrderInSAP(
            ord.Id
        );

        Test.stopTest();
    }

    /*
     * NO SAP SALES ORDER
     */
    @IsTest
    static void testUpdateOrderWithoutSapSalesOrder() {

        Order ord = createOrderData(false);

        Test.startTest();

        API_Ctrl_SolarSalesUpdateController.updateOrderInSAP(
            ord.Id
        );

        Test.stopTest();
    }

    /*
     * INVALID ORDER ID
     * Covers Exception Block
     */
    @IsTest
    static void testUpdateOrderException() {

        Test.startTest();

        API_Ctrl_SolarSalesUpdateController.updateOrderInSAP(
            '801000000000000AAA'
        );

        Test.stopTest();
    }
}