({
    handleClose : function(component, event, helper) {
        var evt = $A.get("e.force:navigateToObjectHome");
        if (evt) {
            evt.setParams({ scope: "Lead" });
            evt.fire();
            return;
        }
    }
})