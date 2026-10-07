@IsTest
private class HOTOChecklistControllerTest {

    private static Id createProject() {
        Project__c p = new Project__c(Name = 'Test Project');
        insert p;
        return p.Id;
    }

    private static String getAnyStatusValue() {
        List<Map<String, String>> options = HOTOChecklistController.getStatusPicklistValues();
        System.assert(!options.isEmpty(), 'Status1__c must have at least one picklist value in this org.');
        return options[0].get('value');
    }

    private static Id createContentDocumentId() {
        ContentVersion cv = new ContentVersion(
            Title = 'HOTO Test File',
            PathOnClient = 'HOTO_Test_File.txt',
            VersionData = Blob.valueOf('Test file content')
        );
        insert cv;

        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        return cv.ContentDocumentId;
    }

    @IsTest
    static void testGetStatusPicklistValuesAndNullProjectId() {
        List<Map<String, String>> options = HOTOChecklistController.getStatusPicklistValues();
        System.assert(options.size() > 0, 'Expected at least one picklist value.');

        for (Map<String, String> opt : options) {
            System.assertNotEquals(null, opt.get('label'));
            System.assertNotEquals(null, opt.get('value'));
        }

        HOTOChecklistController.InitWrapper wrapper = HOTOChecklistController.getChecklistFields(null, 'cache-bust');
        System.assertEquals(0, wrapper.projectInfo.size());
        System.assertEquals(0, wrapper.rows.size());
        System.assertEquals(false, wrapper.hasMoreRows);
    }

    @IsTest
    static void testSaveNewChecklistGetFieldsAndUpdateExisting() {
        Id projectId = createProject();
        String statusValue = getAnyStatusValue();
        Id docId = createContentDocumentId();

        // 1) Create a brand-new checklist record
        HOTOChecklistController.ChecklistRowDTO row1 = new HOTOChecklistController.ChecklistRowDTO();
        row1.globalIndex = 0;
        row1.checked = true;
        row1.status = statusValue;
        row1.remark = 'Initial remark';
        row1.remarkField = 'Remark1__c';
        row1.statusField = 'Status1__c';
        row1.documentIds = new List<String>{ String.valueOf(docId) };

        Id savedId = HOTOChecklistController.saveChecklistPage(
            projectId,
            new Map<String, String>(),
            new List<HOTOChecklistController.ChecklistRowDTO>{ row1 }
        );

        System.assertNotEquals(null, savedId);

        Project_HOTO_Checklist__c insertedChk = [
            SELECT Id, Project__c, Parent_Project_HOTO_Checklist__c,
                   Approved_Civil_Drawings_GA_Foundation__c, Remark1__c, Status1__c
            FROM Project_HOTO_Checklist__c
            WHERE Id = :savedId
            LIMIT 1
        ];
        System.assertEquals(projectId, insertedChk.Project__c);
        System.assertNotEquals(null, insertedChk.Parent_Project_HOTO_Checklist__c);
        System.assertEquals(true, insertedChk.Approved_Civil_Drawings_GA_Foundation__c);
        System.assertEquals('Initial remark', insertedChk.Remark1__c);
        System.assertEquals(statusValue, insertedChk.Status1__c);

        Integer linkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :savedId
        ];
        System.assertEquals(1, linkCount, 'Expected one ContentDocumentLink to be created.');

        // 2) Read checklist fields after one row is already filled
        HOTOChecklistController.InitWrapper wrapper = HOTOChecklistController.getChecklistFields(projectId, 'cache-bust');
        System.assertEquals(8, wrapper.projectInfo.size());
        System.assertEquals(true, String.isBlank(wrapper.projectInfo.get('clientName')));
        System.assertEquals(true, wrapper.rows.size() > 0);
        System.assertEquals(1, wrapper.rows[0].globalIndex, 'First row should skip the already-filled first checklist item.');
        System.assertEquals(String.valueOf(savedId), wrapper.rows[0].recordId);
        System.assertEquals(false, wrapper.rows[0].checked);
        System.assertEquals('', wrapper.rows[0].status);
        System.assertEquals('', wrapper.rows[0].remark);

        // 3) Update the existing checklist using the latest row returned
        HOTOChecklistController.ChecklistRowDTO updateRow = wrapper.rows[0];
        updateRow.checked = false;
        updateRow.status = statusValue;
        updateRow.remark = 'Updated remark';
        updateRow.documentIds = new List<String>();

        Id updatedId = HOTOChecklistController.saveChecklistPage(
            projectId,
            new Map<String, String>(),
            new List<HOTOChecklistController.ChecklistRowDTO>{ updateRow }
        );

        System.assertEquals(savedId, updatedId, 'Existing checklist should be updated, not replaced.');

        String soql = 'SELECT Id, ' + updateRow.fieldApi + ', ' + updateRow.statusField + ', ' + updateRow.remarkField +
                      ' FROM Project_HOTO_Checklist__c WHERE Id = \'' + String.valueOf(updatedId) + '\' LIMIT 1';
        Project_HOTO_Checklist__c updatedChk = (Project_HOTO_Checklist__c)Database.query(soql);

        System.assertEquals(false, (Boolean)updatedChk.get(updateRow.fieldApi));
        System.assertEquals(statusValue, String.valueOf(updatedChk.get(updateRow.statusField)));
        System.assertEquals('Updated remark', String.valueOf(updatedChk.get(updateRow.remarkField)));
    }

    @IsTest
    static void testSaveChecklistValidationAndExceptionPath() {
        Id projectId = createProject();
        String statusValue = getAnyStatusValue();

        // Null project Id -> wrapped AuraHandledException
        try {
            HOTOChecklistController.saveChecklistPage(
                null,
                new Map<String, String>(),
                new List<HOTOChecklistController.ChecklistRowDTO>()
            );
            System.assert(false, 'Expected an AuraHandledException for null project Id.');
        } catch (AuraHandledException e) {
        }

        // Invalid globalIndex -> catch block coverage
        HOTOChecklistController.ChecklistRowDTO badRow = new HOTOChecklistController.ChecklistRowDTO();
        badRow.globalIndex = 9999; // out of range
        badRow.checked = true;
        badRow.status = statusValue;
        badRow.remark = 'Bad row';
        badRow.remarkField = 'Remark9999__c';
        badRow.statusField = 'Status9999__c';

        try {
            HOTOChecklistController.saveChecklistPage(
                projectId,
                new Map<String, String>(),
                new List<HOTOChecklistController.ChecklistRowDTO>{ badRow }
            );
            System.assert(false, 'Expected an AuraHandledException for invalid globalIndex.');
        } catch (AuraHandledException e) {
        }
    }

    @IsTest
    static void testDeleteOrphanedFiles() {
        // Null / empty input should return safely
        HOTOChecklistController.deleteOrphanedFiles(null);
        HOTOChecklistController.deleteOrphanedFiles(new List<String>());

        // Invalid Id format should be swallowed by the catch block
        HOTOChecklistController.deleteOrphanedFiles(new List<String>{ 'notAnId' });

        // Valid deletion path
        Id docId = createContentDocumentId();
        Integer beforeCount = [
            SELECT COUNT()
            FROM ContentDocument
            WHERE Id = :docId
        ];
        System.assertEquals(1, beforeCount);

        HOTOChecklistController.deleteOrphanedFiles(new List<String>{ String.valueOf(docId) });

        Integer afterCount = [
            SELECT COUNT()
            FROM ContentDocument
            WHERE Id = :docId
        ];
        System.assertEquals(0, afterCount, 'ContentDocument should be deleted.');
    }

}