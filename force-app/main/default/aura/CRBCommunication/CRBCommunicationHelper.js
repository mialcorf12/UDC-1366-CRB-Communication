({
    ENABLED_STATUSES: ["REVIEW_PLAN", "REVIEW_MODIFICATION", "SUBMITTED_TO_UASSIST", "ATTENTION_NEEDED", "PLACE_ORDER"],

    refresh: function (component) {
        var recordId = component.get("v.recordId");
        var action = component.get("c.getMessagesFromApi");
        action.setParams({ recordId: recordId });

        var helper = this;
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state !== "SUCCESS") {
                return;
            }
            var result = response.getReturnValue() || {};
            component.set("v.messages", result.messages || []);
            component.set("v.history", result.history || []);
            component.set("v.caseDisposition", result.caseDisposition);
            component.set("v.orgId", result.orgId);
            component.set("v.patientId", result.patientId);
            component.set("v.caseId", result.caseId);
            helper.updateComposerDisabled(component);
        });
        $A.enqueueAction(action);
    },

    postMessage: function (component, txName, content, onSuccess) {
        var action = component.get("c.postMessage");
        action.setParams({
            recordId: component.get("v.recordId"),
            txName: txName,
            content: content
        });
        action.setCallback(this, function (response) {
            if (response.getState() === "SUCCESS" && onSuccess) {
                onSuccess();
            }
        });
        $A.enqueueAction(action);
    },

    postModification: function (component, txName, content, isModification, onSuccess) {
        var action = component.get("c.postModification");
        action.setParams({
            recordId: component.get("v.recordId"),
            txName: txName,
            content: content,
            isModification: isModification
        });
        action.setCallback(this, function (response) {
            if (response.getState() === "SUCCESS" && onSuccess) {
                onSuccess();
            }
        });
        $A.enqueueAction(action);
    },

    afterSend: function (component) {
        component.set("v.inputValue", "");
        component.set("v.selectedPlanName", null);
        component.set("v.selectedMessageId", null);
        this.updateComposerDisabled(component);
        this.refresh(component);
    },

    // mirrors widget.js's composerDisabled()
    updateComposerDisabled: function (component) {
        var messages = component.get("v.messages") || [];
        var caseDisposition = component.get("v.caseDisposition");
        var selectedMessageId = component.get("v.selectedMessageId");

        var disabled = false;
        if (!selectedMessageId) {
            disabled = true;
        } else if (messages.length === 0) {
            disabled = true;
        } else if (this.ENABLED_STATUSES.indexOf(caseDisposition) === -1) {
            disabled = true;
        }
        component.set("v.composerDisabled", disabled);
    }
})