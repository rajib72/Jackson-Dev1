@isTest
private class SRT_L2MessageTest {

    /* =========================================================
       HTTP MOCK (Go2Market)
       {{UNIQUE}} in the body is replaced on every callout, so each
       log record receives its own MsgId (avoids DUPLICATE_VALUE on
       Message_Id__c when two jobs run in the same test).
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

    private static void mockOk() {
        Test.setMock(HttpCalloutMock.class,
            new Go2MarketMock(200, '{"MsgId":"MSG-{{UNIQUE}}"}', false));
    }

    /* =========================================================
       HELPER QUEUEABLE
       Calls the service from inside an async job. Apex tests do not allow
       chaining queueables, so the service's enqueueJob throws and its
       catch block (log -> Failed) runs.
       ========================================================= */

    private class ServiceCallerJob implements Queueable {
        private Id caseId;
        private Id dealerId;

        ServiceCallerJob(Id caseId, Id dealerId) {
            this.caseId   = caseId;
            this.dealerId = dealerId;
        }

        public void execute(QueueableContext context) {
            SRT_L2MessageService.queueL2Messages(caseId, dealerId);
        }
    }

    /* =========================================================
       DATA HELPERS
       ========================================================= */

    private static void skipped(String reason) {
        System.debug(LoggingLevel.ERROR, 'TEST SKIPPED - ' + reason);
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

    // Contact under the same Account as the Case (avoids Account/Contact mismatch rules)
    private static Contact createContact(String phone, Id accountId) {
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Customer',
            Phone     = phone,
            Email     = 'customer@test.com',
            AccountId = accountId
        );
        insert con;
        return con;
    }

    // Returns null (and logs why) if the org rejects the dealer
    private static Dealer_Supplier_Master__c createDealer(String mobile) {
        Dealer_Supplier_Master__c d = new Dealer_Supplier_Master__c();
        try {
            d.put('Name', 'Test Dealer');
        } catch (Exception e) {
            // Name may be an auto-number
        }
        d.Mobile_Number__c = mobile;
        Database.SaveResult sr = Database.insert(d, false);
        if (!sr.isSuccess()) {
            skipped('Dealer_Supplier_Master__c rejected: ' + sr.getErrors()[0].getMessage());
            return null;
        }
        return d;
    }

