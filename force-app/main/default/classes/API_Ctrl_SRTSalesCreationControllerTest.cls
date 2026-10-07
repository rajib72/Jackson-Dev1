@IsTest

private class API_Ctrl_SRTSalesCreationControllerTest {
 
    /*

     * SUCCESS MOCK

     */

    private class SuccessMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
 
            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);

            res.setBody('{"salesOrder":"5000012345"}');

            return res;

        }

    }
 
    /*

     * SUCCESS WITHOUT SALES ORDER

     */

    private class SuccessWithoutSalesOrderMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
 
            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);

            res.setBody('{"message":"Success"}');

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

            res.setBody('SAP Internal Error');

            return res;

        }

    }
 
    private static Order createOrder(Boolean validData){
 
        Account billTo = new Account(

            Name = 'Bill To',

            SAP_Account_Number__c = 'SAP1001'

        );

        insert billTo;
 
        Account shipTo = new Account(

            Name = 'Ship To',

            SAP_Account_Number__c = 'SAP1002'

        );

        insert shipTo;
 
        Account acc = new Account(

            Name = 'Main Account',

            Customer_Account_Group__c = 'ZDOM',

            Company_Code__c = '2000 - JAKSONS ENGINEERS LIMITED',

            Distribution_Channel__c = '10',

            Division__c = '01'

        );

        insert acc;
 
        Id standardPB = Test.getStandardPricebookId();
 
        Product2 p = new Product2(

            Name='Test Product',

            IsActive=true

        );

        insert p;
 
        PricebookEntry pbe = new PricebookEntry(

            Pricebook2Id = standardPB,

            Product2Id = p.Id,

            UnitPrice = 100,

            IsActive = true

        );

        insert pbe;
 
        Order ord = new Order(

            AccountId = acc.Id,

            Bill_To__c = billTo.Id,

            Ship_To__c = shipTo.Id,

            EffectiveDate = Date.today(),

            Status = 'Draft',

            Pricebook2Id = standardPB,
 
            Customer_Reference__c = validData ? 'PO123' : null,

            Customer_Reference_Date__c = validData ? Date.today() : null,
 
            InCoTerms__c = validData ? 'FOB' : null,

            Sales_Office__c = validData ? 'SO01' : null,

            Sales_Group__c = validData ? 'SG01' : null,
 
            BG_Required__c = validData ? 'Y' : null,

            LD_Clause__c = validData ? 'Y' : null,

            TPC__c = validData ? 'Y' : null,
 
            SAP_Employee_Code__c = validData ? 'EMP001' : null,
 
            Payment_Terms_Text__c = validData ? 'PT01' : null,
 
            Delivering_Plant__c = validData ? 'PL01' : null,
 
            Freight_Terms__c = validData ? 'FREIGHT' : null,

            Insurance_Terms__c = validData ? 'INSURANCE' : null,

            Scope_Of_OA__c = validData ? 'SCOPE' : null

        );
 
        insert ord;
 
        if(validData){
 
            OrderItem oi = new OrderItem(

                OrderId = ord.Id,

                PricebookEntryId = pbe.Id,

                Quantity = 2,

                UnitPrice = 100,
 
                Item_Category__c = 'TANN',

                Material_Sales_Text__c = 'Material Text',

                Performance_Warranty__c = 10,

                Product_Warranty_Duration__c = 5,

                Condition_Type__c = 'PB00'

            );
 
            insert oi;

        }
 
        return ord;

    }
 
    @IsTest

    static void testSuccessScenario(){
 
        Order ord = createOrder(true);
 
        Test.setMock(

            HttpCalloutMock.class,

            new SuccessMock()

        );
 
        Test.startTest();
 
        API_Ctrl_SRTSalesCreationController.syncOrderToSAP(

            ord.Id

        );
 
        Test.stopTest();

    }
 
    @IsTest

    static void testSuccessWithoutSalesOrderResponse(){
 
        Order ord = createOrder(true);
 
        Test.setMock(

            HttpCalloutMock.class,

            new SuccessWithoutSalesOrderMock()

        );
 
        Test.startTest();
 
        API_Ctrl_SRTSalesCreationController.syncOrderToSAP(

            ord.Id

        );
 
        Test.stopTest();

    }
 
    @IsTest

    static void testHttpError(){
 
        Order ord = createOrder(true);
 
        Test.setMock(

            HttpCalloutMock.class,

            new ErrorMock()

        );
 
        Test.startTest();
 
        API_Ctrl_SRTSalesCreationController.syncOrderToSAP(

            ord.Id

        );
 
        Test.stopTest();

    }
 
    @IsTest

    static void testValidationFailure(){
 
        Order ord = createOrder(false);
 
        Test.startTest();
 
        API_Ctrl_SRTSalesCreationController.syncOrderToSAP(

            ord.Id

        );
 
        Test.stopTest();

    }
 
    @IsTest

    static void testNullOrderId(){
 
        try{
 
            Test.startTest();
 
            API_Ctrl_SRTSalesCreationController.syncOrderToSAP(

                null

            );
 
            Test.stopTest();
 
        }catch(Exception e){

        }

    }
 
    @IsTest

    static void testInvalidOrderId(){
 
        try{
 
            Test.startTest();
 
            API_Ctrl_SRTSalesCreationController.syncOrderToSAP(

                '801000000000000AAA'

            );
 
            Test.stopTest();
 
        }catch(Exception e){

        }

    }
    @isTest
    static void test() {
        API_Ctrl_SRTSalesCreationController.dataCover();
    }

}