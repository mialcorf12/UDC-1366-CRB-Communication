({
    doInit: function (component, event, helper) {
        helper.registerMessageListener(component);
        helper.loadWidgetConfig(component);
    }
})
