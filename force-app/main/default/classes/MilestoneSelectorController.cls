public with sharing class MilestoneSelectorController {
    
    public class MilestoneDataWrapper {
        @AuraEnabled public List<Milestone__c> allMilestones;
        @AuraEnabled public List<Project_Milestone__c> existingProjectMilestones;
    }

    @AuraEnabled
    public static MilestoneDataWrapper getMilestoneData(Id projectId) {
        MilestoneDataWrapper wrapper = new MilestoneDataWrapper();
        
        // Fetch all master milestones ordered by Name
        wrapper.allMilestones = [
            SELECT Id, Milestone_Name__c 
            FROM Milestone__c 
            ORDER BY Name ASC
        ];
        
        // Fetch existing milestones ONLY for this specific project. 
        // We added Milestone_Name__c to catch the "Draft" record if the ID is missing.
        if (projectId != null) {
            wrapper.existingProjectMilestones = [
                SELECT Id, Milestone_Master__c, Milestone_Name__c, Serial_Number__c 
                FROM Project_Milestone__c 
                WHERE Project_Name__c = :projectId
            ];
        } else {
            wrapper.existingProjectMilestones = new List<Project_Milestone__c>();
        }
        
        return wrapper;
    }

    @AuraEnabled
    public static void saveNewMilestones(Id projectId, List<Id> selectedMilestoneIds) {
        if (selectedMilestoneIds.isEmpty() || projectId == null) return;

        Decimal maxSerial = 0;
        Set<Id> existingMasterIds = new Set<Id>();
        Set<String> existingNames = new Set<String>();
        
        // Find existing milestones to prevent duplicates and find the highest serial number
        for (Project_Milestone__c pm : [SELECT Milestone_Master__c, Milestone_Name__c, Serial_Number__c FROM Project_Milestone__c WHERE Project_Name__c = :projectId]) {
            if (pm.Milestone_Master__c != null) {
                existingMasterIds.add(pm.Milestone_Master__c);
            }
            if (pm.Milestone_Name__c != null) {
                existingNames.add(pm.Milestone_Name__c.toLowerCase());
            }
            if (pm.Serial_Number__c != null && pm.Serial_Number__c > maxSerial) {
                maxSerial = pm.Serial_Number__c;
            }
        }

        Map<Id, Milestone__c> masterMap = new Map<Id, Milestone__c>([
            SELECT Id, Milestone_Name__c 
            FROM Milestone__c 
            WHERE Id IN :selectedMilestoneIds
        ]);

        List<Project_Milestone__c> milestonesToInsert = new List<Project_Milestone__c>();

        for (Id mId : selectedMilestoneIds) {
            String mName = masterMap.get(mId).Milestone_Name__c;
            
            // Check by ID or by Name to avoid duplicates
            if (!existingMasterIds.contains(mId) && (mName == null || !existingNames.contains(mName.toLowerCase()))) {
                maxSerial++; // Increment serial number
                
                Project_Milestone__c newPm = new Project_Milestone__c();
                newPm.Project_Name__c = projectId;
                newPm.Milestone_Master__c = mId;
                newPm.Milestone_Name__c = mName;
                newPm.Serial_Number__c = maxSerial;
                
                milestonesToInsert.add(newPm);
            }
        }

        if (!milestonesToInsert.isEmpty()) {
            insert milestonesToInsert;
        }
    }
}