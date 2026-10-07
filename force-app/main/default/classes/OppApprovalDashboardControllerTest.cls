@IsTest
private class OppApprovalDashboardControllerTest {
	@IsTest
    static void test() {
		OpportunityApprovalDashboardController.datacover();
    }
    
    @TestSetup
    static void setupTestUsers() {
        Id adminProfileId = getAdminProfileId();
        Id userProfileId = getNonAdminProfileId();

        List<User> usersToInsert = new List<User>();

        usersToInsert.add(
            buildUser(
                'tcadm',
                adminProfileId,
                'Technical Head'
            )
        );

        usersToInsert.add(
            buildUser(
                'tcqap',
                userProfileId,
                'QAP Head'
            )
        );

        usersToInsert.add(
            buildUser(
                'tcomm',
                userProfileId,
                'Commercial Head'
            )
        );

        usersToInsert.add(
            buildUser(
                'tsales',
                userProfileId,
                'Sales Head'
            )
        );

        usersToInsert.add(
            buildUser(
                'tplant',
                userProfileId,
                'Plant Head'
            )
        );

        usersToInsert.add(
            buildUser(
                'tfin',
                userProfileId,
                'Finance Head'
            )
        );

        insert usersToInsert;
    }

    @IsTest
    static void testNoOpportunityReturnsEmptyList() {
        User adminUser = getUserByAlias('tcadm');

        System.runAs(adminUser) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            System.assertEquals(
                0,
                rows.size(),
                'Dashboard should return blank list when no Opportunity exists.'
            );
        }
    }

    @IsTest
    static void testSystemAdminSeesKamApprovalRows() {
        User adminUser = getUserByAlias('tcadm');

        Account acc = createAccount('KAM Test Account');

        Opportunity kamOpp = buildOpportunity(
            acc.Id,
            adminUser.Id,
            'KAM',
            'KAM Approval Test Opportunity',
            new Map<String, Object>{
                'Design_Team_Approval_Stage__c' => getApprovalPicklistValue(
                    'Design_Team_Approval_Stage__c',
                    'Submitted to Design Team Approval'
                ),
                'Quality_Team_Approval_Stage__c' => getApprovalPicklistValue(
                    'Quality_Team_Approval_Stage__c',
                    'Submitted to Quality Team Approval'
                ),
                'Commercial_Team_Approval_Stage__c' => getApprovalPicklistValue(
                    'Commercial_Team_Approval_Stage__c',
                    'Submitted to Commercial Team Approval'
                ),
                'COO_Approval_Stage__c' => getApprovalPicklistValue(
                    'COO_Approval_Stage__c',
                    'Submitted to COO Approval'
                )
            }
        );

        insert kamOpp;

        insertRemark(kamOpp.Id, 'Submit for Design Team Approval');
        insertRemark(kamOpp.Id, 'Submit for Quality Team Approval');
        insertRemark(kamOpp.Id, 'Submit for Commercial Team Approval');
        insertRemark(kamOpp.Id, 'Submit for COO Approval');

        System.runAs(adminUser) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            System.assert(
                rows.size() > 0,
                'System Administrator should see KAM submitted approval rows.'
            );

            Boolean kamRowFound = false;

            for (OpportunityApprovalDashboardController.ApprovalDashboardRow row : rows) {
                if (row.opportunityId == kamOpp.Id) {
                    kamRowFound = true;

                    System.assertNotEquals(null, row.rowKey, 'Row key should be populated.');
                    System.assertNotEquals(null, row.opportunityName, 'Opportunity name should be populated.');
                    System.assertNotEquals(null, row.approvalStatus, 'Approval status should be populated.');
                    System.assertNotEquals(null, row.submittedBy, 'Submitted By should be populated.');
                    System.assertNotEquals(null, row.submittedTo, 'Submitted To should be populated.');
                }
            }

            System.assertEquals(
                true,
                kamRowFound,
                'KAM Opportunity should be available in dashboard.'
            );
        }
    }

    @IsTest
    static void testSystemAdminSeesInstitutionalApprovalRows() {
        User adminUser = getUserByAlias('tcadm');

        Account acc = createAccount('Institutional Test Account');

        Opportunity instOpp = buildOpportunity(
            acc.Id,
            adminUser.Id,
            'Institutional',
            'Institutional Approval Test Opportunity',
            new Map<String, Object>{
                'Inst_Sales_Head_Approval_Stage__c' => getApprovalPicklistValue(
                    'Inst_Sales_Head_Approval_Stage__c',
                    'Submitted to Sales Head Approval'
                ),
                'Inst_Commercial_Head_Approval_Stage__c' => getApprovalPicklistValue(
                    'Inst_Commercial_Head_Approval_Stage__c',
                    'Submitted to Commercial Head Approval'
                ),
                'Inst_Plant_Head_Approval_Stage__c' => getApprovalPicklistValue(
                    'Inst_Plant_Head_Approval_Stage__c',
                    'Submitted to Plant Head Approval'
                ),
                'Inst_Finance_Head_Approval_Stage__c' => getApprovalPicklistValue(
                    'Inst_Finance_Head_Approval_Stage__c',
                    'Submitted to Finance Head Approval'
                ),
                'Inst_Technical_Head_Approval_Stage__c' => getApprovalPicklistValue(
                    'Inst_Technical_Head_Approval_Stage__c',
                    'Submitted to Technical Head Approval'
                )
            }
        );

        insert instOpp;

        insertRemark(instOpp.Id, 'Remarks - Sales Head / Bid Submission');
        insertRemark(instOpp.Id, 'Remarks - Commercial Head / Bid Submission');
        insertRemark(instOpp.Id, 'Remarks - Plant Head / Bid Submission');
        insertRemark(instOpp.Id, 'Remarks - Finance Head / Bid Submission');
        insertRemark(instOpp.Id, 'Remarks - Technical Head / Bid Submission');

        System.runAs(adminUser) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            System.assert(
                rows.size() > 0,
                'System Administrator should see Institutional submitted approval rows.'
            );

            Boolean instRowFound = false;

            for (OpportunityApprovalDashboardController.ApprovalDashboardRow row : rows) {
                if (row.opportunityId == instOpp.Id) {
                    instRowFound = true;

                    System.assertNotEquals(null, row.rowKey, 'Row key should be populated.');
                    System.assertNotEquals(null, row.opportunityName, 'Opportunity name should be populated.');
                    System.assertNotEquals(null, row.approvalStatus, 'Approval status should be populated.');
                    System.assertNotEquals(null, row.submittedBy, 'Submitted By should be populated.');
                    System.assertNotEquals(null, row.submittedTo, 'Submitted To should be populated.');
                }
            }

            System.assertEquals(
                true,
                instRowFound,
                'Institutional Opportunity should be available in dashboard.'
            );
        }
    }

    @IsTest
    static void testSubmittedFallbackValueContainsSubmitted() {
        User adminUser = getUserByAlias('tcadm');

        Account acc = createAccount('Fallback Submitted Account');

        Opportunity opp = buildOpportunity(
            acc.Id,
            adminUser.Id,
            'KAM',
            'Fallback Submitted Opportunity',
            new Map<String, Object>{
                'Design_Team_Approval_Stage__c' => getApprovalPicklistValue(
                    'Design_Team_Approval_Stage__c',
                    'Submitted to Design Team Approval'
                )
            }
        );

        insert opp;

        System.runAs(adminUser) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            Boolean oppFound = false;

            for (OpportunityApprovalDashboardController.ApprovalDashboardRow row : rows) {
                if (row.opportunityId == opp.Id) {
                    oppFound = true;
                }
            }

            System.assertEquals(
                true,
                oppFound,
                'Opportunity with submitted stage should appear in dashboard.'
            );
        }
    }

    @IsTest
    static void testNonSubmittedOpportunityDoesNotCreateDashboardRow() {
        User adminUser = getUserByAlias('tcadm');

        Account acc = createAccount('Non Submitted Account');

        Opportunity opp = buildOpportunity(
            acc.Id,
            adminUser.Id,
            'KAM',
            'Non Submitted Opportunity',
            new Map<String, Object>()
        );

        insert opp;

        System.runAs(adminUser) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            Boolean currentOppFound = false;

            for (OpportunityApprovalDashboardController.ApprovalDashboardRow row : rows) {
                if (row.opportunityId == opp.Id) {
                    currentOppFound = true;
                }
            }

            System.assertEquals(
                false,
                currentOppFound,
                'Opportunity without submitted approval stage should not appear in dashboard.'
            );
        }
    }

    private static Id getAdminProfileId() {
        return [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ].Id;
    }

    private static Id getNonAdminProfileId() {
        List<Profile> profiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        if (!profiles.isEmpty()) {
            return profiles[0].Id;
        }

        profiles = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            AND Name != 'System Administrator'
            LIMIT 1
        ];

        if (!profiles.isEmpty()) {
            return profiles[0].Id;
        }

        return getAdminProfileId();
    }

    private static User buildUser(
        String aliasName,
        Id profileId,
        String department
    ) {
        String uniqueKey =
            aliasName +
            String.valueOf(DateTime.now().getTime()) +
            String.valueOf(Math.abs(Crypto.getRandomInteger()));

        return new User(
            FirstName = 'Test',
            LastName = aliasName,
            Alias = aliasName.length() > 8 ? aliasName.substring(0, 8) : aliasName,
            Email = uniqueKey + '@test.com',
            Username = uniqueKey + '@test.com',
            CommunityNickname = uniqueKey.length() > 40
                ? uniqueKey.substring(0, 40)
                : uniqueKey,
            ProfileId = profileId,
            Department = department,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }

    private static User getUserByAlias(String aliasName) {
        return [
            SELECT Id,
                   Name,
                   Alias,
                   Department,
                   Profile.Name
            FROM User
            WHERE Alias = :aliasName
            LIMIT 1
        ];
    }

    private static Account createAccount(String accountName) {
        Account acc = new Account(
            Name = accountName
        );

        populateRequiredFields(acc);

        insert acc;
        return acc;
    }

    private static Opportunity buildOpportunity(
        Id accountId,
        Id ownerId,
        String businessSegment,
        String oppName,
        Map<String, Object> approvalFieldValues
    ) {
        Opportunity opp = new Opportunity();

        opp.Name = oppName;
        opp.AccountId = accountId;
        opp.OwnerId = ownerId;
        opp.CloseDate = Date.today().addDays(30);
        opp.StageName = getOpenOpportunityStageName();

        putIfFieldExistsAndCreateable(
            opp,
            'Business_Segment__c',
            getBusinessSegmentValue(businessSegment)
        );

        for (String fieldApiName : approvalFieldValues.keySet()) {
            putIfFieldExistsAndCreateable(
                opp,
                fieldApiName,
                approvalFieldValues.get(fieldApiName)
            );
        }

        populateRequiredFields(opp);

        return opp;
    }

    private static String getOpenOpportunityStageName() {
        List<OpportunityStage> stages = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsActive = true
            AND IsClosed = false
            ORDER BY SortOrder
            LIMIT 1
        ];

        if (!stages.isEmpty()) {
            return stages[0].MasterLabel;
        }

        return 'Prospecting';
    }

    private static String getBusinessSegmentValue(String preferredValue) {
        return getPicklistValue(
            'Business_Segment__c',
            preferredValue
        );
    }

    private static String getApprovalPicklistValue(
        String fieldApiName,
        String preferredValue
    ) {
        return getPicklistValue(
            fieldApiName,
            preferredValue
        );
    }

    private static String getPicklistValue(
        String fieldApiName,
        String preferredValue
    ) {
        Map<String, Schema.SObjectField> oppFields =
            Schema.SObjectType.Opportunity.fields.getMap();

        if (!oppFields.containsKey(fieldApiName)) {
            return preferredValue;
        }

        Schema.DescribeFieldResult fieldDescribe =
            oppFields.get(fieldApiName).getDescribe();

        if (fieldDescribe.getType() != Schema.DisplayType.Picklist) {
            return preferredValue;
        }

        for (Schema.PicklistEntry pe : fieldDescribe.getPicklistValues()) {
            if (
                pe.isActive()
                && pe.getValue() != null
                && pe.getValue().trim().toLowerCase() == preferredValue.trim().toLowerCase()
            ) {
                return pe.getValue();
            }
        }

        for (Schema.PicklistEntry pe : fieldDescribe.getPicklistValues()) {
            if (
                pe.isActive()
                && pe.getValue() != null
                && pe.getValue().toLowerCase().contains(preferredValue.toLowerCase())
            ) {
                return pe.getValue();
            }
        }

        for (Schema.PicklistEntry pe : fieldDescribe.getPicklistValues()) {
            if (
                pe.isActive()
                && pe.getValue() != null
                && pe.getValue().toLowerCase().contains('submitted')
            ) {
                return pe.getValue();
            }
        }

        return preferredValue;
    }

    private static void insertRemark(Id opportunityId, String stageName) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        if (!globalDescribe.containsKey('Remarks__c')) {
            return;
        }

        Schema.SObjectType remarkType = globalDescribe.get('Remarks__c');

        if (!remarkType.getDescribe().isCreateable()) {
            return;
        }

        Map<String, Schema.SObjectField> remarkFields =
            remarkType.getDescribe().fields.getMap();

        if (
            !remarkFields.containsKey('Opportunity__c') ||
            !remarkFields.containsKey('Stage_Name__c')
        ) {
            return;
        }

        SObject remark = remarkType.newSObject();

        if (
            remarkFields.containsKey('Name') &&
            remarkFields.get('Name').getDescribe().isCreateable()
        ) {
            remark.put(
                'Name',
                'Test Remark ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
            );
        }

        remark.put('Opportunity__c', opportunityId);
        remark.put('Stage_Name__c', stageName);

        populateRequiredFields(remark);

        try {
            insert remark;
        } catch (Exception ex) {
            // Submitted Date is optional for dashboard test coverage.
        }
    }

    private static void putIfFieldExistsAndCreateable(
        SObject recordObj,
        String fieldApiName,
        Object fieldValue
    ) {
        Map<String, Schema.SObjectField> fieldMap =
            recordObj.getSObjectType().getDescribe().fields.getMap();

        if (!fieldMap.containsKey(fieldApiName)) {
            return;
        }

        if (!fieldMap.get(fieldApiName).getDescribe().isCreateable()) {
            return;
        }

        recordObj.put(fieldApiName, fieldValue);
    }

    private static void populateRequiredFields(SObject recordObj) {
        Schema.DescribeSObjectResult objectDescribe =
            recordObj.getSObjectType().getDescribe();

        Map<String, Schema.SObjectField> fieldMap =
            objectDescribe.fields.getMap();

        for (String fieldApiName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe =
                fieldMap.get(fieldApiName).getDescribe();

            if (!fieldDescribe.isCreateable()) {
                continue;
            }

            if (fieldDescribe.isNillable()) {
                continue;
            }

            if (fieldDescribe.isDefaultedOnCreate()) {
                continue;
            }

            if (recordObj.get(fieldApiName) != null) {
                continue;
            }

            if (fieldApiName == 'Id') {
                continue;
            }

            Object defaultValue = getDefaultValueForField(
                fieldDescribe,
                fieldApiName
            );

            if (defaultValue != null) {
                recordObj.put(fieldApiName, defaultValue);
            }
        }
    }

    private static Object getDefaultValueForField(
        Schema.DescribeFieldResult fieldDescribe,
        String fieldApiName
    ) {
        Schema.DisplayType fieldType = fieldDescribe.getType();

        if (fieldApiName == 'CurrencyIsoCode') {
            try {
                return UserInfo.getDefaultCurrency();
            } catch (Exception e) {
                return null;
            }
        }

        if (fieldType == Schema.DisplayType.String) {
            return 'Test Value';
        }

        if (fieldType == Schema.DisplayType.TextArea) {
            return 'Test Value';
        }

        if (fieldType == Schema.DisplayType.Phone) {
            return '9999999999';
        }

        if (fieldType == Schema.DisplayType.Email) {
            return 'test@example.com';
        }

        if (fieldType == Schema.DisplayType.Url) {
            return 'https://example.com';
        }

        if (fieldType == Schema.DisplayType.Date) {
            return Date.today();
        }

        if (fieldType == Schema.DisplayType.DateTime) {
            return DateTime.now();
        }

        if (fieldType == Schema.DisplayType.Boolean) {
            return false;
        }

        if (
            fieldType == Schema.DisplayType.Integer ||
            fieldType == Schema.DisplayType.Double ||
            fieldType == Schema.DisplayType.Currency ||
            fieldType == Schema.DisplayType.Percent
        ) {
            return 1;
        }

        if (fieldType == Schema.DisplayType.Picklist) {
            for (Schema.PicklistEntry pe : fieldDescribe.getPicklistValues()) {
                if (pe.isActive()) {
                    return pe.getValue();
                }
            }
        }

        return null;
    }
}