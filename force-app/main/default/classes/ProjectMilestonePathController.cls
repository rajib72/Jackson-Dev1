public with sharing class ProjectMilestonePathController {

    @AuraEnabled(cacheable=true)
    public static List<Project_Milestone__c> getMilestones( Id recordId){

        List<Project_Milestone__c> milestoneList = [
            SELECT Id,
                   Milestone_Name__c,
                   Serial_Number__c
            FROM Project_Milestone__c
            WHERE Project_Name__c = :recordId
            AND Milestone_Master__c != null
            ORDER BY Serial_Number__c
        ];
        return milestoneList;
    }

	@AuraEnabled(cacheable=true)
	public static Project_Milestone__c getCurrentMilestone(Id recordId) {
		List<Project_Milestone__c> milestoneList = [
            SELECT Id,
                   Milestone_Name__c, Is_Current_Milestone__c,
                   Serial_Number__c
            FROM Project_Milestone__c
            WHERE Project_Name__c = :recordId
			AND Is_Current_Milestone__c = true
            AND Milestone_Master__c != null
        ];
        if (!milestoneList.isEmpty()) {
            return milestoneList.get(0);
        }
        
        return null;
	}

}