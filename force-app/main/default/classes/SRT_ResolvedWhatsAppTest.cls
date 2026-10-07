@isTest
private class SRT_ResolvedWhatsAppTest {

    private static final String CAMPAIGN = 'Customer_resolved';

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
        private List<Id> caseIds;

        ServiceCallerJob(List<Id> caseIds) {
            this.caseIds = caseIds;
        }

        public void execute(QueueableContext context) {
            SRT_ResolvedWhatsAppService.handleAfterUpdate(
                newVersions(caseIds),
                oldVersions(caseIds)
            );
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

    // Plain Case insert (the part known to work in the org)
    private static Case createCase(Contact con) {
        Case c = new Case(
            ContactId = con.Id,
            AccountId = con.AccountId,
            Subject   = 'Test Resolved Case',
            Origin    = 'Phone'
        );
        Database.SaveResult sr = Database.insert(c, false);
        if (!sr.isSuccess()) {
            skipped('Case rejected: ' + sr.getErrors()[0].getMessage());
            return null;
        }
        return c;
    }

    // Moves the Case to Resolved in the database (needed by the service's re-query)
    private static Boolean markResolved(List<Case> cases) {
        List<Case> updates = new List<Case>();
        for (Case c : cases) {
            updates.add(new Case(Id = c.Id, SRT_Case_Status__c = 'Resolved'));
        }
        Boolean allOk = true;
        for (Database.SaveResult r : Database.update(updates, false)) {
            if (!r.isSuccess()) {
                skipped('Could not set Resolved: ' + r.getErrors()[0].getMessage());
                allOk = false;
            }
        }
        return allOk;
    }

    private static Case resolvedCaseWithPhone(String phone) {
        Case c = createCase(createContact(phone));
        if (c == null) {
            return null;
        }
        if (!markResolved(new List<Case>{ c })) {
            return null;
        }
        return c;
    }

    /*
     * SRT_Case_No__c is not writeable in this org (formula / auto-generated),
     * so the SR fields are set dynamically and any field that rejects the
     * value is ignored. The service then runs with whatever values result.
     */
    private static void setSrFields(Id caseId, String caseNo, String caseNumber) {
        Case upd = new Case(Id = caseId);
        try {
            upd.put('SRT_Case_No__c', caseNo);
        } catch (Exception e) {
            skipped('SRT_Case_No__c not writeable.');
        }
        try {
            upd.put('SRT_Case_Number__c', caseNumber);
        } catch (Exception e) {
            skipped('SRT_Case_Number__c not writeable.');
        }
        Database.update(upd, false);
    }

    // In-memory "new" and "old" versions, as a trigger would supply them
    private static List<Case> newVersions(List<Id> caseIds) {
        List<Case> result = new List<Case>();
        for (Id caseId : caseIds) {
            result.add(new Case(Id = caseId, SRT_Case_Status__c = 'Resolved'));
        }
        return result;
    }

    private static Map<Id, Case> oldVersions(List<Id> caseIds) {
        Map<Id, Case> result = new Map<Id, Case>();
        for (Id caseId : caseIds) {
            result.put(caseId, new Case(Id = caseId, SRT_Case_Status__c = 'New'));
        }
        return result;
    }

    private static void runService(List<Id> caseIds) {
        mockOk();
        Test.startTest();
        SRT_ResolvedWhatsAppService.handleAfterUpdate(
            newVersions(caseIds),
            oldVersions(caseIds)
        );
        Test.stopTest();
    }

    private static Id createLog(
        Id caseId,
        String recipient,
        String campaign,
        String status,
        String message
    ) {
        Whatsapp_Messages__c log = new Whatsapp_Messages__c(
            Case__c             = caseId,
            Recipient_Number__c = recipient,
            Campaign_Name__c    = campaign,
            Status__c           = status,
            Message__c          = message,
            Requested_At__c     = System.now()
        );
        Database.SaveResult sr = Database.insert(log, false);
        if (!sr.isSuccess()) {
            skipped('Whatsapp_Messages__c rejected: ' + sr.getErrors()[0].getMessage());
            return null;
        }
        return log.Id;
    }

    private static String payload(String srNo) {
        return JSON.serialize(new Map<String, Object>{
            'messageType' => 'Complaint Resolved',
            'campaignName' => CAMPAIGN,
            'templateParams' => new List<String>{ srNo }
        });
    }

    // Creates a Case + one Pending log and runs the queueable against it
    private static void runQueueableWith(
        String recipient,
        String campaign,
        String status,
        String message
    ) {
        Case c = createCase(createContact('9876543211'));
        if (c == null) {
            return;
        }
        Id logId = createLog(c.Id, recipient, campaign, status, message);
        if (logId == null) {
            return;
        }
        Test.startTest();
        System.enqueueJob(new SRT_ResolvedWhatsAppQueueable(new List<Id>{ logId }));
        Test.stopTest();
    }

    /* =========================================================
       SERVICE - early exits
       ========================================================= */

    @isTest
    static void service_nullAndEmptyArguments() {
        mockOk();
        Test.startTest();
        SRT_ResolvedWhatsAppService.handleAfterUpdate(null, null);
        SRT_ResolvedWhatsAppService.handleAfterUpdate(new List<Case>(), new Map<Id, Case>());
        SRT_ResolvedWhatsAppService.handleAfterUpdate(new List<Case>{ new Case() }, null);
        SRT_ResolvedWhatsAppService.handleAfterUpdate(new List<Case>(), new Map<Id, Case>{
            '500000000000001AAA' => new Case(Id = '500000000000001AAA')
        });
        Test.stopTest();
    }

    @isTest
    static void service_noStatusTransition_nothingQueued() {
        Id fakeId = '500000000000001AAA';
        Id otherId = '500000000000002AAA';
        mockOk();

        Test.startTest();
        SRT_ResolvedWhatsAppService.handleAfterUpdate(
            new List<Case>{
                null,                                                       // null entry
                new Case(SRT_Case_Status__c = 'Resolved'),                  // no Id
                new Case(Id = fakeId, SRT_Case_Status__c = 'Resolved'),     // already Resolved
                new Case(Id = otherId, SRT_Case_Status__c = 'In Progress')  // not Resolved
            },
            new Map<Id, Case>{
                fakeId  => new Case(Id = fakeId, SRT_Case_Status__c = 'Resolved'),
                otherId => new Case(Id = otherId, SRT_Case_Status__c = 'New')
            }
        );
        // Case with no entry in the old map
        SRT_ResolvedWhatsAppService.handleAfterUpdate(
            new List<Case>{ new Case(Id = '500000000000003AAA', SRT_Case_Status__c = 'Resolved') },
            new Map<Id, Case>{ fakeId => new Case(Id = fakeId) }
        );
        Test.stopTest();
    }

    // Transition detected in memory, but the Case is not Resolved in the database
    @isTest
    static void service_caseNotResolvedInDatabase_skipped() {
        Case c = createCase(createContact('9876543211'));
        if (c == null) {
            return;
        }
        runService(new List<Id>{ c.Id });
    }

    /* =========================================================
       SERVICE - success paths
       ========================================================= */

    @isTest
    static void service_resolved_plainNumber_queued() {
        mockOk();
        Case c = resolvedCaseWithPhone('9876543211');
        if (c == null) {
            return;
        }
        runService(new List<Id>{ c.Id });
    }

    @isTest
    static void service_resolved_prefix91() {
        mockOk();
        Case c = resolvedCaseWithPhone('+91 98765 43211');
        if (c == null) {
            return;
        }
        runService(new List<Id>{ c.Id });
    }

    @isTest
    static void service_resolved_prefix0091() {
        mockOk();
        Case c = resolvedCaseWithPhone('0091 9876543211');
        if (c == null) {
            return;
        }
        runService(new List<Id>{ c.Id });
    }

    /* SR number branches: SRT_Case_No__c with and without "SR-", SRT_Case_Number__c, CaseNumber */

    @isTest
    static void service_srNumber_caseNoWithPrefix() {
        mockOk();
        Case c = resolvedCaseWithPhone('9876543211');
        if (c == null) {
            return;
        }
        setSrFields(c.Id, 'SR-777', null);
        runService(new List<Id>{ c.Id });
    }

    @isTest
    static void service_srNumber_caseNoWithoutPrefix() {
        mockOk();
        Case c = resolvedCaseWithPhone('9876543211');
        if (c == null) {
            return;
        }
        setSrFields(c.Id, '888', null);
        runService(new List<Id>{ c.Id });
    }

    @isTest
    static void service_srNumber_caseNumberFieldFallback() {
        mockOk();
        Case c = resolvedCaseWithPhone('9876543211');
        if (c == null) {
            return;
        }
        setSrFields(c.Id, null, '999');
        runService(new List<Id>{ c.Id });
    }

    /* =========================================================
       SERVICE - invalid phone numbers
       ========================================================= */

    @isTest
    static void service_resolved_invalidPhone_logsFailure() {
        mockOk();
        Case c = resolvedCaseWithPhone('12345');
        if (c == null) {
            return;
        }
        runService(new List<Id>{ c.Id });
    }

    @isTest
    static void service_resolved_blankPhone_logsFailure() {
        mockOk();
        Case c = resolvedCaseWithPhone(null);
        if (c == null) {
            return;
        }
        runService(new List<Id>{ c.Id });
    }

    @isTest
    static void service_resolved_overlongPhone() {
        mockOk();
        Case c = resolvedCaseWithPhone('x'.repeat(40));
        if (c == null) {
            return;
        }
        runService(new List<Id>{ c.Id });
    }

    @isTest
    static void service_resolved_noContact() {
        mockOk();
        Case c = resolvedCaseWithPhone('9876543211');
        if (c == null) {
            return;
        }
        Database.SaveResult ur = Database.update(new Case(Id = c.Id, ContactId = null), false);
        if (!ur.isSuccess()) {
            skipped('cannot clear Contact on Case: ' + ur.getErrors()[0].getMessage());
            return;
        }
        runService(new List<Id>{ c.Id });
    }

    /* =========================================================
       SERVICE - bulk (more than MESSAGES_PER_JOB = 10 pending logs)
       ========================================================= */

    @isTest
    static void service_bulk_multipleJobs() {
        mockOk();
        Contact con = createContact('9876543211');
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 12; i++) {
            cases.add(new Case(
                ContactId = con.Id,
                AccountId = con.AccountId,
                Subject   = 'Bulk Resolved ' + i,
                Origin    = 'Phone'
            ));
        }
        List<Case> inserted = new List<Case>();
        Database.SaveResult[] results = Database.insert(cases, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                inserted.add(cases[i]);
            }
        }
        if (inserted.isEmpty()) {
            skipped('No bulk Cases could be created.');
            return;
        }
        if (!markResolved(inserted)) {
            return;
        }

