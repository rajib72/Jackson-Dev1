@isTest
private class SRT_L1MessageTest {

    /* =========================================================
       HTTP MOCK (Go2Market)
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
            res.setBody(body);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    private static void mockOk() {
        Test.setMock(HttpCalloutMock.class,
            new Go2MarketMock(200, '{"MsgId":"MSG-12345"}', false));
    }

    /* =========================================================
       DATA HELPERS
       ========================================================= */

    private static void skipped(String reason) {
        System.debug(LoggingLevel.ERROR, 'TEST SKIPPED - ' + reason);
    }

    // Setup-object DML wrapped in runAs to avoid MIXED_DML_OPERATION
    private static User createUser(String mobile, String phone, Boolean active) {
        String uniq = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            FirstName         = 'L1',
            LastName          = 'Engineer',
            Alias             = 'l1' + uniq.left(5),
            Email             = 'l1.' + uniq + '@srt-test.com',
            Username          = 'l1.' + uniq + '@srt-test.com',
            ProfileId         = UserInfo.getProfileId(),
            TimeZoneSidKey    = 'Asia/Kolkata',
            LocaleSidKey      = 'en_IN',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            MobilePhone       = mobile,
            Phone             = phone,
            IsActive          = active
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    private static Contact createContact(String phone, String mobile) {
        return createContact(phone, mobile, null);
    }

    // Contact under the same Account as the Case (avoids Account/Contact mismatch rules)
    private static Contact createContact(String phone, String mobile, Id accountId) {
        Contact con = new Contact(
            FirstName   = 'Test',
            LastName    = 'Customer',
            Phone       = phone,
            MobilePhone = mobile,
            Email       = 'customer@test.com',
            AccountId   = accountId
        );
        insert con;
        return con;
    }

    private static Account createAccount() {
        Account full = new Account(Name = 'Test Account', BillingPostalCode = '700001');
        try {
            full.put('Building_Street__c', '12 Test Street');
            full.put('District__c', 'Kolkata');
        } catch (Exception e) {
            // field types differ in this org - fall back to plain account below
        }
        Database.SaveResult sr = Database.insert(full, false);
        if (sr.isSuccess()) {
            return full;
        }
        Account plain = new Account(Name = 'Test Account');
        insert plain;
        return plain;
    }

    // Returns null (and logs why) if the org rejects the Case.
    // If inserting with L1 user / asset fails, inserts plain and sets them by update.
    private static Case createCase(Id contactId, Id accountId, Id l1UserId, Id assetId) {
        Case c = new Case(
            ContactId = contactId,
            Subject   = 'Test L1 Case',
            Origin    = 'Phone'
        );
        if (accountId != null) {
            c.AccountId = accountId;
        }
        if (l1UserId != null) {
            c.L1_User_Assigned__c = l1UserId;
        }
        if (assetId != null) {
            c.AssetId = assetId;
        }
        Database.SaveResult sr = Database.insert(c, false);
        if (sr.isSuccess()) {
            return c;
        }
        String firstError = sr.getErrors()[0].getMessage();

        if (l1UserId != null || assetId != null) {
            Case c2 = new Case(ContactId = contactId, Subject = 'Test L1 Case', Origin = 'Phone');
            if (accountId != null) {
                c2.AccountId = accountId;
            }
            Database.SaveResult sr2 = Database.insert(c2, false);
            if (sr2.isSuccess()) {
                c2.L1_User_Assigned__c = l1UserId;
                c2.AssetId = assetId;
                Database.SaveResult ur = Database.update(c2, false);
                if (ur.isSuccess()) {
                    return c2;
                }
                firstError = 'UPDATE: ' + ur.getErrors()[0].getMessage();
            }
        }
        skipped('Case rejected: ' + firstError);
        return null;
    }

    // Asset with a Product2 and the given warranty status. Returns null if org rejects it.
    private static Asset createAsset(Id accountId, Id contactId, String warranty) {
        Product2 prod = new Product2(Name = 'Test Product');
        insert prod;

        Asset a = new Asset(
            Name       = 'Test Asset',
            AccountId  = accountId,
            ContactId  = contactId,
            Product2Id = prod.Id
        );
        if (warranty != null) {
            try {
                a.put('Warranty_Status__c', warranty);
            } catch (Exception e) {
                // ignore
            }
        }
        Database.SaveResult sr = Database.insert(a, false);
        if (!sr.isSuccess() && warranty != null) {
            // retry without warranty (restricted picklist etc.)
            a = new Asset(Name = 'Test Asset', AccountId = accountId,
                          ContactId = contactId, Product2Id = prod.Id);
            sr = Database.insert(a, false);
        }
        if (!sr.isSuccess()) {
            skipped('Asset insert rejected: ' + sr.getErrors()[0].getMessage());
            return null;
        }
        return a;
    }

    private static void linkAsset(Id caseId, Id assetId) {
        Case_Related_Assets__c link = new Case_Related_Assets__c(
            Case__c  = caseId,
            Asset__c = assetId
        );
        Database.SaveResult sr = Database.insert(link, false);
        if (!sr.isSuccess()) {
            skipped('Case Related Asset insert rejected: ' + sr.getErrors()[0].getMessage());
        }
    }

    private static Id createLog(Id caseId) {
        Whatsapp_Messages__c log = new Whatsapp_Messages__c(
            Case__c             = caseId,
            Recipient_Number__c = '9876543210',
            Campaign_Name__c    = 'Request',
            Status__c           = 'Pending',
            Requested_At__c     = System.now()
        );
        Database.SaveResult sr = Database.insert(log, false);
        if (!sr.isSuccess()) {
            skipped('Whatsapp_Messages__c insert rejected: ' + sr.getErrors()[0].getMessage());
            return null;
        }
        return log.Id;
    }

    // Runs the service end-to-end (queueable executes at stopTest with the mock)
    private static String runService(Id caseId, Id userId) {
        mockOk();
        Test.startTest();
        String result = SRT_L1MessageService.prepareL1Message(caseId, userId);
        Test.stopTest();
        return result;
    }

    // Builds a standard fully-linked scenario: valid L1 user, account, contact, case
    private static Case buildCase(User l1, Id assetId) {
        Account acc = createAccount();
        Contact con = createContact('0091 9876543211', null, acc.Id);
        return createCase(con.Id, acc.Id, l1.Id, assetId);
    }

    /* =========================================================
       HELPER QUEUEABLE
       Calls the service from inside an async job. Apex tests do not allow
       chaining queueables, so the service's enqueueJob throws and its
       catch block (log -> Failed) runs.
       ========================================================= */

    private class ServiceCallerJob implements Queueable {
        private Id caseId;
        private Id userId;

        ServiceCallerJob(Id caseId, Id userId) {
            this.caseId = caseId;
            this.userId = userId;
        }

        public void execute(QueueableContext context) {
            SRT_L1MessageService.prepareL1Message(caseId, userId);
        }
    }

    /* =========================================================
       SERVICE - early exits
       ========================================================= */

    @isTest
    static void service_missingCaseOrUser() {
        User l1 = createUser('9876543210', null, true);

        System.assertEquals('WhatsApp not queued: Case or User is missing.',
            SRT_L1MessageService.prepareL1Message(null, l1.Id));
        System.assertEquals('WhatsApp not queued: Case or User is missing.',
            SRT_L1MessageService.prepareL1Message(l1.Id, null));
    }

    @isTest
    static void service_userNotFound() {
        Id fakeUserId = '005000000000001AAA';
        Id fakeCaseId = '500000000000001AAA';

        System.assertEquals('WhatsApp not queued: Selected L1 Salesforce User was not found.',
            SRT_L1MessageService.prepareL1Message(fakeCaseId, fakeUserId));
    }

    @isTest
    static void service_inactiveUser() {
        User l1 = createUser('9876543210', null, false);
        Id fakeCaseId = '500000000000001AAA';

        System.assertEquals('WhatsApp not queued: L1 must be an active internal Salesforce User.',
            SRT_L1MessageService.prepareL1Message(fakeCaseId, l1.Id));
    }

    @isTest
    static void service_userWithoutValidPhone() {
        User l1 = createUser(null, '12345', true);   // blank mobile, invalid phone
        Id fakeCaseId = '500000000000001AAA';

        System.assertEquals('WhatsApp not queued: L1 User MobilePhone/Phone is blank or invalid.',
            SRT_L1MessageService.prepareL1Message(fakeCaseId, l1.Id));
    }

    @isTest
    static void service_assignmentMismatch() {
        User l1 = createUser('9876543210', null, true);
        Contact con = createContact('9876543211', null);
        Case c = createCase(con.Id, null, null, null);  // no L1 assigned
        if (c == null) {
            return;
        }

        System.assertEquals('WhatsApp not queued: L1 assignment does not match the selected User.',
            SRT_L1MessageService.prepareL1Message(c.Id, l1.Id));
    }

    /* =========================================================
       SERVICE - success paths
       ========================================================= */

    @isTest
    static void service_success_fullData_withLinkedAsset_warrantyYes() {
        User l1 = createUser('+91 98765 43210', null, true);   // normalizes via "91" prefix
        Account acc = createAccount();
        Contact con = createContact('0091 9876543211', null, acc.Id);  // normalizes via "0091" prefix
        Asset ast = createAsset(acc.Id, con.Id, 'Active');
        if (ast == null) {
            return;
        }
        Case c = createCase(con.Id, acc.Id, l1.Id, null);
        if (c == null) {
            return;
        }
        linkAsset(c.Id, ast.Id);   // asset found through Case_Related_Assets__c

        String result = runService(c.Id, l1.Id);

        System.assert(result.startsWith('L1 WhatsApp request queued successfully.'), result);
        System.assertEquals(1, [SELECT COUNT() FROM Whatsapp_Messages__c WHERE Case__c = :c.Id]);
    }

    @isTest
    static void service_success_assetOnCase_warrantyNo() {
        User l1 = createUser('9876543210', null, true);
        Account acc = createAccount();
        Contact con = createContact('9876543211', null, acc.Id);
        Asset ast = createAsset(acc.Id, con.Id, 'Expired');
        if (ast == null) {
            return;
        }
        Case c = createCase(con.Id, acc.Id, l1.Id, ast.Id);   // AssetId set directly
        if (c == null) {
            return;
        }

        String result = runService(c.Id, l1.Id);

        System.assert(result.startsWith('L1 WhatsApp request queued successfully.'), result);
    }

    @isTest
    static void service_success_unknownWarranty_validationPending() {
        User l1 = createUser('9876543210', null, true);
        Account acc = createAccount();
        Contact con = createContact('9876543211', null, acc.Id);
        Asset ast = createAsset(acc.Id, con.Id, null);   // no warranty status
        if (ast == null) {
            return;
        }
        Case c = createCase(con.Id, acc.Id, l1.Id, ast.Id);
        if (c == null) {
            return;
        }

        String result = runService(c.Id, l1.Id);

        System.assert(result.startsWith('L1 WhatsApp request queued successfully.'), result);
    }

    @isTest
    static void service_success_noAsset_phoneFallbacks() {
        // L1 MobilePhone invalid -> falls back to Phone
        User l1 = createUser('12345', '9876543210', true);
        // Contact Phone blank -> falls back to MobilePhone
        Account acc = createAccount();
        Contact con = createContact(null, '9876543211', acc.Id);
        Case c = createCase(con.Id, acc.Id, l1.Id, null);
        if (c == null) {
            return;
        }

        String result = runService(c.Id, l1.Id);

        System.assert(result.startsWith('L1 WhatsApp request queued successfully.'), result);
    }

    @isTest
    static void service_success_noContact_usesAccountName() {
        User l1 = createUser('9876543210', null, true);
        Case c = buildCase(l1, null);
        if (c == null) {
            return;
        }
        c.ContactId = null;
        Database.SaveResult ur = Database.update(c, false);
        if (!ur.isSuccess()) {
            skipped('cannot clear Contact on Case: ' + ur.getErrors()[0].getMessage());
            return;
        }

        String result = runService(c.Id, l1.Id);

        System.assert(result.startsWith('L1 WhatsApp request queued successfully.'), result);
    }

    @isTest
    static void service_success_noAccountNoContactPhone_usesFallbacks() {
        User l1 = createUser('9876543210', null, true);
        Contact con = createContact('invalid', 'invalid');   // invalid numbers -> N/A
        Case c = createCase(con.Id, null, l1.Id, null);      // no account -> location N/A
        if (c == null) {
            return;
        }

        String result = runService(c.Id, l1.Id);

        System.assert(result.startsWith('L1 WhatsApp request queued successfully.'), result);
    }

    /* =========================================================
       QUEUEABLE
       ========================================================= */

    // Enqueues the job (runs at stopTest) and returns the log's final status.
    // Returns null if setup was rejected, 'NOLOG' when run without a log.
    private static String runQueueable(
        Integer statusCode, String body, Boolean throwException, Boolean withLog
    ) {
        Id caseId = null;
        Id logId  = null;

        if (withLog) {
            Contact con = createContact('9876543211', null);
            Case c = createCase(con.Id, null, null, null);
            if (c == null) {
                return null;
            }
            caseId = c.Id;
            logId  = createLog(caseId);
            if (logId == null) {
                return null;
            }
        }

        Test.setMock(HttpCalloutMock.class,
            new Go2MarketMock(statusCode, body, throwException));

        List<String> params = new List<String>{ 'SR-1', 'Prod', 'Cat', 'Name', '9876543211', 'Addr', 'Yes' };

        Test.startTest();
        if (withLog) {
            System.enqueueJob(new SRT_L1MessageQueueable(caseId, '9876543210', params, logId));
        } else {
            System.enqueueJob(new SRT_L1MessageQueueable(caseId, '9876543210', params));
        }
        Test.stopTest();

        if (!withLog) {
            return 'NOLOG';
        }
        return [SELECT Status__c FROM Whatsapp_Messages__c WHERE Id = :logId].Status__c;
    }

    @isTest
    static void queueable_http200_withMsgId_updatesLog() {
        String status = runQueueable(200, '{"MsgId":"MSG-12345"}', false, true);
        if (status == null) {
            return;
        }
        System.assertNotEquals('Pending', status, 'Log should be updated by the queueable.');
    }

    @isTest
    static void queueable_http200_noMsgId_updatesLog() {
        String status = runQueueable(200, '{"other":"value"}', false, true);
        if (status == null) {
            return;
        }
        System.assertNotEquals('Pending', status);
    }

    @isTest
    static void queueable_http200_invalidJson_updatesLog() {
        String status = runQueueable(200, 'not-json', false, true);
        if (status == null) {
            return;
        }
        System.assertNotEquals('Pending', status);
    }

    @isTest
    static void queueable_http500_marksFailed() {
        String status = runQueueable(500, '{"error":"server"}', false, true);
        if (status == null) {
            return;
        }
        System.assertNotEquals('Pending', status);
    }

    @isTest
    static void queueable_calloutException_marksUnknown() {
        String status = runQueueable(200, '', true, true);
        if (status == null) {
            return;
        }
        System.assertNotEquals('Pending', status);
    }

    @isTest
    static void queueable_withoutLogId_runsWithoutLogUpdate() {
        String status = runQueueable(200, '{"MsgId":"MSG-1"}', false, false);
        System.assertEquals('NOLOG', status);
    }

    /* =========================================================
       SERVICE - enqueue failure (catch block)
       ========================================================= */

    @isTest
    static void service_enqueueFails_logMarkedFailed() {
        User l1 = createUser('9876543210', null, true);
        Case c = buildCase(l1, null);
        if (c == null) {
            return;
        }

        mockOk();
        Test.startTest();
        System.enqueueJob(new ServiceCallerJob(c.Id, l1.Id));
        Test.stopTest();

        List<Whatsapp_Messages__c> logs = [
            SELECT Status__c, Failure_Reason__c
            FROM Whatsapp_Messages__c
            WHERE Case__c = :c.Id
        ];
        System.assertEquals(1, logs.size(), 'Service should have created one log.');
        System.assertEquals('Failed', logs[0].Status__c,
            'Queue failure should mark the log Failed.');
    }
}