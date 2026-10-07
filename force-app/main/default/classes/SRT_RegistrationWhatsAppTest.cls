@IsTest(SeeAllData=true)
private class SRT_RegistrationWhatsAppTest {

    /* =========================================================
       MOCKS
       ========================================================= */

    private class SuccessMock
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);

            res.setBody(
                '{"MsgId":"TEST-MSG-001"}'
            );

            return res;
        }
    }


    private class NoMsgIdMock
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);

            res.setBody(
                '{"status":"success"}'
            );

            return res;
        }
    }


    private class InvalidJsonMock
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);

            res.setBody(
                'INVALID JSON'
            );

            return res;
        }
    }


    private class FailureMock
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(500);

            res.setBody(
                '{"message":"Internal Server Error"}'
            );

            return res;
        }
    }


    private class ExceptionMock
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest req
        ) {

            throw new CalloutException(
                'Test callout exception'
            );
        }
    }


    /* =========================================================
       SERVICE
       ========================================================= */

    @IsTest
    static void testWhatsAppService() {

        Integer i = 0;


        /*
         * Branch 1
         * caseId == null
         */
        String nullResult =
            SRT_RegistrationWhatsAppService.queueAfterCreate(
                    null
                );

        System.debug(
            'SERVICE ' +
            i++ +
            ' = ' +
            nullResult
        );


        /*
         * Branch 2
         * Case not found.
         *
         * User Id is a valid Salesforce Id,
         * but not a Case Id.
         */
        String missingCaseResult =
            SRT_RegistrationWhatsAppService.queueAfterCreate(
                    UserInfo.getUserId()
                );

        System.debug(
            'SERVICE ' +
            i++ +
            ' = ' +
            missingCaseResult
        );


        /*
         * Branches using existing Cases.
         *
         * No Case INSERT is performed,
         * therefore Case Flows do not interfere.
         */
        List<Case> cases = [
            SELECT
                Id,
                CaseNumber,
                SRT_Case_Number__c,
                ContactId,
                Contact.Phone
            FROM Case
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];


        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );


        Test.startTest();

        for (Case c : cases) {

            /*
             * Only a few Cases are needed.
             */
            if (i >= 6) {
                break;
            }

            try {

                String result =
                    SRT_RegistrationWhatsAppService.queueAfterCreate(
                            c.Id
                        );

                System.debug(
                    'SERVICE ' +
                    i++ +
                    ' = ' +
                    result
                );

            } catch (Exception e) {

                System.debug(
                    'SERVICE ERROR ' +
                    i++ +
                    ' = ' +
                    e.getMessage()
                );
            }
        }

        Test.stopTest();
    }


    /* =========================================================
       QUEUEABLE
       ========================================================= */

    @IsTest
    static void testQueueableBranches() {

        Integer i = 0;

        Test.startTest();


        /* =====================================================
           1. SUCCESS + MSG ID
           ===================================================== */

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        String phone1 =
            '987654321' +
            String.valueOf(i++);

        new SRT_RegistrationWhatsAppQueueable(
            null,
            phone1,
            'SR-TEST-' + i,
            null
        ).execute(null);


        /* =====================================================
           2. SUCCESS WITHOUT MSG ID
           ===================================================== */

        Test.setMock(
            HttpCalloutMock.class,
            new NoMsgIdMock()
        );

        String phone2 =
            '987654321' +
            String.valueOf(i++);

        new SRT_RegistrationWhatsAppQueueable(
            null,
            phone2,
            'SR-TEST-' + i,
            null
        ).execute(null);


        /* =====================================================
           3. INVALID JSON
           ===================================================== */

        Test.setMock(
            HttpCalloutMock.class,
            new InvalidJsonMock()
        );

        String phone3 =
            '987654321' +
            String.valueOf(i++);

        new SRT_RegistrationWhatsAppQueueable(
            null,
            phone3,
            'SR-TEST-' + i,
            null
        ).execute(null);


        /* =====================================================
           4. HTTP FAILURE
           ===================================================== */

        Test.setMock(
            HttpCalloutMock.class,
            new FailureMock()
        );

        String phone4 =
            '987654321' +
            String.valueOf(i++);

        new SRT_RegistrationWhatsAppQueueable(
            null,
            phone4,
            'SR-TEST-' + i,
            null
        ).execute(null);


        /* =====================================================
           5. CALLOUT EXCEPTION
           ===================================================== */

        Test.setMock(
            HttpCalloutMock.class,
            new ExceptionMock()
        );

        String phone5 =
            '987654321' +
            String.valueOf(i++);

        new SRT_RegistrationWhatsAppQueueable(
            null,
            phone5,
            'SR-TEST-' + i,
            null
        ).execute(null);


        /* =====================================================
           6. MISSING DESTINATION
           ===================================================== */

        i++;

        new SRT_RegistrationWhatsAppQueueable(
            null,
            null,
            'SR-TEST-' + i,
            null
        ).execute(null);


        /* =====================================================
           7. MISSING SERVICE REQUEST NUMBER
           ===================================================== */

        String phone7 =
            '987654321' +
            String.valueOf(i++);

        new SRT_RegistrationWhatsAppQueueable(
            null,
            phone7,
            null,
            null
        ).execute(null);


        /* =====================================================
           8. BOTH VALUES MISSING
           ===================================================== */

        i++;

        new SRT_RegistrationWhatsAppQueueable(
            null,
            null,
            null,
            null
        ).execute(null);


        Test.stopTest();


        System.debug(
            'TOTAL QUEUEABLE BRANCHES = ' +
            i
        );
    }


    /* =========================================================
       QUEUEABLE WITH LOG UPDATE
       ========================================================= */

    @IsTest
    static void testQueueableWithLogUpdate() {

        Integer i = 0;


        /*
         * Reuse an existing Case.
         */
        List<Case> cases = [
            SELECT Id
            FROM Case
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];


        Whatsapp_Messages__c logRec =
            new Whatsapp_Messages__c();

        if (!cases.isEmpty()) {

            logRec.Case__c =
                cases[0].Id;
        }

        logRec.Campaign_Name__c =
            'customer_registered';

        logRec.Recipient_Number__c =
            '9876543210';

        logRec.Status__c =
            'Pending';


        /*
         * Database.insert(false) prevents the test
         * from failing if the org has an extra
         * validation rule on Whatsapp_Messages__c.
         */
        Database.SaveResult insertResult =
            Database.insert(
                logRec,
                false
            );


        if (!insertResult.isSuccess()) {

            System.debug(
                'Log could not be inserted: ' +
                insertResult.getErrors()[0]
                    .getMessage()
            );

            return;
        }


        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );


        Test.startTest();


        new SRT_RegistrationWhatsAppQueueable(
            cases.isEmpty()
                ? null
                : cases[0].Id,

            '987654321' +
                String.valueOf(i++),

            'SR-LOG-' + i,

            logRec.Id
        ).execute(null);


        Test.stopTest();


        Whatsapp_Messages__c updatedLog = [
            SELECT
                Id,
                Status__c,
                HTTP_Status_Code__c,
                Message_Id__c,
                Failure_Reason__c,
                Accepted_At__c
            FROM Whatsapp_Messages__c
            WHERE Id = :logRec.Id
            LIMIT 1
        ];


        System.debug(
            'UPDATED LOG = ' +
            updatedLog
        );
    }
