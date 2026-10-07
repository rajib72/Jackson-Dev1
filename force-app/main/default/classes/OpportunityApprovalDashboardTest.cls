@IsTest
private class OpportunityApprovalDashboardTest {

    private static Integer counter = 0;

    private static String uniqueText(String prefix) {
        counter++;
        return prefix + '_' + String.valueOf(DateTime.now().getTime()) + '_' +
            String.valueOf(Math.abs(Crypto.getRandomInteger())) + '_' + counter;
    }

    @TestSetup
    static void setupUsers() {
        Profile adminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        Profile standardProfile;
        List<Profile> standardProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        if (!standardProfiles.isEmpty()) {
            standardProfile = standardProfiles[0];
        } else {
            standardProfile = [
                SELECT Id
                FROM Profile
                WHERE UserType = 'Standard'
                AND Name != 'System Administrator'
                LIMIT 1
            ];
        }

        UserRole parentRole = new UserRole(
            Name = 'Dashboard Parent Role ' + String.valueOf(DateTime.now().getTime()),
            DeveloperName = 'Dashboard_Parent_Role_' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
        );
        insert parentRole;

        UserRole childRole = new UserRole(
            Name = 'Dashboard Child Role ' + String.valueOf(DateTime.now().getTime()),
            DeveloperName = 'Dashboard_Child_Role_' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            ParentRoleId = parentRole.Id
        );
        insert childRole;

        List<User> usersToInsert = new List<User>();

        usersToInsert.add(buildUser('dashadm', adminProfile.Id, 'Admin Department', null));
        usersToInsert.add(buildUser('dashtech', standardProfile.Id, 'Technical Head', null));
        usersToInsert.add(buildUser('dashqap', standardProfile.Id, 'QAP Head', null));
        usersToInsert.add(buildUser('dashcomm', standardProfile.Id, 'Commercial Head', null));
        usersToInsert.add(buildUser('dashsales', standardProfile.Id, 'Sales Head', null));
        usersToInsert.add(buildUser('dashplant', standardProfile.Id, 'Plant Head', null));
        usersToInsert.add(buildUser('dashfin', standardProfile.Id, 'Finance Head', null));
        usersToInsert.add(buildUser('dashsub', standardProfile.Id, 'Sales User', null));
        usersToInsert.add(buildUser('dashnoac', standardProfile.Id, null, null));
        usersToInsert.add(buildUser('dashmgr', standardProfile.Id, 'Management', parentRole.Id));
        usersToInsert.add(buildUser('dashchild', standardProfile.Id, 'Sales User', childRole.Id));

        insert usersToInsert;
    }

    private static User buildUser(
        String aliasValue,
        Id profileId,
        String department,
        Id roleId
    ) {
        String uniqueName =
            aliasValue + '.' +
            String.valueOf(DateTime.now().getTime()) + '.' +
            String.valueOf(Math.abs(Crypto.getRandomInteger())) +
            '@test.com';

        String nickName = uniqueName;
        if (nickName.length() > 40) {
            nickName = nickName.substring(0, 40);
        }

        User usr = new User(
            FirstName = aliasValue,
            LastName = 'DashboardTest',
            Alias = aliasValue.length() > 8 ? aliasValue.substring(0, 8) : aliasValue,
            Email = uniqueName,
            Username = uniqueName,
            CommunityNickname = nickName,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            ProfileId = profileId
        );

        if (department != null) {
            usr.Department = department;
        }

        if (roleId != null) {
            usr.UserRoleId = roleId;
        }

        return usr;
    }

    private static User getUserByAlias(String aliasValue) {
        return [
            SELECT Id, Name, Department, UserRoleId
            FROM User
            WHERE Alias = :aliasValue
            LIMIT 1
        ];
    }

