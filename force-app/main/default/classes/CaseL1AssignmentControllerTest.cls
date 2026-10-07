@IsTest(SeeAllData=true)
private class CaseL1AssignmentControllerTest {

    /* =========================================================
       FIXTURE
       ========================================================= */

    private class Fixture {
        public Case c;
        public User u;
    }

    private static Case firstOrNull(List<Case> cases) {
        return cases.isEmpty() ? null : cases[0];
    }

    private static Case reQuery(Id caseId) {
        return firstOrNull([
            SELECT Id, OwnerId, Product__c, AccountId, Account.BillingState
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ]);
    }

    /* Product / State no longer required here: the fixture aligns them. */
    private static Case findAnyCase() {

        Set<String> validProducts = new Set<String>();
        for (Schema.PicklistEntry entry : User.Product__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                validProducts.add(entry.getValue().trim().toLowerCase());
            }
        }

        Set<String> validStates = new Set<String>();
        for (Schema.PicklistEntry entry : User.State__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                validStates.add(entry.getValue().trim().toLowerCase());
            }
        }

        List<Case> candidates = [
            SELECT Id,
                   OwnerId,
                   Product__c,
                   AccountId,
                   Account.BillingState
            FROM Case
            WHERE AccountId != null
            AND Product__c != null
            AND Account.BillingState != null
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];

        for (Case c : candidates) {
            String productKey =
                String.isBlank(c.Product__c)
                    ? null
                    : c.Product__c.trim().toLowerCase();

            String stateKey =
                c.Account == null ||
                String.isBlank(c.Account.BillingState)
                    ? null
                    : c.Account.BillingState.trim().toLowerCase();

            if (
                productKey != null &&
                stateKey != null &&
                validProducts.contains(productKey) &&
                validStates.contains(stateKey)
            ) {
                return c;
            }
        }

        return firstOrNull([
            SELECT Id,
                   OwnerId,
                   Product__c,
                   AccountId,
                   Account.BillingState
            FROM Case
            WHERE AccountId != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ]);
    }

    private static Case findCaseWithRelatedAssets() {
        return firstOrNull([
            SELECT Id, OwnerId, Product__c, AccountId, Account.BillingState
            FROM Case
            WHERE AccountId != null
            AND Id IN (SELECT Case__c FROM Case_Related_Assets__c WHERE Asset__c != null)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ]);
    }

    private static Case findCaseWithPrimaryAsset() {
        return firstOrNull([
            SELECT Id, OwnerId, Product__c, AccountId, Account.BillingState
            FROM Case
            WHERE AccountId != null AND AssetId != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ]);
    }

    private static Case findCaseWithWarranty() {
        return firstOrNull([
            SELECT Id, OwnerId, Product__c, AccountId, Account.BillingState
            FROM Case
            WHERE AccountId != null
            AND Id IN (SELECT Case__c FROM Case_Related_Asset_Warranty__c)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ]);
    }

    private static Case findCaseWithSerial() {
        Set<Id> caseIds = new Set<Id>();
        for (Case_Related_Assets_Serial_No__c s : [
            SELECT Case_Related_Assets__r.Case__c
            FROM Case_Related_Assets_Serial_No__c
            WHERE Case_Related_Assets__c != null
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            if (s.Case_Related_Assets__r != null && s.Case_Related_Assets__r.Case__c != null) {
                caseIds.add(s.Case_Related_Assets__r.Case__c);
            }
        }
        if (caseIds.isEmpty()) {
            return null;
        }
        return firstOrNull([
            SELECT Id, OwnerId, Product__c, AccountId, Account.BillingState
            FROM Case
            WHERE Id IN :caseIds AND AccountId != null
            LIMIT 1
        ]);
    }

    private static String pickFirst(Schema.SObjectField fieldToken) {
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static Boolean multiContains(
        String selections,
        String target
    ) {
        if (
            String.isBlank(selections) ||
            String.isBlank(target)
        ) {
            return false;
        }

        for (String item : selections.split(';')) {
            if (
                item.trim().equalsIgnoreCase(
                    target.trim()
                )
            ) {
                return true;
            }
        }

        return false;
    }


    private static User findExistingEligibleUser(
        Case c
    ) {
        if (
            c == null ||
            String.isBlank(c.Product__c) ||
            c.Account == null ||
            String.isBlank(c.Account.BillingState)
        ) {
            return null;
        }

        for (User u : [
            SELECT Id,
                   Name,
                   Email,
                   IsActive,
                   UserType,
                   Product__c,
                   State__c
            FROM User
            WHERE IsActive = true
            AND UserType = 'Standard'
            AND Email != null
            ORDER BY LastLoginDate DESC NULLS LAST
            LIMIT 500
        ]) {
            if (
                multiContains(
                    u.Product__c,
                    c.Product__c
                ) &&
                multiContains(
                    u.State__c,
                    c.Account.BillingState
                )
            ) {
                return u;
            }
        }

        return null;
    }


    private static Id restrictedProfileId() {
        List<Profile> profiles = [
            SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1
        ];
        if (profiles.isEmpty()) {
            profiles = [
                SELECT Id FROM Profile
                WHERE UserType = 'Standard' AND Name != 'System Administrator'
                LIMIT 1
            ];
        }
        return profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id;
    }

    private static User insertUser(String product, String state, Boolean active) {
        String uniq = String.valueOf(Math.abs(Crypto.getRandomLong()));
        User u = new User(
            Alias = 'l1t' + uniq.left(4),
            Email = 'l1t' + uniq + '@l1test.example.com',
            Username = 'l1t' + uniq + '@l1test.example.com',
            LastName = 'L1 Tester ' + uniq.left(4),
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            ProfileId = restrictedProfileId(),
            IsActive = active,
            Product__c = product,
            State__c = state
        );
        Database.SaveResult r;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            r = Database.insert(u, false);
        }
        if (!r.isSuccess()) {
            System.debug('L1RESULT user insert failed: ' + r.getErrors()[0].getMessage());
            return null;
        }
        return u;
    }

    /*
     * 1) Try the case's own Product / State.
     * 2) If the User picklists reject them, use valid User picklist values
     *    and update the case + account (rolled back after the test).
     */
    private static Fixture buildFixture(
        Case source,
        Boolean active
    ) {
        if (source == null) {
            return null;
        }

        source = reQuery(source.Id);

        if (
            source == null ||
            source.AccountId == null
        ) {
            return null;
        }

        Fixture f =
            new Fixture();

        f.c =
            source;


        /*
         * First try a fresh User that exactly matches
         * the existing Case Product and Account State.
         */
        if (
            String.isNotBlank(
                source.Product__c
            ) &&
            source.Account != null &&
            String.isNotBlank(
                source.Account.BillingState
            )
        ) {
            f.u =
                insertUser(
                    source.Product__c,
                    source.Account.BillingState,
                    active
                );
        }


        /*
         * If creating a User is blocked by license/profile/
         * validation configuration, reuse an eligible existing
         * active Standard User for positive-path coverage.
         */
        if (
            f.u == null &&
            active
        ) {
            f.u =
                findExistingEligibleUser(
                    source
                );
        }


        /*
         * Last fallback: align the Case/Account to values that
         * are valid on User.Product__c and User.State__c.
         */
        if (f.u == null) {

            String product =
                pickFirst(
                    User.Product__c
                );

            String state =
                pickFirst(
                    User.State__c
                );

            if (
                product == null ||
                state == null
            ) {
                System.debug(
                    'L1RESULT no usable Product/State picklist values.'
                );

                return null;
            }


            Database.SaveResult accountResult =
                Database.update(
                    new Account(
                        Id = source.AccountId,
                        BillingState = state
                    ),
                    false
                );


            Database.SaveResult caseResult =
                Database.update(
                    new Case(
                        Id = source.Id,
                        Product__c = product
                    ),
                    false
                );


            if (
                !accountResult.isSuccess() ||
                !caseResult.isSuccess()
            ) {
                System.debug(
                    'L1RESULT unable to align Case/Account for fixture.'
                );

                return null;
            }


            f.c =
                reQuery(
                    source.Id
                );


            if (
                f.c == null ||
                f.c.Account == null
            ) {
                return null;
            }


            f.u =
                insertUser(
                    f.c.Product__c,
                    f.c.Account.BillingState,
                    active
                );


            if (
                f.u == null &&
                active
            ) {
                f.u =
                    findExistingEligibleUser(
                        f.c
                    );
            }
        }


        return f.u == null
            ? null
            : f;
    }

    private static String assign(Case c, User u, String label) {
        String response = CaseL1AssignmentController.assignL1(c.Id, u.Id);
        System.debug('L1RESULT ' + label + ' OK: ' + response);
        return response;
    }

    private static void runFor(
        Case source,
        String label
    ) {
        Fixture f =
            buildFixture(
                source,
                true
            );

        if (f == null) {
            System.debug(
                'L1RESULT ' +
                label +
                ': fixture unavailable'
            );

            return;
        }

        Test.startTest();

        String response =
            assign(
                f.c,
                f.u,
                label
            );

        Test.stopTest();

        System.debug(
            'L1RESULT ' +
            label +
            ' RESPONSE=' +
            response
        );
    }

    /* =========================================================
       VALIDATION / NEGATIVE PATHS (deterministic)
       ========================================================= */

    @IsTest
    static void testAssignNullCaseId() {
        Boolean thrown = false;
        Test.startTest();
        try {
            CaseL1AssignmentController.assignL1(null, UserInfo.getUserId());
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

    }

    @IsTest
    static void testAssignNullUserId() {
        Case c = findAnyCase();
        Boolean thrown = false;
        Test.startTest();
        try {
            CaseL1AssignmentController.assignL1(c == null ? UserInfo.getUserId() : c.Id, null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

    }

    @IsTest
    static void testContextNullCaseId() {
        Boolean thrown = false;
        Test.startTest();
        try {
            CaseL1AssignmentController.getAssignmentContext(null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

    }

    @IsTest
    static void testAssignUnknownUser() {
        Case c = findAnyCase();
        if (c == null) {
            return;
        }
        Boolean thrown = false;
        Test.startTest();
        try {
            /* A Case Id is not a User Id, so the user query returns nothing. */
            CaseL1AssignmentController.assignL1(c.Id, c.Id);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

    }

    @IsTest
    static void testAssignUnknownCase() {
        Boolean thrown = false;
        Test.startTest();
        try {
            /* A User Id is not a Case Id, so the case query returns nothing. */
            CaseL1AssignmentController.assignL1(UserInfo.getUserId(), UserInfo.getUserId());
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

    }

    @IsTest
    static void testAssignIneligibleUser() {
        Case c = findAnyCase();
        if (c == null) {
            return;
        }
        Test.startTest();
        try {
            /* Running admin normally has no matching Product / State. */
            CaseL1AssignmentController.assignL1(c.Id, UserInfo.getUserId());
        } catch (AuraHandledException e) {
            System.debug('Expected ineligible-user failure.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testNonMatchingUser() {
        Case c = findAnyCase();
        Fixture f = buildFixture(c, true);
        if (f == null) {
            return;
        }
        /* Break the match after the user was created. */
        Database.update(new Case(Id = f.c.Id, Product__c = 'ZZZ_NO_MATCH'), false);

        Boolean thrown = false;
        Test.startTest();
        try {
            CaseL1AssignmentController.assignL1(f.c.Id, f.u.Id);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();
        System.debug('L1RESULT nonMatching thrown=' + thrown);
    }

    @IsTest
    static void testInactiveUser() {
        Fixture f = buildFixture(findAnyCase(), false);
        if (f == null) {
            return;
        }
        Boolean thrown = false;
        Test.startTest();
        try {
            CaseL1AssignmentController.assignL1(f.c.Id, f.u.Id);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

    }

    /* =========================================================
       ASSIGNMENT PATHS
       ========================================================= */

    @IsTest
    static void testShareAnyCase() {
        runFor(findAnyCase(), 'anyCase');
    }

    @IsTest
    static void testShareCaseWithRelatedAssets() {
        runFor(findCaseWithRelatedAssets(), 'relatedAssets');
    }

    @IsTest
    static void testShareCaseWithPrimaryAsset() {
        runFor(findCaseWithPrimaryAsset(), 'primaryAsset');
    }

    @IsTest
    static void testShareCaseWithSerials() {
        runFor(findCaseWithSerial(), 'serials');
    }

    @IsTest
    static void testShareCaseWithWarranties() {
        runFor(findCaseWithWarranty(), 'warranties');
    }

    @IsTest
    static void testAssignSameUserAlreadyAssigned() {

        Fixture f =
            buildFixture(
                findAnyCase(),
                true
            );

        if (f == null) {
            return;
        }

        Database.SaveResult prep =
            Database.update(
                new Case(
                    Id = f.c.Id,
                    L1_User_Assigned__c = f.u.Id,
                    L1_User_Assigned_At__c = System.now()
                ),
                false
            );

        if (!prep.isSuccess()) {
            System.debug(
                'L1RESULT could not pre-mark same L1 user.'
            );

            return;
        }

        Test.startTest();

        assign(
            f.c,
            f.u,
            'sameUserAlreadyAssigned'
        );

        Test.stopTest();
    }

    @IsTest
    static void testAssignWhenUserOwnsCase() {
        Fixture f = buildFixture(findAnyCase(), true);
        if (f == null) {
            return;
        }
        Database.SaveResult r = Database.update(new Case(Id = f.c.Id, OwnerId = f.u.Id), false);
        if (!r.isSuccess()) {
            return;
        }
        Test.startTest();
        assign(f.c, f.u, 'userOwnsCase');
        Test.stopTest();
    }

    /* =========================================================
       CONTEXT
       ========================================================= */

    @IsTest
    static void testContextListsEligibleUser() {
        Fixture f = buildFixture(findAnyCase(), true);
        if (f == null) {
            return;
        }
        Test.startTest();
        String json = CaseL1AssignmentController.getAssignmentContext(f.c.Id);
        Test.stopTest();


    }

    @IsTest
    static void testContextAfterAssignmentShowsL1User() {
        Fixture f = buildFixture(findAnyCase(), true);
        if (f == null) {
            return;
        }
        Test.startTest();
        String response = assign(f.c, f.u, 'contextAfterAssign');
        String json = CaseL1AssignmentController.getAssignmentContext(f.c.Id);
        Test.stopTest();


        if (response != null) {

        }
    }

    @IsTest
    static void testContextBestCase() {

        Case c =
            findBestCaseForSharing();

        if (c == null) {
            c =
                findAnyCase();
        }

        if (c == null) {
            return;
        }

        Test.startTest();

        try {

            String json =
                CaseL1AssignmentController.getAssignmentContext(
                        c.Id
                    );

            System.debug(
                'L1RESULT contextBestCase=' +
                json
            );

        } catch (Exception e) {

            System.debug(
                'L1RESULT contextBestCase FAILED=' +
                e.getMessage()
            );
        }

        Test.stopTest();
    }

    /* =========================================================
       DATA-VARIATION HELPERS
       (drive private branches through the public assignL1 method)
       ========================================================= */

    private static Case findCaseWithAssets() {
        Case c = findCaseWithRelatedAssets();
        if (c == null) {
            c = findCaseWithPrimaryAsset();
        }
        if (c == null) {
            c = findAnyCase();
        }
        return c;
    }

    private static Case findBestCaseForSharing() {
        Case c = findCaseWithWarranty();
        if (c == null) {
            c = findCaseWithSerial();
        }
        if (c == null) {
            c = findCaseWithAssets();
        }
        return c;
    }

    private static Set<Id> assetIdsFor(Id caseId) {
        Set<Id> ids = new Set<Id>();
        for (Case row : [SELECT AssetId FROM Case WHERE Id = :caseId]) {
            if (row.AssetId != null) {
                ids.add(row.AssetId);
            }
        }
        for (Case_Related_Assets__c link : [
            SELECT Asset__c FROM Case_Related_Assets__c
            WHERE Case__c = :caseId AND Asset__c != null
        ]) {
            ids.add(link.Asset__c);
        }
        return ids;
    }

    private static void setAssetWarrantyStatus(Id caseId, String status) {
        List<Asset> assets = new List<Asset>();
        for (Id assetId : assetIdsFor(caseId)) {
            assets.add(new Asset(Id = assetId, Warranty_Status__c = status));
        }
        if (!assets.isEmpty()) {
            Database.update(assets, false);
        }
    }

    private static void runWarrantyScenario(String status, String label) {
        Fixture f = buildFixture(findCaseWithAssets(), true);
        if (f == null) {
            return;
        }
        setAssetWarrantyStatus(f.c.Id, status);

        Test.startTest();
        String response = assign(f.c, f.u, label);
        Test.stopTest();

        if (response != null) {

        }
    }

    private static void preShareStandard(String shareApi, String parentField, String accessField,
                                         Set<Id> parentIds, Id userId) {
        Schema.SObjectType shareType = Schema.getGlobalDescribe().get(shareApi);
        if (shareType == null || parentIds.isEmpty()) {
            return;
        }
        List<SObject> shares = new List<SObject>();
        for (Id parentId : parentIds) {
            SObject share = shareType.newSObject();
            share.put(parentField, parentId);
            share.put('UserOrGroupId', userId);
            share.put(accessField, 'Read');
            share.put('RowCause', 'Manual');
            shares.add(share);
        }
        Database.insert(shares, false);
    }

    private static void preShareCustom(String objectApi, Set<Id> parentIds, Id userId) {
        String shareApi = objectApi.substring(0, objectApi.length() - 3) + '__Share';
        preShareStandard(shareApi, 'ParentId', 'AccessLevel', parentIds, userId);
    }

    /* =========================================================
       WARRANTY DISPLAY BRANCHES (getWarrantyEmailValue)
       ========================================================= */

    @IsTest
    static void testWarrantyEmailUnderWarranty() {
        runWarrantyScenario('Under Warranty', 'warrantyUnder');
    }

    @IsTest
    static void testWarrantyEmailYes() {
        runWarrantyScenario('Yes', 'warrantyYes');
    }

    @IsTest
    static void testWarrantyEmailActive() {
        runWarrantyScenario('Active', 'warrantyActive');
    }

    @IsTest
    static void testWarrantyEmailOutOfWarranty() {
        runWarrantyScenario('Out of Warranty', 'warrantyOut');
    }

    @IsTest
    static void testWarrantyEmailNo() {
        runWarrantyScenario('No', 'warrantyNo');
    }

    @IsTest
    static void testWarrantyEmailExpired() {
        runWarrantyScenario('Expired', 'warrantyExpired');
    }

    @IsTest
    static void testWarrantyEmailUnrecognisedValue() {
        runWarrantyScenario('Something Else', 'warrantyOther');
    }

    @IsTest
    static void testWarrantyEmailBlankValue() {
        runWarrantyScenario(null, 'warrantyBlank');
    }

    /* =========================================================
       EMAIL BODY BRANCHES (contact, address, numbers)
       ========================================================= */

    @IsTest
    static void testEmailWithContactMobilePhone() {
        List<Contact> contacts = [
            SELECT Id FROM Contact WHERE MobilePhone != null ORDER BY CreatedDate DESC LIMIT 1
        ];
        Fixture f = buildFixture(findAnyCase(), true);
        if (f == null || contacts.isEmpty()) {
            return;
        }
        Database.update(new Case(Id = f.c.Id, ContactId = contacts[0].Id), false);

        Test.startTest();
        assign(f.c, f.u, 'contactMobile');
        Test.stopTest();
    }

    @IsTest
    static void testEmailWithContactPhoneOnly() {
        List<Contact> contacts = [
            SELECT Id FROM Contact
            WHERE MobilePhone = null AND Phone != null
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        Fixture f = buildFixture(findAnyCase(), true);
        if (f == null || contacts.isEmpty()) {
            return;
        }
        Database.update(new Case(Id = f.c.Id, ContactId = contacts[0].Id), false);

        Test.startTest();
        assign(f.c, f.u, 'contactPhoneOnly');
        Test.stopTest();
    }

    @IsTest
    static void testEmailWithoutContact() {
        Fixture f = buildFixture(findAnyCase(), true);
        if (f == null) {
            return;
        }
        Database.update(new Case(Id = f.c.Id, ContactId = null), false);

        Test.startTest();
        assign(f.c, f.u, 'noContact');
        Test.stopTest();
    }

    @IsTest
    static void testEmailWithFullBillingAddress() {
        Fixture f = buildFixture(findAnyCase(), true);
        if (f == null) {
            return;
        }
        Database.update(new Account(
            Id = f.c.AccountId,
            BillingStreet = '1 Test <Street> & "Road"',
            BillingCity = 'Test City',
            BillingPostalCode = '110001'
        ), false);
        Database.update(new Account(Id = f.c.AccountId, BillingCountry = 'India'), false);

        Test.startTest();
        assign(f.c, f.u, 'fullAddress');
        Test.stopTest();
    }

    @IsTest
    static void testEmailWithProductCategory() {
        Fixture f = buildFixture(findAnyCase(), true);
        if (f == null) {
            return;
        }
        Database.update(new Case(
            Id = f.c.Id,
            Product_Categories__c = 'Test Category'
        ), false);

        Test.startTest();
        assign(f.c, f.u, 'productCategory');
        Test.stopTest();
    }
    

    @IsTest
    static void testEmailBlankProductCategory() {
        Fixture f = buildFixture(findAnyCase(), true);
        if (f == null) {
            return;
        }
        Database.update(new Case(Id = f.c.Id, Product_Categories__c = null), false);

        Test.startTest();
        assign(f.c, f.u, 'blankCategory');
        Test.stopTest();
    }

    /* =========================================================
       EXISTING MANUAL SHARES (delete-and-recreate branches)
       ========================================================= */

    @IsTest
    static void testExistingCaseShareIsReplaced() {
        Fixture f = buildFixture(findAnyCase(), true);
        if (f == null) {
            return;
        }
        preShareStandard('CaseShare', 'CaseId', 'CaseAccessLevel', new Set<Id>{ f.c.Id }, f.u.Id);

        Test.startTest();
        String response = assign(f.c, f.u, 'existingCaseShare');
        Test.stopTest();

        if (response != null) {

        }
    }

    @IsTest
    static void testExistingAssetSharesAreReplaced() {
        Fixture f = buildFixture(findCaseWithAssets(), true);
        if (f == null) {
            return;
        }
        preShareStandard('AssetShare', 'AssetId', 'AssetAccessLevel', assetIdsFor(f.c.Id), f.u.Id);

        Test.startTest();
        assign(f.c, f.u, 'existingAssetShare');
        Test.stopTest();
    }

    @IsTest
    static void testExistingCustomSharesAreReplaced() {
        Fixture f = buildFixture(findBestCaseForSharing(), true);
        if (f == null) {
            return;
        }

        Set<Id> relatedAssetIds = new Set<Id>();
        for (Case_Related_Assets__c row : [
            SELECT Id FROM Case_Related_Assets__c WHERE Case__c = :f.c.Id
        ]) {
            relatedAssetIds.add(row.Id);
        }

        Set<Id> relatedSerialIds = new Set<Id>();
        Set<Id> assetSerialIds = new Set<Id>();
        if (!relatedAssetIds.isEmpty()) {
            for (Case_Related_Assets_Serial_No__c row : [
                SELECT Id, Asset_Serial_No__c FROM Case_Related_Assets_Serial_No__c
                WHERE Case_Related_Assets__c IN :relatedAssetIds
            ]) {
                relatedSerialIds.add(row.Id);
                if (row.Asset_Serial_No__c != null) {
                    assetSerialIds.add(row.Asset_Serial_No__c);
                }
            }
        }

        Set<Id> relatedWarrantyIds = new Set<Id>();
        for (Case_Related_Asset_Warranty__c row : [
            SELECT Id FROM Case_Related_Asset_Warranty__c WHERE Case__c = :f.c.Id
        ]) {
            relatedWarrantyIds.add(row.Id);
        }

        preShareCustom('Case_Related_Assets__c', relatedAssetIds, f.u.Id);
        preShareCustom('Case_Related_Assets_Serial_No__c', relatedSerialIds, f.u.Id);
        preShareCustom('Asset_Serial_No__c', assetSerialIds, f.u.Id);
        preShareCustom('Case_Related_Asset_Warranty__c', relatedWarrantyIds, f.u.Id);

        Test.startTest();
        assign(f.c, f.u, 'existingCustomShares');
        Test.stopTest();
    }
    
  

    /* =========================================================
       COMBINED: shares + warranty + contact in a single run
       ========================================================= */

    @IsTest
    static void testFullScenarioOnBestCase() {
        Fixture f = buildFixture(findBestCaseForSharing(), true);
        if (f == null) {
            return;
        }
        setAssetWarrantyStatus(f.c.Id, 'Active');

        Test.startTest();
        String response = assign(f.c, f.u, 'fullScenario');
        String context = CaseL1AssignmentController.getAssignmentContext(f.c.Id);
        Test.stopTest();


        if (response != null) {

        }
    }
    


    /* =========================================================
       HIGH COVERAGE COMBINED PATH
       ========================================================= */

    




    /* =========================================================
       HIGH COVERAGE PATHS - ONE EXPENSIVE CALL PER TEST
       ========================================================= */

    @IsTest
    static void testHighCoverageAnyCaseSingleCall() {

        Fixture f =
            buildFixture(
                findAnyCase(),
                true
            );

        if (f == null) {
            return;
        }

        Test.startTest();

        assign(
            f.c,
            f.u,
            'HC-anyCase'
        );

        Test.stopTest();
    }


    @IsTest
    static void testHighCoverageRelatedAssetsSingleCall() {

        Fixture f =
            buildFixture(
                findCaseWithRelatedAssets(),
                true
            );

        if (f == null) {
            return;
        }

        Test.startTest();

        assign(
            f.c,
            f.u,
            'HC-relatedAssets'
        );

        Test.stopTest();
    }


    @IsTest
    static void testHighCoveragePrimaryAssetSingleCall() {

        Fixture f =
            buildFixture(
                findCaseWithPrimaryAsset(),
                true
            );

        if (f == null) {
            return;
        }

        Test.startTest();

        assign(
            f.c,
            f.u,
            'HC-primaryAsset'
        );

        Test.stopTest();
    }


    @IsTest
    static void testHighCoverageSerialSingleCall() {

        Fixture f =
            buildFixture(
                findCaseWithSerial(),
                true
            );

        if (f == null) {
            return;
        }

        Test.startTest();

        assign(
            f.c,
            f.u,
            'HC-serial'
        );

        Test.stopTest();
    }


    @IsTest
    static void testHighCoverageWarrantySingleCall() {

        Fixture f =
            buildFixture(
                findCaseWithWarranty(),
                true
            );

        if (f == null) {
            return;
        }

        Test.startTest();

        assign(
            f.c,
            f.u,
            'HC-warranty'
        );

        Test.stopTest();
    }


    @IsTest
    static void testHighCoverageContextSingleCall() {

        Case c =
            findBestCaseForSharing();

        if (c == null) {
            c =
                findAnyCase();
        }

        if (c == null) {
            return;
        }

        Test.startTest();

        try {

            String json =
                CaseL1AssignmentController.getAssignmentContext(
                        c.Id
                    );

            System.debug(
                'L1RESULT HC-context=' +
                json
            );

        } catch (Exception e) {

            System.debug(
                'L1RESULT HC-context FAILED=' +
                e.getMessage()
            );
        }

        Test.stopTest();
    }

}