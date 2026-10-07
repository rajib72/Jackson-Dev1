public with sharing class ProjectController {

    @AuraEnabled
    public static Id createProject(String name, String location, Decimal capacity, String type) {

        Project__c proj = new Project__c();
        proj.Name = name;
        proj.Project_Location__c = location;
        proj.Project_Capacity__c = capacity;
        proj.Project_Type__c = type;

        insert proj;

        return proj.Id;
    }
}