@IsTest
private class ProjectMilestonePathControllerTest {

    //  Generic record creator (handles required fields)
    private static Id createRecord(Schema.SObjectType type) {
        SObject obj = type.newSObject();
        Map<String, Schema.SObjectField> fields = type.getDescribe().fields.getMap();

        for (String fieldName : fields.keySet()) {
            Schema.DescribeFieldResult d = fields.get(fieldName).getDescribe();

            if (!d.isCreateable() || d.isAutoNumber() || d.isCalculated()) continue;

            if (!d.isNillable()) {
                if (d.getType() == Schema.DisplayType.String) obj.put(fieldName, 'Test');
                else if (d.getType() == Schema.DisplayType.Boolean) obj.put(fieldName, true);
                else if (d.getType() == Schema.DisplayType.Date) obj.put(fieldName, Date.today());
                else if (d.getType() == Schema.DisplayType.DateTime) obj.put(fieldName, System.now());
                else if (d.getType() == Schema.DisplayType.Integer) obj.put(fieldName, 1);
                else if (d.getType() == Schema.DisplayType.Double) obj.put(fieldName, 1);
                else if (d.getType() == Schema.DisplayType.Picklist) {
                    List<Schema.PicklistEntry> vals = d.getPicklistValues();
                    if (!vals.isEmpty()) obj.put(fieldName, vals[0].getValue());
                }
            }
        }

        insert obj;
        return obj.Id;
    }

    //  Create Project dynamically (based on lookup)
    private static Id createProject() {
        Schema.DescribeFieldResult d = Project_Milestone__c.Project_Name__c.getDescribe();
        return createRecord(d.getReferenceTo()[0]);
    }

    //  Create Milestone Master dynamically
    private static Id createMilestoneMaster() {
        Schema.DescribeFieldResult d = Project_Milestone__c.Milestone_Master__c.getDescribe();
        return createRecord(d.getReferenceTo()[0]);
    }

    @IsTest
    static void testAllScenarios() {

        Id projectId = createProject();
        Id masterId = createMilestoneMaster();

        //  Insert records (one current, one not)
        insert new List<Project_Milestone__c>{
            new Project_Milestone__c(
                Project_Name__c = projectId,
                Milestone_Name__c = 'M1',
                Serial_Number__c = 1,
                Milestone_Master__c = masterId,
                Is_Current_Milestone__c = true
            ),
            new Project_Milestone__c(
                Project_Name__c = projectId,
                Milestone_Name__c = 'M2',
                Serial_Number__c = 2,
                Milestone_Master__c = masterId,
                Is_Current_Milestone__c = false
            )
        };

        Test.startTest();

        //  Cover getMilestones
        List<Project_Milestone__c> listData =
            ProjectMilestonePathController.getMilestones(projectId);

        //  Cover IF block
        Project_Milestone__c current =
            ProjectMilestonePathController.getCurrentMilestone(projectId);

        Test.stopTest();

        // Assertions
        System.assertEquals(2, listData.size(), 'Milestones should be returned');
        System.assertNotEquals(null, current, 'Current milestone should exist');
        System.assertEquals(true, current.Is_Current_Milestone__c);

        //  Cover NULL path
        Id newProject = createProject();

        Project_Milestone__c noData =
            ProjectMilestonePathController.getCurrentMilestone(newProject);

        System.assertEquals(null, noData);
    }
}