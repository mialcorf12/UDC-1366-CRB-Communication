({
    registerMessageListener: function (component) {
        var helper = this;
        var handler = function (event) {
            var frameEl = component.find("widgetFrame").getElement();
            if (!frameEl || event.source !== frameEl.contentWindow) {
                return;
            }
            var data = event.data;
            if (!data || !data.type) {
                return;
            }
            if (data.type === "CRB_READY") {
                component.set("v.frameReady", true);
                helper.sendConfigWhenReady(component, event.origin);
            } else if (data.type === "CRB_API_REQUEST") {
                helper.respondToApiRequest(component, event.origin, data);
            } else if (data.type === "CRB_ERROR") {
                helper.logWidgetError(data);
            }
        };
        window.addEventListener("message", handler);
        component._crbMessageHandler = handler;
    },

    loadWidgetConfig: function (component) {
        var helper = this;
        var action = component.get("c.getWidgetConfig");
        action.setParams({ recordId: component.get("v.recordId") });
        action.setCallback(this, function (response) {
            if (response.getState() !== "SUCCESS") {
                return;
            }
            var config = response.getReturnValue();
            component.set("v.orgId", config.orgId);
            component.set("v.patientId", config.patientId);
            component.set("v.caseId", config.caseId);
            component.set("v.apiBaseUrl", config.apiBaseUrl);
            component.set("v.configReady", true);
            helper.sendConfigWhenReady(component);
        });
        $A.enqueueAction(action);
    },

    sendConfigWhenReady: function (component, targetOrigin) {
        if (!component.get("v.frameReady") || !component.get("v.configReady")) {
            return;
        }
        var frameEl = component.find("widgetFrame").getElement();
        if (!frameEl || !frameEl.contentWindow) {
            return;
        }
        frameEl.contentWindow.postMessage({
            type: "CRB_CONFIG",
            orgId: component.get("v.orgId"),
            patientId: component.get("v.patientId"),
            caseId: component.get("v.caseId"),
            apiBaseUrl: component.get("v.apiBaseUrl")
        }, targetOrigin || window.location.origin);
    },

    respondToApiRequest: function (component, targetOrigin, data) {
        var frameEl = component.find("widgetFrame").getElement();
        var action = component.get("c.proxyApiRequest");
        action.setParams({
            recordId: component.get("v.recordId"),
            method: data.method,
            path: data.path,
            body: data.body
        });
        action.setCallback(this, function (response) {
            if (!frameEl || !frameEl.contentWindow) {
                return;
            }
            if (response.getState() === "SUCCESS") {
                var result = response.getReturnValue();
                frameEl.contentWindow.postMessage({
                    type: "CRB_API_RESPONSE",
                    requestId: data.requestId,
                    status: result.statusCode,
                    body: result.body
                }, targetOrigin);
            } else {
                var errors = response.getError();
                var message = (errors && errors[0] && errors[0].message) || "Request failed";
                frameEl.contentWindow.postMessage({
                    type: "CRB_API_RESPONSE",
                    requestId: data.requestId,
                    status: 500,
                    body: JSON.stringify({ error: message })
                }, targetOrigin);
            }
        });
        $A.enqueueAction(action);
    },

    logWidgetError: function (data) {
        // eslint-disable-next-line no-console
        console.error("CRBCommunication widget error", data);
    }
})
