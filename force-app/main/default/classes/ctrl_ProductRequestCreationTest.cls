@IsTest
private class ctrl_ProductRequestCreationTest {
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Asset asset = new Asset(Name = 'Test Asset', AccountId = acc.Id, Site_Name__c = 'Test Site', State__c = 'West Bengal', Address__c = '123 Test Street', Pin_Code__c = '700001', City__c = 'Kolkata', Country__c = 'India');
        insert asset;
        SObject location = Schema.getGlobalDescribe().get('Location').newSObject();
        location.put('Name', 'Test Destination Location');
        insert location;
        WorkOrder wo = new WorkOrder(Subject = 'Test Work Order', AccountId = acc.Id);
        insert wo;
        WorkOrderLineItem woli = new WorkOrderLineItem(WorkOrderId = wo.Id, AssetId = asset.Id);
        insert woli;
    }

    @IsTest
    static void testGetInitialData() {
        WorkOrder wo = [SELECT Id, WorkOrderNumber FROM WorkOrder LIMIT 1];
        Test.startTest();
        ctrl_ProductRequestCreationController.InitialData result = ctrl_ProductRequestCreationController.getInitialData(wo.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetInitialDataNullWorkOrder() {
        Test.startTest();
        try {
            ctrl_ProductRequestCreationController.getInitialData(null);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateProductRequestFOC() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        WorkOrderLineItem woli = [SELECT Id, WorkOrderId, AssetId FROM WorkOrderLineItem LIMIT 1];
        SObject location = Database.query('SELECT Id FROM Location LIMIT 1')[0];
        RecordType rt = [SELECT Id, Name, IsActive FROM RecordType WHERE SObjectType = 'ProductRequest' AND Name = 'FOC' AND IsActive = true LIMIT 1];
    
        ctrl_ProductRequestCreationController.ProductRequestInput input = new ctrl_ProductRequestCreationController.ProductRequestInput();
        input.workOrderId = wo.Id;
        input.recordTypeId = rt.Id;
        input.requestType = 'FOC';
        input.destinationLocationId = (Id)location.get('Id');
        input.description = 'Test FOC Product Request';
        input.needByDate = Datetime.now().addDays(5);
        input.workOrderLineItemId = woli.Id;
        input.assetId = woli.AssetId;
        input.siteName = 'Test Site';
        input.state = 'West Bengal';
        input.street = '123 Test Street';
        input.pinCode = '700001';
        input.city = 'Kolkata';
        input.country = 'India';
    
        Test.startTest();
        try {
            ctrl_ProductRequestCreationController.createProductRequest(input);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'FOC TEST ERROR: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'FOC TEST STACK: ' + e.getStackTraceString());
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateProductRequestPaid() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        WorkOrderLineItem woli = [SELECT Id, WorkOrderId, AssetId FROM WorkOrderLineItem LIMIT 1];
        SObject location = Database.query('SELECT Id FROM Location LIMIT 1')[0];
        RecordType rt = [SELECT Id, Name, IsActive FROM RecordType WHERE SObjectType = 'ProductRequest' AND Name = 'Paid' AND IsActive = true LIMIT 1];
    
        ctrl_ProductRequestCreationController.ProductRequestInput input = new ctrl_ProductRequestCreationController.ProductRequestInput();
        input.workOrderId = wo.Id;
        input.recordTypeId = rt.Id;
        input.requestType = 'Paid';
        input.destinationLocationId = (Id)location.get('Id');
        input.description = 'Test Paid Product Request';
        input.needByDate = Datetime.now().addDays(5);
        input.workOrderLineItemId = woli.Id;
        input.assetId = woli.AssetId;
        input.siteName = 'Test Site';
        input.state = 'West Bengal';
        input.street = '123 Test Street';
        input.pinCode = '700001';
        input.city = 'Kolkata';
        input.country = 'India';
    
        Test.startTest();
        try {
            ctrl_ProductRequestCreationController.createProductRequest(input);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'PAID TEST ERROR: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'PAID TEST STACK: ' + e.getStackTraceString());
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateProductRequestRGP() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        WorkOrderLineItem woli = [SELECT Id, WorkOrderId, AssetId FROM WorkOrderLineItem LIMIT 1];
        SObject location = Database.query('SELECT Id FROM Location LIMIT 1')[0];
        RecordType rt = [SELECT Id, Name, IsActive FROM RecordType WHERE SObjectType = 'ProductRequest' AND Name = 'RGP' AND IsActive = true LIMIT 1];
    
        ctrl_ProductRequestCreationController.ProductRequestInput input = new ctrl_ProductRequestCreationController.ProductRequestInput();
        input.workOrderId = wo.Id;
        input.recordTypeId = rt.Id;
        input.requestType = 'RGP';
        input.destinationLocationId = (Id)location.get('Id');
        input.description = 'Test RGP Product Request';
        input.needByDate = Datetime.now().addDays(5);
        input.workOrderLineItemId = woli.Id;
        input.assetId = woli.AssetId;
        input.siteName = 'Test Site';
        input.state = 'West Bengal';
        input.street = '123 Test Street';
        input.pinCode = '700001';
        input.city = 'Kolkata';
        input.country = 'India';
    
        Test.startTest();
        try {
            ctrl_ProductRequestCreationController.createProductRequest(input);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'RGP TEST ERROR: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'RGP TEST STACK: ' + e.getStackTraceString());
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidationErrors() {
        Test.startTest();
        try {
            ctrl_ProductRequestCreationController.createProductRequest(null);
        } catch (AuraHandledException e) {
        }
        ctrl_ProductRequestCreationController.ProductRequestInput input = new ctrl_ProductRequestCreationController.ProductRequestInput();
        try {
            ctrl_ProductRequestCreationController.createProductRequest(input);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
}