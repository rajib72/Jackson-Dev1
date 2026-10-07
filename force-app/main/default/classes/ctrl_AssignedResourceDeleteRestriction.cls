public class ctrl_AssignedResourceDeleteRestriction {

    private Id recordId;

    public ctrl_AssignedResourceDeleteRestriction(ApexPages.StandardController controller) {
       recordId = controller.getId();

        ApexPages.addMessage(
            new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Delete action is not allowed for Assigned Resource records.'
            )
        );
    }

      public PageReference goBack() {
        
        if(recordId != null){
            PageReference pr = new PageReference('/' + recordId);
            pr.setRedirect(true);
            return pr;
        }
        
        PageReference home = new PageReference('/lightning/r/WorkOrder/list');
        home.setRedirect(true);
        return home;
    }
}