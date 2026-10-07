public without sharing class ServiceEstimationPDF_Ctrl {
    public Service_Estimation_Feedback__c feedbackRecord { get; set; }
    public WorkOrder woRecord { get; set; }
    public List<WorkOrderLineItem> woliList { get; set; }
    public List<Service_Cost_Details__c> costDetails { get; set; }
    public List<ResourceInfoWrapper> resourceInfoList { get; set; }

    public ServiceEstimationPDF_Ctrl(ApexPages.StandardController stdController) {
        Id feedbackId = stdController.getId();
        resourceInfoList = new List<ResourceInfoWrapper>();

        if (feedbackId == null) return;

        feedbackRecord = [
            SELECT Id, Work_Order__c, Customar_Feedback__c, Remarks__c
            FROM Service_Estimation_Feedback__c
            WHERE Id = :feedbackId
            LIMIT 1
        ];

        if (feedbackRecord.Work_Order__c == null) return;

        Id woId = feedbackRecord.Work_Order__c;

        woRecord = [
            SELECT Id, WorkOrderNumber, Final_Service_Estimation_Cost__c,
                   CaseId, Case.CaseNumber, Case.Account.Name,
                   Case.Contact.Name, Case.ContactPhone, Case.ContactEmail,
                   Case.Complaint_Type__c
            FROM WorkOrder
            WHERE Id = :woId
            LIMIT 1
        ];

        woliList = [
            SELECT Id, Asset.Name, Asset_Serial_No__c
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :woId
        ];

        List<ResourcePreference> prefs = [
            SELECT Id, ServiceResource.Name, ServiceResource.ResourceType,
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
        ];
    }

    public class ResourceInfoWrapper {
        public String resourceName { get; set; }
        public String resourceType { get; set; }
        public String phone { get; set; }
        public String email { get; set; }
    }
}