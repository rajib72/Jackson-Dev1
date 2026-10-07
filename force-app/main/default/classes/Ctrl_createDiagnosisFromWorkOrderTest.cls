@isTest
private class Ctrl_createDiagnosisFromWorkOrderTest {

    @TestSetup
    static void setupData() {

        // Create a test WorkOrder linked to the Case
        WorkOrder testWO = new WorkOrder(
            // CaseId = testCase.Id,
            Subject = 'Test Work Order'
        );
        insert testWO;
    }

    @isTest
    static void testGetWorkOrderDetails_Success() {
        WorkOrder wo = [SELECT Id, CaseId FROM WorkOrder LIMIT 1];

        Test.startTest();

        WorkOrder result = Ctrl_createDiagnosisFromWorkOrder.getWorkOrderDetails(wo.Id);
        Test.stopTest();

    }

    @isTest
    static void testGetWorkOrderDetails_Exception() {
        Id fakeWorkOrderId = '0WO000000000000'; 

        Test.startTest();
        try {
            Ctrl_createDiagnosisFromWorkOrder.getWorkOrderDetails(fakeWorkOrderId);
        } catch (Exception e) {
        }
        Test.stopTest();
    }
}