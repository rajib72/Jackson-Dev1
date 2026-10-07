({
    showModal: function (component, event, helper) {
        if (component.get("v.hasOpened")) {
            return;
        }
        component.set("v.hasOpened", true);

        $A.createComponent(
            "c:createNewLeadSRTComponent",
            {
                onclose: component.getReference("c.closeAction"),
                recordIds: component.get("v.recordIds")
            },
            function (content, status, errorMessage) {
                if (status === "SUCCESS") {
                    component.find("overlayLib").showCustomModal({
                        body: content,
                        showCloseButton: true,
                        cssClass: "slds-modal_medium",
                        closeCallback: $A.getCallback(function () {
                            if (component.get("v.isClosing")) {
                                return;
                            }
                            component.set("v.isClosing", true);
                            helper.navigateBackToList(component);
                        })
                    });
                } else {
                    console.error("Error: " + errorMessage);
                }
            }
        );
    },

    navigateBackToList: function (component) {
        // Your existing navigation logic remains the same
        var navEvt = $A.get("e.force:navigateToList");
        if (navEvt) {
            navEvt.setParams({ scope: "Lead", listViewName: "Recent" });
            navEvt.fire();
        }
    }
});