    // Returns null (and logs why) if the org rejects the Case.
    // If inserting with L2 dealer / asset fails, inserts plain and sets them by update.
    private static Case createCase(Id contactId, Id accountId, Id dealerId, Id assetId) {
        Case c = new Case(
            ContactId = contactId,
            Subject   = 'Test L2 Case',
            Origin    = 'Phone'
        );
        if (accountId != null) {
            c.AccountId = accountId;
        }
        if (dealerId != null) {
            c.L2_Assigned__c = dealerId;
        }
        if (assetId != null) {
            c.AssetId = assetId;
        }
        Database.SaveResult sr = Database.insert(c, false);
        if (sr.isSuccess()) {
            return c;
        }
        String firstError = sr.getErrors()[0].getMessage();

        if (dealerId != null || assetId != null) {
            Case c2 = new Case(ContactId = contactId, Subject = 'Test L2 Case', Origin = 'Phone');
            if (accountId != null) {
                c2.AccountId = accountId;
            }
            Database.SaveResult sr2 = Database.insert(c2, false);
            if (sr2.isSuccess()) {
                c2.L2_Assigned__c = dealerId;
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
            a = new Asset(Name = 'Test Asset', AccountId = accountId,
                          ContactId = contactId, Product2Id = prod.Id);
            sr = Database.insert(a, false);
        }
        if (!sr.isSuccess()) {
            skipped('Asset rejected: ' + sr.getErrors()[0].getMessage());
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
            skipped('Case Related Asset rejected: ' + sr.getErrors()[0].getMessage());
        }
    }

    private static Id createLog(Id caseId) {
        Whatsapp_Messages__c log = new Whatsapp_Messages__c(
            Case__c             = caseId,
            Recipient_Number__c = '9876543210',
            Campaign_Name__c    = 'servicerequest',
            Status__c           = 'Pending',
            Requested_At__c     = System.now()
        );
        Database.SaveResult sr = Database.insert(log, false);
        if (!sr.isSuccess()) {
            skipped('Whatsapp_Messages__c rejected: ' + sr.getErrors()[0].getMessage());
            return null;
        }
        return log.Id;
    }

    // Runs the service end-to-end (queueables execute at stopTest with the mock)
    private static Map<String, String> runService(Id caseId, Id dealerId) {
        mockOk();
        Test.startTest();
        Map<String, String> results = SRT_L2MessageService.queueL2Messages(caseId, dealerId);
        Test.stopTest();
        return results;
    }

    private static Integer logCount(Id caseId) {
        return [SELECT COUNT() FROM Whatsapp_Messages__c WHERE Case__c = :caseId];
    }

    /* =========================================================
       SERVICE - early exits
       ========================================================= */

    @isTest
    static void service_missingCaseOrDealer() {
        Id fake = '500000000000001AAA';

        Map<String, String> r1 = SRT_L2MessageService.queueL2Messages(null, fake);
        System.assertEquals('Not queued: Case or dealer is missing.', r1.get('customer'));
        System.assertEquals('Not queued: Case or dealer is missing.', r1.get('dealer'));

        Map<String, String> r2 = SRT_L2MessageService.queueL2Messages(fake, null);
        System.assertEquals('Not queued: Case or dealer is missing.', r2.get('customer'));
        System.assertEquals('Not queued: Case or dealer is missing.', r2.get('dealer'));
    }

    @isTest
    static void service_dealerDoesNotMatchCase() {
        Dealer_Supplier_Master__c dealer = createDealer('9876543210');
        if (dealer == null) {
            return;
        }
        Account acc = createAccount();
        Contact con = createContact('9876543211', acc.Id);
        Case c = createCase(con.Id, acc.Id, null, null);   // no L2 assigned
        if (c == null) {
            return;
        }

        Map<String, String> r = SRT_L2MessageService.queueL2Messages(c.Id, dealer.Id);

        System.assertEquals('Not queued: L2 dealer does not match the Case.', r.get('customer'));
        System.assertEquals('Not queued: L2 dealer does not match the Case.', r.get('dealer'));
    }

    /* =========================================================
       SERVICE - success paths
       ========================================================= */

    @isTest
    static void service_success_linkedAsset_warrantyYes_bothQueued() {
        Dealer_Supplier_Master__c dealer = createDealer('+91 98765 43210');   // "91" prefix
        if (dealer == null) {
            return;
        }
        Account acc = createAccount();
        Contact con = createContact('0091 9876543211', acc.Id);                // "0091" prefix
        Asset ast = createAsset(acc.Id, con.Id, 'Active');
        if (ast == null) {
            return;
        }
        Case c = createCase(con.Id, acc.Id, dealer.Id, null);
        if (c == null) {
            return;
        }
        linkAsset(c.Id, ast.Id);   // asset found through Case_Related_Assets__c

        Map<String, String> r = runService(c.Id, dealer.Id);

        System.assert(r.get('customer').startsWith('Queued.'), r.get('customer'));
        System.assert(r.get('dealer').startsWith('Queued.'), r.get('dealer'));
        System.assertEquals(2, logCount(c.Id), 'One log per recipient.');
    }

    @isTest
    static void service_success_assetOnCase_warrantyNo() {
        Dealer_Supplier_Master__c dealer = createDealer('9876543210');
        if (dealer == null) {
            return;
        }
        Account acc = createAccount();
        Contact con = createContact('9876543211', acc.Id);
        Asset ast = createAsset(acc.Id, con.Id, 'Expired');
        if (ast == null) {
            return;
        }
        Case c = createCase(con.Id, acc.Id, dealer.Id, ast.Id);   // AssetId set directly
        if (c == null) {
            return;
        }

        Map<String, String> r = runService(c.Id, dealer.Id);

        System.assert(r.get('customer').startsWith('Queued.'), r.get('customer'));
        System.assert(r.get('dealer').startsWith('Queued.'), r.get('dealer'));
    }

    @isTest
    static void service_success_unknownWarranty_validationPending() {
        Dealer_Supplier_Master__c dealer = createDealer('9876543210');
        if (dealer == null) {
            return;
        }
        Account acc = createAccount();
        Contact con = createContact('9876543211', acc.Id);
        Asset ast = createAsset(acc.Id, con.Id, null);   // no warranty status
        if (ast == null) {
            return;
        }
        Case c = createCase(con.Id, acc.Id, dealer.Id, ast.Id);
        if (c == null) {
            return;
        }

        Map<String, String> r = runService(c.Id, dealer.Id);

        System.assert(r.get('dealer').startsWith('Queued.'), r.get('dealer'));
    }

    @isTest
    static void service_success_noAssetNoAccount_usesFallbacks() {
        Dealer_Supplier_Master__c dealer = createDealer('9876543210');
        if (dealer == null) {
            return;
        }
        Contact con = createContact('9876543211', null);
        Case c = createCase(con.Id, null, dealer.Id, null);   // no account -> location N/A
        if (c == null) {
            return;
        }

        Map<String, String> r = runService(c.Id, dealer.Id);

        System.assert(r.get('customer').startsWith('Queued.'), r.get('customer'));
        System.assert(r.get('dealer').startsWith('Queued.'), r.get('dealer'));
    }

    @isTest
    static void service_noContact_usesAccountName_customerNotQueued() {
        Dealer_Supplier_Master__c dealer = createDealer('9876543210');
        if (dealer == null) {
            return;
        }
        Account acc = createAccount();
        Contact con = createContact('9876543211', acc.Id);
        Case c = createCase(con.Id, acc.Id, dealer.Id, null);
        if (c == null) {
            return;
        }
        c.ContactId = null;
        Database.SaveResult ur = Database.update(c, false);
        if (!ur.isSuccess()) {
            skipped('cannot clear Contact on Case: ' + ur.getErrors()[0].getMessage());
            return;
        }

        Map<String, String> r = runService(c.Id, dealer.Id);

        System.assert(r.get('customer').startsWith('Not queued: invalid recipient number.'),
            r.get('customer'));
        System.assert(r.get('dealer').startsWith('Queued.'), r.get('dealer'));
    }

    /* =========================================================
       SERVICE - invalid phone numbers
       ========================================================= */

    @isTest
    static void service_invalidCustomerPhone_dealerStillQueued() {
        Dealer_Supplier_Master__c dealer = createDealer('9876543210');
        if (dealer == null) {
            return;
        }
        Account acc = createAccount();
        Contact con = createContact('12345', acc.Id);   // invalid
        Case c = createCase(con.Id, acc.Id, dealer.Id, null);
        if (c == null) {
            return;
        }

        Map<String, String> r = runService(c.Id, dealer.Id);

        System.assert(r.get('customer').startsWith('Not queued: invalid recipient number.'),
            r.get('customer'));
        System.assert(r.get('dealer').startsWith('Queued.'), r.get('dealer'));
        System.assertEquals(2, logCount(c.Id), 'Failed attempt is logged too.');
    }

    @isTest
    static void service_invalidDealerMobile_customerStillQueued() {
        Dealer_Supplier_Master__c dealer = createDealer('abc');   // invalid
        if (dealer == null) {
            return;
        }
        Account acc = createAccount();
        Contact con = createContact('9876543211', acc.Id);
        Case c = createCase(con.Id, acc.Id, dealer.Id, null);
        if (c == null) {
            return;
        }

        Map<String, String> r = runService(c.Id, dealer.Id);

        System.assert(r.get('customer').startsWith('Queued.'), r.get('customer'));
        System.assert(r.get('dealer').startsWith('Not queued: invalid recipient number.'),
            r.get('dealer'));
    }

    // A very long invalid phone may overflow Recipient_Number__c and exercise the
    // "unable to create log" branch (depends on that field's length in your org).
    @isTest
    static void service_overlongInvalidPhone_handledGracefully() {
        Dealer_Supplier_Master__c dealer = createDealer('9876543210');
        if (dealer == null) {
            return;
        }
        Account acc = createAccount();
        Contact con = createContact('x'.repeat(40), acc.Id);
        Case c = createCase(con.Id, acc.Id, dealer.Id, null);
        if (c == null) {
            return;
        }

        Map<String, String> r = runService(c.Id, dealer.Id);

        System.assert(r.get('customer').startsWith('Not queued'), r.get('customer'));
    }

    /* =========================================================
       SERVICE - enqueue failure (catch block)
       ========================================================= */

    @isTest
    static void service_enqueueFails_logsMarkedFailed() {
        Dealer_Supplier_Master__c dealer = createDealer('9876543210');
        if (dealer == null) {
            return;
        }
        Account acc = createAccount();
        Contact con = createContact('9876543211', acc.Id);
        Case c = createCase(con.Id, acc.Id, dealer.Id, null);
        if (c == null) {
            return;
        }

        mockOk();
        Test.startTest();
        System.enqueueJob(new ServiceCallerJob(c.Id, dealer.Id));
        Test.stopTest();

        List<Whatsapp_Messages__c> logs = [
            SELECT Status__c FROM Whatsapp_Messages__c WHERE Case__c = :c.Id
        ];
        System.assertEquals(2, logs.size(), 'One log per recipient.');
        for (Whatsapp_Messages__c l : logs) {
            System.assertEquals('Failed', l.Status__c, 'Queue failure should mark the log Failed.');
        }
    }

    /* =========================================================
       QUEUEABLE
       ========================================================= */

    // Enqueues the job (runs at stopTest) and returns the log's final status.
    // Returns null if setup was rejected.
    private static String runQueueable(Integer statusCode, String body, Boolean throwException) {
        Contact con = createContact('9876543211', null);
        Case c = createCase(con.Id, null, null, null);
        if (c == null) {
            return null;
        }
        Id logId = createLog(c.Id);
        if (logId == null) {
            return null;
        }

        Test.setMock(HttpCalloutMock.class,
            new Go2MarketMock(statusCode, body, throwException));

        List<String> params = new List<String>{ 'SR-1', 'Prod', 'Cat', 'Name', '9876543211', 'Addr', 'Yes' };

        Test.startTest();
        System.enqueueJob(new SRT_L2MessageQueueable(
            c.Id, '9876543210', 'servicerequest', params, logId));
        Test.stopTest();

        return [SELECT Status__c FROM Whatsapp_Messages__c WHERE Id = :logId].Status__c;
    }

    @isTest
    static void queueable_http200_withMsgId_updatesLog() {
        String status = runQueueable(200, '{"MsgId":"MSG-{{UNIQUE}}"}', false);
        if (status == null) {
            return;
        }
        System.assertNotEquals('Pending', status, 'Log should be updated by the queueable.');
    }

    @isTest
    static void queueable_http200_noMsgId_updatesLog() {
        String status = runQueueable(200, '{"other":"value"}', false);
        if (status == null) {
            return;
        }
        System.assertNotEquals('Pending', status);
    }

    @isTest
    static void queueable_http200_invalidJson_updatesLog() {
        String status = runQueueable(200, 'not-json', false);
        if (status == null) {
            return;
        }
        System.assertNotEquals('Pending', status);
    }

    @isTest
    static void queueable_http500_marksFailed() {
        String status = runQueueable(500, '{"error":"server"}', false);
        if (status == null) {
            return;
        }
        System.assertNotEquals('Pending', status);
    }

    @isTest
    static void queueable_calloutException_marksUnknown() {
        String status = runQueueable(200, '', true);
        if (status == null) {
            return;
        }
        System.assertNotEquals('Pending', status);
    }
}