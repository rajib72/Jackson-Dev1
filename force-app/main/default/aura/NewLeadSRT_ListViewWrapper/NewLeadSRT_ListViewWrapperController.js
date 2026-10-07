({
    doInit: function (component, event, helper) {
        helper.showModal(component, event, helper);
    },

    // Add this handler to your Aura Component (see HTML section below)
    reInit: function (component, event, helper) {
        // Reset the flags so the modal can open again
        component.set("v.hasOpened", false);
        component.set("v.isClosing", false);
        helper.showModal(component, event, helper);
    },

    closeAction: function (component, event, helper) {
        component.set("v.isClosing", true);
        try {
            component.find("overlayLib").notifyClose();
        } catch (e) {}
        
        helper.navigateBackToList(component);
    }
});