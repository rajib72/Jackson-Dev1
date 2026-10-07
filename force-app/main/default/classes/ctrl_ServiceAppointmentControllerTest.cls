@isTest
private class ctrl_ServiceAppointmentControllerTest {

    @testSetup
    static void setupTestData() {
        // 1. Create Account
        Account testAccount = new Account(Name = 'Test Account for SA');
        insert testAccount;

        // 2. Create Operating Hours (Required for Service Territory)
        OperatingHours oh = new OperatingHours(
            Name = 'Standard Hours',
            TimeZone = 'America/Los_Angeles'
        );
        insert oh;

        // 3. Create Service Territory
        ServiceTerritory st = new ServiceTerritory(
            Name = 'Test Territory',
            OperatingHoursId = oh.Id,
            IsActive = true
        );
        insert st;

        // 4. Create Work Type (Requires Duration fields)
        WorkType wt = new WorkType(
            Name = 'Test Work Type',
            EstimatedDuration = 2,
            DurationType = 'Hours'
        );
        insert wt;

        // 5. Create Work Order
        WorkOrder wo = new WorkOrder(
            AccountId = testAccount.Id,
            ServiceTerritoryId = st.Id,
            WorkTypeId = wt.Id,
            Subject = 'Test Work Order Subject',
            Street = '123 Setup St',
            PostalCode = '12345'
        );
        insert wo;
    }

    @isTest
    static void testGetWorkOrderDefaults_Success() {
        WorkOrder wo = [SELECT Id, WorkOrderNumber FROM WorkOrder LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];

        Test.startTest();
        ctrl_ServiceAppointmentController.WorkOrderDefaults result = ctrl_ServiceAppointmentController.getWorkOrderDefaults(wo.Id);
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, result, 'WorkOrderDefaults should not be null');
        System.assertEquals(wo.Id, result.workOrderId, 'WorkOrderId should match');
        System.assertEquals(wo.WorkOrderNumber, result.workOrderNumber, 'WorkOrderNumber should match');
        System.assertEquals('Test Work Order Subject', result.subject, 'Subject should match');
        System.assertEquals(acc.Id, result.accountId, 'AccountId should match');
        System.assertEquals(acc.Name, result.accountName, 'Account Name should match');
        System.assertEquals('123 Setup St', result.street, 'Street should match');
    }

    @isTest
    static void testGetWorkOrderDefaults_NullIdException() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            ctrl_ServiceAppointmentController.getWorkOrderDefaults(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assertEquals('Script-thrown exception', e.getMessage(), 'AuraHandledException message wrapper check');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown for null WorkOrderId');
    }

    @isTest
    static void testSearchAccounts_Success() {
        Test.startTest();
        List<ctrl_ServiceAppointmentController.LookupOption> results = ctrl_ServiceAppointmentController.searchAccounts('Test Account');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results list should not be null');
        System.assertEquals(1, results.size(), 'Should find exactly 1 matching account');
        System.assertEquals('Test Account for SA', results[0].name, 'Account name should match');
    }

    @isTest
    static void testCreateServiceAppointment_Success() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        ServiceTerritory st = [SELECT Id FROM ServiceTerritory LIMIT 1];
        WorkType wt = [SELECT Id FROM WorkType LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // Build the request payload
        ctrl_ServiceAppointmentController.SaveRequest req = new ctrl_ServiceAppointmentController.SaveRequest();
        req.workOrderId = wo.Id;
        req.subject = 'New SA Subject';
        req.status = 'None';
        req.serviceTerritoryId = st.Id;
        req.workTypeId = wt.Id;
        req.shipToAccountId = acc.Id;
        req.siteName = 'Test Site';
        req.street = '456 Appt St';
        req.postalCode = '67890';
        req.description = 'Test Description';

        Test.startTest();
        Id saId = ctrl_ServiceAppointmentController.createServiceAppointment(req);
        Test.stopTest();

        System.assertNotEquals(null, saId, 'Service Appointment Id should be returned');

        // Verify the insert in the database
        ServiceAppointment insertedSa = [
            SELECT ParentRecordId, Subject, Status, Street, Description 
            FROM ServiceAppointment 
            WHERE Id = :saId
        ];
        
        System.assertEquals(wo.Id, insertedSa.ParentRecordId, 'Parent Work Order should be linked properly');
        System.assertEquals('New SA Subject', insertedSa.Subject, 'Subject should match');
        System.assertEquals('456 Appt St', insertedSa.Street, 'Street should match');
    }

    @isTest
    static void testCreateServiceAppointment_MissingReqException() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            // Passing null directly
            ctrl_ServiceAppointmentController.createServiceAppointment(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown for a null request');
    }

    @isTest
    static void testCreateServiceAppointment_DmlException() {
        // Build an invalid request payload to force a DML exception (invalid ParentId)
        ctrl_ServiceAppointmentController.SaveRequest req = new ctrl_ServiceAppointmentController.SaveRequest();
        req.workOrderId = '000000000000000AAA'; // Fake / Invalid ID to cause insertion failure
        req.subject = 'Failed SA';

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ctrl_ServiceAppointmentController.createServiceAppointment(req);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown due to a DML error on bad ID');
    }
}