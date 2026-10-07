public class SerialNumberUpdateController {

	// Fetch all records, including Serial 1 / Draft
    @AuraEnabled(cacheable=true)
    public static List<Project_Milestone__c> getMilestones(Id recordId) {
        return [
            SELECT Id, Milestone_Name__c, Serial_Number__c 
            FROM Project_Milestone__c 
            WHERE Project_Name__c = :recordId 
            ORDER BY Serial_Number__c ASC
        ];
    }

    @AuraEnabled
    public static void updateMilestones(List<Project_Milestone__c> milestonesToUpdate) {
        try {
            update milestonesToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}