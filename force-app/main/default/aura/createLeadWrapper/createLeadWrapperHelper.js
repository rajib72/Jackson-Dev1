({
    navigateBackToList: function(component) {
        try {
            var navEvt = $A.get("e.force:navigateToList");
            navEvt.setParams({
                scope: "Lead",
                listViewName: "Recent"
            });
            navEvt.fire();
        } catch (e) {
            try {
                var homeEvt = $A.get("e.force:navigateToObjectHome");
                homeEvt.setParams({ scope: "Lead" });
                homeEvt.fire();
            } catch (e2) {}
        }
    }
})