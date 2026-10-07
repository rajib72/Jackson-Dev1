public with sharing class TestingCommissioningController {
    
    // Wrapper class to pass data cleanly to LWC
    public class InitDataWrapper {
        @AuraEnabled public List<Project_Material__c> pendingMaterials;
        @AuraEnabled public Id milestoneId;
    }

    @AuraEnabled(cacheable=true)
    public static InitDataWrapper getInitialData(Id projectId) {
        InitDataWrapper wrapper = new InitDataWrapper();
        
        // 1. Fetch Materials where testing is NOT completed
        wrapper.pendingMaterials = [
            SELECT Id, Name, Material_Name__c 
            FROM Project_Material__c 
            WHERE Project__c = :projectId 
            AND Is_Testing_Completed__c = false
        ];
        
        // 2. Fetch the target Milestone for file uploads
        List<Project_Milestone__c> milestones = [
            SELECT Id 
            FROM Project_Milestone__c 
            WHERE Project_Name__c = :projectId 
            AND Milestone_Name__c = 'Testing & Commissioning'
            LIMIT 1
        ];
        
        if (!milestones.isEmpty()) {
            wrapper.milestoneId = milestones[0].Id;
        }
        
        return wrapper;
    }

    @AuraEnabled
    public static void saveCompletedMaterials(List<Id> materialIds) {
        if (materialIds.isEmpty()) return;
        
        List<Project_Material__c> materialsToUpdate = new List<Project_Material__c>();
        for (Id matId : materialIds) {
            materialsToUpdate.add(new Project_Material__c(
                Id = matId,
                Is_Testing_Completed__c = true
            ));
        }
        
        try {
            update materialsToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating materials: ' + e.getMessage());
        }
    }
}