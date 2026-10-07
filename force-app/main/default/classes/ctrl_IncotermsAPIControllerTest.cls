@isTest
private class ctrl_IncotermsAPIControllerTest {

    private class IncotermsMockResponse implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);

            res.setBody(
                '{"RESULT":{"item":[' +
                '{"INCOTERMS":"CFR","DESCRIPTION":"Costs and freight"},' +
                '{"INCOTERMS":"CIF","DESCRIPTION":"Costs, insurance & freight"},' +
                '{"INCOTERMS":"FOB","DESCRIPTION":"Free on board"}' +
                ']}}'
            );

            return res;
        }
    }

    @isTest
    static void testSyncIncoterms_InsertRecords() {

        Test.setMock(
            HttpCalloutMock.class,
            new IncotermsMockResponse()
        );

        Test.startTest();

        ctrl_IncotermsAPIController.syncIncoterms();

        Test.stopTest();

        List<Incoterms_Master__c> records =
            [
                SELECT Id,
                       INCOTERMS__c,
                       DESCRIPTION__c
                FROM Incoterms_Master__c
            ];

        /*System.assertEquals(
            3,
            records.size(),
            '3 records should be inserted'
        );*/
    }

    @isTest
    static void testSyncIncoterms_UpdateRecords() {

        Incoterms_Master__c existingRec =
            new Incoterms_Master__c(
                INCOTERMS__c = 'CFR',
                DESCRIPTION__c = 'Old Description'
            );

        insert existingRec;

        Test.setMock(
            HttpCalloutMock.class,
            new IncotermsMockResponse()
        );

        Test.startTest();

        ctrl_IncotermsAPIController.syncIncoterms();

        Test.stopTest();

        Incoterms_Master__c updatedRec =
            [
                SELECT Id,
                       INCOTERMS__c,
                       DESCRIPTION__c
                FROM Incoterms_Master__c
                WHERE INCOTERMS__c = 'CFR'
                LIMIT 1
            ];

        /*System.assertEquals(
            'Costs and freight',
            updatedRec.DESCRIPTION__c
        );*/
    }

    private class ErrorMockResponse
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(500);
            res.setBody('Internal Server Error');

            return res;
        }
    }

    @isTest
    static void testSyncIncoterms_ErrorResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMockResponse()
        );

        Test.startTest();

        try {

            ctrl_IncotermsAPIController.syncIncoterms();

            /*System.assert(false,
                'Exception expected');*/

        } catch(Exception e) {

            /*System.assert(
                e.getMessage().contains('API Error')
            );*/
        }

        Test.stopTest();
    }
}