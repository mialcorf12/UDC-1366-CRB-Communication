// messageWidget.js
import { LightningElement, api } from "lwc"
import { loadScript, loadStyle } from "lightning/platformResourceLoader"
import MSGW_JS from "@salesforce/resourceUrl/messageWidgetJs"
import MSGW_CSS from "@salesforce/resourceUrl/messageWidgetCss"
import getToken from "@salesforce/apex/MessageWidgetController.getToken"

export default class MessageWidget extends LightningElement {
  @api orgId; @api patientId; @api caseId
  _done = false

  renderedCallback() {
    if (this._done) return
    this._done = true
    Promise.all([loadStyle(this, MSGW_CSS), loadScript(this, MSGW_JS)]).then(() => {
      window.MessageWidget.mount(this.template.querySelector(".host"), {
        apiBaseUrl: "https://apis.qa.udesign.cloud",
        orgId: this.orgId, patientId: this.patientId, caseId: this.caseId,
        getToken: (force) => getToken({ forceRefresh: !!force }),
        onError: (err) => { if (err?.status === 401) {/* SFDC re-login */} },
      })
    })
  }
}