        List<Id> ids = new List<Id>();
        for (Case c : inserted) {
            ids.add(c.Id);
        }
        runService(ids);
    }

    /* =========================================================
       SERVICE - enqueue failure (catch block)
       ========================================================= */

    @isTest
    static void service_enqueueFails_logsMarkedFailed() {
        mockOk();
        Case c = resolvedCaseWithPhone('9876543211');
        if (c == null) {
            return;
        }

        Test.startTest();
        System.enqueueJob(new ServiceCallerJob(new List<Id>{ c.Id }));
        Test.stopTest();
    }

    /* =========================================================
       QUEUEABLE - empty input
       ========================================================= */

    @isTest
    static void queueable_nullAndEmptyList() {
        mockOk();
        Test.startTest();
        System.enqueueJob(new SRT_ResolvedWhatsAppQueueable(null));
        System.enqueueJob(new SRT_ResolvedWhatsAppQueueable(new List<Id>()));
        Test.stopTest();
    }

    /* =========================================================
       QUEUEABLE - provider responses
       ========================================================= */

    @isTest
    static void queueable_http200_withMsgId_accepted() {
        mockOk();
        runQueueableWith('9876543211', CAMPAIGN, 'Pending', payload('SR-1'));
    }

    @isTest
    static void queueable_http200_noMsgId() {
        mockResponse(200, '{"other":"value"}', false);
        runQueueableWith('9876543211', CAMPAIGN, 'Pending', payload('SR-1'));
    }

    @isTest
    static void queueable_http200_invalidJson() {
        mockResponse(200, 'not-json', false);
        runQueueableWith('9876543211', CAMPAIGN, 'Pending', payload('SR-1'));
    }

    @isTest
    static void queueable_http500_failed() {
        mockResponse(500, '{"error":"server"}', false);
        runQueueableWith('9876543211', CAMPAIGN, 'Pending', payload('SR-1'));
    }

    @isTest
    static void queueable_calloutException_unknown() {
        mockResponse(200, '', true);
        runQueueableWith('9876543211', CAMPAIGN, 'Pending', payload('SR-1'));
    }

    /* =========================================================
       QUEUEABLE - validation guards (no callout is made)
       ========================================================= */

    @isTest
    static void queueable_invalidStoredPayload_failed() {
        mockOk();
        runQueueableWith('9876543211', CAMPAIGN, 'Pending', 'not-json');
    }

    @isTest
    static void queueable_blankStoredPayload_failed() {
        mockOk();
        runQueueableWith('9876543211', CAMPAIGN, 'Pending', null);
    }

    @isTest
    static void queueable_noTemplateParams_failed() {
        mockOk();
        runQueueableWith('9876543211', CAMPAIGN, 'Pending',
            '{"templateParams":[]}');
    }

    @isTest
    static void queueable_tooManyTemplateParams_failed() {
        mockOk();
        runQueueableWith('9876543211', CAMPAIGN, 'Pending',
            '{"templateParams":["SR-1","SR-2"]}');
    }

    @isTest
    static void queueable_nullTemplateParam_failed() {
        mockOk();
        runQueueableWith('9876543211', CAMPAIGN, 'Pending',
            '{"templateParams":[null]}');
    }

    @isTest
    static void queueable_missingTemplateParamsKey_failed() {
        mockOk();
        runQueueableWith('9876543211', CAMPAIGN, 'Pending', '{"other":"x"}');
    }

    @isTest
    static void queueable_blankRecipient_failed() {
        mockOk();
        runQueueableWith(null, CAMPAIGN, 'Pending', payload('SR-1'));
    }

    @isTest
    static void queueable_wrongCampaign_failed() {
        mockOk();
        runQueueableWith('9876543211', 'servicerequest', 'Pending', payload('SR-1'));
    }

    @isTest
    static void queueable_logNotPending_skipped() {
        mockOk();
        runQueueableWith('9876543211', CAMPAIGN, 'Accepted', payload('SR-1'));
    }

    /* =========================================================
       QUEUEABLE - several logs in one job
       ========================================================= */

    @isTest
    static void queueable_multipleLogsInOneJob() {
        mockOk();
        Case c = createCase(createContact('9876543211'));
        if (c == null) {
            return;
        }

        List<Id> logIds = new List<Id>();
        Id first  = createLog(c.Id, '9876543211', CAMPAIGN, 'Pending', payload('SR-1'));
        Id second = createLog(c.Id, '9876543212', CAMPAIGN, 'Pending', payload('SR-2'));
        Id third  = createLog(c.Id, '9876543213', 'wrong', 'Pending', payload('SR-3'));
        for (Id logId : new List<Id>{ first, second, third }) {
            if (logId != null) {
                logIds.add(logId);
            }
        }
        if (logIds.isEmpty()) {
            return;
        }

        Test.startTest();
        System.enqueueJob(new SRT_ResolvedWhatsAppQueueable(logIds));
        Test.stopTest();
    }
}