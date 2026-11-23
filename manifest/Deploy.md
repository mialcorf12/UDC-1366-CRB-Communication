Static resource CRBWidgetHost.resource: update widget.js/widget.css from /jira. host.html (proxy shim) is maintained by hand: do not overwrite it with the build output.
Before deploying CustomLabels, set the CRBApiUserId label value (the API user-id header).

for production
1) Replace:
apis.qa.aligneroem.com -> apis.aligneroem.com
apis.qa.udesign.cloud -> apis.udesign.cloud
ulab-ciam-qa.okta.com -> ulab-ciam.okta.com

2) prod js y css