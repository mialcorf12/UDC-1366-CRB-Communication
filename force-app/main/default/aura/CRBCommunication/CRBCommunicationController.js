({
    submit: function (component, event, helper) {
        helper.refresh(component);
    },

    startModification: function (component, event, helper) {
        var row = event.getSource().get("v.value") || {};
        component.set("v.selectedPlanName", row.title);
        component.set("v.selectedMessageId", row.id);
        component.set("v.isSubmitModification", false);
        component.set("v.inputValue", "");
        helper.updateComposerDisabled(component);
    },

    startReply: function (component, event, helper) {
        var row = event.getSource().get("v.value") || {};
        component.set("v.selectedPlanName", row.title);
        component.set("v.selectedMessageId", row.id);
        component.set("v.isSubmitReply", false);
        component.set("v.inputValue", "");
        helper.updateComposerDisabled(component);
    },

    send: function (component, event, helper) {
        var content = (component.get("v.inputValue") || "").trim();
        if (!content) {
            return;
        }

        var txName = component.get("v.selectedPlanName");

        if (!component.get("v.isSubmitModification")) {
            helper.postModification(component, txName, content, true, function () {
                component.set("v.isSubmitModification", true);
                helper.afterSend(component);
            });
        } else if (!component.get("v.isSubmitReply")) {
            helper.postModification(component, undefined, content, false, function () {
                component.set("v.isSubmitReply", true);
                helper.afterSend(component);
            });
        } else {
            helper.postMessage(component, txName, content, function () {
                helper.afterSend(component);
            });
        }
    }
})
