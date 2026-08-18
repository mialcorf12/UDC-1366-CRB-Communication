global class CRBCommunication
{
    private static final String API_DOMAIN = 'https://apis.qa.aligneroem.com';

    @AuraEnabled
    public static CaseMessagesResult getMessagesFromApi(Id recordId)
    {
        CaseMessagesResult result = new CaseMessagesResult();
        try {
            Ids ids = resolveIds(recordId);
            result.orgId = String.valueOf(ids.orgId);
            result.patientId = String.valueOf(ids.patientId);
            result.caseId = String.valueOf(ids.caseId);

            String messagesPath = '/shared/v1/org/' + ids.orgId + '/patients/' + ids.patientId + '/txplans/' + ids.caseId + '/messages';
            HttpResponse messagesRes = callApi('GET', messagesPath, null);
            fromJSON messagesWrapper = (fromJSON) System.JSON.deserialize(messagesRes.getBody(), fromJSON.class);

            result.messages = mapThread(messagesWrapper.results.current_thread, messagesWrapper.results.users_avatar);
            result.history = mapThread(messagesWrapper.results.previous_thread, messagesWrapper.results.users_avatar);

            String casePath = '/patient-mgmt/v2/org/' + ids.orgId + '/patients/' + ids.patientId + '/txplans/' + ids.caseId;
            HttpResponse caseRes = callApi('GET', casePath, null);
            caseJSON caseWrapper = (caseJSON) System.JSON.deserialize(caseRes.getBody(), caseJSON.class);
            if (caseWrapper != null && caseWrapper.result != null) {
                result.caseDisposition = caseWrapper.result.caseDisposition;
            }
        } catch (Exception e) {
            result.errorMessage = e.getMessage();
        }
        return result;
    }

    /**
     * Resolves the iframe-hosted widget's identifiers. apiBaseUrl is a
     * placeholder — widget.js only uses it to build path strings; the actual
     * network call never leaves the page (see proxyApiRequest / host.html's
     * fetch() override), so no real domain is needed here.
     */
    @AuraEnabled
    public static WidgetConfig getWidgetConfig(Id recordId)
    {
        WidgetConfig config = new WidgetConfig();
        Ids ids = resolveIds(recordId);
        config.orgId = String.valueOf(ids.orgId);
        config.patientId = String.valueOf(ids.patientId);
        config.caseId = String.valueOf(ids.caseId);
        config.apiBaseUrl = 'https://crb-widget.internal';
        return config;
    }

    /**
     * Generic relay for the widget's intercepted fetch() calls: the iframe never
     * talks to the external API directly (CORS) nor to a public REST endpoint
     * (Salesforce platform auth would reject it) — it sends {method, path, body}
     * over postMessage to this already-authenticated Aura/Apex channel instead.
     * Only requests whose path matches this recordId's own org/patient/case are
     * forwarded.
     */
    @AuraEnabled
    public static ProxyResponse proxyApiRequest(Id recordId, String method, String path, String body)
    {
        Ids ids = resolveIds(recordId);
        String expectedPrefix = '/org/' + ids.orgId + '/patients/' + ids.patientId + '/txplans/' + ids.caseId;
        if (path == null || !path.contains(expectedPrefix)) {
            throw new AuraHandledException('Path does not match this record');
        }

        HttpResponse upstream = forwardRequest(method, path, body);
        ProxyResponse response = new ProxyResponse();
        response.statusCode = upstream.getStatusCode();
        response.body = upstream.getBody();
        return response;
    }

    public static HttpResponse forwardRequest(String method, String path, String body)
    {
        return callApi(method, path, body);
    }

    @AuraEnabled
    public static void postMessage(Id recordId, String txName, String content)
    {
        Ids ids = resolveIds(recordId);
        Map<String, Object> payload = new Map<String, Object>{
            'subject' => null,
            'txName' => txName,
            'content' => content
        };
        String path = '/shared/v1/org/' + ids.orgId + '/patients/' + ids.patientId + '/txplans/' + ids.caseId + '/messages';
        callApi('POST', path, System.JSON.serialize(payload));
    }

    @AuraEnabled
    public static void postModification(Id recordId, String txName, String content, Boolean isModification)
    {
        Ids ids = resolveIds(recordId);
        Map<String, Object> payload = new Map<String, Object>();
        if (isModification == true) {
            payload.put('message', content);
            payload.put('plan_name', txName);
            payload.put('is_modification_requested', 1);
        } else {
            payload.put('message', content);
            payload.put('is_modification_requested', 0);
        }
        String path = '/shared/v1/org/' + ids.orgId + '/orchestration/patients/' + ids.patientId + '/txplans/' + ids.caseId + '/messages/';
        callApi('POST', path, System.JSON.serialize(payload));
    }

    @AuraEnabled
    public static void markRead(Id recordId, Long messageId)
    {
        Ids ids = resolveIds(recordId);
        Map<String, Object> payload = new Map<String, Object>{ 'read' => 1 };
        String path = '/shared/v1/org/' + ids.orgId + '/patients/' + ids.patientId + '/txplans/' + ids.caseId + '/messages/' + messageId;
        callApi('PUT', path, System.JSON.serialize(payload));
    }

    // ---- shared helpers -----------------------------------------------------

    private static Ids resolveIds(Id recordId)
    {
        uLab_Order__c orderRec = [Select id, uLab_Acct_Number__c, uLab_Case__c from uLab_Order__c where id = :recordId limit 1];
        uLab_Case__c caseRec = [Select id, Name, Patient_ID__c from uLab_Case__c where id = :orderRec.uLab_Case__c limit 1];
        Patient__c patientRec = [Select id, Name from Patient__c where id = :caseRec.Patient_ID__c limit 1];

        Ids ids = new Ids();
        if (patientRec != null && patientRec.Name != null) {
            ids.patientId = Integer.valueOf(patientRec.Name.replace('PID-', ''));
        }
        if (caseRec != null && caseRec.Name != null) {
            ids.caseId = Integer.valueOf(caseRec.Name);
        }
        if (orderRec != null && orderRec.uLab_Acct_Number__c != null) {
            ids.orgId = Integer.valueOf(orderRec.uLab_Acct_Number__c);
        }
        return ids;
    }

    private static String getBearerToken()
    {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(System.Label.tokenapi);
        req.setMethod('POST');
        req.setHeader('Authorization', System.Label.Authkey);
        req.setHeader('Cache-Control', 'no-cache');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('grant_type=client_credentials&scope=m2m');
        Http http = new Http();
        HttpResponse res = http.send(req);
        tokenWrapper wrapper = (tokenWrapper) System.JSON.deserialize(res.getBody(), tokenWrapper.class);
        return wrapper.access_token;
    }

    private static HttpResponse callApi(String method, String path, String body)
    {
        String token = getBearerToken();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_DOMAIN + path);
        req.setMethod(method);
        req.setHeader('Authorization', 'Bearer ' + token);
        if (body != null) {
            req.setHeader('Content-Type', 'application/json');
            req.setBody(body);
        }
        Http http = new Http();
        return http.send(req);
    }

    private static List<CaseMessageRow> mapThread(List<cls_current_thread> thread, List<cls_users_avatar> usersAvatar)
    {
        List<CaseMessageRow> rows = new List<CaseMessageRow>();
        if (thread == null) {
            return rows;
        }

        Map<Integer, cls_users_avatar> avatarById = new Map<Integer, cls_users_avatar>();
        if (usersAvatar != null) {
            for (cls_users_avatar avatar : usersAvatar) {
                avatarById.put(avatar.id, avatar);
            }
        }

        for (cls_current_thread item : thread) {
            CaseMessageRow row = new CaseMessageRow();
            row.id = item.id;
            row.messageTime = formatTime(item.created_at);
            row.messageStatus = item.message_type;
            row.buttonEnable = item.button_enable;
            row.title = item.plan_name;

            message body = (message) System.JSON.deserialize(item.body, message.class);
            row.subject = body.subject;
            row.text = body.content;

            cls_users_avatar avatar = avatarById.get(item.created_by);
            if (avatar != null) {
                row.firstname = avatar.first_name;
                row.lastname = avatar.last_name;
                row.initials = ((avatar.first_name == null ? '' : avatar.first_name.left(1)) +
                                 (avatar.last_name == null ? '' : avatar.last_name.left(1))).toUpperCase();
                row.photo = (avatar.avatar_link == '-') ? '' : avatar.avatar_link;
                row.color = avatar.avatar_colour;
                row.role = (avatar.title_name != null && avatar.title_name.type_name != null)
                    ? avatar.title_name.type_name.toUpperCase()
                    : '';
            }

            rows.add(row);
        }
        return rows;
    }

    private static String formatTime(String isoDate)
    {
        if (String.isBlank(isoDate)) {
            return '';
        }
        Datetime gmtDate = Datetime.newInstanceGmt(
            Integer.valueOf(isoDate.substring(0, 4)),
            Integer.valueOf(isoDate.substring(5, 7)),
            Integer.valueOf(isoDate.substring(8, 10)),
            Integer.valueOf(isoDate.substring(11, 13)),
            Integer.valueOf(isoDate.substring(14, 16)),
            Integer.valueOf(isoDate.substring(17, 19))
        );
        return gmtDate.format('MM/dd/yy hh:mm a');
    }

    // ---- wrapper / JSON shape classes ---------------------------------------

    private class Ids {
        Integer orgId;
        Integer patientId;
        Integer caseId;
    }

    private class tokenWrapper {
        public String access_token;
    }

    private class fromJSON {
        public cls_results results;
    }
    private class cls_results {
        public List<cls_current_thread> current_thread;
        public List<cls_current_thread> previous_thread;
        public List<cls_users_avatar> users_avatar;
    }
    private class cls_current_thread {
        public Long id;
        public String created_at;
        public Integer created_by;
        public String message_type;
        public Boolean button_enable;
        public String body;
        public String plan_name;
    }
    private class cls_users_avatar {
        public Integer id;
        public String first_name;
        public String last_name;
        public String avatar_colour;
        public String avatar_link;
        public cls_title_name title_name;
    }
    private class cls_title_name {
        public String type_name;
    }
    private class message {
        public String content;
        public String subject;
    }

    private class caseJSON {
        public caseResult result;
    }
    private class caseResult {
        public String caseDisposition;
    }

    public class CaseMessageRow {
        @AuraEnabled public Long id;
        @AuraEnabled public String firstname;
        @AuraEnabled public String lastname;
        @AuraEnabled public String initials;
        @AuraEnabled public String role;
        @AuraEnabled public String photo;
        @AuraEnabled public String color;
        @AuraEnabled public String messageTime;
        @AuraEnabled public String messageStatus;
        @AuraEnabled public Boolean buttonEnable;
        @AuraEnabled public String subject;
        @AuraEnabled public String title;
        @AuraEnabled public String text;
    }

    public class ProxyResponse {
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public String body;
    }

    public class WidgetConfig {
        @AuraEnabled public String orgId;
        @AuraEnabled public String patientId;
        @AuraEnabled public String caseId;
        @AuraEnabled public String apiBaseUrl;
    }

    public class CaseMessagesResult {
        @AuraEnabled public List<CaseMessageRow> messages = new List<CaseMessageRow>();
        @AuraEnabled public List<CaseMessageRow> history = new List<CaseMessageRow>();
        @AuraEnabled public String caseDisposition;
        @AuraEnabled public String orgId;
        @AuraEnabled public String patientId;
        @AuraEnabled public String caseId;
        @AuraEnabled public String errorMessage;
    }
}
