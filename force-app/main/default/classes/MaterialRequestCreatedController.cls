public class MaterialRequestCreatedController {
    
    private Id workOrderIdValue;
    private Boolean dataLoaded = false;

    private String caseNumberValue = '';
    private String workOrderNumberValue = '';
    private String productRequestNumberValue = '';
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
                errorMessageValue =
                    'Work Order ID was not received.';
                return;
            }

            /* Get Work Order and Case */
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
                errorMessageValue =
                    'Work Order was not found.';
                return;
            }

            WorkOrder workOrderRecord =
                workOrders[0];

            workOrderNumberValue =
                workOrderRecord.WorkOrderNumber;

            if (workOrderRecord.CaseId != null) {
                caseNumberValue =
                    workOrderRecord.Case.CaseNumber;
            }

            /* Get the latest Product Request */
            List<ProductRequest> productRequests = [
                SELECT Id,
                       ProductRequestNumber,
                       WorkOrderId,
                       CreatedDate
                FROM ProductRequest
                WHERE WorkOrderId = :workOrderIdValue
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (productRequests.isEmpty()) {
                errorMessageValue =
                    'No Product Request was found for this Work Order.';
                return;
            }

            productRequestNumberValue =
                productRequests[0].ProductRequestNumber;

        } catch (Exception ex) {
            errorMessageValue =
                'Unable to load Product Request details: ' +
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

    public String getProductRequestNumber() {
        loadData();
        return productRequestNumberValue;
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