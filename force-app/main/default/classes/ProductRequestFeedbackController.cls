public without sharing class ProductRequestFeedbackController {
    public ProductRequest prRecord { get; set; }
    public WorkOrder woRecord { get; set; }

    public List<ProductRequestLineItem> prliList { get; set; }
    public List<LineItemWrapper> lineItemRows { get; set; }
    public List<ResourceInfoWrapper> resourceInfoList { get; set; }

    public String remarks { get; set; }
    public String feedbackStatus { get; set; }
    public Boolean showRemarksBox { get; set; }
    public Boolean isSuccess { get; set; }

    // Section 1 and 2
    public String caseNumber { get; set; }
    public String complaintType { get; set; }
    public String accountName { get; set; }
    public String contactName { get; set; }
    public String contactPhone { get; set; }
    public String contactEmail { get; set; }
    public String workOrderNumber { get; set; }

    // Section 3
    public String productRequestNumber { get; set; }
    public String needByDateText { get; set; }
    public String finalAmountText { get; set; }
    public String shipToAddressText { get; set; }

    public ProductRequestFeedbackController(ApexPages.StandardController stdController) {
        Id prId = stdController.getId();

        showRemarksBox = false;
        isSuccess = false;
        resourceInfoList = new List<ResourceInfoWrapper>();
        prliList = new List<ProductRequestLineItem>();
        lineItemRows = new List<LineItemWrapper>();

        if (prId == null) {
            System.debug('ProductRequest Id is null');
            return;
        }

        System.debug('Loading ProductRequest Id = ' + prId);

        prRecord = [
            SELECT Id,
                   ProductRequestNumber,
                   NeedByDate,
                   ShipToStreet,
                   ShipToCity,
                   ShipToState,
                   ShipToPostalCode,
                   ShipToCountry,
                   Final_Amount_to_be_paid__c,
                   WorkOrderId
            FROM ProductRequest
            WHERE Id = :prId
            LIMIT 1
        ];

        System.debug('ProductRequest = ' + JSON.serializePretty(prRecord));

        productRequestNumber = !String.isBlank(prRecord.ProductRequestNumber)
            ? prRecord.ProductRequestNumber
            : prRecord.Id;

        needByDateText = (prRecord.NeedByDate == null)
            ? null
            : String.valueOf(prRecord.NeedByDate);

        finalAmountText = (prRecord.Final_Amount_to_be_paid__c == null)
            ? null
            : String.valueOf(prRecord.Final_Amount_to_be_paid__c);

        shipToAddressText = buildAddress(
            prRecord.ShipToStreet,
            prRecord.ShipToCity,
            prRecord.ShipToState,
            prRecord.ShipToPostalCode,
            prRecord.ShipToCountry
        );

        if (prRecord.WorkOrderId != null) {
            woRecord = [
                SELECT Id,
                       WorkOrderNumber,
                       CaseId,
                       Case.CaseNumber,
                       Case.Complaint_Type__c,
                       Case.Account.Name,
                       Case.Contact.Name,
                       Case.ContactPhone,
                       Case.ContactEmail
                FROM WorkOrder
                WHERE Id = :prRecord.WorkOrderId
                LIMIT 1
            ];

            System.debug('WorkOrder = ' + JSON.serializePretty(woRecord));

            workOrderNumber = woRecord.WorkOrderNumber;

            if (woRecord.CaseId != null) {
                Case c = [
                    SELECT Id,
                           CaseNumber,
                           Complaint_Type__c,
                           Account.Name,
                           Contact.Name,
                           ContactPhone,
                           ContactEmail
                    FROM Case
                    WHERE Id = :woRecord.CaseId
                    LIMIT 1
                ];

                System.debug('Case = ' + JSON.serializePretty(c));

                caseNumber = c.CaseNumber;
                complaintType = c.Complaint_Type__c;
                accountName = (c.Account != null) ? c.Account.Name : null;
                contactName = (c.Contact != null) ? c.Contact.Name : null;
                contactPhone = c.ContactPhone;
                contactEmail = c.ContactEmail;
            }
        }

        // Keep the parent lookup exactly as your org is using it
        prliList = [
            SELECT Id,
                   Material_Code__c,
                   Material_Description__c,
                   QuantityRequested,
                   QuantityUnitOfMeasure,
                   Price__c
            FROM ProductRequestLineItem
            WHERE ParentId = :prId
            ORDER BY CreatedDate ASC
        ];

        System.debug('ProductRequestLineItem count = ' + prliList.size());

        for (ProductRequestLineItem li : prliList) {
            System.debug('--- LINE ITEM ---');
            System.debug('Id: ' + li.Id);
            System.debug('Material Code: ' + li.Material_Code__c);
            System.debug('Description: ' + li.Material_Description__c);
            System.debug('Quantity: ' + li.QuantityRequested);
            System.debug('UOM: ' + li.QuantityUnitOfMeasure);
            System.debug('Price: ' + li.Price__c);

            LineItemWrapper row = new LineItemWrapper();
            row.materialCode = li.Material_Code__c;
            row.materialDescription = li.Material_Description__c;
            row.quantityRequested = (li.QuantityRequested == null) ? null : String.valueOf(li.QuantityRequested);
            row.quantityUom = li.QuantityUnitOfMeasure;
            row.priceText = (li.Price__c == null) ? null : String.valueOf(li.Price__c);

            lineItemRows.add(row);
        }

        if (prRecord.WorkOrderId != null) {
            List<ResourcePreference> prefs = [
                SELECT Id,
                       ServiceResource.Name,
                       ServiceResource.ResourceType,
                       ServiceResource.RelatedRecordId
                FROM ResourcePreference
                WHERE RelatedRecordId = :prRecord.WorkOrderId
            ];

            Set<Id> userIds = new Set<Id>();
            for (ResourcePreference rp : prefs) {
                if (rp.ServiceResource != null && rp.ServiceResource.RelatedRecordId != null) {
                    userIds.add(rp.ServiceResource.RelatedRecordId);
                }
            }

            Map<Id, User> userMap = new Map<Id, User>();
            if (!userIds.isEmpty()) {
                userMap = new Map<Id, User>([
                    SELECT Id, MobilePhone, Email
                    FROM User
                    WHERE Id IN :userIds
                ]);
            }

            for (ResourcePreference rp : prefs) {
                ResourceInfoWrapper wrapper = new ResourceInfoWrapper();
                if (rp.ServiceResource != null) {
                    wrapper.resourceName = rp.ServiceResource.Name;
                    wrapper.resourceType = rp.ServiceResource.ResourceType;

                    if (rp.ServiceResource.RelatedRecordId != null &&
                        userMap.containsKey(rp.ServiceResource.RelatedRecordId)) {
                        wrapper.phone = userMap.get(rp.ServiceResource.RelatedRecordId).MobilePhone;
                        wrapper.email = userMap.get(rp.ServiceResource.RelatedRecordId).Email;
                    }
                }
                resourceInfoList.add(wrapper);
            }
        }
    }

    public PageReference selectApprove() {
        feedbackStatus = 'Approved';
        showRemarksBox = true;
        return null;
    }

    public PageReference selectReject() {
        feedbackStatus = 'Rejected';
        showRemarksBox = true;
        return null;
    }

    public PageReference saveFeedback() {
        if (String.isBlank(remarks)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Please provide your remarks before submitting.'
            ));
            return null;
        }

        try {
            Customer_Product_Request__c feedback = new Customer_Product_Request__c();
            feedback.Product_Request__c = prRecord.Id;
            feedback.Work_Order__c = prRecord.WorkOrderId;
            feedback.Case__c = (woRecord != null) ? woRecord.CaseId : null;
            feedback.Customar_Feedback__c = feedbackStatus;
            feedback.Remarks__c = remarks;

            insert feedback;

            isSuccess = true;
            showRemarksBox = false;
            return null;
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }

    private static String buildAddress(String street, String city, String state, String postalCode, String country) {
        List<String> parts = new List<String>();

        if (!String.isBlank(street)) parts.add(street);

        List<String> cityParts = new List<String>();
        if (!String.isBlank(city)) cityParts.add(city);
        if (!String.isBlank(state)) cityParts.add(state);
        if (!String.isBlank(postalCode)) cityParts.add(postalCode);
        if (!cityParts.isEmpty()) parts.add(String.join(cityParts, ' '));

        if (!String.isBlank(country)) parts.add(country);

        return parts.isEmpty() ? null : String.join(parts, ', ');
    }

    public class LineItemWrapper {
        public String materialCode { get; set; }
        public String materialDescription { get; set; }
        public String quantityRequested { get; set; }
        public String quantityUom { get; set; }
        public String priceText { get; set; }
    }

    public class ResourceInfoWrapper {
        public String resourceName { get; set; }
        public String resourceType { get; set; }
        public String phone { get; set; }
        public String email { get; set; }
    }
}