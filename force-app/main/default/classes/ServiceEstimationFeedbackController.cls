public without sharing class ServiceEstimationFeedbackController {
    // Data Variables
    public WorkOrder woRecord { get; set; }
    public List<WorkOrderLineItem> woliList { get; set; }
    public List<Service_Cost_Details__c> costDetails { get; set; }
    
    // Wrapper list to hold the completely flattened Resource + User data for the UI
    public List<ResourceInfoWrapper> resourceInfoList { get; set; }
    
    // State Variables for the UI
    public String remarks { get; set; }
    public String feedbackStatus { get; set; }
    public Boolean showRemarksBox { get; set; }
    public Boolean isSuccess { get; set; }
    
    public ServiceEstimationFeedbackController(ApexPages.StandardController stdController) {
        Id woId = stdController.getId();
        showRemarksBox = false;
        isSuccess = false;
        resourceInfoList = new List<ResourceInfoWrapper>();
        
        if (woId != null) {
            // 1. Fetch Work Order & Case Basic Info
            woRecord = [SELECT Id, WorkOrderNumber, Final_Service_Estimation_Cost__c,
                               CaseId, Case.CaseNumber, Case.Account.Name, 
                               Case.Contact.Name, Case.ContactPhone, Case.ContactEmail, 
                               Case.Complaint_Type__c 
                        FROM WorkOrder WHERE Id = :woId LIMIT 1];
            
            // 2. Fetch Work Order Line Items (Item Details)
            woliList = [SELECT Id, Asset.Name, Asset_Serial_No__c 
                        FROM WorkOrderLineItem WHERE WorkOrderId = :woId];
            
            // ==========================================
            // 3. Fetch Assigned Resource Information
            // ==========================================
            List<ResourcePreference> prefs = [SELECT Id, ServiceResource.Name, ServiceResource.ResourceType, 
                                                     ServiceResource.RelatedRecordId 
                                              FROM ResourcePreference 
                                              WHERE RelatedRecordId = :woId];
            
            Set<Id> userIds = new Set<Id>();
            for(ResourcePreference rp : prefs) {
                if(rp.ServiceResource != null && rp.ServiceResource.RelatedRecordId != null) {
                    userIds.add(rp.ServiceResource.RelatedRecordId);
                }
            }
            
            Map<Id, User> userMap = new Map<Id, User>();
            if(!userIds.isEmpty()){
                userMap = new Map<Id, User>([SELECT Id, MobilePhone, Email FROM User WHERE Id IN :userIds]);
            }
            
            for(ResourcePreference rp : prefs) {
                ResourceInfoWrapper wrapper = new ResourceInfoWrapper();
                if(rp.ServiceResource != null) {
                    wrapper.resourceName = rp.ServiceResource.Name;
                    wrapper.resourceType = rp.ServiceResource.ResourceType;
                    
                    if(rp.ServiceResource.RelatedRecordId != null && userMap.containsKey(rp.ServiceResource.RelatedRecordId)){
                        wrapper.phone = userMap.get(rp.ServiceResource.RelatedRecordId).MobilePhone;
                        wrapper.email = userMap.get(rp.ServiceResource.RelatedRecordId).Email;
                    }
                }
                resourceInfoList.add(wrapper);
            }
            // ==========================================
                             
            // 4. Fetch Cost Details
            costDetails = [SELECT Id, Estimated_Cost__c, Description__c 
                           FROM Service_Cost_Details__c WHERE Work_Order__c = :woId];
        }
    }
    
    // Action Methods for the Buttons
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
    
    // Save the Record
    public PageReference saveFeedback() {
        // --- NEW VALIDATION CHECK: Makes Remarks Mandatory ---
        if (String.isBlank(remarks)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please provide your remarks before submitting.'));
            return null; 
        }
        // ---------------------------------------------------

        try {
            Service_Estimation_Feedback__c feedback = new Service_Estimation_Feedback__c();
            feedback.Work_Order__c = woRecord.Id;
            feedback.Case__c = woRecord.CaseId;
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

    // ==========================================
    // WRAPPER CLASS to handle Polymorphic Data
    // ==========================================
    public class ResourceInfoWrapper {
        public String resourceName { get; set; }
        public String resourceType { get; set; }
        public String phone { get; set; }
        public String email { get; set; }
    }
}