    private static String getOppPicklistValue(
        String fieldApiName,
        List<String> preferredValues,
        Boolean mustContainSubmitted
    ) {
        Schema.SObjectField fieldToken =
            Schema.SObjectType.Opportunity.fields.getMap().get(fieldApiName);

        System.assertNotEquals(
            null,
            fieldToken,
            'Opportunity field not found: ' + fieldApiName
        );

        List<Schema.PicklistEntry> entries =
            fieldToken.getDescribe().getPicklistValues();

        for (String preferredValue : preferredValues) {
            for (Schema.PicklistEntry pe : entries) {
                if (
                    pe.isActive()
                    && pe.getValue() != null
                    && pe.getValue().trim().toLowerCase() == preferredValue.trim().toLowerCase()
                ) {
                    return pe.getValue();
                }
            }
        }

        if (mustContainSubmitted) {
            for (Schema.PicklistEntry pe : entries) {
                if (
                    pe.isActive()
                    && pe.getValue() != null
                    && pe.getValue().toLowerCase().contains('submitted')
                ) {
                    return pe.getValue();
                }
            }
        }

        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }

        return null;
    }

    private static String getRequiredBusinessSegment(String expectedValue) {
        String value = getOppPicklistValue(
            'Business_Segment__c',
            new List<String>{ expectedValue },
            false
        );

        System.assertEquals(
            expectedValue.toLowerCase(),
            value != null ? value.toLowerCase() : null,
            'Business_Segment__c must have value: ' + expectedValue
        );

        return value;
    }

    private static String getSubmittedValue(String fieldApiName, List<String> expectedValues) {
        String value = getOppPicklistValue(fieldApiName, expectedValues, true);

        System.assert(
            value != null && value.toLowerCase().contains('submitted'),
            fieldApiName + ' must have an active submitted picklist value.'
        );

        return value;
    }

    private static String getAnyNonSubmittedValue(String fieldApiName) {
        Schema.SObjectField fieldToken =
            Schema.SObjectType.Opportunity.fields.getMap().get(fieldApiName);

        for (Schema.PicklistEntry pe : fieldToken.getDescribe().getPicklistValues()) {
            if (
                pe.isActive()
                && pe.getValue() != null
                && !pe.getValue().toLowerCase().contains('submitted')
            ) {
                return pe.getValue();
            }
        }

        return null;
    }

    private static String getStageNameValue() {
        for (Schema.PicklistEntry pe : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }

        return 'Prospecting';
    }

    private static Id getDefaultOpportunityRecordTypeId() {
        for (Schema.RecordTypeInfo info : Opportunity.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (info.isAvailable() && info.isDefaultRecordTypeMapping()) {
                return info.getRecordTypeId();
            }
        }

        return null;
    }

    private static Account createAccount(String namePrefix) {
        Account acc = new Account(
            Name = uniqueText(namePrefix)
        );

        fillRequiredFields(acc, new Map<String, Id>());

        insert acc;
        return acc;
    }

    private static Contact createContact(Account acc) {
        Contact con = new Contact(
            LastName = uniqueText('Contact'),
            AccountId = acc.Id
        );

        fillRequiredFields(
            con,
            new Map<String, Id>{
                'AccountId' => acc.Id
            }
        );

        insert con;
        return con;
    }

    private static Campaign createCampaign() {
        Campaign camp = new Campaign(
            Name = uniqueText('Campaign'),
            IsActive = true
        );

        fillRequiredFields(camp, new Map<String, Id>());

        insert camp;
        return camp;
    }

    private static Contract createContract(Account acc) {
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12
        );

        Schema.SObjectField statusField = Schema.SObjectType.Contract.fields.getMap().get('Status');
        if (statusField != null && statusField.getDescribe().isCreateable()) {
            for (Schema.PicklistEntry pe : statusField.getDescribe().getPicklistValues()) {
                if (pe.isActive()) {
                    con.Status = pe.getValue();
                    break;
                }
            }
        }

        fillRequiredFields(
            con,
            new Map<String, Id>{
                'AccountId' => acc.Id
            }
        );

        Database.SaveResult sr = Database.insert(con, false);

        if (sr.isSuccess()) {
            return con;
        }

        return null;
    }

    private static void fillRequiredFields(SObject recordObj, Map<String, Id> referenceIdsByField) {
        Map<String, Schema.SObjectField> fieldsMap =
            recordObj.getSObjectType().getDescribe().fields.getMap();

        for (String fieldName : fieldsMap.keySet()) {
            Schema.DescribeFieldResult d = fieldsMap.get(fieldName).getDescribe();

            if (!d.isCreateable()) {
                continue;
            }

            if (d.isNillable() || d.isDefaultedOnCreate()) {
                continue;
            }

            if (recordObj.get(fieldName) != null) {
                continue;
            }

            try {
                if (referenceIdsByField != null && referenceIdsByField.containsKey(fieldName)) {
                    recordObj.put(fieldName, referenceIdsByField.get(fieldName));
                    continue;
                }

                Schema.DisplayType fieldType = d.getType();

                if (fieldType == Schema.DisplayType.String ||
                    fieldType == Schema.DisplayType.TextArea ||
                    fieldType == Schema.DisplayType.Phone ||
                    fieldType == Schema.DisplayType.Email ||
                    fieldType == Schema.DisplayType.Url) {
                    recordObj.put(fieldName, uniqueText('Test'));
                } else if (fieldType == Schema.DisplayType.Boolean) {
                    recordObj.put(fieldName, false);
                } else if (fieldType == Schema.DisplayType.Date) {
                    recordObj.put(fieldName, Date.today());
                } else if (fieldType == Schema.DisplayType.DateTime) {
                    recordObj.put(fieldName, System.now());
                } else if (fieldType == Schema.DisplayType.Currency ||
                           fieldType == Schema.DisplayType.Double ||
                           fieldType == Schema.DisplayType.Percent) {
                    recordObj.put(fieldName, 1);
                } else if (fieldType == Schema.DisplayType.Integer) {
                    recordObj.put(fieldName, 1);
                } else if (fieldType == Schema.DisplayType.Picklist) {
                    for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                        if (pe.isActive()) {
                            recordObj.put(fieldName, pe.getValue());
                            break;
                        }
                    }
                } else if (fieldType == Schema.DisplayType.MultiPicklist) {
                    for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                        if (pe.isActive()) {
                            recordObj.put(fieldName, pe.getValue());
                            break;
                        }
                    }
                }
            } catch (Exception ex) {
                System.debug('Skipping required field fill for ' + fieldName + ': ' + ex.getMessage());
            }
        }
    }

    private static Opportunity createOpportunityRecord(
        Id ownerId,
        String businessSegment,
        Map<String, String> approvalFieldValues
    ) {
        Account acc = createAccount('Opp Account');
        Account partnerAcc = createAccount('Partner Account');
        Contact con = createContact(acc);
        Campaign camp = createCampaign();
        Contract contractRec = createContract(acc);

        Id pricebookId;
        try {
            pricebookId = Test.getStandardPricebookId();
        } catch (Exception ex) {
            pricebookId = null;
        }

        Opportunity opp = new Opportunity(
            Name = uniqueText('Opportunity'),
            OwnerId = ownerId,
            AccountId = acc.Id,
            StageName = getStageNameValue(),
            CloseDate = Date.today().addDays(30)
        );

        Id recordTypeId = getDefaultOpportunityRecordTypeId();
        if (recordTypeId != null) {
            opp.RecordTypeId = recordTypeId;
        }

        opp.put('Business_Segment__c', businessSegment);

        if (Schema.SObjectType.Opportunity.fields.getMap().containsKey('Contact__c')) {
            opp.put('Contact__c', con.Id);
        }

        if (
            contractRec != null &&
            Schema.SObjectType.Opportunity.fields.getMap().containsKey('ContractId')
        ) {
            opp.put('ContractId', contractRec.Id);
        }

        if (Schema.SObjectType.Opportunity.fields.getMap().containsKey('Partner_Assigned__c')) {
            opp.put('Partner_Assigned__c', partnerAcc.Id);
        }

        if (
            pricebookId != null &&
            Schema.SObjectType.Opportunity.fields.getMap().containsKey('Pricebook2Id')
        ) {
            opp.Pricebook2Id = pricebookId;
        }

        if (Schema.SObjectType.Opportunity.fields.getMap().containsKey('CampaignId')) {
            opp.CampaignId = camp.Id;
        }

        if (approvalFieldValues != null) {
            for (String fieldApi : approvalFieldValues.keySet()) {
                opp.put(fieldApi, approvalFieldValues.get(fieldApi));
            }
        }

        Map<String, Id> refIds = new Map<String, Id>{
            'OwnerId' => ownerId,
            'AccountId' => acc.Id,
            'Contact__c' => con.Id,
            'Partner_Assigned__c' => partnerAcc.Id,
            'Pricebook2Id' => pricebookId,
            'CampaignId' => camp.Id
        };

        if (contractRec != null) {
            refIds.put('ContractId', contractRec.Id);
        }

        fillRequiredFields(opp, refIds);

        insert opp;
        return opp;
    }

    private static void shareOpportunity(Id oppId, Id userId) {
        OpportunityShare oppShare = new OpportunityShare(
            OpportunityId = oppId,
            UserOrGroupId = userId,
            OpportunityAccessLevel = 'Read',
            RowCause = Schema.OpportunityShare.RowCause.Manual
        );

        Database.insert(oppShare, false);
    }

    private static void createRemark(Id oppId, String stageName) {
        Remarks__c remark = new Remarks__c();

        if (Schema.SObjectType.Remarks__c.fields.getMap().containsKey('Name')) {
            Schema.DescribeFieldResult nameDescribe =
                Schema.SObjectType.Remarks__c.fields.getMap().get('Name').getDescribe();

            if (nameDescribe.isCreateable()) {
                remark.put('Name', uniqueText('Remark'));
            }
        }

        remark.put('Opportunity__c', oppId);
        remark.put('Stage_Name__c', stageName);

        fillRequiredFields(
            remark,
            new Map<String, Id>{
                'Opportunity__c' => oppId
            }
        );

        Database.insert(remark, false);
    }

    @IsTest
    static void testSystemAdminCanSeeAllRows() {
        User adminUser = getUserByAlias('dashadm');
        User submitter = getUserByAlias('dashsub');

        String kamSegment = getRequiredBusinessSegment('KAM');
        String instSegment = getRequiredBusinessSegment('Institutional');

        Opportunity kamOpp = createOpportunityRecord(
            submitter.Id,
            kamSegment,
            new Map<String, String>{
                'Design_Team_Approval_Stage__c' => getSubmittedValue(
                    'Design_Team_Approval_Stage__c',
                    new List<String>{ 'Submitted to Design Team Approval', 'Submitted to Design Team approval' }
                ),
                'Quality_Team_Approval_Stage__c' => getSubmittedValue(
                    'Quality_Team_Approval_Stage__c',
                    new List<String>{ 'Submitted to Quality Team Approval', 'Submitted to Quality Team approval' }
                ),
                'Commercial_Team_Approval_Stage__c' => getSubmittedValue(
                    'Commercial_Team_Approval_Stage__c',
                    new List<String>{ 'Submitted to Commercial Team Approval', 'Submitted to Commercial Team approval' }
                ),
                'COO_Approval_Stage__c' => getSubmittedValue(
                    'COO_Approval_Stage__c',
                    new List<String>{ 'Submitted to COO Approval', 'Submitted to COO approval' }
                )
            }
        );

        Opportunity instOpp = createOpportunityRecord(
            submitter.Id,
            instSegment,
            new Map<String, String>{
                'Inst_Sales_Head_Approval_Stage__c' => getSubmittedValue(
                    'Inst_Sales_Head_Approval_Stage__c',
                    new List<String>{ 'Submitted to Sales Head Approval', 'Submitted to Sales Head approval', 'Submitted to Sales Head', 'Sales Head Submitted' }
                ),
                'Inst_Commercial_Head_Approval_Stage__c' => getSubmittedValue(
                    'Inst_Commercial_Head_Approval_Stage__c',
                    new List<String>{ 'Submitted to Commercial Head Approval', 'Submitted to Commercial Head approval', 'Submitted to Commercial Head', 'Commercial Head Submitted' }
                ),
                'Inst_Plant_Head_Approval_Stage__c' => getSubmittedValue(
                    'Inst_Plant_Head_Approval_Stage__c',
                    new List<String>{ 'Submitted to Plant Head Approval', 'Submitted to Plant Head approval', 'Submitted to Plant Head', 'Plant Head Submitted' }
                ),
                'Inst_Finance_Head_Approval_Stage__c' => getSubmittedValue(
                    'Inst_Finance_Head_Approval_Stage__c',
                    new List<String>{ 'Submitted to Finance Head Approval', 'Submitted to Finance Head approval', 'Submitted to Finance Head', 'Finance Head Submitted' }
                ),
                'Inst_Technical_Head_Approval_Stage__c' => getSubmittedValue(
                    'Inst_Technical_Head_Approval_Stage__c',
                    new List<String>{ 'Submitted to Technical Head Approval', 'Submitted to Technical Head approval', 'Submitted to Technical Head', 'Technical Head Submitted' }
                )
            }
        );

        createRemark(kamOpp.Id, 'Submit for Design Team Approval');
        createRemark(kamOpp.Id, 'Submit for Design Team Approval');
        createRemark(kamOpp.Id, 'Submit for Quality Team Approval');
        createRemark(kamOpp.Id, 'Submit for Commercial Team Approval');
        createRemark(kamOpp.Id, 'Submit for COO Approval');

        createRemark(instOpp.Id, 'Remarks - Sales Head / Bid Submission');
        createRemark(instOpp.Id, 'Remarks - Commercial Head / Bid Submission');
        createRemark(instOpp.Id, 'Remarks - Plant Head / Bid Submission');
        createRemark(instOpp.Id, 'Remarks - Finance Head / Bid Submission');
        createRemark(instOpp.Id, 'Remarks - Technical Head / Bid Submission');
        createRemark(instOpp.Id, 'Invalid Remark Stage');
        createRemark(instOpp.Id, null);

        System.runAs(adminUser) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            System.assert(rows.size() > 0, 'Admin should see approval dashboard rows.');

            Boolean foundSubmittedDate = false;

            for (OpportunityApprovalDashboardController.ApprovalDashboardRow row : rows) {
                System.assertNotEquals(null, row.rowKey);
                System.assertNotEquals(null, row.opportunityId);
                System.assertNotEquals(null, row.opportunityName);
                System.assertNotEquals(null, row.approvalStatus);

                if (row.submittedDate != null) {
                    foundSubmittedDate = true;
                }
            }

            System.assertEquals(true, foundSubmittedDate, 'Submitted date should be populated from Remarks__c.');
        }
    }

    @IsTest
    static void testApproverDepartmentVisibility() {
        User techUser = getUserByAlias('dashtech');
        User submitter = getUserByAlias('dashsub');

        String kamSegment = getRequiredBusinessSegment('KAM');
        String instSegment = getRequiredBusinessSegment('Institutional');

        Opportunity kamOpp = createOpportunityRecord(
            submitter.Id,
            kamSegment,
            new Map<String, String>{
                'Design_Team_Approval_Stage__c' => getSubmittedValue(
                    'Design_Team_Approval_Stage__c',
                    new List<String>{ 'Submitted to Design Team Approval', 'Submitted to Design Team approval' }
                )
            }
        );

        Opportunity instOpp = createOpportunityRecord(
            submitter.Id,
            instSegment,
            new Map<String, String>{
                'Inst_Technical_Head_Approval_Stage__c' => getSubmittedValue(
                    'Inst_Technical_Head_Approval_Stage__c',
                    new List<String>{ 'Submitted to Technical Head Approval', 'Submitted to Technical Head approval', 'Submitted to Technical Head', 'Technical Head Submitted' }
                )
            }
        );

        Opportunity commercialOpp = createOpportunityRecord(
            submitter.Id,
            kamSegment,
            new Map<String, String>{
                'Commercial_Team_Approval_Stage__c' => getSubmittedValue(
                    'Commercial_Team_Approval_Stage__c',
                    new List<String>{ 'Submitted to Commercial Team Approval', 'Submitted to Commercial Team approval' }
                )
            }
        );

        shareOpportunity(kamOpp.Id, techUser.Id);
        shareOpportunity(instOpp.Id, techUser.Id);
        shareOpportunity(commercialOpp.Id, techUser.Id);

        System.runAs(techUser) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            System.assert(rows.size() >= 2, 'Technical Head should see technical approval rows.');

            Boolean foundTechnicalSubmittedTo = false;

            for (OpportunityApprovalDashboardController.ApprovalDashboardRow row : rows) {
                if (row.submittedTo == techUser.Name) {
                    foundTechnicalSubmittedTo = true;
                }
            }

            System.assertEquals(true, foundTechnicalSubmittedTo);
        }
    }

    @IsTest
    static void testSubmitterOwnOpportunityVisibility() {
        User submitter = getUserByAlias('dashsub');

        String kamSegment = getRequiredBusinessSegment('KAM');

        createOpportunityRecord(
            submitter.Id,
            kamSegment,
            new Map<String, String>{
                'Commercial_Team_Approval_Stage__c' => getSubmittedValue(
                    'Commercial_Team_Approval_Stage__c',
                    new List<String>{ 'Submitted to Commercial Team Approval', 'Submitted to Commercial Team approval' }
                ),
                'COO_Approval_Stage__c' => getSubmittedValue(
                    'COO_Approval_Stage__c',
                    new List<String>{ 'Submitted to COO Approval', 'Submitted to COO approval' }
                )
            }
        );

        System.runAs(submitter) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            System.assert(rows.size() > 0, 'Submitter should see own Opportunity approval rows.');
        }
    }

    @IsTest
    static void testManagerRoleHierarchyVisibility() {
        User managerUser = getUserByAlias('dashmgr');
        User childUser = getUserByAlias('dashchild');

        String kamSegment = getRequiredBusinessSegment('KAM');

        Opportunity opp = createOpportunityRecord(
            childUser.Id,
            kamSegment,
            new Map<String, String>{
                'Quality_Team_Approval_Stage__c' => getSubmittedValue(
                    'Quality_Team_Approval_Stage__c',
                    new List<String>{ 'Submitted to Quality Team Approval', 'Submitted to Quality Team approval' }
                )
            }
        );

        shareOpportunity(opp.Id, managerUser.Id);

        System.runAs(managerUser) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            System.assert(rows.size() > 0, 'Manager should see subordinate Opportunity approval row.');
        }
    }

    @IsTest
    static void testUserWithoutDashboardVisibility() {
        User noAccessUser = getUserByAlias('dashnoac');
        User submitter = getUserByAlias('dashsub');

        String instSegment = getRequiredBusinessSegment('Institutional');

        Opportunity opp = createOpportunityRecord(
            submitter.Id,
            instSegment,
            new Map<String, String>{
                'Inst_Finance_Head_Approval_Stage__c' => getSubmittedValue(
                    'Inst_Finance_Head_Approval_Stage__c',
                    new List<String>{ 'Submitted to Finance Head Approval', 'Submitted to Finance Head approval', 'Submitted to Finance Head', 'Finance Head Submitted' }
                )
            }
        );

        shareOpportunity(opp.Id, noAccessUser.Id);

        System.runAs(noAccessUser) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            System.assertNotEquals(null, rows);
        }
    }

    @IsTest
    static void testEmptyDashboardBranch() {
        User submitter = getUserByAlias('dashsub');

        System.runAs(submitter) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            System.assertNotEquals(null, rows);
        }
    }

    @IsTest
    static void testBlankAndRejectedStageBranches() {
        User adminUser = getUserByAlias('dashadm');
        User submitter = getUserByAlias('dashsub');

        String kamSegment = getRequiredBusinessSegment('KAM');

        String rejectedOrOtherValue = getAnyNonSubmittedValue('Quality_Team_Approval_Stage__c');

        Map<String, String> values = new Map<String, String>{
            'Design_Team_Approval_Stage__c' => ''
        };

        if (rejectedOrOtherValue != null) {
            values.put('Quality_Team_Approval_Stage__c', rejectedOrOtherValue);
        }

        createOpportunityRecord(
            submitter.Id,
            kamSegment,
            values
        );

        System.runAs(adminUser) {
            Test.startTest();

            List<OpportunityApprovalDashboardController.ApprovalDashboardRow> rows =
                OpportunityApprovalDashboardController.getApprovalDashboard();

            Test.stopTest();

            System.assertNotEquals(null, rows);
        }
    }
}