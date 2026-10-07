@IsTest
private class Ctrl_OrderPaymentTermSelectionTest {

    /*
     * MOCK : LIST RESPONSE
     */
    private class PaymentTermListMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody(
                '{' +
                '"RESULT":{' +
                    '"item":[' +
                        '{' +
                            '"PAYMENT_TERMS":"PT01",' +
                            '"DESCRIPTION":"Immediate Payment"' +
                        '},' +
                        '{' +
                            '"PAYMENT_TERMS":"PT02",' +
                            '"DESCRIPTION":"30 Days Credit"' +
                        '}' +
                    ']' +
                '}' +
                '}'
            );

            return res;
        }
    }

    /*
     * MOCK : SINGLE OBJECT RESPONSE
     */
    private class PaymentTermSingleMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody(
                '{' +
                '"RESULT":{' +
                    '"item":{' +
                        '"PAYMENT_TERMS":"PT99",' +
                        '"DESCRIPTION":"Cash Payment"' +
                    '}' +
                '}' +
                '}'
            );

            return res;
        }
    }

    /*
     * MOCK : ERROR RESPONSE
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
            Name = 'Payment Term Account'
        );
        insert acc;

        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',

            //Sold_to_party_Code__c = 'SAP10001',
            Payment_Terms_Text__c = 'OLDTERM',
            Payment_Terms_Description__c = 'OLD DESC'
        );

        insert ord;

        return ord;
    }

    /*
     * SUCCESS : LIST RESPONSE
     */
    @IsTest
    static void testFetchPaymentTermsListResponse() {

        Order ord = createOrder();

        Test.setMock(
            HttpCalloutMock.class,
            new PaymentTermListMock()
        );

        Test.startTest();

        Ctrl_OrderPaymentTermSelection.fetchPaymentTerms(
            ord.Id
        );

        Test.stopTest();
    }

    /*
     * SUCCESS : SINGLE OBJECT RESPONSE
     */
    @IsTest
    static void testFetchPaymentTermsSingleResponse() {

        Order ord = createOrder();

        Test.setMock(
            HttpCalloutMock.class,
            new PaymentTermSingleMock()
        );

        Test.startTest();

        Ctrl_OrderPaymentTermSelection.fetchPaymentTerms(
            ord.Id
        );

        Test.stopTest();
    }

    /*
     * ERROR RESPONSE
     */
    @IsTest
    static void testFetchPaymentTermsError() {

        Order ord = createOrder();

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMock()
        );

        try {

            Test.startTest();

            Ctrl_OrderPaymentTermSelection.fetchPaymentTerms(
                ord.Id
            );

            Test.stopTest();

        } catch(Exception e) {
        }
    }

    /*
     * SAVE PAYMENT TERM
     */
    @IsTest
    static void testSaveSelectedPaymentTerm() {

        Order ord = createOrder();

        Test.startTest();

        Ctrl_OrderPaymentTermSelection.saveSelectedPaymentTerm(
            ord.Id,
            'PT01',
            'Immediate Payment'
        );

        Test.stopTest();
    }

    /*
     * SAVE EXCEPTION PATH
     */
    @IsTest
    static void testSaveSelectedPaymentTermException() {

        try {

            Test.startTest();

            Ctrl_OrderPaymentTermSelection.saveSelectedPaymentTerm(
                null,
                'PT01',
                'Immediate Payment'
            );

            Test.stopTest();

        } catch(Exception e) {
        }
    }
}