({
    handleClose: function(component, event, helper) {
        var navEvent = $A.get("e.force:navigateToObjectHome");
        navEvent.setParams({ "scope": "Project__c" });
        navEvent.fire();
    }
})