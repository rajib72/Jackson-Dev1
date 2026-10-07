public with sharing class ApprovalHistoryController {
    
    @AuraEnabled(cacheable=true)
    public static List<ApprovalHistoryWrapper> getFullApprovalHistory(Id recordId) {
        List<ApprovalHistoryWrapper> historyList = new List<ApprovalHistoryWrapper>();
        
        // Query the Process Instance and its related Steps/Workitems
        List<ProcessInstance> instances = [
            SELECT Id, 
                   (SELECT Id, StepStatus, OriginalActor.Name, Actor.Name, Comments, SystemModstamp, ProcessNode.Name 
                    FROM StepsAndWorkitems 
                    ORDER BY SystemModstamp DESC)
            FROM ProcessInstance
            WHERE TargetObjectId = :recordId
            ORDER BY CreatedDate DESC
        ];
        
        for (ProcessInstance pi : instances) {
            for (ProcessInstanceHistory history : pi.StepsAndWorkitems) {
                ApprovalHistoryWrapper wrapper = new ApprovalHistoryWrapper();
                wrapper.Id = history.Id;
                
                // Mimic standard Salesforce Step Naming logic
                if (history.StepStatus == 'Started') {
                    wrapper.StepName = 'Approval Request Submitted';
                } else if (history.ProcessNode != null) {
                    wrapper.StepName = history.ProcessNode.Name;
                } else {
                    wrapper.StepName = 'Approval Step'; // Fallback
                }
                
                wrapper.CreatedDate = history.SystemModstamp;
                
                // Standardize Status Text
                wrapper.Status = (history.StepStatus == 'Started') ? 'Submitted' : history.StepStatus;
                
                wrapper.AssignedTo = history.OriginalActor.Name;
                wrapper.ActualApprover = history.Actor.Name;
                wrapper.Comments = history.Comments;
                
                // Flag to determine if row actions (Approve/Reject) should be available
                wrapper.IsPending = (history.StepStatus == 'Pending');
                
                historyList.add(wrapper);
            }
        }
        return historyList;
    }

    @AuraEnabled
    public static void processApprovalAction(Id workItemId, String actionName, String comments) {
        // Pending WorkItems start with '04i'. Historical steps start with '04h'.
        if (String.valueOf(workItemId).startsWith('04i')) {
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setComments(comments == null ? '' : comments);
            req.setAction(actionName); // 'Approve' or 'Reject'
            req.setWorkitemId(workItemId);
            
            Approval.ProcessResult result = Approval.process(req);
            
            if (!result.isSuccess()) {
                throw new AuraHandledException('Error processing approval.');
            }
        } else {
            throw new AuraHandledException('This step has already been processed.');
        }
    }
    
    // Wrapper class to flatten the data for the LWC Datatable
    public class ApprovalHistoryWrapper {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String StepName { get; set; }
        @AuraEnabled public Datetime CreatedDate { get; set; }
        @AuraEnabled public String Status { get; set; }
        @AuraEnabled public String AssignedTo { get; set; }
        @AuraEnabled public String ActualApprover { get; set; }
        @AuraEnabled public String Comments { get; set; }
        @AuraEnabled public Boolean IsPending { get; set; }
    }
}