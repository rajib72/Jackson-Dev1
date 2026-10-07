@IsTest
private class CaseL2AssignmentControllerTest {

    /* =========================================================
       DYNAMIC SCHEMA HELPERS
       ========================================================= */

    private static Schema.SObjectType getDealerSObjectType() {
        List<Schema.SObjectType> referenceTypes = Case.L2_Assigned__c.getDescribe().getReferenceTo();
        System.assert(
            referenceTypes != null && !referenceTypes.isEmpty(),
            'Case.L2_Assigned__c must be a lookup field.'
        );
        return referenceTypes[0];
    }

    private static String getDealerObjectApiName() {
        return getDealerSObjectType().getDescribe().getName();
    }

    private static String getValidPicklistValue(Schema.SObjectField field, String fallback) {
        if (field == null) {
            return fallback;
        }
        List<Schema.PicklistEntry> entries = field.getDescribe().getPicklistValues();
        if (entries != null && !entries.isEmpty()) {
            for (Schema.PicklistEntry entry : entries) {
                if (entry.isActive()) {
                    return entry.getValue();
                }
            }
            return entries[0].getValue();
        }
        return fallback;
    }

    private static String getDifferentPicklistValue(Schema.SObjectField field, String currentValue, String fallback) {
        if (field == null) {
            return fallback;
        }
        List<Schema.PicklistEntry> entries = field.getDescribe().getPicklistValues();
        if (entries != null && !entries.isEmpty()) {
            for (Schema.PicklistEntry entry : entries) {
                if (entry.isActive() && !entry.getValue().equalsIgnoreCase(currentValue)) {
                    return entry.getValue();
                }
            }
        }
        return fallback;
    }

    private static void setFieldIfExists(SObject record, String fieldName, Object value) {
        Map<String, Schema.SObjectField> fieldMap = record.getSObjectType().getDescribe().fields.getMap();
        String lowerFieldName = fieldName.toLowerCase();
        if (fieldMap.containsKey(lowerFieldName)) {
            Schema.DescribeFieldResult dfr = fieldMap.get(lowerFieldName).getDescribe();
            // Prevents System.SObjectException on Auto-Number and formula fields
            if (dfr.isCreateable()) {
                record.put(dfr.getSObjectField(), value);
            }
        }
    }

    private static Id getFakeId(Schema.SObjectType sObjectType) {
        String prefix = sObjectType.getDescribe().getKeyPrefix();
        return (Id) (prefix + '000000000001AAA');
    }

    /* =========================================================
       TEST DATA SETUP
       ========================================================= */

    @TestSetup
    static void setupTestData() {
        String defaultProduct = getValidPicklistValue(Case.Product__c, 'Solar Inverter');
        String defaultState = getValidPicklistValue(Account.State__c, 'Delhi');

        Account acc = new Account(Name = 'Test Customer Account');
        setFieldIfExists(acc, 'State__c', defaultState);
        insert acc;

        Case testCase = new Case(
            AccountId = acc.Id,
            Subject = 'Inverter Power Failure',
            Description = 'Unit is overheating and shutting down.',
            Priority = 'High'
        );
        setFieldIfExists(testCase, 'Product__c', defaultProduct);
        setFieldIfExists(testCase, 'SRT_Case_Number__c', 'SRT-10001');
        setFieldIfExists(testCase, 'SRT_Case_Status__c', 'New');
        insert testCase;

        Schema.SObjectType dealerSObjectType = getDealerSObjectType();
        SObject dealer = dealerSObjectType.newSObject();
        setFieldIfExists(dealer, 'Name', 'Apex Solar Solutions');
        setFieldIfExists(dealer, 'Vendor_Type__c', 'Dealer');
        setFieldIfExists(dealer, 'Product__c', defaultProduct);
        setFieldIfExists(dealer, 'State__c', defaultState);
        setFieldIfExists(dealer, 'Code__c', 'DLR-501');
        setFieldIfExists(dealer, 'Contact_Person__c', 'John Doe');
        setFieldIfExists(dealer, 'Email__c', 'dealer.notifications@test.com');
        setFieldIfExists(dealer, 'Mobile_Number__c', '9876543210');
        setFieldIfExists(dealer, 'City__c', 'New Delhi');
        setFieldIfExists(dealer, 'User__c', UserInfo.getUserId());
        insert dealer;
    }

