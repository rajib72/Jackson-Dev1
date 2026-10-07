public without sharing class CaseClosedEmailController {

    public Id caseId { get; set; }

    private Boolean dataLoaded = false;
    private String resolutionTypeValue = '';
    private String feedbackFormLinkValue = '';
    private String errorMessageValue = '';

    private void loadData() {

        if (dataLoaded) {
            return;
        }

        dataLoaded = true;

        try {
            if (caseId == null) {
                errorMessageValue =
                    'Case ID was not received.';
                return;
            }

            /* Confirm Case exists */
            List<Case> caseRecords = [
                SELECT Id,
                       CaseNumber,
                       CreatedDate,
                       Resolved_Target_Date__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            if (caseRecords.isEmpty()) {
                errorMessageValue =
                    'Case was not found.';
                return;
            }

            /* Fetch latest Work Order */
            List<WorkOrder> workOrders = [
                SELECT Id,
                       WorkOrderNumber,
                       CaseId
                FROM WorkOrder
                WHERE CaseId = :caseId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (!workOrders.isEmpty()) {

                Id workOrderId =
                    workOrders[0].Id;

                /* Fetch latest Solar CAPA */
                List<Solar_CAPA__c> capaRecords = [
                    SELECT Id,
                           Work_Order__c,
                           D3_Containment_Action__c,
                           CreatedDate
                    FROM Solar_CAPA__c
                    WHERE Work_Order__c = :workOrderId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];

                if (!capaRecords.isEmpty()) {
                    resolutionTypeValue =
                        capaRecords[0].D3_Containment_Action__c;
                }
            }

            /* Fetch latest Feedback Form */
            List<Feedback_Form__c> feedbackRecords = [
                SELECT Id,
                       Name,
                       Case__c,
                       CreatedDate
                FROM Feedback_Form__c
                WHERE Case__c = :caseId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (!feedbackRecords.isEmpty()) {

                Id feedbackFormId =
                    feedbackRecords[0].Id;

                feedbackFormLinkValue =
    URL.getOrgDomainUrl().toExternalForm() +
    '/lightning/cmp/c__feedbackForm' +
    '?c__caseId=' +
    EncodingUtil.urlEncode(
        String.valueOf(caseId),
        'UTF-8'
    );
            } else {
                errorMessageValue =
                    'No Feedback Form was found for this Case.';
            }

        } catch (Exception ex) {
            errorMessageValue =
                'Unable to load Case closure details: ' +
                ex.getMessage();
        }
    }

    public String getResolutionType() {
        loadData();
        return resolutionTypeValue;
    }

    public String getFeedbackFormLink() {
        loadData();
        return feedbackFormLinkValue;
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