global class CRBCommunication
{
    private static final String API_DOMAIN = 'https://apis.qa.aligneroem.com';
    // Hosts that front the same API gateway. The API returns absolute download_path URLs on
    // the second host; those are rewritten onto API_DOMAIN so the Remote Site Setting and the
    // credentials stay bound to a single host. Extend per environment.
    @TestVisible private static final Set<String> API_HOST_ALIASES = new Set<String>{
        new Url(API_DOMAIN).getHost().toLowerCase(),
        'apis.qa.udesign.cloud'
    };

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
     * (Salesforce platform auth would reject it) — it sends the request over
     * postMessage to this already-authenticated Aura/Apex channel instead.
     *
     * requestJson: {method, path, body, fields}. When fileBase64 is present the
     * call is a multipart upload (file metadata in requestJson.file, bytes in
     * fileBase64, passed separately to avoid holding the payload twice in heap).
     * Only paths allowed by isAllowedPath() for this recordId's own
     * org/patient/case are forwarded.
     */
    @AuraEnabled
    public static ProxyResponse proxyApiRequest(Id recordId, String requestJson, String fileBase64)
    {
        ProxyRequest request;
        try {
            request = (ProxyRequest) System.JSON.deserialize(requestJson, ProxyRequest.class);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid proxy request');
        }
        if (request == null || String.isBlank(request.method) || String.isBlank(request.path)) {
            throw new AuraHandledException('Invalid proxy request');
        }

        String method = request.method.toUpperCase();
        Ids ids = resolveIds(recordId);
        request.path = normalizePath(request.path);
        if (!isAllowedPath(method, request.path, ids)) {
            // Query string (download ticket) is intentionally left out of the log.
            System.debug(LoggingLevel.WARN, 'CRB proxy rejected path: ' + method + ' ' + request.path.substringBefore('?'));
            throw new AuraHandledException('Path does not match this record');
        }

        Blob bodyBlob = null;
        String contentType = null;
        String body = request.body;
        if (String.isNotBlank(fileBase64)) {
            if (method != 'POST' || request.file == null) {
                throw new AuraHandledException('Invalid proxy request');
            }
            // 3 base64 chars carry ~2.25 bytes; reject before decoding anything.
            if (fileBase64.length() > (MAX_UPLOAD_BYTES / 3) * 4 + 4) {
                return errorResponse(413, 'file_too_large');
            }
            String boundary = '----CRB' + EncodingUtil.convertToHex(Crypto.generateAesKey(128));
            bodyBlob = buildMultipart(boundary, request.fields, request.file, fileBase64);
            contentType = 'multipart/form-data; boundary=' + boundary;
            body = null;
        }

        HttpResponse upstream = sendProxied(method, request.path, body, bodyBlob, contentType);
        Boolean expectBinary = method == 'GET' && request.path.substringBefore('?').toLowerCase().contains('/download/');
        return toProxyResponse(upstream, expectBinary);
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

    /**
     * The widget can be placed on a uLab_Order__c or a uLab_Case__c record page.
     * Order resolves through its related case and patient; Case reads the
     * identifiers directly from its own fields.
     */
    private static Ids resolveIds(Id recordId)
    {
        if (recordId != null && recordId.getSobjectType() == uLab_Case__c.SObjectType) {
            return resolveIdsFromCase(recordId);
        }
        if (recordId == null || recordId.getSobjectType() != uLab_Order__c.SObjectType) {
            throw new AuraHandledException('Unsupported record type');
        }
        return resolveIdsFromOrder(recordId);
    }

    private static Ids resolveIdsFromCase(Id recordId)
    {
        uLab_Case__c caseRec = [
            Select id, uLab_Acct_Number__c, uLab_Case_Number__c, Patient_Portal_ID__c
            from uLab_Case__c where id = :recordId limit 1
        ];

        Ids ids = new Ids();
        ids.orgId = toInteger(caseRec.uLab_Acct_Number__c);
        ids.caseId = toInteger(caseRec.uLab_Case_Number__c);
        ids.patientId = toInteger(caseRec.Patient_Portal_ID__c);
        return ids;
    }

    // Works whether the source field is Text or Number.
    private static Integer toInteger(Object value)
    {
        return value == null ? null : Integer.valueOf(String.valueOf(value).trim());
    }

    private static Ids resolveIdsFromOrder(Id recordId)
    {
        uLab_Order__c orderRec = [Select id, uLab_Acct_Number__c, Related_Case_Number__c, Patient_Portal_ID__c from uLab_Order__c where id = :recordId limit 1];

        Ids ids = new Ids();
        ids.patientId = Integer.valueOf(orderRec.Patient_Portal_ID__c);
        ids.caseId = Integer.valueOf(orderRec.Related_Case_Number__c);
        ids.orgId = Integer.valueOf(orderRec.uLab_Acct_Number__c);
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

    // ---- widget proxy helpers -----------------------------------------------

    private static final Integer MAX_REDIRECTS = 3;
    // Sync Apex heap is 6 MB and the payload is copied several times
    // (base64 param, combined base64, Blob), so uploads stay small.
    // Tune after measuring in the sandbox.
    @TestVisible private static final Integer MAX_UPLOAD_BYTES = 1000000;
    @TestVisible private static final Integer MAX_DOWNLOAD_BYTES = 2500000;
    private static final String USER_ID_PLACEHOLDER = 'REPLACE_';

    /**
     * Strict allowlist of the API paths the widget may reach for this record.
     * Everything is anchored with startsWith on this record's own org/patient/case.
     */
    private static Boolean isAllowedPath(String method, String path, Ids ids)
    {
        if (ids == null || ids.orgId == null || ids.patientId == null || ids.caseId == null) {
            return false;
        }
        if (String.isBlank(path) || !path.startsWith('/')) {
            return false;
        }
        String p = path.substringBefore('?');
        String lower = p.toLowerCase();
        if (p.contains('//') || lower.contains('..') || lower.contains('%2e') ||
            lower.contains('%2f') || lower.contains('%5c') ||
            !Pattern.matches('[A-Za-z0-9._~!$&\'()*+,;=:@%/-]+', p)) {
            return false;
        }

        String org = String.valueOf(ids.orgId);
        String caseTail = '/org/' + org + '/patients/' + ids.patientId + '/txplans/' + ids.caseId + '/';
        String orchestration = '/shared/v1/org/' + org + '/orchestration/patients/' + ids.patientId + '/txplans/' + ids.caseId + '/';
        String files = '/file-mgmt/v1/org/' + org + '/files/attachment/';
        String order = '/order-mgmt/v2/org/' + org + '/orders/';

        if (p.startsWith('/shared/v1' + caseTail) || p.startsWith('/shared/v2' + caseTail) || p.startsWith(orchestration)) {
            return method == 'GET' || method == 'POST' || method == 'PUT' || method == 'DELETE';
        }
        if (p.startsWith(files)) {
            return method == 'GET' || method == 'POST' || method == 'DELETE';
        }
        if (p.startsWith(order)) {
            // org-scoped only: the order id is not verifiable against this record here
            return method == 'PUT' && Pattern.matches('[0-9]+', p.substring(order.length()));
        }
        return false;
    }

    /**
     * The API returns absolute download URLs. When the host is one of API_HOST_ALIASES the
     * URL is reduced to '/path[?query]' (the ?t= ticket is kept) so it can go through
     * isAllowedPath and be sent to API_DOMAIN. Any other host is returned untouched and
     * is rejected later because it does not start with '/'.
     */
    private static String normalizePath(String path)
    {
        if (String.isBlank(path) || !path.startsWith('https://')) {
            return path;
        }
        try {
            Url parsed = new Url(path);
            Integer port = parsed.getPort();
            if (!API_HOST_ALIASES.contains(parsed.getHost().toLowerCase()) ||
                parsed.getUserInfo() != null ||
                (port != -1 && port != 443)) {
                return path;
            }
            String result = parsed.getPath();
            if (String.isNotBlank(parsed.getQuery())) {
                result += '?' + parsed.getQuery();
            }
            return result;
        } catch (Exception e) {
            return path;
        }
    }

    private static String apiUserId()
    {
        String value = System.Label.CRBApiUserId;
        return (String.isBlank(value) || value.startsWith(USER_ID_PLACEHOLDER)) ? null : value;
    }

    private static String hostOf(String url)
    {
        return new Url(url).getHost();
    }

    private static String resolveLocation(String current, String location)
    {
        if (String.isBlank(location)) {
            return null;
        }
        if (location.startsWith('https://')) {
            return location;
        }
        if (location.startsWith('/') && !location.startsWith('//')) {
            Url u = new Url(current);
            return u.getProtocol() + '://' + u.getHost() + location;
        }
        return null;
    }

    /**
     * Sends the proxied call with the m2m bearer token and the configured user-id.
     * Only GET follows redirects (attachment downloads 302 to a presigned URL);
     * credentials are never forwarded to a different host.
     */
    private static HttpResponse sendProxied(String method, String path, String body, Blob bodyBlob, String contentType)
    {
        String token = getBearerToken();
        String userId = apiUserId();
        String url = API_DOMAIN + path;
        String originHost = hostOf(url);
        HttpResponse res;

        for (Integer hop = 0; hop <= MAX_REDIRECTS; hop++) {
            Boolean trusted = hostOf(url) == originHost;
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod(method);
            req.setTimeout(120000);
            if (trusted) {
                req.setHeader('Authorization', 'Bearer ' + token);
                if (userId != null) {
                    req.setHeader('user-id', userId);
                }
            }
            if (bodyBlob != null) {
                req.setHeader('Content-Type', contentType);
                req.setBodyAsBlob(bodyBlob);
            } else if (body != null) {
                req.setHeader('Content-Type', 'application/json');
                req.setBody(body);
            }

            res = new Http().send(req);

            Integer code = res.getStatusCode();
            Boolean isRedirect = code == 301 || code == 302 || code == 303 || code == 307 || code == 308;
            if (method != 'GET' || !isRedirect || hop == MAX_REDIRECTS) {
                break;
            }
            String next = resolveLocation(url, res.getHeader('Location'));
            if (next == null) {
                break;
            }
            url = next;
        }
        return res;
    }

    // A blank Content-Type is binary only when a download was requested and succeeded,
    // otherwise getBody() would corrupt the bytes.
    private static Boolean isBinaryContent(String contentType, Boolean binaryFallback)
    {
        if (String.isBlank(contentType)) {
            return binaryFallback;
        }
        String ct = contentType.toLowerCase();
        return !(ct.contains('json') || ct.startsWith('text/') || ct.contains('xml'));
    }

    private static ProxyResponse toProxyResponse(HttpResponse upstream, Boolean expectBinary)
    {
        ProxyResponse response = new ProxyResponse();
        response.statusCode = upstream.getStatusCode();
        response.contentType = upstream.getHeader('Content-Type');
        Boolean binaryFallback = expectBinary == true && response.statusCode >= 200 && response.statusCode < 300;
        if (!isBinaryContent(response.contentType, binaryFallback)) {
            response.body = upstream.getBody();
            return response;
        }
        String length = upstream.getHeader('Content-Length');
        if (String.isNotBlank(length) && length.isNumeric() && Long.valueOf(length) > MAX_DOWNLOAD_BYTES) {
            return errorResponse(413, 'file_too_large');
        }
        Blob bytes = upstream.getBodyAsBlob();
        if (bytes.size() > MAX_DOWNLOAD_BYTES) {
            return errorResponse(413, 'file_too_large');
        }
        response.bodyBase64 = EncodingUtil.base64Encode(bytes);
        return response;
    }

    private static ProxyResponse errorResponse(Integer statusCode, String code)
    {
        ProxyResponse response = new ProxyResponse();
        response.statusCode = statusCode;
        response.body = '{"status":"Failed","error":"' + code + '"}';
        return response;
    }

    private static String headerSafe(String value)
    {
        return value == null ? '' : value.replace('"', '').replace('\r', '').replace('\n', '');
    }

    /**
     * Binary-safe multipart/form-data builder. Blob has no concat, so the parts
     * are joined as base64: the head is padded to a multiple of 3 bytes (spaces
     * after the Content-Type value, which headers tolerate), and the last base64
     * group of the file is re-encoded together with the footer.
     */
    private static Blob buildMultipart(String boundary, Map<String, String> fields, ProxyFile file, String fileBase64)
    {
        String crlf = '\r\n';
        String head = '';
        if (fields != null) {
            for (String key : fields.keySet()) {
                String value = fields.get(key);
                head += '--' + boundary + crlf +
                    'Content-Disposition: form-data; name="' + headerSafe(key) + '"' + crlf + crlf +
                    (value == null ? '' : value) + crlf;
            }
        }
        String partHead = '--' + boundary + crlf +
            'Content-Disposition: form-data; name="attachment"; filename="' + headerSafe(file.name) + '"' + crlf +
            'Content-Type: ' + headerSafe(String.isBlank(file.type) ? 'application/octet-stream' : file.type);
        String blank = crlf + crlf;

        Integer remainder = Math.mod(Blob.valueOf(head + partHead + blank).size(), 3);
        if (remainder != 0) {
            partHead += ' '.repeat(3 - remainder);
        }
        Blob headBlob = Blob.valueOf(head + partHead + blank);

        Integer length = fileBase64.length();
        if (Math.mod(length, 4) != 0) {
            throw new AuraHandledException('Invalid file encoding');
        }
        String prefix = fileBase64.left(length - 4);
        Blob lastBytes = EncodingUtil.base64Decode(fileBase64.right(4));
        Blob footer = Blob.valueOf(crlf + '--' + boundary + '--' + crlf);
        Blob tail = EncodingUtil.convertFromHex(EncodingUtil.convertToHex(lastBytes) + EncodingUtil.convertToHex(footer));

        return EncodingUtil.base64Decode(EncodingUtil.base64Encode(headBlob) + prefix + EncodingUtil.base64Encode(tail));
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

    private class ProxyRequest {
        public String method;
        public String path;
        public String body;
        public Map<String, String> fields;
        public ProxyFile file;
    }

    private class ProxyFile {
        public String name;
        public String type;
    }

    public class ProxyResponse {
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public String body;
        @AuraEnabled public String bodyBase64;
        @AuraEnabled public String contentType;
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