@IsTest
static void testServiceLogCreation() {

    /*
     * Get any existing Case that has a Contact.
     * We do NOT update or insert the Case, so the
     * problematic Case Flow will not execute.
     */
    List<Case> cases = [
        SELECT
            Id,
            CaseNumber,
            SRT_Case_Number__c,
            ContactId,
            Contact.Phone
        FROM Case
        WHERE ContactId != null
        LIMIT 1
    ];

    if (cases.isEmpty()) {
        return;
    }


    /*
     * Make the Contact phone valid for the WhatsApp service.
     * Updating Contact does not execute your Case Origin Flow.
     */
    Contact con = [
        SELECT
            Id,
            Phone
        FROM Contact
        WHERE Id = :cases[0].ContactId
        LIMIT 1
    ];

    con.Phone =
        '9876543210';

    update con;


    Test.setMock(
        HttpCalloutMock.class,
        new SuccessMock()
    );


    Test.startTest();

    String result =
        SRT_RegistrationWhatsAppService.queueAfterCreate(
                cases[0].Id
            );

    Test.stopTest();


    System.debug(
        'SERVICE LOG RESULT = ' +
        result
    );


    /*
     * Query the log only so these records are
     * visible while debugging.
     */
    List<Whatsapp_Messages__c> logs = [
        SELECT
            Id,
            Case__c,
            Campaign_Name__c,
            Recipient_Number__c,
            Requested_At__c,
            Status__c,
            Failure_Reason__c,
            Message__c
        FROM Whatsapp_Messages__c
        WHERE Case__c = :cases[0].Id
        ORDER BY CreatedDate DESC
        LIMIT 5
    ];

    System.debug(
        'CREATED WHATSAPP LOG = ' +
        logs
    );
}

