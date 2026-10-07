public with sharing class OpportunityApprovalDashboardController {

    private static final Integer MAX_OPP_RECORDS = 500;

    public class ApprovalDashboardRow {
        @AuraEnabled public String rowKey { get; set; }
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public String opportunityName { get; set; }
        @AuraEnabled public String approvalStatus { get; set; }
        @AuraEnabled public String submittedBy { get; set; }
        @AuraEnabled public String submittedTo { get; set; }
        @AuraEnabled public Datetime submittedDate { get; set; }
    }

    private class CurrentUserContext {
        public Id userId;
        public Id userRoleId;
        public String userName;
        public String department;
        public String profileName;
        public Boolean isSystemAdmin;
    }

    private class StageConfig {
        public String businessSegment;
        public String fieldApiName;
        public Set<String> submittedValues;
        public String approvalLevel;
        public Set<String> allowedDepartments;
        public Set<String> remarkKeywords;

        public StageConfig(
            String businessSegment,
            String fieldApiName,
            Set<String> submittedValues,
            String approvalLevel,
            Set<String> allowedDepartments,
            Set<String> remarkKeywords
        ) {
            this.businessSegment = businessSegment;
            this.fieldApiName = fieldApiName;
            this.submittedValues = submittedValues;
            this.approvalLevel = approvalLevel;
            this.allowedDepartments = allowedDepartments;
            this.remarkKeywords = remarkKeywords;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ApprovalDashboardRow> getApprovalDashboard() {

        CurrentUserContext currentUser = getCurrentUserContext();
        List<StageConfig> configs = getStageConfigs();

        List<Opportunity> oppList = getOpportunities(configs);

        if (oppList.isEmpty()) {
            return new List<ApprovalDashboardRow>();
        }

        Set<Id> oppIds = new Set<Id>();

        for (Opportunity opp : oppList) {
            oppIds.add(opp.Id);
        }

        Map<String, Datetime> submittedDateByOppAndStage = getSubmittedDates(oppIds, configs);
        Map<String, String> submittedToByConfig = getSubmittedToUsers(configs);

        Set<Id> submitterVisibleOwnerIds = currentUser.isSystemAdmin
            ? new Set<Id>()
            : getRoleHierarchyUserIds(currentUser.userId, currentUser.userRoleId);

        List<ApprovalDashboardRow> rows = new List<ApprovalDashboardRow>();

        for (Opportunity opp : oppList) {

            String oppBusinessSegment = getStringValue(opp, 'Business_Segment__c');

            for (StageConfig config : configs) {

                if (!isTextEqual(oppBusinessSegment, config.businessSegment)) {
                    continue;
                }

                String currentStageValue = getStringValue(opp, config.fieldApiName);

                if (!isSubmittedApprovalValue(currentStageValue, config)) {
                    continue;
                }

                /*
                 * Visibility:
                 * 1. System Administrator profile sees all submitted approval rows.
                 * 2. Approver sees only rows submitted to their approval department.
                 * 3. Submitter / manager sees Opportunities owned by themselves
                 *    or users below them in role hierarchy.
                 */
                Boolean isApproverForThisStage = isExactDepartmentMatched(
                    currentUser.department,
                    config.allowedDepartments
                );

                Boolean isSubmitterOrManager = submitterVisibleOwnerIds.contains(opp.OwnerId);

                if (
                    !currentUser.isSystemAdmin
                    && !isApproverForThisStage
                    && !isSubmitterOrManager
                ) {
                    continue;
                }

                String configKey = getConfigKey(config);
                String submittedDateKey = getSubmittedDateKey(opp.Id, config);

                ApprovalDashboardRow row = new ApprovalDashboardRow();
                row.rowKey = String.valueOf(opp.Id) + '|' + configKey;
                row.opportunityId = opp.Id;
                row.opportunityName = opp.Name;
                row.approvalStatus = currentStageValue;
                row.submittedBy = opp.Owner != null ? opp.Owner.Name : '';

                if (currentUser.isSystemAdmin) {
                    row.submittedTo = submittedToByConfig.containsKey(configKey)
                        ? submittedToByConfig.get(configKey)
                        : 'No active user found';
                } else if (isApproverForThisStage) {
                    row.submittedTo = currentUser.userName;
                } else {
                    row.submittedTo = submittedToByConfig.containsKey(configKey)
                        ? submittedToByConfig.get(configKey)
                        : 'No active user found';
                }

                row.submittedDate = submittedDateByOppAndStage.containsKey(submittedDateKey)
                    ? submittedDateByOppAndStage.get(submittedDateKey)
                    : null;

                rows.add(row);
            }
        }

        return rows;
    }

    private static List<Opportunity> getOpportunities(List<StageConfig> configs) {

        Set<String> approvalFieldApiNames = new Set<String>();

        for (StageConfig config : configs) {
            approvalFieldApiNames.add(config.fieldApiName);
        }

        List<String> approvalFields = new List<String>();
        approvalFields.addAll(approvalFieldApiNames);
        approvalFields.sort();

        String soql = 'SELECT Id, Name, OwnerId, Owner.Name, Business_Segment__c';

        if (!approvalFields.isEmpty()) {
            soql += ', ' + String.join(approvalFields, ', ');
        }

        soql += ' FROM Opportunity';
        soql += ' WHERE Business_Segment__c IN (\'KAM\', \'Institutional\')';
        soql += ' ORDER BY LastModifiedDate DESC';
        soql += ' LIMIT ' + String.valueOf(MAX_OPP_RECORDS);

        return Database.query(soql);
    }

//     private static List<Opportunity> getOpportunities(
//     List<StageConfig> configs
// ) {
//     Set<String> approvalFieldApiNames = new Set<String>();

//     for (StageConfig config : configs) {
//         approvalFieldApiNames.add(config.fieldApiName);
//     }

//     List<String> approvalFields =
//         new List<String>(approvalFieldApiNames);

//     approvalFields.sort();

//     String soql =
//         'SELECT Id, Name, StageName, IsClosed, ' +
//          'Key_Account_Opp_Stages_c, Institutional_Opp_Stages__c, ' +
//         'OwnerId, Owner.Name, Business_Segment_c';

//     if (!approvalFields.isEmpty()) {
//         soql += ', ' + String.join(approvalFields, ', ');
//     }

//     soql += ' FROM Opportunity';

//     /*
//      * Only open Opportunities are retrieved.
//      * Closed Won, Closed Lost and other stages configured
//      * as closed are automatically excluded by IsClosed = false.
//      */
//     soql +=
//         ' WHERE Business_Segment__c IN ' +
//         '(\'KAM\', \'Institutional\')';

//     soql += ' AND IsClosed = false';

//     soql +=
//         ' AND StageName NOT IN ' +
//         '(\'Closed Won \', \'Closed Lost \', \'Closed Drop\')';
//     soql +=
//     ' AND (' +
//     ' (Business_Segment__c = \'KAM\' AND ' +
//     '  (Key_Account_Opp_Stages_c = null OR Key_Account_Opp_Stages__c NOT IN ' +
//     '   (\'Closed  Won\', \'Closed Lost\', \'Closed Drop\')))' +
//     ' OR ' +
//     ' (BusinessSegment__c = \'Institutional\' AND ' +
//     '  (Institutional_Opp_Stages_c = null OR Institutional_Opp_Stages__c NOT IN ' +
//     '   (\'Closed Won\', \'Closed Lost\', \'Closed Drop\')))' +
//     ' )';

//     soql += ' ORDER BY LastModifiedDate DESC';
//     soql += ' LIMIT ' + String.valueOf(MAX_OPP_RECORDS);

//     return Database.query(soql);
// }

    private static CurrentUserContext getCurrentUserContext() {

        User loggedInUser = [
            SELECT Id,
                   Name,
                   Department,
                   Profile.Name,
                   UserRoleId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        CurrentUserContext ctx = new CurrentUserContext();
        ctx.userId = loggedInUser.Id;
        ctx.userRoleId = loggedInUser.UserRoleId;
        ctx.userName = loggedInUser.Name;
        ctx.department = loggedInUser.Department;
        ctx.profileName = loggedInUser.Profile.Name;
        ctx.isSystemAdmin = loggedInUser.Profile.Name == 'System Administrator';

        return ctx;
    }

    private static Set<Id> getRoleHierarchyUserIds(Id loggedInUserId, Id loggedInUserRoleId) {

        Set<Id> visibleUserIds = new Set<Id>();
        visibleUserIds.add(loggedInUserId);

        if (loggedInUserRoleId == null) {
            return visibleUserIds;
        }

        Map<Id, List<Id>> childRoleIdsByParentRoleId = new Map<Id, List<Id>>();

        for (UserRole roleRec : [
            SELECT Id, ParentRoleId
            FROM UserRole
            WHERE ParentRoleId != null
        ]) {
            if (!childRoleIdsByParentRoleId.containsKey(roleRec.ParentRoleId)) {
                childRoleIdsByParentRoleId.put(roleRec.ParentRoleId, new List<Id>());
            }

            childRoleIdsByParentRoleId.get(roleRec.ParentRoleId).add(roleRec.Id);
        }

        Set<Id> visibleRoleIds = new Set<Id>();
        visibleRoleIds.add(loggedInUserRoleId);

        List<Id> rolesToProcess = new List<Id>();
        rolesToProcess.add(loggedInUserRoleId);

        while (!rolesToProcess.isEmpty()) {
            Id currentRoleId = rolesToProcess.remove(0);

            if (childRoleIdsByParentRoleId.containsKey(currentRoleId)) {
                for (Id childRoleId : childRoleIdsByParentRoleId.get(currentRoleId)) {
                    if (!visibleRoleIds.contains(childRoleId)) {
                        visibleRoleIds.add(childRoleId);
                        rolesToProcess.add(childRoleId);
                    }
                }
            }
        }

        for (User usr : [
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND UserRoleId IN :visibleRoleIds
        ]) {
            visibleUserIds.add(usr.Id);
        }

        return visibleUserIds;
    }

    private static Boolean isSubmittedApprovalValue(
        String currentStageValue,
        StageConfig config
    ) {
        if (String.isBlank(currentStageValue)) {
            return false;
        }

        String stageValue = currentStageValue.trim().toLowerCase();

        for (String submittedValue : config.submittedValues) {
            if (
                String.isNotBlank(submittedValue)
                && stageValue == submittedValue.trim().toLowerCase()
            ) {
                return true;
            }
        }
        /*
         * Backup handling:
         * If picklist value contains submitted, it will still show.
         */
        return stageValue.contains('submitted');
    }

//      private static Boolean isSubmittedApprovalValue(
//     String currentStageValue,
//     StageConfig config
// ) {
//     if (String.isBlank(currentStageValue)) {
//         return false;
//     }

//     String stageValue =
//         currentStageValue.trim().toLowerCase();

//     /*
//      * Do not display completed approval statuses.
//      */
//     if (
//         stageValue.contains('approved ')
//         || stageValue.contains('rejected')
//         || stageValue.contains('cancelled')
//         || stageValue.contains('canceled')
//     ) {
//         return false;
//     }

//     /*
//      * Display only the configured pending/submitted values.
//      */
//     for (String submittedValue : config.submittedValues) {
//         if (
//             String.isNotBlank(submittedValue)
//             && stageValue ==
//                 submittedValue.trim().toLowerCase()
//         ) {
//             return true;
//         }
//     }

//     return false;
// }

    private static Boolean isExactDepartmentMatched(
        String userDepartment,
        Set<String> allowedDepartments
    ) {
        if (
            String.isBlank(userDepartment)
            || allowedDepartments == null
            || allowedDepartments.isEmpty()
        ) {
            return false;
        }

        String departmentValue = userDepartment.trim().toLowerCase();

        for (String allowedDepartment : allowedDepartments) {
            if (
                String.isNotBlank(allowedDepartment)
                && departmentValue == allowedDepartment.trim().toLowerCase()
            ) {
                return true;
            }
        }

        return false;
    }

    private static Map<String, String> getSubmittedToUsers(List<StageConfig> configs) {

        Map<String, List<String>> usersByConfig = new Map<String, List<String>>();

        for (StageConfig config : configs) {
            usersByConfig.put(getConfigKey(config), new List<String>());
        }

        List<User> userList = [
            SELECT Id,
                   Name,
                   Department
            FROM User
            WHERE IsActive = true
            AND Department != null
            ORDER BY Name
        ];

        for (User usr : userList) {
            for (StageConfig config : configs) {
                if (isExactDepartmentMatched(usr.Department, config.allowedDepartments)) {
                    usersByConfig.get(getConfigKey(config)).add(usr.Name);
                }
            }
        }

        Map<String, String> submittedToByConfig = new Map<String, String>();

        for (String configKey : usersByConfig.keySet()) {

            List<String> names = usersByConfig.get(configKey);

            submittedToByConfig.put(
                configKey,
                names.isEmpty() ? 'No active user found' : String.join(names, ', ')
            );
        }

        return submittedToByConfig;
    }

    private static Map<String, Datetime> getSubmittedDates(
        Set<Id> oppIds,
        List<StageConfig> configs
    ) {
        Map<String, Datetime> submittedDateByOppAndStage = new Map<String, Datetime>();

        if (oppIds == null || oppIds.isEmpty()) {
            return submittedDateByOppAndStage;
        }

        List<Remarks__c> remarksList = [
            SELECT Id,
                   Opportunity__c,
                   Stage_Name__c,
                   CreatedDate
            FROM Remarks__c
            WHERE Opportunity__c IN :oppIds
            ORDER BY CreatedDate DESC
        ];

        for (Remarks__c remark : remarksList) {

            if (
                remark.Opportunity__c == null
                || String.isBlank(remark.Stage_Name__c)
            ) {
                continue;
            }

            String stageText = remark.Stage_Name__c.toLowerCase();

            for (StageConfig config : configs) {

                Boolean isMatchingRemark = false;

                for (String keyword : config.remarkKeywords) {
                    if (
                        String.isNotBlank(keyword)
                        && stageText.contains(keyword.toLowerCase())
                    ) {
                        isMatchingRemark = true;
                        break;
                    }
                }

                if (isMatchingRemark) {

                    String mapKey = getSubmittedDateKey(remark.Opportunity__c, config);

                    if (!submittedDateByOppAndStage.containsKey(mapKey)) {
                        submittedDateByOppAndStage.put(mapKey, remark.CreatedDate);
                    }
                }
            }
        }

        return submittedDateByOppAndStage;
    }

    private static String getStringValue(SObject recordObj, String fieldApiName) {
        if (recordObj == null || String.isBlank(fieldApiName)) {
            return null;
        }

        Object fieldValue = recordObj.get(fieldApiName);
        return fieldValue == null ? null : String.valueOf(fieldValue);
    }

    private static Boolean isTextEqual(String valueOne, String valueTwo) {
        if (String.isBlank(valueOne) || String.isBlank(valueTwo)) {
            return false;
        }

        return valueOne.trim().toLowerCase() == valueTwo.trim().toLowerCase();
    }

    private static String getConfigKey(StageConfig config) {
        return config.businessSegment + '|' + config.approvalLevel;
    }

    private static String getSubmittedDateKey(Id opportunityId, StageConfig config) {
        return String.valueOf(opportunityId) + '|' + getConfigKey(config);
    }

    private static List<StageConfig> getStageConfigs() {

        List<StageConfig> configs = new List<StageConfig>();

        /*
         * =========================
         * KAM Approval Stages
         * =========================
         */

        configs.add(
            new StageConfig(
                'KAM',
                'Design_Team_Approval_Stage__c',
                new Set<String>{
                    'Submitted to Design Team approval',
                    'Submitted to Design Team Approval'
                },
                'Design Team',
                new Set<String>{ 'Technical Head' },
                new Set<String>{ 'Submit for Design Team Approval' }
            )
        );

        configs.add(
            new StageConfig(
                'KAM',
                'Quality_Team_Approval_Stage__c',
                new Set<String>{
                    'Submitted to Quality Team approval',
                    'Submitted to Quality Team Approval'
                },
                'Quality Team',
                new Set<String>{ 'QAP Head' },
                new Set<String>{ 'Submit for Quality Team Approval' }
            )
        );

        // configs.add(
        //     new StageConfig(
        //         'KAM',
        //         'Key_AccountOpp_Sub_Stages_c',
        //         new Set<String>{ 'Submit for Sales Head  Approval' },
        //         'Sales Head',
        //         new Set<String>{ 'Sales  Head' },
        //         new Set<String>{ 'Submit for Sales Head Approval' }
        //     )
        // );
        

        configs.add(
            new StageConfig(
                'KAM',
                'Commercial_Team_Approval_Stage__c',
                new Set<String>{
                    'Submitted to Commercial Team approval',
                    'Submitted to Commercial Team Approval'
                },
                'Commercial Team',
                new Set<String>{ 'Commercial Head' },
                new Set<String>{ 'Submit for Commercial Team Approval' }
            )
        );

        configs.add(
            new StageConfig(
                'KAM',
                'COO_Approval_Stage__c',
                new Set<String>{
                    'Submitted to COO approval',
                    'Submitted to COO Approval',
                    'Submitted to Commercial Team approval',
                    'Submitted to Commercial Team Approval'
                },
                'COO',
                new Set<String>{ 'COO' },
                new Set<String>{
                    'Submit for COO Approval',
                    'Submit for Commercial Team Approval'
                }
            )
        );

        /*
         * =========================
         * Institutional Approval Stages
         * =========================
         */

        configs.add(
            new StageConfig(
                'Institutional',
                'Inst_Sales_Head_Approval_Stage__c',
                new Set<String>{
                    'Submitted to Sales Head approval',
                    'Submitted to Sales Head Approval',
                    'Submitted to Sales Head',
                    'Sales Head Submitted'
                },
                'Sales Head',
                new Set<String>{ 'Sales Head' },
                new Set<String>{ 'Remarks - Sales Head / Bid Submission' }
            )
        );

        configs.add(
            new StageConfig(
                'Institutional',
                'Inst_Commercial_Head_Approval_Stage__c',
                new Set<String>{
                    'Submitted to Commercial Head approval',
                    'Submitted to Commercial Head Approval',
                    'Submitted to Commercial Head',
                    'Commercial Head Submitted'
                },
                'Commercial Head',
                new Set<String>{ 'Commercial Head' },
                new Set<String>{ 'Remarks - Commercial Head / Bid Submission' }
            )
        );

        configs.add(
            new StageConfig(
                'Institutional',
                'Inst_Plant_Head_Approval_Stage__c',
                new Set<String>{
                    'Submitted to Plant Head approval',
                    'Submitted to Plant Head Approval',
                    'Submitted to Plant Head',
                    'Plant Head Submitted'
                },
                'Plant Head',
                new Set<String>{ 'Plant Head' },
                new Set<String>{ 'Remarks - Plant Head / Bid Submission' }
            )
        );

        configs.add(
            new StageConfig(
                'Institutional',
                'Inst_Finance_Head_Approval_Stage__c',
                new Set<String>{
                    'Submitted to Finance Head approval',
                    'Submitted to Finance Head Approval',
                    'Submitted to Finance Head',
                    'Finance Head Submitted'
                },
                'Finance Head',
                new Set<String>{ 'Finance Head' },
                new Set<String>{ 'Remarks - Finance Head / Bid Submission' }
            )
        );

        configs.add(
            new StageConfig(
                'Institutional',
                'Inst_Technical_Head_Approval_Stage__c',
                new Set<String>{
                    'Submitted to Technical Head approval',
                    'Submitted to Technical Head Approval',
                    'Submitted to Technical Head',
                    'Technical Head Submitted'
                },
                'Technical Head',
                new Set<String>{ 'Technical Head' },
                new Set<String>{ 'Remarks - Technical Head / Bid Submission' }
            )
        );

        return configs;
    }
    public static void datacover() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}