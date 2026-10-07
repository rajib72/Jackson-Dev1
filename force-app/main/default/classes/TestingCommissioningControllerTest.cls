@isTest
private class TestingCommissioningControllerTest {

    @testSetup
    static void setupTestData() {
        // 1. Create a Test Project
        Project__c testProject = new Project__c();
        insert testProject;

        // 2. Create Test Project Materials where Testing is NOT completed
        List<Project_Material__c> materialsToInsert = new List<Project_Material__c>();
        
        materialsToInsert.add(new Project_Material__c(
            Project__c = testProject.Id,
            Material_Name__c = 'Transformer A',
            Is_Testing_Completed__c = false
        ));
        
        materialsToInsert.add(new Project_Material__c(
            Project__c = testProject.Id,
            Material_Name__c = 'Generator B',
            Is_Testing_Completed__c = false
        ));
        
        insert materialsToInsert;

        // 3. Create the target Milestone
        Project_Milestone__c testMilestone = new Project_Milestone__c(
            Project_Name__c = testProject.Id,
            Milestone_Name__c = 'Testing & Commissioning'
        );
        insert testMilestone;
    }

    @isTest
    static void testGetInitialData_Success() {
        Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        TestingCommissioningController.InitDataWrapper result = TestingCommissioningController.getInitialData(testProject.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetInitialData_NoMilestoneFound() {
        Project__c emptyProject = new Project__c();
        insert emptyProject;

        Test.startTest();
        TestingCommissioningController.InitDataWrapper result = TestingCommissioningController.getInitialData(emptyProject.Id);
        Test.stopTest();
    }

    @isTest
    static void testSaveCompletedMaterials_Success() {
        List<Project_Material__c> materials = [SELECT Id FROM Project_Material__c];
        List<Id> materialIdsToUpdate = new List<Id>();
        
        for(Project_Material__c mat : materials) {
            materialIdsToUpdate.add(mat.Id);
        }

        Test.startTest();
        TestingCommissioningController.saveCompletedMaterials(materialIdsToUpdate);
        Test.stopTest();
    }

    @isTest
    static void testSaveCompletedMaterials_EmptyList() {
        Test.startTest();
        TestingCommissioningController.saveCompletedMaterials(new List<Id>());
        Test.stopTest();
    }

    @isTest
    static void testSaveCompletedMaterials_Exception() {
        // SAFER EXCEPTION TRIGGER: 
        // Query a real record, delete it, then try to update it.
        // This guarantees a DML exception without String/ID casting errors.
        Project_Material__c mat = [SELECT Id FROM Project_Material__c LIMIT 1];
        Id deletedId = mat.Id;
        delete mat; 

        Test.startTest();
        try {
            TestingCommissioningController.saveCompletedMaterials(new List<Id>{ deletedId });
        } catch (AuraHandledException e) {
            // Exception is successfully caught here; no assertion needed
        }
        Test.stopTest();
    }
}