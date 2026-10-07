public with sharing class LeadApprovalStatusController {

    @AuraEnabled(cacheable=true)
    public static String getApprovalStatus(Id recordId) {

        Lead l = [
            SELECT Approval_Status__c
            FROM Lead
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (l.Approval_Status__c == null) {
            return 'Not Submitted';
        }

        return l.Approval_Status__c; // Pending, Approved, Rejected
    }
}