public with sharing class Ctrl_createDiagnosisFromWorkOrder {
    @AuraEnabled(cacheable=true)
    public static WorkOrder getWorkOrderDetails(Id workOrderId) {
        try {
            return [SELECT Id, CaseId FROM WorkOrder WHERE Id = :workOrderId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Work Order: ' + e.getMessage());
        }
    }
}