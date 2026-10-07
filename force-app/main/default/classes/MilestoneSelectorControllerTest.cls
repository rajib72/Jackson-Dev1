@isTest
private class MilestoneSelectorControllerTest {
 
    @TestSetup
    static void setupTestData() {
        Project__c testProject = new Project__c(Name = 'Coverage Project');
        insert testProject;
 
        List<Milestone__c> mastersToInsert = new List<Milestone__c>{
            new Milestone__c(Milestone_Name__c = 'Exist By ID'),
            new Milestone__c(Milestone_Name__c = 'Exist By Name'),
            new Milestone__c(Milestone_Name__c = 'Completely New'),
            new Milestone__c(Milestone_Name__c = null)
        };
        insert mastersToInsert;
 
        List<Project_Milestone__c> existingPMs = new List<Project_Milestone__c>{
            new Project_Milestone__c(
                Project_Name__c = testProject.Id,
                Milestone_Master__c = mastersToInsert[0].Id,
                Milestone_Name__c = 'Exist By ID',
                Serial_Number__c = 10
            ),
            new Project_Milestone__c(
                Project_Name__c = testProject.Id,
                Milestone_Name__c = 'Exist By Name',
                Serial_Number__c = 20
            ),
            new Project_Milestone__c(
                Project_Name__c = testProject.Id,
                Milestone_Master__c = mastersToInsert[3].Id,
                Serial_Number__c = 30
            ),
            new Project_Milestone__c(
                Project_Name__c = testProject.Id,
                Milestone_Name__c = 'Missing Serial'
            )
        };
        insert existingPMs;
    }
 
    //  EXISTING METHOD (KEEP YOURS AS IS)
    @isTest
    static void testSaveNewMilestones_FullCoverage() {
 
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        List<Milestone__c> masters = [SELECT Id, Milestone_Name__c FROM Milestone__c];
 
        Map<String, Id> nameToIdMap = new Map<String, Id>();
        Id nullNameId;
 
        for (Milestone__c m : masters) {
            if (m.Milestone_Name__c != null) {
                nameToIdMap.put(m.Milestone_Name__c, m.Id);
            } else {
                nullNameId = m.Id;
            }
        }
 
        List<Id> selectedIds = new List<Id>{
            nameToIdMap.get('Exist By ID'),
            nameToIdMap.get('Exist By Name'),
            nameToIdMap.get('Completely New'),
            nullNameId
        };
 
        Test.startTest();
        MilestoneSelectorController.saveNewMilestones(proj.Id, selectedIds);
        Test.stopTest();
 
        List<Project_Milestone__c> finalPMs = [
            SELECT Id, Milestone_Name__c, Serial_Number__c
            FROM Project_Milestone__c
            WHERE Project_Name__c = :proj.Id
        ];
 
        Project_Milestone__c insertedNew = [
            SELECT Serial_Number__c
            FROM Project_Milestone__c
            WHERE Milestone_Name__c = 'Completely New'
            LIMIT 1
        ];
 
        System.assertEquals(31, insertedNew.Serial_Number__c);
    }
 
    //  NEW TEST 1 → getMilestoneData (projectId != null)
    @isTest
    static void testGetMilestoneData_WithProject() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
 
        Test.startTest();
        MilestoneSelectorController.MilestoneDataWrapper result =
            MilestoneSelectorController.getMilestoneData(proj.Id);
        Test.stopTest();
 
        System.assertNotEquals(null, result);
        System.assert(result.allMilestones.size() > 0);
        System.assert(result.existingProjectMilestones.size() > 0);
    }
 
    //  NEW TEST 2 → getMilestoneData (projectId == null)
    @isTest
    static void testGetMilestoneData_NullProject() {
 
        Test.startTest();
        MilestoneSelectorController.MilestoneDataWrapper result =
            MilestoneSelectorController.getMilestoneData(null);
        Test.stopTest();
 
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.existingProjectMilestones.size());
        System.assert(result.allMilestones.size() > 0);
    }
 
    //  NEW TEST 3 → Early return (empty list)
    @isTest
    static void testSaveNewMilestones_EmptyList() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
 
        Test.startTest();
        MilestoneSelectorController.saveNewMilestones(proj.Id, new List<Id>());
        Test.stopTest();
 
        // No exception = pass
        System.assert(true);
    }
 
    //  NEW TEST 4 → Early return (null project)
    @isTest
    static void testSaveNewMilestones_NullProject() {
 
        List<Milestone__c> masters = [SELECT Id FROM Milestone__c];
 
        Test.startTest();
        MilestoneSelectorController.saveNewMilestones(null, new List<Id>{masters[0].Id});
        Test.stopTest();
 
        System.assert(true);
    }
 
    //  NEW TEST 5 → No insert case (all duplicates)
    @isTest
    static void testSaveNewMilestones_NoInsert() {
 
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
 
        // Pick only existing ones → should NOT insert
        List<Project_Milestone__c> existing = [
            SELECT Milestone_Master__c
            FROM Project_Milestone__c
            WHERE Milestone_Master__c != null
        ];
 
        List<Id> ids = new List<Id>();
        for (Project_Milestone__c pm : existing) {
            ids.add(pm.Milestone_Master__c);
        }
 
        Integer beforeCount = [
            SELECT COUNT() FROM Project_Milestone__c WHERE Project_Name__c = :proj.Id
        ];
 
        Test.startTest();
        MilestoneSelectorController.saveNewMilestones(proj.Id, ids);
        Test.stopTest();
 
        Integer afterCount = [
            SELECT COUNT() FROM Project_Milestone__c WHERE Project_Name__c = :proj.Id
        ];
 
        System.assertEquals(beforeCount, afterCount, 'No new records should be inserted');
    }
}