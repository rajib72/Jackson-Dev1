public without sharing class MaterialDispatchedEmailController {

    public Id workOrderId { get; set; }

    private Boolean dataLoaded = false;

    private String caseNumberValue = '';
    private String workOrderNumberValue = '';
    private String productRequestNumberValue = '';

    private Datetime dispatchDateValue;
    private String materialDetailsValue = '';
    private Decimal materialQuantityValue = 0;
    private Datetime expectedDeliveryDateValue;

    private String courierNameValue =
        'Not Available';

    private String trackingNumberValue =
        'Not Available';

    private String errorMessageValue = '';

    private void loadData() {

        if (dataLoaded) {
            return;
        }

        dataLoaded = true;

        try {
            if (workOrderId == null) {
                errorMessageValue =
                    'Work Order ID was not received.';
                return;
            }

            /* Fetch Work Order and Case */
            List<WorkOrder> workOrders = [
                SELECT Id,
                       WorkOrderNumber,
                       CaseId,
                       Case.CaseNumber
                FROM WorkOrder
                WHERE Id = :workOrderId
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

            /*
             * Fetch Product Request Line Items directly
             * using WorkOrderId.
             */
            List<ProductRequestLineItem> requestItems = [
                SELECT Id,
                       ProductRequestLineItemNumber,
                       ParentId,
                       Parent.ProductRequestNumber,
                       WorkOrderId,
                       Product2Id,
                       Product2.Name,
                       Description,
                       QuantityRequested,
                       NeedByDate,
                       CreatedDate
                FROM ProductRequestLineItem
                WHERE WorkOrderId = :workOrderId
                ORDER BY CreatedDate DESC
            ];

            if (requestItems.isEmpty()) {
                errorMessageValue =
                    'No Product Request Line Items were found ' +
                    'for this Work Order.';
                return;
            }

            List<String> materialLines =
                new List<String>();

            Decimal totalQuantity = 0;

            for (
                ProductRequestLineItem requestItem :
                requestItems
            ) {
                String productName;

                if (
                    requestItem.Product2Id != null &&
                    requestItem.Product2 != null
                ) {
                    productName =
                        requestItem.Product2.Name;
                } else {
                    productName =
                        requestItem.Description;
                }

                Decimal quantity =
                    requestItem.QuantityRequested == null
                    ? 0
                    : requestItem.QuantityRequested;

                if (String.isNotBlank(productName)) {
                    materialLines.add(
                        productName +
                        ' - Qty: ' +
                        String.valueOf(quantity)
                    );
                }

                totalQuantity += quantity;

                /*
                 * Use the latest line item's parent
                 * Product Request number.
                 */
                if (
                    String.isBlank(
                        productRequestNumberValue
                    ) &&
                    requestItem.Parent != null
                ) {
                    productRequestNumberValue =
                        requestItem.Parent
                            .ProductRequestNumber;
                }

                /*
                 * Latest line-item creation date is
                 * temporarily treated as Dispatch Date.
                 */
                if (dispatchDateValue == null) {
                    dispatchDateValue =
                        requestItem.CreatedDate;
                }

                /*
                 * Use latest available Need By Date as
                 * Expected Delivery Date.
                 */
                if (
                    expectedDeliveryDateValue == null &&
                    requestItem.NeedByDate != null
                ) {
                    expectedDeliveryDateValue =
                        requestItem.NeedByDate;
                }
            }

            materialDetailsValue =
                materialLines.isEmpty()
                ? 'Not Available'
                : String.join(materialLines, ', ');

            materialQuantityValue =
                totalQuantity;

            if (
                String.isBlank(
                    productRequestNumberValue
                )
            ) {
                productRequestNumberValue =
                    'Not Available';
            }

        } catch (Exception ex) {
            errorMessageValue =
                'Unable to load material dispatch details: ' +
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

    public Datetime getDispatchDate() {
        loadData();
        return dispatchDateValue;
    }

    public String getMaterialDetails() {
        loadData();
        return materialDetailsValue;
    }

    public Decimal getMaterialQuantity() {
        loadData();
        return materialQuantityValue;
    }

    public String getCourierName() {
        loadData();
        return courierNameValue;
    }

    public String getTrackingNumber() {
        loadData();
        return trackingNumberValue;
    }

    public Datetime getExpectedDeliveryDate() {
        loadData();
        return expectedDeliveryDateValue;
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