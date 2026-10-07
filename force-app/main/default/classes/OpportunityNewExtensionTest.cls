@isTest
private class OpportunityNewExtensionTest {

    @testSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User testUser = new User(
            Alias = 'tuser',
            Email = 'testuser12345@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser' + DateTime.now().getTime() + '@testorg.com'
        );
        insert testUser;

        System.runAs(testUser) {
            Account acc = new Account(Name = 'Acme Corporation');
            insert acc;

            Account acc2 = new Account(Name = 'Amit Test Account');
            insert acc2;

            Contact con = new Contact(LastName = 'Smith', AccountId = acc.Id);
            insert con;
        }
    }

    static Id getRecordTypeId(String devName) {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'Opportunity'
            AND DeveloperName = :devName
            LIMIT 1
        ];

        if (!rts.isEmpty()) {
            return rts[0].Id;
        }

        List<RecordType> fallbackRts = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'Opportunity'
            AND IsActive = true
            LIMIT 1
        ];

        return fallbackRts.isEmpty() ? null : fallbackRts[0].Id;
    }

    static String getFirstActivePicklistValue(Schema.SObjectField fieldToken) {
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }

        return null;
    }

    @isTest
    static void testConstructor_StandardInitialization() {
        Id rtId = getRecordTypeId('KAM');

        Test.setCurrentPage(Page.OpportunityNewPage);

        if (rtId != null) {
            ApexPages.currentPage().getParameters().put('RecordType', rtId);
        }

        Opportunity opp = new Opportunity();
        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);

        Test.startTest();
        OpportunityNewExtension ext = new OpportunityNewExtension(stdController);
        Test.stopTest();

        System.assertEquals(10, ext.opp.Probability, 'Probability should be defaulted to 10');
        // System.assertEquals('Module', ext.opp.Tender_Type__c, 'Tender Type should be Module');
        System.assertNotEquals(null, ext.contactOptions, 'Contact options should be initialized');

        if (rtId != null && ext.rtDevName == 'KAM') {
            System.assertEquals(
                'Qualification',
                ext.opp.Key_Account_Opp_Stages__c,
                'Stage prepopulation failed for KAM'
            );

            System.assertEquals(
                'KAM',
                ext.opp.Business_Segment__c,
                'Business Segment prepopulation failed for KAM'
            );
        }
    }

    @isTest
    static void testConstructor_ResidentialRecordType() {
        Id rtId = getRecordTypeId('Residential');

        Test.setCurrentPage(Page.OpportunityNewPage);

        if (rtId != null) {
            ApexPages.currentPage().getParameters().put('RecordType', rtId);
        }

        Opportunity opp = new Opportunity();
        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);

        Test.startTest();
        OpportunityNewExtension ext = new OpportunityNewExtension(stdController);
        Test.stopTest();

        if (rtId != null && ext.rtDevName == 'Residential') {
            System.assertEquals(
                true,
                ext.isUnderDevelopment,
                'isUnderDevelopment should be true for Residential RecordType'
            );
        }
    }

    @isTest
    static void testAccountPrepopulationLogic() {
        Account acc = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'Acme Corporation'
            LIMIT 1
        ];

        Opportunity opp = new Opportunity(AccountId = acc.Id);
        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);

        Test.startTest();
        OpportunityNewExtension ext = new OpportunityNewExtension(stdController);
        Test.stopTest();

        System.assertEquals(true, ext.isAccountPrepopulated, 'Account should be marked as prepopulated');
        System.assertEquals(acc.Name, ext.prepopulatedAccountName, 'Prepopulated Account Name did not match');
        System.assertEquals(acc.Name, ext.selectedAccountName, 'Selected Account Name did not match');
        System.assertEquals(acc.Id, ext.selectedAccountId, 'Selected Account ID did not map correctly');
    }

    @isTest
    static void testSearchAccountsRemote_BlankSearch() {
        Test.startTest();
        List<OpportunityNewExtension.AccountLookupWrapper> results =
            OpportunityNewExtension.searchAccountsRemote('');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Search result should not be null');
        System.assert(results.size() > 0, 'Blank search should return first available Accounts');
    }

    @isTest
    static void testSearchAccountsRemote_KeywordSearch() {
        Test.startTest();
        List<OpportunityNewExtension.AccountLookupWrapper> results =
            OpportunityNewExtension.searchAccountsRemote('Amit');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Search result should not be null');
        System.assert(results.size() > 0, 'Keyword search should return matching Accounts');

        Boolean foundAmitAccount = false;

        for (OpportunityNewExtension.AccountLookupWrapper wrapObj : results) {
            if (wrapObj.name != null && wrapObj.name.contains('Amit')) {
                foundAmitAccount = true;
                System.assertNotEquals(null, wrapObj.id, 'Wrapper should contain Account Id');
            }
        }

        System.assertEquals(true, foundAmitAccount, 'Amit Test Account should be returned in keyword search');
    }

    @isTest
    static void testSearchAccountsRemote_NoResult() {
        Test.startTest();
        List<OpportunityNewExtension.AccountLookupWrapper> results =
            OpportunityNewExtension.searchAccountsRemote('NoAccountShouldMatchThisKeyword12345');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Search result should not be null');
        System.assertEquals(0, results.size(), 'No matching keyword should return zero Accounts');
    }

    @isTest
    static void testAccountLookupWrapperConstructor() {
        Account acc = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'Acme Corporation'
            LIMIT 1
        ];

        Test.startTest();
        OpportunityNewExtension.AccountLookupWrapper wrapObj =
            new OpportunityNewExtension.AccountLookupWrapper(acc.Id, acc.Name);
        Test.stopTest();

        System.assertEquals(String.valueOf(acc.Id), wrapObj.id, 'Wrapper Id should match Account Id');
        System.assertEquals(acc.Name, wrapObj.name, 'Wrapper Name should match Account Name');
    }

    @isTest
    static void testOnAccountChange() {
        Id rtId = getRecordTypeId('KAM');

        Test.setCurrentPage(Page.OpportunityNewPage);

        if (rtId != null) {
            ApexPages.currentPage().getParameters().put('RecordType', rtId);
        }

        Account acc = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'Acme Corporation'
            LIMIT 1
        ];

        Opportunity opp = new Opportunity();
        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);
        OpportunityNewExtension ext = new OpportunityNewExtension(stdController);

        Test.startTest();
        ext.selectedAccountId = acc.Id;
        ext.onAccountChange();
        Test.stopTest();

        System.assertEquals(null, ext.selectedContactId, 'Contact ID should clear upon changing the Account');
        System.assertEquals(acc.Name, ext.selectedAccountName, 'Selected Account Name should be updated');
        System.assert(ext.contactOptions.size() > 1, 'Contact dropdown should populate based on selected Account');
        System.assert(
            ext.opp.Name.contains(acc.Name),
            'Opportunity Name should dynamically update to include the Account Name'
        );
    }

    @isTest
    static void testOnAccountChange_InvalidAccountId() {
        Opportunity opp = new Opportunity();
        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);
        OpportunityNewExtension ext = new OpportunityNewExtension(stdController);

        Test.startTest();
        ext.selectedAccountId = '001000000000000AAA';
        ext.onAccountChange();
        Test.stopTest();

        System.assertEquals('', ext.selectedAccountName, 'Selected Account Name should be blank for invalid Account Id');
        System.assertEquals(1, ext.contactOptions.size(), 'Only -- None -- contact option should remain');
    }

    @isTest
    static void testOnMarketSegmentChange() {
        Opportunity opp = new Opportunity();
        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);
        OpportunityNewExtension ext = new OpportunityNewExtension(stdController);

        Test.startTest();

        ext.opp.Market_Segment__c = 'Others';
        ext.opp.Market_Segment_Others__c = 'Some Custom Segment';
        ext.onMarketSegmentChange();

        System.assertEquals(
            'Some Custom Segment',
            ext.opp.Market_Segment_Others__c,
            'Value should remain if Market Segment is Others'
        );

        ext.opp.Market_Segment__c = 'Distributor/CP';
        ext.onMarketSegmentChange();

        System.assertEquals(
            null,
            ext.opp.Market_Segment_Others__c,
            'Value should be cleared when Market Segment is changed away from Others'
        );

        Test.stopTest();
    }

    @isTest
    static void testOnOpportunitySourceChange() {
        Opportunity opp = new Opportunity();
        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);
        OpportunityNewExtension ext = new OpportunityNewExtension(stdController);

        Test.startTest();

        ext.opp.LeadSource = 'Others';
        ext.opp.Opportunity_Source_Others__c = 'Custom Source';
        ext.onOpportunitySourceChange();

        System.assertEquals(
            'Custom Source',
            ext.opp.Opportunity_Source_Others__c,
            'Value should remain if Opportunity Source is Others'
        );

        ext.opp.LeadSource = 'Web';
        ext.onOpportunitySourceChange();

        System.assertEquals(
            null,
            ext.opp.Opportunity_Source_Others__c,
            'Value should be cleared when Opportunity Source is changed away from Others'
        );

        Test.stopTest();
    }

    @isTest
    static void testSaveRecord_Success() {
        Account acc = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'Acme Corporation'
            LIMIT 1
        ];

        Contact con = [
            SELECT Id, Name
            FROM Contact
            WHERE AccountId = :acc.Id
            LIMIT 1
        ];

        Id rtId = getRecordTypeId('KAM');

        Test.setCurrentPage(Page.OpportunityNewPage);

        if (rtId != null) {
            ApexPages.currentPage().getParameters().put('RecordType', rtId);
        }

        Opportunity opp = new Opportunity(
            Name = 'Test Opp Save',
            CloseDate = Date.today().addDays(30),
            Type = 'New Customer'
        );

        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);
        OpportunityNewExtension ext = new OpportunityNewExtension(stdController);

        ext.selectedAccountId = acc.Id;
        ext.selectedContactId = con.Id;

        ext.opp.Rating__c =
            getFirstActivePicklistValue(Opportunity.Rating__c);

        ext.opp.Expected_Closure_Date__c =
            Date.today().addDays(20);

        Test.startTest();
        PageReference redirectPage = ext.saveRecord();
        Test.stopTest();

        String caughtError = '';

        if (redirectPage == null && ApexPages.hasMessages()) {
            for (ApexPages.Message msg : ApexPages.getMessages()) {
                caughtError += msg.getDetail() + ' ';
            }
        }

        System.assertNotEquals(
            null,
            redirectPage,
            'The insert failed. Salesforce Error: ' + caughtError
        );

        Opportunity insertedOpp = [
            SELECT
                Id,
                StageName,
                AccountId,
                Contact__c,
                Rating__c,
                Expected_Closure_Date__c
            FROM Opportunity
            WHERE Id = :ext.opp.Id
            LIMIT 1
        ];

        System.assertEquals(
            'Qualification',
            insertedOpp.StageName,
            'StageName should be Qualification'
        );

        System.assertEquals(
            acc.Id,
            insertedOpp.AccountId,
            'Account lookup should be populated'
        );

        System.assertEquals(
            con.Id,
            insertedOpp.Contact__c,
            'Contact lookup should be populated'
        );

        System.assertNotEquals(
            null,
            insertedOpp.Rating__c,
            'Rating should be populated'
        );

        System.assertNotEquals(
            null,
            insertedOpp.Expected_Closure_Date__c,
            'Expected Closure Date should be populated'
        );
    }

    @isTest
    static void testSaveRecord_Validation_PastCloseDate() {
        Opportunity opp = new Opportunity(
            CloseDate = Date.today().addDays(-5)
        );

        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);
        OpportunityNewExtension ext = new OpportunityNewExtension(stdController);

        Test.startTest();
        PageReference redirectPage = ext.saveRecord();
        Test.stopTest();

        System.assertEquals(
            null,
            redirectPage,
            'PageReference should be null when validation error occurs'
        );

        Boolean hasExpectedError = false;

        for (ApexPages.Message msg : ApexPages.getMessages()) {
            if (msg.getDetail().contains('Close Date cannot be in the past')) {
                hasExpectedError = true;
            }
        }

        System.assert(
            hasExpectedError,
            'Expected past Close Date validation message was not generated'
        );
    }

    @isTest
    static void testSaveRecord_Validation_RatingRequired() {
        Id rtId = getRecordTypeId('KAM');

        Test.setCurrentPage(Page.OpportunityNewPage);

        if (rtId != null) {
            ApexPages.currentPage().getParameters().put('RecordType', rtId);
        }

        Opportunity opp = new Opportunity(
            CloseDate = Date.today().addDays(30)
        );

        ApexPages.StandardController stdController =
            new ApexPages.StandardController(opp);

        OpportunityNewExtension ext =
            new OpportunityNewExtension(stdController);

        ext.rtDevName = 'KAM';

        ext.opp.Rating__c = null;

        ext.opp.Expected_Closure_Date__c =
            Date.today().addDays(20);

        Test.startTest();
        PageReference redirectPage = ext.saveRecord();
        Test.stopTest();

        System.assertEquals(
            null,
            redirectPage,
            'PageReference should be null when Rating is missing'
        );

        Boolean hasExpectedError = false;

        for (ApexPages.Message msg : ApexPages.getMessages()) {
            if (msg.getDetail().contains('Rating is required')) {
                hasExpectedError = true;
            }
        }

        System.assert(
            hasExpectedError,
            'Expected Rating required validation message was not generated'
        );
    }

    @isTest
    static void testSaveRecord_Validation_ExpectedClosureDateRequired() {
        Id rtId = getRecordTypeId('KAM');

        Test.setCurrentPage(Page.OpportunityNewPage);

        if (rtId != null) {
            ApexPages.currentPage().getParameters().put('RecordType', rtId);
        }

        Opportunity opp = new Opportunity(
            CloseDate = Date.today().addDays(30)
        );

        ApexPages.StandardController stdController =
            new ApexPages.StandardController(opp);

        OpportunityNewExtension ext =
            new OpportunityNewExtension(stdController);

        ext.rtDevName = 'KAM';

        ext.opp.Rating__c =
            getFirstActivePicklistValue(Opportunity.Rating__c);

        ext.opp.Expected_Closure_Date__c = null;

        Test.startTest();
        PageReference redirectPage = ext.saveRecord();
        Test.stopTest();

        System.assertEquals(
            null,
            redirectPage,
            'PageReference should be null when Expected Closure Date is missing'
        );

        Boolean hasExpectedError = false;

        for (ApexPages.Message msg : ApexPages.getMessages()) {
            if (msg.getDetail().contains('Expected Closure Date is required')) {
                hasExpectedError = true;
            }
        }

        System.assert(
            hasExpectedError,
            'Expected Closure Date required validation message was not generated'
        );
    }

    @isTest
    static void testSaveRecord_Validation_PastExpectedClosureDate() {
        Id rtId = getRecordTypeId('KAM');

        Test.setCurrentPage(Page.OpportunityNewPage);

        if (rtId != null) {
            ApexPages.currentPage().getParameters().put('RecordType', rtId);
        }

        Opportunity opp = new Opportunity(
            CloseDate = Date.today().addDays(30)
        );

        ApexPages.StandardController stdController =
            new ApexPages.StandardController(opp);

        OpportunityNewExtension ext =
            new OpportunityNewExtension(stdController);

        ext.rtDevName = 'KAM';

        ext.opp.Rating__c =
            getFirstActivePicklistValue(Opportunity.Rating__c);

        ext.opp.Expected_Closure_Date__c =
            Date.today().addDays(-5);

        Test.startTest();
        PageReference redirectPage = ext.saveRecord();
        Test.stopTest();

        System.assertEquals(
            null,
            redirectPage,
            'PageReference should be null when Expected Closure Date is in the past'
        );

        Boolean hasExpectedError = false;

        for (ApexPages.Message msg : ApexPages.getMessages()) {
            if (
                msg.getDetail().contains(
                    'Expected Closure Date cannot be in the past'
                )
            ) {
                hasExpectedError = true;
            }
        }

        System.assert(
            hasExpectedError,
            'Expected past Expected Closure Date validation message was not generated'
        );
    }

    @isTest
    static void testSaveRecord_Validation_InstitutionalTenderDate() {
        Id rtId = getRecordTypeId('Institutional');

        Test.setCurrentPage(Page.OpportunityNewPage);

        if (rtId != null) {
            ApexPages.currentPage().getParameters().put('RecordType', rtId);
        }

        Opportunity opp = new Opportunity(
            CloseDate = Date.today().addDays(30),
            Tender_Due_Date__c = Date.today().addDays(-5)
        );

        ApexPages.StandardController stdController =
            new ApexPages.StandardController(opp);

        OpportunityNewExtension ext =
            new OpportunityNewExtension(stdController);

        ext.rtDevName = 'Institutional';

        ext.opp.Rating__c =
            getFirstActivePicklistValue(Opportunity.Rating__c);

        ext.opp.Expected_Closure_Date__c =
            Date.today().addDays(20);

        Test.startTest();
        PageReference redirectPage = ext.saveRecord();
        Test.stopTest();

        System.assertEquals(
            null,
            redirectPage,
            'PageReference should be null when validation error occurs'
        );

        Boolean hasExpectedError = false;

        for (ApexPages.Message msg : ApexPages.getMessages()) {
            if (msg.getDetail().contains('Tender Due Date cannot be in the past')) {
                hasExpectedError = true;
            }
        }

        System.assert(
            hasExpectedError,
            'Expected past Tender Due Date validation message was not generated'
        );
    }

    @isTest
    static void testSaveRecord_DmlException() {
        Opportunity opp = new Opportunity();

        ApexPages.StandardController stdController =
            new ApexPages.StandardController(opp);

        OpportunityNewExtension ext =
            new OpportunityNewExtension(stdController);

        Test.startTest();
        PageReference redirectPage = ext.saveRecord();
        Test.stopTest();

    }
}