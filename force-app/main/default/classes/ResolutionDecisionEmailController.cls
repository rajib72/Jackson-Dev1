public class ResolutionDecisionEmailController {
    
     private Id workOrderIdValue;
    private Boolean dataLoaded = false;

    private String caseNumberValue = '';
    private String workOrderNumberValue = '';
    private Date decisionDateValue;
    private String containmentActionValue = '';
    private String errorMessageValue = '';

    public Id getWorkOrderId() {
        return workOrderIdValue;
    }

    public void setWorkOrderId(Id value) {
        workOrderIdValue = value;
        dataLoaded = false;
    }

    private void loadData() {

        if (dataLoaded) {
            return;
        }

        dataLoaded = true;

        try {
            if (workOrderIdValue == null) {
                errorMessageValue = 'Work Order ID was not received.';
                return;
            }

            List<WorkOrder> workOrders = [
                SELECT Id,
                       WorkOrderNumber,
                       CaseId,
                       Case.CaseNumber
                FROM WorkOrder
                WHERE Id = :workOrderIdValue
                LIMIT 1
            ];

            if (workOrders.isEmpty()) {
                errorMessageValue = 'Work Order was not found.';
                return;
            }

            WorkOrder workOrderRecord = workOrders[0];

            workOrderNumberValue =
                workOrderRecord.WorkOrderNumber;

            if (workOrderRecord.CaseId != null) {
                caseNumberValue =
                    workOrderRecord.Case.CaseNumber;
            }

            List<Solar_CAPA__c> capaRecords = [
                SELECT Id,
                       Work_Order__c,
                       D3_Containment_Action__c,
                       Date_Detected__c,
                       CreatedDate
                FROM Solar_CAPA__c
                WHERE Work_Order__c = :workOrderIdValue
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (capaRecords.isEmpty()) {
                errorMessageValue =
                    'No Solar CAPA record was found for this Work Order.';
                return;
            }

            Solar_CAPA__c capaRecord =
                capaRecords[0];

            containmentActionValue =
                capaRecord.D3_Containment_Action__c;

            decisionDateValue =
                capaRecord.Date_Detected__c;

        } catch (Exception ex) {
            errorMessageValue =
                'Unable to load resolution details: ' +
                ex.getMessage();
        }
    }

    public String getCaseNumber() {
        loadData();
        return caseNumberValue;
    }

    public String getWorkOrderNumber() {
        loadData();
        return workOrderNumberValue;
    }

    public Date getDecisionDate() {
        loadData();
        return decisionDateValue;
    }

    public String getContainmentAction() {
        loadData();
        return containmentActionValue;
    }

    public String getErrorMessage() {
        loadData();
        return errorMessageValue;
    }

    public Boolean getHasError() {
        loadData();
        return String.isNotBlank(errorMessageValue);
    }
}