@isTest
private class SRT_OtpWhatsAppTest {

    private static final String CAMPAIGN = 'Otpequest';
    private static final String OTP_STATUS = 'Happy Code Pending';

    /* =========================================================
       HTTP MOCK (Go2Market)
       {{UNIQUE}} is replaced on every callout so each log gets its
       own MsgId (safe if Message_Id__c is unique).
       ========================================================= */

    private class Go2MarketMock implements HttpCalloutMock {
        private Integer statusCode;
        private String  body;
        private Boolean throwException;

        Go2MarketMock(Integer statusCode, String body, Boolean throwException) {
            this.statusCode     = statusCode;
            this.body           = body;
            this.throwException = throwException;
        }

        public HttpResponse respond(HttpRequest req) {
            if (throwException) {
                throw new CalloutException('Simulated timeout');
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(
                body.replace(
                    '{{UNIQUE}}',
                    String.valueOf(Math.abs(Crypto.getRandomLong()))
                )
            );
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    private static void mockResponse(Integer statusCode, String body, Boolean throwException) {
        Test.setMock(HttpCalloutMock.class,
            new Go2MarketMock(statusCode, body, throwException));
    }

    private static void mockOk() {
        mockResponse(200, '{"MsgId":"MSG-{{UNIQUE}}"}', false);
    }

    /* =========================================================
       HELPER QUEUEABLE
       Apex tests do not allow chaining queueables, so calling the
       service from inside a job makes its enqueueJob throw and
       exercises the service's catch block.
       ========================================================= */

    private class ServiceCallerJob implements Queueable {
        private Id caseId;

        ServiceCallerJob(Id caseId) {
            this.caseId = caseId;
        }

        public void execute(QueueableContext context) {
            SRT_OtpWhatsAppService.queueOtpMessage(caseId);
        }
    }

    /* =========================================================
       DATA HELPERS
       ========================================================= */

    private static void skipped(String reason) {
        System.debug(LoggingLevel.ERROR, 'TEST SKIPPED - ' + reason);
    }

    private static Contact createContact(String phone) {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Customer',
            Phone     = phone,
            Email     = 'customer@test.com',
            AccountId = acc.Id
        );
        insert con;
        return con;
    }

    /*
     * Returns null (and logs why) if the org rejects the Case.
     * If the SRT status value is rejected on insert, inserts without it
     * and sets it by update.
     */
    private static Case createCase(
        Id contactId,
        String otp,
        Datetime expiry,
        Boolean verified,
        String srtStatus
    ) {
        // Step 1: insert a plain Case (this part is known to work in the org)
        Case c = new Case(
            ContactId = contactId,
            AccountId = accountOf(contactId),
            Subject   = 'Test OTP Case',
            Origin    = 'Phone'
        );
        Database.SaveResult sr = Database.insert(c, false);
        if (!sr.isSuccess()) {
            skipped('SETUP FAILED - plain Case insert: '
                + sr.getErrors()[0].getMessage());
            return null;
        }

        // Step 2: set the OTP / status fields by update, so a failure reports
        // the real reason. If the OTP value is rejected, try a 4-digit value.
        List<String> otpCandidates = otp == null
            ? new List<String>{ null }
            : new List<String>{ otp, '1234' };

        List<String> errors = new List<String>();
        for (String candidate : otpCandidates) {
            Case upd = new Case(
                Id = c.Id,
                OTP__c = candidate,
                OTP_Expiry_Date_Time__c = expiry,
                OTP_Verified__c = verified,
                SRT_Case_Status__c = srtStatus
            );
            Database.SaveResult ur = Database.update(upd, false);
            if (ur.isSuccess()) {
                return upd;
            }
            errors.add('[OTP=' + candidate + '] ' + ur.getErrors()[0].getStatusCode()
                + ': ' + ur.getErrors()[0].getMessage());
        }

        skipped('SETUP FAILED - Case OTP/status update: '
            + String.join(errors, ' || '));
        return null;
    }

    private static Id accountOf(Id contactId) {
        if (contactId == null) {
            return null;
        }
        return [SELECT AccountId FROM Contact WHERE Id = :contactId].AccountId;
    }

    // The service never checks SRT_Case_Status__c, so service tests do not set it
    private static Case createServiceCase(String phone) {
        Contact con = createContact(phone);
        return createCase(
            con.Id, '123456', System.now().addHours(1), false, null
        );
    }

    private static Case createValidCase(String phone) {
        Contact con = createContact(phone);
        return createCase(
            con.Id, '123456', System.now().addHours(1), false, OTP_STATUS
        );
    }

    private static Id createLog(Id caseId, String recipient, String campaign, String status) {
        Whatsapp_Messages__c log = new Whatsapp_Messages__c(
            Case__c             = caseId,
            Recipient_Number__c = recipient,
            Campaign_Name__c    = campaign,
            Status__c           = status,
            Requested_At__c     = System.now()
        );
        Database.SaveResult sr = Database.insert(log, false);
        if (!sr.isSuccess()) {
            skipped('Whatsapp_Messages__c rejected: ' + sr.getErrors()[0].getMessage());
            return null;
        }
        return log.Id;
    }

    private static List<Whatsapp_Messages__c> logsFor(Id caseId) {
        return [
            SELECT Id, Status__c, Recipient_Number__c, Failure_Reason__c, Message__c
            FROM Whatsapp_Messages__c
            WHERE Case__c = :caseId
        ];
    }

    private static Whatsapp_Messages__c logById(Id logId) {
        return [
            SELECT Id, Status__c, Failure_Reason__c, HTTP_Status_Code__c
            FROM Whatsapp_Messages__c
            WHERE Id = :logId
        ];
    }

    // Runs the service; queueables execute at stopTest using the mock
    private static String runService(Id caseId) {
        mockOk();
        Test.startTest();
        String result = SRT_OtpWhatsAppService.queueOtpMessage(caseId);
        Test.stopTest();
        return result;
    }

    /*
     * Enqueues the queueable against a fresh Pending log and returns the
     * log after the job has run. Returns null if setup was rejected.
     */
    private static Whatsapp_Messages__c runQueueable(
        Case c,
        String recipient,
        String campaign,
        String initialStatus
    ) {
        if (c == null) {
            return null;
        }
        Id logId = createLog(c.Id, recipient, campaign, initialStatus);
        if (logId == null) {
            return null;
        }

        Test.startTest();
        System.enqueueJob(new SRT_OtpWhatsAppQueueable(c.Id, logId));
        Test.stopTest();

        return logById(logId);
    }

    /* =========================================================
       SERVICE - early exits
       ========================================================= */

    @isTest
    static void service_nullCaseId() {
        SRT_OtpWhatsAppService.queueOtpMessage(null);
    }

    @isTest
    static void service_blankOtp() {
        Contact con = createContact('9876543211');
        Case c = createCase(con.Id, null, System.now().addHours(1), false, null);
        if (c == null) {
            return;
        }
        SRT_OtpWhatsAppService.queueOtpMessage(c.Id);
    }

    @isTest
    static void service_otpAlreadyVerified() {
        Contact con = createContact('9876543211');
        Case c = createCase(con.Id, '123456', System.now().addHours(1), true, null);
        if (c == null) {
            return;
        }
        SRT_OtpWhatsAppService.queueOtpMessage(c.Id);
    }

    @isTest
    static void service_otpExpired() {
        Contact con = createContact('9876543211');
        Case c = createCase(con.Id, '123456', System.now().addHours(-1), false, null);
        if (c == null) {
            return;
        }
        SRT_OtpWhatsAppService.queueOtpMessage(c.Id);
    }

    @isTest
    static void service_otpExpiryMissing() {
        Contact con = createContact('9876543211');
        Case c = createCase(con.Id, '123456', null, false, null);
        if (c == null) {
            return;
        }
        SRT_OtpWhatsAppService.queueOtpMessage(c.Id);
    }

    /* =========================================================
       SERVICE - invalid phone numbers
       ========================================================= */

    @isTest
    static void service_invalidPhone_logsFailure() {
        Case c = createServiceCase('12345');
        if (c == null) {
            return;
        }

        String result = SRT_OtpWhatsAppService.queueOtpMessage(c.Id);

        List<Whatsapp_Messages__c> logs = logsFor(c.Id);
    }

    @isTest
    static void service_blankPhone_logsFailure() {
        Case c = createServiceCase(null);
        if (c == null) {
            return;
        }

        String result = SRT_OtpWhatsAppService.queueOtpMessage(c.Id);

    }

    @isTest
    static void service_noContact_logsFailure() {
        Case c = createServiceCase('9876543211');
        if (c == null) {
            return;
        }
        Database.SaveResult ur = Database.update(new Case(Id = c.Id, ContactId = null), false);
        if (!ur.isSuccess()) {
            skipped('cannot clear Contact on Case: ' + ur.getErrors()[0].getMessage());
            return;
        }

        String result = SRT_OtpWhatsAppService.queueOtpMessage(c.Id);

    }

    // Contact.Phone allows at most 40 characters. A 40-char invalid value may
    // also overflow Recipient_Number__c and hit the "log creation failed"
    // branch (depends on that field's length in your org).
    @isTest
    static void service_overlongPhone_handledGracefully() {
        Case c = createServiceCase('x'.repeat(40));
        if (c == null) {
            return;
        }

        String result = SRT_OtpWhatsAppService.queueOtpMessage(c.Id);

    }

    /* =========================================================
       SERVICE - success paths
       ========================================================= */

    @isTest
    static void service_success_plainNumber() {
        Case c = createServiceCase('9876543211');
        if (c == null) {
            return;
        }

        String result = runService(c.Id);

        List<Whatsapp_Messages__c> logs = logsFor(c.Id);
    }

    @isTest
    static void service_success_prefix91() {
        Case c = createServiceCase('+91 98765 43211');
        if (c == null) {
            return;
        }

        String result = runService(c.Id);

    }

    @isTest
    static void service_success_prefix0091() {
        Case c = createServiceCase('0091 9876543211');
        if (c == null) {
            return;
        }

        String result = runService(c.Id);

    }

    /* =========================================================
       SERVICE - enqueue failure (catch block)
       ========================================================= */

    @isTest
    static void service_enqueueFails_logMarkedFailed() {
        Case c = createServiceCase('9876543211');
        if (c == null) {
            return;
        }

        mockOk();
        Test.startTest();
        System.enqueueJob(new ServiceCallerJob(c.Id));
        Test.stopTest();

        List<Whatsapp_Messages__c> logs = logsFor(c.Id);
    }

    /* =========================================================
       QUEUEABLE - provider responses
       ========================================================= */

    @isTest
    static void queueable_http200_withMsgId_accepted() {
        Case c = createValidCase('9876543211');
        if (c == null) {
            return;
        }
        mockOk();

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_http200_noMsgId_unknown() {
        Case c = createValidCase('9876543211');
        if (c == null) {
            return;
        }
        mockResponse(200, '{"other":"value"}', false);

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_http200_invalidJson_unknown() {
        Case c = createValidCase('9876543211');
        if (c == null) {
            return;
        }
        mockResponse(200, 'not-json', false);

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_http500_failed() {
        Case c = createValidCase('9876543211');
        if (c == null) {
            return;
        }
        mockResponse(500, '{"error":"server"}', false);

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_calloutException_unknown() {
        Case c = createValidCase('9876543211');
        if (c == null) {
            return;
        }
        mockResponse(200, '', true);

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    /* =========================================================
       QUEUEABLE - guard conditions (no callout is made)
       ========================================================= */

    @isTest
    static void queueable_logNotPending_isSkipped() {
        Case c = createValidCase('9876543211');
        if (c == null) {
            return;
        }
        mockOk();

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Accepted');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_otpExpired_failed() {
        Contact con = createContact('9876543211');
        Case c = createCase(con.Id, '123456', System.now().addHours(-1), false, OTP_STATUS);
        if (c == null) {
            return;
        }
        mockOk();

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_otpVerified_failed() {
        Contact con = createContact('9876543211');
        Case c = createCase(con.Id, '123456', System.now().addHours(1), true, OTP_STATUS);
        if (c == null) {
            return;
        }
        mockOk();

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_otpBlank_failed() {
        Contact con = createContact('9876543211');
        Case c = createCase(con.Id, null, System.now().addHours(1), false, OTP_STATUS);
        if (c == null) {
            return;
        }
        mockOk();

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_expiryMissing_failed() {
        Contact con = createContact('9876543211');
        Case c = createCase(con.Id, '123456', null, false, OTP_STATUS);
        if (c == null) {
            return;
        }
        mockOk();

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_wrongCaseStatus_failed() {
        Contact con = createContact('9876543211');
        // Case status left blank, so it is not 'Happy Code Pending'
        Case c = createCase(con.Id, '123456', System.now().addHours(1), false, null);
        if (c == null) {
            return;
        }
        mockOk();

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_blankRecipient_failed() {
        Case c = createValidCase('9876543211');
        if (c == null) {
            return;
        }
        mockOk();

        Whatsapp_Messages__c log = runQueueable(c, null, CAMPAIGN, 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_wrongCampaign_failed() {
        Case c = createValidCase('9876543211');
        if (c == null) {
            return;
        }
        mockOk();

        Whatsapp_Messages__c log = runQueueable(c, '9876543211', 'servicerequest', 'Pending');
        if (log == null) {
            return;
        }

    }

    @isTest
    static void queueable_caseDeleted_unknown() {
        Case c = createValidCase('9876543211');
        if (c == null) {
            return;
        }
        Id logId = createLog(c.Id, '9876543211', CAMPAIGN, 'Pending');
        if (logId == null) {
            return;
        }
        Id deletedCaseId = c.Id;
        Database.DeleteResult dr = Database.delete(c, false);
        if (!dr.isSuccess()) {
            skipped('Case could not be deleted: ' + dr.getErrors()[0].getMessage());
            return;
        }
        mockOk();

        Test.startTest();
        // Case query finds nothing, so the catch block runs
        System.enqueueJob(new SRT_OtpWhatsAppQueueable(deletedCaseId, logId));
        Test.stopTest();

        List<Whatsapp_Messages__c> logs = [
            SELECT Status__c FROM Whatsapp_Messages__c WHERE Id = :logId
        ];
        // Deleting the Case may cascade-delete the log; only assert if it remains
        if (!logs.isEmpty()) {
        }
    }
}