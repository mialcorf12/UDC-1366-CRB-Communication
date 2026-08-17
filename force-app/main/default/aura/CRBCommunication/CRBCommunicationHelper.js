({
    API_BASE_URL: "https://apis.qa.udesign.cloud",

    mountIfReady: function (component, event, helper) {
        if (component._mounted) {
            return;
        }
        if (!component.get("v.scriptsLoaded")) {
            return;
        }

        var fields = component.get("v.orderFields");
        if (!fields) {
            return;
        }

        var orgId = fields.uLab_Acct_Number__c ? fields.uLab_Acct_Number__c.value : null;
        var patientId = fields.Patient_Portal_ID__c ? fields.Patient_Portal_ID__c.value : null;
        var caseId = fields.Related_Case_Number__c ? fields.Related_Case_Number__c.value : null;

        if (!orgId || !patientId || !caseId) {
            return;
        }

        var sessionId = component.get("v.sessionId");
        var logoUrl = component.get("v.logoUrl");
        var hostEl = component.find("msgwHost").getElement();

        if (logoUrl) {
            hostEl.style.setProperty("--crb-logo-url", "url(" + logoUrl + ")");
        }

        component._mounted = true;

        window.MessageWidget.mount(hostEl, {
            apiBaseUrl: this.API_BASE_URL,
            orgId: orgId,
            patientId: patientId,
            caseId: caseId,
            getToken: function () {
                return Promise.resolve(sessionId);
            },
            onError: function (err) {
                if (err && err.status === 401) {
                    return;
                }
                // eslint-disable-next-line no-console
                console.error("CRBCommunication widget error", err);
            }
        });
    }
})
