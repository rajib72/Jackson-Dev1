({
    handleClose : function(component, event, helper) {
        var closeQA = $A.get("e.force:closeQuickAction");
        if (closeQA) {
            closeQA.fire();
        }
    }
})