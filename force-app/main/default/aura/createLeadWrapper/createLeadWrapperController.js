({
    doInit: function(component, event, helper) {
        if (component.get("v.hasOpened")) return;
        component.set("v.hasOpened", true);

        $A.createComponent(
            "c:createNewLeadComponent",
            { onclose: component.getReference("c.closeAction") },
            function(content, status) {
                if (status === "SUCCESS") {
                    component.find("overlayLib").showCustomModal({
                        body: content,
                        showCloseButton: true,
                        cssClass: "slds-fade-in-open slds-modal_medium",
                        closeCallback: $A.getCallback(function () {
                            if (component.get("v.isClosing")) return;
                            helper.navigateBackToList(component);
                        })
                    });
                }
            }
        );
    },

    closeAction: function(component, event, helper) {
        component.set("v.isClosing", true);

        try {
            component.find("overlayLib").notifyClose();
        } catch (e) {}

        helper.navigateBackToList(component);

        try { $A.get("e.force:closeQuickAction").fire(); } catch (e) {}
        window.setTimeout($A.getCallback(function(){
            try { $A.get("e.force:refreshView").fire(); } catch (e) {}
        }), 0);
    }
})