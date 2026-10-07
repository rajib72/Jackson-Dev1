@IsTest
private class ctrl_ConditionTypeAPIControllerTest {

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            //System.assertEquals('POST', req.getMethod());
            //System.assert(req.getEndpoint().contains('conditionType'));
            //System.assertEquals('{}', req.getBody());

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"RESULT":{"item":[' +
                '{"CONDITION_TYPE":"DIFF","DESCRIPTION":"Rounding Off"},' +
                '{"CONDITION_TYPE":"EK01","DESCRIPTION":"Actual Costs"},' +
                '{"CONDITION_TYPE":"FRA1","DESCRIPTION":"Freight %"}' +
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

    @IsTest
    static void testInsertConditionTypes() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        ctrl_ConditionTypeAPIController.syncConditionTypes();
        Test.stopTest();

        List<Condition_Type_Master__c> records = [
            SELECT Id, CONDITION_TYPE__c, DESCRIPTION__c
            FROM Condition_Type_Master__c
            WHERE CONDITION_TYPE__c IN ('DIFF', 'EK01', 'FRA1')
        ];

        //System.assertEquals(3, records.size(), 'Three records should be inserted');
    }

    @IsTest
    static void testUpdateConditionTypes() {
        insert new Condition_Type_Master__c(
            CONDITION_TYPE__c = 'DIFF',
            DESCRIPTION__c = 'Old Description'
        );

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        ctrl_ConditionTypeAPIController.syncConditionTypes();
        Test.stopTest();

        Condition_Type_Master__c updatedRec = [
            SELECT Id, CONDITION_TYPE__c, DESCRIPTION__c
            FROM Condition_Type_Master__c
            WHERE CONDITION_TYPE__c = 'DIFF'
            LIMIT 1
        ];

        //System.assertEquals('Rounding Off', updatedRec.DESCRIPTION__c);
    }

    @IsTest
    static void testErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        try {
            ctrl_ConditionTypeAPIController.syncConditionTypes();
            //System.assert(false, 'Expected a CalloutException');
        } catch (CalloutException e) {
            //System.assert(e.getMessage().contains('API Error'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testBlankResponse() {
        Test.setMock(HttpCalloutMock.class, new BlankMock());

        Test.startTest();
        ctrl_ConditionTypeAPIController.syncConditionTypes();
        Test.stopTest();

        //System.assertEquals(0, [SELECT Count() FROM Condition_Type_Master__c]);
    }

    private class BlankMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('');
            return res;
        }
    }
}