public without sharing class CustomerProductRequestPDF_Ctrl {
    public Customer_Product_Request__c cprRecord { get; set; }
    public ProductRequest prRecord { get; set; }
    public WorkOrder woRecord { get; set; }

    public List<ProductRequestLineItem> prliList { get; set; }
    public List<LineItemWrapper> lineItemRows { get; set; }
    public List<ResourceInfoWrapper> resourceInfoList { get; set; }
    public List<Service_Cost_Details__c> costDetails { get; set; }

    public String caseNumber { get; set; }
    public String complaintType { get; set; }
    public String accountName { get; set; }
    public String contactName { get; set; }
    public String contactPhone { get; set; }
    public String contactEmail { get; set; }
    public String workOrderNumber { get; set; }

    public String productRequestNumber { get; set; }
    public String needByDateText { get; set; }
    public String finalAmountText { get; set; }
    public String shipToAddressText { get; set; }

    public CustomerProductRequestPDF_Ctrl(ApexPages.StandardController stdController) {
        Id cprId = stdController.getId();

        prliList = new List<ProductRequestLineItem>();
        lineItemRows = new List<LineItemWrapper>();
        resourceInfoList = new List<ResourceInfoWrapper>();
        costDetails = new List<Service_Cost_Details__c>();

        if (cprId == null) {
            return;
        }

        cprRecord = [
            SELECT Id,
                   Product_Request__c,
                   Work_Order__c,
                   Case__c,
                   Customar_Feedback__c,
                   Remarks__c
            FROM Customer_Product_Request__c
            WHERE Id = :cprId
            LIMIT 1
        ];

        Id prId = cprRecord.Product_Request__c;

        if (prId == null && cprRecord.Work_Order__c != null) {
            List<ProductRequest> fallbackPr = [
                SELECT Id
                FROM ProductRequest
                WHERE WorkOrderId = :cprRecord.Work_Order__c
                LIMIT 1
            ];
            if (!fallbackPr.isEmpty()) {
                prId = fallbackPr[0].Id;
            }
        }

        if (prId == null) {
            return;
        }

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

        productRequestNumber = !String.isBlank(prRecord.ProductRequestNumber)
            ? prRecord.ProductRequestNumber
            : prRecord.Id;

        needByDateText = (prRecord.NeedByDate == null) ? null : String.valueOf(prRecord.NeedByDate);
        finalAmountText = (prRecord.Final_Amount_to_be_paid__c == null) ? null : String.valueOf(prRecord.Final_Amount_to_be_paid__c);
        shipToAddressText = buildAddress(
            prRecord.ShipToStreet,
            prRecord.ShipToCity,
            prRecord.ShipToState,
            prRecord.ShipToPostalCode,
            prRecord.ShipToCountry
        );

        Id woId = prRecord.WorkOrderId != null ? prRecord.WorkOrderId : cprRecord.Work_Order__c;

        if (woId != null) {
            woRecord = [
                SELECT Id,
                       WorkOrderNumber,
                       Final_Service_Estimation_Cost__c,
                       CaseId,
                       Case.CaseNumber,
                       Case.Account.Name,
                       Case.Contact.Name,
                       Case.ContactPhone,
                       Case.ContactEmail,
                       Case.Complaint_Type__c
                FROM WorkOrder
                WHERE Id = :woId
                LIMIT 1
            ];

            workOrderNumber = woRecord.WorkOrderNumber;

            Id caseIdToUse = cprRecord.Case__c != null ? cprRecord.Case__c : woRecord.CaseId;

            if (caseIdToUse != null) {
                Case c = [
                    SELECT Id,
                           CaseNumber,
                           Complaint_Type__c,
                           Account.Name,
                           Contact.Name,
                           ContactPhone,
                           ContactEmail
                    FROM Case
                    WHERE Id = :caseIdToUse
                    LIMIT 1
                ];

                caseNumber = c.CaseNumber;
                complaintType = c.Complaint_Type__c;
                accountName = (c.Account != null) ? c.Account.Name : null;
                contactName = (c.Contact != null) ? c.Contact.Name : null;
                contactPhone = c.ContactPhone;
                contactEmail = c.ContactEmail;
            }

            List<ResourcePreference> prefs = [
                SELECT Id,
                       ServiceResource.Name,
                       ServiceResource.ResourceType,
                       ServiceResource.RelatedRecordId
                FROM ResourcePreference
                WHERE RelatedRecordId = :woId
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

            costDetails = [
                SELECT Id, Estimated_Cost__c, Description__c
                FROM Service_Cost_Details__c
                WHERE Work_Order__c = :woId
                ORDER BY CreatedDate ASC
            ];
        }

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

        for (ProductRequestLineItem li : prliList) {
            LineItemWrapper row = new LineItemWrapper();
            row.materialCode = li.Material_Code__c;
            row.materialDescription = li.Material_Description__c;
            row.quantityRequested = (li.QuantityRequested == null) ? null : String.valueOf(li.QuantityRequested);
            row.quantityUom = li.QuantityUnitOfMeasure;
            row.priceText = (li.Price__c == null) ? null : String.valueOf(li.Price__c);
            lineItemRows.add(row);
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