    /* =========================================================
       SEARCH DEALERS TESTS
       ========================================================= */

    @IsTest
    static void testSearchDealersNullCaseId() {
        Test.startTest();
        List<CaseL2AssignmentController.DealerOption> results = 
            CaseL2AssignmentController.searchDealers('Solar', null);
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(0, results.size(), 'Null caseId must immediately return an empty list.');
    }

    @IsTest
    static void testSearchDealersCaseNotFound() {
        Id fakeCaseId = getFakeId(Case.SObjectType);

        Test.startTest();
        List<CaseL2AssignmentController.DealerOption> results = 
            CaseL2AssignmentController.searchDealers('Solar', fakeCaseId);
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(0, results.size(), 'Non-existent Case should return an empty list.');
    }

    @IsTest
    static void testSearchDealersCaseMissingProductOrAccountState() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Case caseWithoutProduct = new Case(
            AccountId = acc.Id,
            Subject = 'Missing Product Case'
        );
        insert caseWithoutProduct;

        String defaultProduct = getValidPicklistValue(Case.Product__c, 'Solar Inverter');
        Case caseWithoutAccount = new Case(
            Subject = 'Missing Account Case'
        );
        setFieldIfExists(caseWithoutAccount, 'Product__c', defaultProduct);
        insert caseWithoutAccount;

        Account accWithoutState = new Account(Name = 'State Less Account');
        insert accWithoutState;
        Case caseWithBlankAccountState = new Case(
            AccountId = accWithoutState.Id,
            Subject = 'Blank State Case'
        );
        setFieldIfExists(caseWithBlankAccountState, 'Product__c', defaultProduct);
        insert caseWithBlankAccountState;

        Test.startTest();
        List<CaseL2AssignmentController.DealerOption> r1 = 
            CaseL2AssignmentController.searchDealers(null, caseWithoutProduct.Id);
        List<CaseL2AssignmentController.DealerOption> r2 = 
            CaseL2AssignmentController.searchDealers(null, caseWithoutAccount.Id);
        List<CaseL2AssignmentController.DealerOption> r3 = 
            CaseL2AssignmentController.searchDealers(null, caseWithBlankAccountState.Id);
        Test.stopTest();

