@IsTest
private class SerialNumberUpdateControllerTest {

    @IsTest
    static void testGetMilestones() {
        Project__c proj = new Project__c(
            Name = 'Test Project'
        );
        insert proj;

        Project_Milestone__c pm1 = new Project_Milestone__c(
            Project_Name__c = proj.Id,
            Milestone_Name__c = 'Test Serial 998',
            Serial_Number__c = 998
        );

        Project_Milestone__c pm2 = new Project_Milestone__c(
            Project_Name__c = proj.Id,
            Milestone_Name__c = 'Test Serial 999',
            Serial_Number__c = 999
        );

        insert new List<Project_Milestone__c>{ pm2, pm1 };

        Test.startTest();
        List<Project_Milestone__c> result = SerialNumberUpdateController.getMilestones(proj.Id);
        Test.stopTest();

        System.assert(result.size() >= 2, 'At least the inserted milestones should be returned');

        Boolean found998 = false;
        Boolean found999 = false;
        Integer index998 = -1;
        Integer index999 = -1;

        for (Integer i = 0; i < result.size(); i++) {
            if (result[i].Milestone_Name__c == 'Test Serial 998' && result[i].Serial_Number__c == 998) {
                found998 = true;
                index998 = i;
            }
            if (result[i].Milestone_Name__c == 'Test Serial 999' && result[i].Serial_Number__c == 999) {
                found999 = true;
                index999 = i;
            }
        }

        System.assertEquals(true, found998, 'Milestone with serial 998 should be returned');
        System.assertEquals(true, found999, 'Milestone with serial 999 should be returned');
        System.assert(index998 < index999, 'Milestones should be sorted by Serial_Number__c ASC');
    }

    @IsTest
    static void testUpdateMilestones() {
        Project__c proj = new Project__c(
            Name = 'Test Project Update'
        );
        insert proj;

        Project_Milestone__c pm = new Project_Milestone__c(
            Project_Name__c = proj.Id,
            Milestone_Name__c = 'Draft',
            Serial_Number__c = 1
        );
        insert pm;

        pm.Serial_Number__c = 5;
        pm.Milestone_Name__c = 'Updated Milestone';

        Test.startTest();
        SerialNumberUpdateController.updateMilestones(new List<Project_Milestone__c>{ pm });
        Test.stopTest();

        Project_Milestone__c updatedPm = [
            SELECT Id, Milestone_Name__c, Serial_Number__c
            FROM Project_Milestone__c
            WHERE Id = :pm.Id
        ];

        System.assertEquals(5, updatedPm.Serial_Number__c);
        System.assertEquals('Updated Milestone', updatedPm.Milestone_Name__c);
    }

    @IsTest
    static void testUpdateMilestones_WithInvalidData() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            SerialNumberUpdateController.updateMilestones(null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown when null is passed');
    }
}