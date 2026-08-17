({
    handleScriptsLoaded: function (component, event, helper) {
        component.set("v.scriptsLoaded", true);
        helper.mountIfReady(component);
    },

    handleRecordUpdated: function (component, event, helper) {
        var changeType = event.getParams().changeType;
        if (changeType === "LOADED" || changeType === "CHANGED") {
            helper.mountIfReady(component);
        }
    }
})
