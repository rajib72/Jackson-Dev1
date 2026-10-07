public with sharing class CaseResolutionTimerController {

    @AuraEnabled(cacheable=true)
    public static Case getTimerDetails(Id caseId) {

        if (caseId == null) {
            throw new AuraHandledException(
                'Case Id is required.'
            );
        }

        List<Case> caseList = [
            SELECT Id,
                   CaseNumber,
                   Subject,
                   SRT_Case_Status__c,
                   CreatedDate,
                   ClosedDate
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (caseList.isEmpty()) {
            throw new AuraHandledException(
                'Case record was not found.'
            );
        }

        return caseList[0];
    }
}