        System.assertEquals(0, r1.size(), 'Cases with blank Product__c must return no dealers.');
        System.assertEquals(0, r2.size(), 'Cases with null Account must return no dealers.');
        System.assertEquals(0, r3.size(), 'Cases where Account.State__c is blank must return no dealers.');
    }

    @IsTest
    static void testSearchDealersSuccessWithBlankAndSpecificSearch() {
        Case targetCase = [SELECT Id FROM Case WHERE Subject = 'Inverter Power Failure' LIMIT 1];

        Test.startTest();
        List<CaseL2AssignmentController.DealerOption> blankResults = 
            CaseL2AssignmentController.searchDealers(null, targetCase.Id);
        List<CaseL2AssignmentController.DealerOption> whitespaceResults = 
            CaseL2AssignmentController.searchDealers('   ', targetCase.Id);
        List<CaseL2AssignmentController.DealerOption> filteredResults = 
            CaseL2AssignmentController.searchDealers('DLR-501', targetCase.Id);
        List<CaseL2AssignmentController.DealerOption> emptyResults = 
            CaseL2AssignmentController.searchDealers('ZZZNonExistentDealerZZZ', targetCase.Id);
        Test.stopTest();

        System.assert(!blankResults.isEmpty(), 'Blank search should return all matching dealers.');
        System.assertEquals(blankResults.size(), whitespaceResults.size());
        System.assert(!filteredResults.isEmpty(), 'Search term matching Code__c should return results.');
        System.assertEquals(0, emptyResults.size(), 'Non-matching term should return 0 results.');

        CaseL2AssignmentController.DealerOption option = filteredResults[0];
        System.assertNotEquals(null, option.id);
        System.assertNotEquals(null, option.name, 'Name should be populated (either by text or auto-number).');
        System.assertEquals('DLR-501', option.code);
        System.assertEquals('John Doe', option.contactPerson);
        System.assertEquals('dealer.notifications@test.com', option.email);
        System.assertEquals('9876543210', option.mobile);
        System.assertEquals('New Delhi', option.city);
    }

    /* =========================================================
       ESCALATE TO L2 - VALIDATIONS
       ========================================================= */

    @IsTest
    static void testEscalateValidationParameters() {
        Case targetCase = [SELECT Id FROM Case LIMIT 1];
        SObject dealer = Database.query('SELECT Id FROM ' + getDealerObjectApiName() + ' LIMIT 1');

        Boolean nullCaseCaught = false;
        Boolean nullDealerCaught = false;
        Boolean blankRemarksCaught = false;

        Test.startTest();
        try {
            CaseL2AssignmentController.escalateToL2(null, dealer.Id, 'Remarks');
        } catch (AuraHandledException e) {
            nullCaseCaught = true;
        }

        try {
            CaseL2AssignmentController.escalateToL2(targetCase.Id, null, 'Remarks');
        } catch (AuraHandledException e) {
            nullDealerCaught = true;
        }

        try {
            CaseL2AssignmentController.escalateToL2(targetCase.Id, dealer.Id, '   ');
        } catch (AuraHandledException e) {
            blankRemarksCaught = true;
        }
        Test.stopTest();

        System.assert(nullCaseCaught, 'Null caseId should throw AuraHandledException.');
        System.assert(nullDealerCaught, 'Null dealerId should throw AuraHandledException.');
        System.assert(blankRemarksCaught, 'Blank remarks should throw AuraHandledException.');
    }

    @IsTest
    static void testEscalateInvalidDealerAndCase() {
        Case targetCase = [SELECT Id FROM Case LIMIT 1];
        Id fakeDealerId = getFakeId(getDealerSObjectType());
        Id fakeCaseId = getFakeId(Case.SObjectType);
        SObject dealer = Database.query('SELECT Id FROM ' + getDealerObjectApiName() + ' LIMIT 1');

        Boolean invalidDealerCaught = false;
        Boolean invalidCaseCaught = false;

        Test.startTest();
        try {
            CaseL2AssignmentController.escalateToL2(targetCase.Id, fakeDealerId, 'Valid remarks');
        } catch (AuraHandledException e) {
            invalidDealerCaught = true;
        }

        try {
            CaseL2AssignmentController.escalateToL2(fakeCaseId, dealer.Id, 'Valid remarks');
        } catch (AuraHandledException e) {
            invalidCaseCaught = true;
        }
        Test.stopTest();

        System.assert(invalidDealerCaught, 'Non-existent dealer should be rejected.');
        System.assert(invalidCaseCaught, 'Non-existent Case should be rejected.');
    }

    @IsTest
    static void testEscalateNonDealerVendorType() {
        Case targetCase = [SELECT Id, Product__c, Account.State__c FROM Case LIMIT 1];
        Schema.SObjectType dealerSObjectType = getDealerSObjectType();

        SObject vendorRecord = dealerSObjectType.newSObject();
        setFieldIfExists(vendorRecord, 'Name', 'Subcontractor Hub');
        setFieldIfExists(vendorRecord, 'Vendor_Type__c', 'Vendor');
        setFieldIfExists(vendorRecord, 'Product__c', targetCase.Product__c);
        setFieldIfExists(vendorRecord, 'State__c', targetCase.Account.State__c);
        insert vendorRecord;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CaseL2AssignmentController.escalateToL2(targetCase.Id, vendorRecord.Id, 'Remarks');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Records with Vendor_Type__c != Dealer must be rejected.');
    }

    @IsTest
    static void testEscalateClosedOrAlreadyAssignedCase() {
        Case targetCase = [SELECT Id FROM Case LIMIT 1];
        SObject dealer = Database.query('SELECT Id FROM ' + getDealerObjectApiName() + ' LIMIT 1');

        // 1. Closed Case
        setFieldIfExists(targetCase, 'SRT_Case_Status__c', 'Closed');
        update targetCase;

        Boolean closedCaseCaught = false;
        Test.startTest();
        try {
            CaseL2AssignmentController.escalateToL2(targetCase.Id, dealer.Id, 'Remarks');
        } catch (AuraHandledException e) {
            closedCaseCaught = true;
        }

        // 2. Already Assigned Case (reset to New)
        setFieldIfExists(targetCase, 'SRT_Case_Status__c', 'New');
        setFieldIfExists(targetCase, 'L2_Assigned__c', dealer.Id);
        setFieldIfExists(targetCase, 'L2_Assigned_At__c', System.now());
        update targetCase;

        Boolean alreadyAssignedCaught = false;
        try {
            CaseL2AssignmentController.escalateToL2(targetCase.Id, dealer.Id, 'Remarks');
        } catch (AuraHandledException e) {
            alreadyAssignedCaught = true;
        }
        Test.stopTest();

        System.assert(closedCaseCaught, 'Closed case escalation must be blocked.');
        System.assert(alreadyAssignedCaught, 'Already escalated case must be blocked.');
    }

    @IsTest
    static void testEscalateProductOrStateMismatch() {
        Case targetCase = [SELECT Id, Product__c, Account.State__c FROM Case LIMIT 1];
        Schema.SObjectType dealerSObjectType = getDealerSObjectType();

        String mismatchedProduct = getDifferentPicklistValue(Case.Product__c, targetCase.Product__c, 'DifferentProductVal');
        String mismatchedState = getDifferentPicklistValue(Account.State__c, targetCase.Account.State__c, 'DifferentStateVal');

        SObject mismatchedDealer = dealerSObjectType.newSObject();
        setFieldIfExists(mismatchedDealer, 'Name', 'Mismatched Coverage Dealer');
        setFieldIfExists(mismatchedDealer, 'Vendor_Type__c', 'Dealer');
        setFieldIfExists(mismatchedDealer, 'Product__c', mismatchedProduct);
        setFieldIfExists(mismatchedDealer, 'State__c', mismatchedState);
        insert mismatchedDealer;

        Boolean mismatchCaught = false;
        Test.startTest();
        try {
            CaseL2AssignmentController.escalateToL2(targetCase.Id, mismatchedDealer.Id, 'Product/State mismatch test');
        } catch (AuraHandledException e) {
            mismatchCaught = true;
        }
        Test.stopTest();

        System.assert(mismatchCaught, 'Dealer with mismatched Product/State must be rejected.');
    }

    /* =========================================================
       SUCCESSFUL ESCALATION & COMMUNICATION BRANCHING
       ========================================================= */

    @IsTest
    static void testEscalateSuccessStandardFlow() {
        Case targetCase = [SELECT Id FROM Case WHERE Subject = 'Inverter Power Failure' LIMIT 1];
        SObject dealer = Database.query('SELECT Id FROM ' + getDealerObjectApiName() + ' LIMIT 1');

        Test.startTest();
        CaseL2AssignmentController.L2EscalationResult result = 
            CaseL2AssignmentController.escalateToL2(targetCase.Id, dealer.Id, '  Urgent assistance needed.  ');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.success);
        System.assertEquals(targetCase.Id, result.caseId);
        System.assertEquals(dealer.Id, result.dealerId);
        System.assert(
            result.status == 'L2 WIP' || result.status == 'L2 Assigned',
            'Status must reflect the L2 escalation status.'
        );
        System.assertEquals(true, result.l2Visibility);
        System.assertNotEquals(null, result.assignedAt);
        System.assertNotEquals(null, result.customerWhatsAppStatus);
        System.assertNotEquals(null, result.dealerWhatsAppStatus);

        Case updatedCase = [
            SELECT Id, L2_Assigned__c, L2_Assigned_At__c, L2_Escalated_By__c, 
                   L2_Escalation_Remarks_c__c, L2_Assigned_Visibility_checkbox__c, SRT_Case_Status__c
            FROM Case 
            WHERE Id = :targetCase.Id
        ];
        System.assertEquals(dealer.Id, updatedCase.L2_Assigned__c);
        System.assertNotEquals(null, updatedCase.L2_Assigned_At__c);
        System.assertEquals(UserInfo.getUserId(), updatedCase.L2_Escalated_By__c);
        System.assertEquals('Urgent assistance needed.', updatedCase.L2_Escalation_Remarks_c__c);
        System.assertEquals(true, updatedCase.L2_Assigned_Visibility_checkbox__c);
        System.assert(
            updatedCase.SRT_Case_Status__c == 'L2 WIP' || updatedCase.SRT_Case_Status__c == 'L2 Assigned',
            'Database record must reflect the updated L2 status.'
        );
    }

    @IsTest
    static void testEscalateFallbacksAndNullCommunicationPaths() {
        Account acc = [SELECT Id, State__c FROM Account LIMIT 1];
        String defaultProduct = getValidPicklistValue(Case.Product__c, 'Solar Inverter');

        Case minimalCase = new Case(
            AccountId = acc.Id,
            Subject = 'Minimal Detail Case',
            Description = null,
            Priority = null
        );
        setFieldIfExists(minimalCase, 'Product__c', defaultProduct);
        setFieldIfExists(minimalCase, 'SRT_Case_Number__c', null);
        setFieldIfExists(minimalCase, 'SRT_Case_Status__c', 'New');
        insert minimalCase;

        Schema.SObjectType dealerSObjectType = getDealerSObjectType();
        SObject bareDealer = dealerSObjectType.newSObject();
        setFieldIfExists(bareDealer, 'Name', 'Barebones Services');
        setFieldIfExists(bareDealer, 'Vendor_Type__c', 'Dealer');
        setFieldIfExists(bareDealer, 'Product__c', defaultProduct);
        setFieldIfExists(bareDealer, 'State__c', acc.State__c);
        setFieldIfExists(bareDealer, 'Contact_Person__c', null);
        setFieldIfExists(bareDealer, 'Email__c', null);
        setFieldIfExists(bareDealer, 'User__c', null);
        insert bareDealer;

        Test.startTest();
        CaseL2AssignmentController.L2EscalationResult result = 
            CaseL2AssignmentController.escalateToL2(minimalCase.Id, bareDealer.Id, 'Testing null paths');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(false, result.notificationSent, 'Notification must be skipped when Dealer User__c is null.');
        System.assertEquals(false, result.emailSent, 'Email must be skipped when Dealer Email__c is null.');
    }

    @IsTest
    static void testEscalateDealerContactPersonFallbackInEmail() {
        Account acc = [SELECT Id, State__c FROM Account LIMIT 1];
        String defaultProduct = getValidPicklistValue(Case.Product__c, 'Solar Inverter');

        Case caseRec = new Case(
            AccountId = acc.Id,
            Subject = 'Email Fallback Case'
        );
        setFieldIfExists(caseRec, 'Product__c', defaultProduct);
        setFieldIfExists(caseRec, 'SRT_Case_Status__c', 'New');
        insert caseRec;

        Schema.SObjectType dealerSObjectType = getDealerSObjectType();
        SObject fallbackDealer = dealerSObjectType.newSObject();
        setFieldIfExists(fallbackDealer, 'Name', 'Direct Dealer Corporate');
        setFieldIfExists(fallbackDealer, 'Vendor_Type__c', 'Dealer');
        setFieldIfExists(fallbackDealer, 'Product__c', defaultProduct);
        setFieldIfExists(fallbackDealer, 'State__c', acc.State__c);
        setFieldIfExists(fallbackDealer, 'Contact_Person__c', '   ');
        setFieldIfExists(fallbackDealer, 'Email__c', 'corporate@dealer.com');
        setFieldIfExists(fallbackDealer, 'User__c', UserInfo.getUserId());
        insert fallbackDealer;

        Test.startTest();
        CaseL2AssignmentController.L2EscalationResult result = 
            CaseL2AssignmentController.escalateToL2(caseRec.Id, fallbackDealer.Id, 'Testing fallback dealer name.');
        Test.stopTest();

        System.assertEquals(true, result.success);
    }
}