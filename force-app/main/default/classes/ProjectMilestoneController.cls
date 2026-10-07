public with sharing class ProjectMilestoneController {

    @AuraEnabled(cacheable=true)
    public static List<Milestone__c> getMilestones(){
        return [SELECT Id, Milestone_Name__c FROM Milestone__c  ];
    }

    @AuraEnabled
    public static void saveProjectMilestones(Id projectId, List<String> milestoneNames){

        List<Project_Milestone__c> pmList = new List<Project_Milestone__c>();
        Integer serialNo = 1;

        List<Project_Milestone__c> lastRecord = [
            SELECT Serial_Number__c
            FROM Project_Milestone__c
            WHERE Project_Name__c = :projectId
            ORDER BY Serial_Number__c DESC
            LIMIT 1
        ];
         if(!lastRecord.isEmpty()){
            serialNo = Integer.valueOf(lastRecord[0].Serial_Number__c) + 1;
        }
        for(String m : milestoneNames){

            Project_Milestone__c pm = new Project_Milestone__c();
            pm.Project_Name__c = projectId;
            pm.Milestone_Name__c = m;
            pm.Serial_Number__c = serialNo;
            
            pmList.add(pm);
            serialNo++;
        }

        insert pmList;
    }
}