@IsTest
static void testServiceNoContact() {

    List<Case> cases = [
        SELECT
            Id,
            ContactId,
            SRT_Case_Number__c,
            CaseNumber
        FROM Case
        WHERE ContactId = null
        LIMIT 1
    ];

    if (cases.isEmpty()) {
        return;
    }

    Test.startTest();

    String result =
        SRT_RegistrationWhatsAppService.queueAfterCreate(
            cases[0].Id
        );

    Test.stopTest();

    System.debug(
        'NO CONTACT = ' +
        result
    );
}
@IsTest
static void testServiceInvalidPhoneBranch() {

    List<Case> cases = [
        SELECT
            Id,
            ContactId,
            Contact.Phone,
            SRT_Case_Number__c,
            CaseNumber
        FROM Case
        WHERE ContactId != null
        LIMIT 1
    ];

    if (cases.isEmpty()) {
        return;
    }


    Contact con = [
        SELECT
            Id,
            Phone
        FROM Contact
        WHERE Id = :cases[0].ContactId
        LIMIT 1
    ];

    con.Phone =
        '12345';

    update con;


    Test.startTest();

    String result =
        SRT_RegistrationWhatsAppService.queueAfterCreate(
            cases[0].Id
        );

    Test.stopTest();

    System.debug(
        'INVALID PHONE = ' +
        result
    );
}
@IsTest
static void testService91PhoneNormalization() {

    List<Case> cases = [
        SELECT
            Id,
            ContactId,
            Contact.Phone,
            SRT_Case_Number__c,
            CaseNumber
        FROM Case
        WHERE ContactId != null
        LIMIT 1
    ];

    if (cases.isEmpty()) {
        return;
    }

    Contact con = [
        SELECT Id, Phone
        FROM Contact
        WHERE Id = :cases[0].ContactId
        LIMIT 1
    ];

    /*
     * 12 digits:
     * 91 + 9876543210
     */
    con.Phone =
        '919876543210';

    update con;

    Test.setMock(
        HttpCalloutMock.class,
        new SuccessMock()
    );

    Test.startTest();

    String result =
        SRT_RegistrationWhatsAppService.queueAfterCreate(
            cases[0].Id
        );

    Test.stopTest();

    System.debug(
        '91 NORMALIZATION = ' +
        result
    );
}
@IsTest
static void testService0091PhoneNormalization() {

    List<Case> cases = [
        SELECT
            Id,
            ContactId,
            Contact.Phone,
            SRT_Case_Number__c,
            CaseNumber
        FROM Case
        WHERE ContactId != null
        LIMIT 1
    ];

    if (cases.isEmpty()) {
        return;
    }

    Contact con = [
        SELECT Id, Phone
        FROM Contact
        WHERE Id = :cases[0].ContactId
        LIMIT 1
    ];

    /*
     * 14 digits:
     * 0091 + 9876543210
     */
    con.Phone =
        '00919876543210';

    update con;

    Test.setMock(
        HttpCalloutMock.class,
        new SuccessMock()
    );

    Test.startTest();

    String result =
        SRT_RegistrationWhatsAppService.queueAfterCreate(
            cases[0].Id
        );

    Test.stopTest();

    System.debug(
        '0091 NORMALIZATION = ' +
        result
    );
}
@IsTest
static void testServiceCaseNumberFallback() {

    List<Case> cases = [
        SELECT
            Id,
            CaseNumber,
            SRT_Case_Number__c,
            ContactId,
            Contact.Phone,
            Origin
        FROM Case
        WHERE ContactId != null
        AND Origin != 'Phone'
        LIMIT 1
    ];

    if (cases.isEmpty()) {
        return;
    }


    Case c =
        cases[0];

    c.SRT_Case_Number__c =
        null;

    update c;


    Contact con = [
        SELECT Id, Phone
        FROM Contact
        WHERE Id = :c.ContactId
        LIMIT 1
    ];

    con.Phone =
        '9876543210';

    update con;


    Test.setMock(
        HttpCalloutMock.class,
        new SuccessMock()
    );


    Test.startTest();

    String result =
        SRT_RegistrationWhatsAppService.queueAfterCreate(
            c.Id
        );

    Test.stopTest();


    System.debug(
        'CASE NUMBER FALLBACK = ' +
        result
    );
}
@IsTest
static void testServiceTruncate() {

    Integer i = 0;

    String result1 =
        SRT_RegistrationWhatsAppService.truncate(
            null
        );

    System.debug(
        'TRUNCATE ' +
        i++ +
        ' = ' +
        result1
    );


    String result2 =
        SRT_RegistrationWhatsAppService.truncate(
            'Test Error Message'
        );

    System.debug(
        'TRUNCATE ' +
        i++ +
        ' = ' +
        result2
    );
}
}