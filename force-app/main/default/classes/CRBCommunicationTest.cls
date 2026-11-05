@isTest
private class CRBCommunicationTest
{
    private static final String TOKEN_RESPONSE = '{"access_token":"mock-token-123"}';

    private static final String MESSAGES_RESPONSE =
        '{"results":{' +
            '"current_thread":[' +
                '{"id":1001,"created_at":"2024-01-05T19:47:06Z","created_by":501,"message_type":"MESSAGE_WITH_REPLY","button_enable":true,' +
                '"body":"{\\"subject\\":\\"Please review the case\\",\\"content\\":\\"It has been designed.\\"}","plan_name":"Standard Plan"},' +
                '{"id":1002,"created_at":"2024-01-06T10:15:00Z","created_by":502,"message_type":"MESSAGE_SELECTED","button_enable":false,' +
                '"body":"{\\"subject\\":\\"\\",\\"content\\":\\"Looks good, thanks.\\"}","plan_name":""}' +
            '],' +
            '"previous_thread":[' +
                '{"id":900,"created_at":"2023-12-01T08:00:00Z","created_by":501,"message_type":"MESSAGE","button_enable":false,' +
                '"body":"{\\"subject\\":\\"Older subject\\",\\"content\\":\\"Older content\\"}","plan_name":"Prior Plan"}' +
            '],' +
            '"users_avatar":[' +
                '{"id":501,"first_name":"Test","last_name":"Uassist","avatar_colour":"#16AADC","avatar_link":"-","title_name":{"type_name":"uAssist User"}},' +
                '{"id":502,"first_name":"Test","last_name":"Doctor","avatar_colour":"#739EFF","avatar_link":"-","title_name":{"type_name":"Doctor"}}' +
            ']' +
        '}}';

    private static final String CASE_RESPONSE = '{"result":{"caseDisposition":"REVIEW_PLAN"}}';

    private class CalloutRouterMock implements HttpCalloutMock
    {
        public HTTPResponse respond(HTTPRequest req)
        {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/oauth') || endpoint.endsWith('token') || req.getBody() != null && req.getBody().startsWith('grant_type=')) {
                res.setBody(TOKEN_RESPONSE);
            } else if (endpoint.contains('/patient-mgmt/v2/')) {
                res.setBody(CASE_RESPONSE);
            } else if (endpoint.contains('/messages') && req.getMethod() == 'GET') {
                res.setBody(MESSAGES_RESPONSE);
            } else {
                // POST /messages, POST orchestration/.../messages/, PUT /messages/{id}
                res.setBody('{}');
            }
            return res;
        }
    }

    private static Id createTestOrder()
    {
        // uLab_Order__c.uLab_Acct_Number__c is a formula (TEXT(uLab_Case__r.Account__r.uLab_Acct_Number__c)),
        // so the account number has to be seeded on the related Account instead.
        Account acct = new Account(Name = 'Test Account', uLab_Acct_Number__c = 199040);
        insert acct;

        // Patient__c.Name is an auto-number ("PID-xxxx"); requery to read the generated value.
        Patient__c patient = new Patient__c();
        insert patient;
        patient = [SELECT Id, Name FROM Patient__c WHERE Id = :patient.Id LIMIT 1];

        uLab_Case__c caseRec = new uLab_Case__c(
            Name = '616614',
            Account__c = acct.Id,
            Patient_ID__c = patient.Id
        );
        insert caseRec;

        uLab_Order__c order = new uLab_Order__c(uLab_Case__c = caseRec.Id);
        insert order;
        return order.Id;
    }

    @isTest
    static void testGetMessagesFromApi_success()
    {
        Id orderId = createTestOrder();
        Test.setMock(HttpCalloutMock.class, new CalloutRouterMock());

        Test.startTest();
        CRBCommunication.CaseMessagesResult result = CRBCommunication.getMessagesFromApi(orderId);
        Test.stopTest();

        System.assertEquals(null, result.errorMessage, 'Should not have an error: ' + result.errorMessage);
        System.assertEquals(2, result.messages.size(), 'Expected two current-thread rows');
        System.assertEquals(1, result.history.size(), 'Expected one previous-thread row');
        System.assertEquals('REVIEW_PLAN', result.caseDisposition);

        CRBCommunication.CaseMessageRow first = result.messages[0];
        System.assertEquals('UASSIST USER', first.role);
        System.assertEquals('Please review the case', first.subject);
        System.assertEquals('It has been designed.', first.text);
        System.assertEquals('Standard Plan', first.title);
        System.assertEquals(true, first.buttonEnable);
        System.assertEquals('TU', first.initials);

        CRBCommunication.CaseMessageRow second = result.messages[1];
        System.assertEquals('DOCTOR', second.role);
        System.assertEquals('Looks good, thanks.', second.text);
    }

    @isTest
    static void testGetMessagesFromApi_handlesError()
    {
        Test.setMock(HttpCalloutMock.class, new CalloutRouterMock());

        Test.startTest();
        CRBCommunication.CaseMessagesResult result = CRBCommunication.getMessagesFromApi(null);
        Test.stopTest();

        System.assertNotEquals(null, result.errorMessage, 'Expected an error message for a null recordId');
        System.assertEquals(0, result.messages.size());
        System.assertEquals(0, result.history.size());
    }

    @isTest
    static void testPostMessage()
    {
        Id orderId = createTestOrder();
        Test.setMock(HttpCalloutMock.class, new CalloutRouterMock());

        Test.startTest();
        CRBCommunication.postMessage(orderId, 'Standard Plan', 'A new reply');
        Test.stopTest();
        // no exception thrown => callout completed successfully
    }

    @isTest
    static void testPostModification_request()
    {
        Id orderId = createTestOrder();
        Test.setMock(HttpCalloutMock.class, new CalloutRouterMock());

        Test.startTest();
        CRBCommunication.postModification(orderId, 'Standard Plan', 'Please adjust the plan', true);
        Test.stopTest();
    }

    @isTest
    static void testPostModification_reply()
    {
        Id orderId = createTestOrder();
        Test.setMock(HttpCalloutMock.class, new CalloutRouterMock());

        Test.startTest();
        CRBCommunication.postModification(orderId, null, 'Just a reply', false);
        Test.stopTest();
    }

    @isTest
    static void testMarkRead()
    {
        Id orderId = createTestOrder();
        Test.setMock(HttpCalloutMock.class, new CalloutRouterMock());

        Test.startTest();
        CRBCommunication.markRead(orderId, 1001L);
        Test.stopTest();
    }

    @isTest
    static void testGetWidgetConfig()
    {
        Id orderId = createTestOrder();

        Test.startTest();
        CRBCommunication.WidgetConfig config = CRBCommunication.getWidgetConfig(orderId);
        Test.stopTest();

        System.assertEquals('199040', config.orgId);
        System.assertEquals('616614', config.caseId);
        System.assertNotEquals(null, config.patientId);
        System.assertNotEquals(null, config.apiBaseUrl);
    }

    // ---- proxyApiRequest ----------------------------------------------------

    private static final Blob PNG_BYTES = Blob.valueOf('PNGDATA');

    private class ProxyMock implements HttpCalloutMock
    {
        public List<HttpRequest> seen = new List<HttpRequest>();

        public HTTPResponse respond(HTTPRequest req)
        {
            seen.add(req);
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();

            if (endpoint == System.Label.tokenapi) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(TOKEN_RESPONSE);
            } else if (endpoint.contains('/redirect/')) {
                res.setStatusCode(302);
                res.setHeader('Location', 'https://files.example.com/blob.png');
            } else if (endpoint.startsWith('https://files.example.com') || endpoint.contains('/download/')) {
                res.setHeader('Content-Type', 'image/png');
                res.setBodyAsBlob(PNG_BYTES);
            } else if (endpoint.contains('/huge/')) {
                res.setHeader('Content-Type', 'image/png');
                res.setHeader('Content-Length', '9999999');
                res.setBodyAsBlob(Blob.valueOf('x'));
            } else {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"results":{}}');
            }
            return res;
        }

        public HttpRequest lastTo(String fragment)
        {
            HttpRequest found;
            for (HttpRequest r : seen) {
                if (r.getEndpoint().contains(fragment)) {
                    found = r;
                }
            }
            return found;
        }
    }

    private static String requestJson(String method, String path)
    {
        return System.JSON.serialize(new Map<String, Object>{ 'method' => method, 'path' => path });
    }

    private static String uploadJson(String path)
    {
        return System.JSON.serialize(new Map<String, Object>{
            'method' => 'POST',
            'path' => path,
            'fields' => new Map<String, String>{ 'case_id' => '616614' },
            'file' => new Map<String, String>{ 'name' => 'scan.png', 'type' => 'image/png' }
        });
    }

    private static String casePath(CRBCommunication.WidgetConfig c, String version)
    {
        return '/shared/' + version + '/org/' + c.orgId + '/patients/' + c.patientId + '/txplans/' + c.caseId + '/messages';
    }

    private static String filesPath(CRBCommunication.WidgetConfig c)
    {
        return '/file-mgmt/v1/org/' + c.orgId + '/files/attachment/';
    }

    private static void assertRejected(Id orderId, String json, String fileBase64)
    {
        try {
            CRBCommunication.proxyApiRequest(orderId, json, fileBase64);
            System.assert(false, 'Expected an AuraHandledException for: ' + json);
        } catch (AuraHandledException e) {
            // expected
        }
    }

    @isTest
    static void testProxyApiRequest_forwardsAllowedFamilies()
    {
        Id orderId = createTestOrder();
        ProxyMock mock = new ProxyMock();
        Test.setMock(HttpCalloutMock.class, mock);
        CRBCommunication.WidgetConfig c = CRBCommunication.getWidgetConfig(orderId);
        String orchestration = '/shared/v1/org/' + c.orgId + '/orchestration/patients/' + c.patientId + '/txplans/' + c.caseId + '/v2/messages/';

        Test.startTest();
        List<CRBCommunication.ProxyResponse> responses = new List<CRBCommunication.ProxyResponse>{
            CRBCommunication.proxyApiRequest(orderId, requestJson('GET', casePath(c, 'v1')), null),
            CRBCommunication.proxyApiRequest(orderId, requestJson('GET', casePath(c, 'v2') + '?limit=20'), null),
            CRBCommunication.proxyApiRequest(orderId, requestJson('POST', orchestration), null),
            CRBCommunication.proxyApiRequest(orderId, requestJson('DELETE', filesPath(c) + '55/'), null),
            CRBCommunication.proxyApiRequest(orderId, requestJson('PUT', '/order-mgmt/v2/org/' + c.orgId + '/orders/123'), null)
        };
        Test.stopTest();

        for (CRBCommunication.ProxyResponse r : responses) {
            System.assertEquals(200, r.statusCode);
            System.assertEquals('{"results":{}}', r.body);
            System.assertEquals(null, r.bodyBase64);
        }
        HttpRequest upstream = mock.lastTo('/orders/123');
        System.assertEquals('PUT', upstream.getMethod());
        System.assert(upstream.getHeader('Authorization').startsWith('Bearer mock-token-123'));
        System.assertEquals(null, upstream.getHeader('user-id'), 'Placeholder label must not be sent');
    }

    @isTest
    static void testProxyApiRequest_rejectsDisallowedRequests()
    {
        Id orderId = createTestOrder();
        Test.setMock(HttpCalloutMock.class, new ProxyMock());
        CRBCommunication.WidgetConfig c = CRBCommunication.getWidgetConfig(orderId);
        String org = c.orgId;

        Test.startTest();
        assertRejected(orderId, requestJson('GET', '/shared/v1/org/000000/patients/0/txplans/0/messages'), null);
        assertRejected(orderId, requestJson('GET', casePath(c, 'v2').replace('/messages', '/../../other')), null);
        assertRejected(orderId, requestJson('GET', casePath(c, 'v2') + '%2e%2e/x'), null);
        assertRejected(orderId, requestJson('GET', '/file-mgmt/v1/org/' + org + '/files/attachment//x'), null);
        assertRejected(orderId, requestJson('GET', '/file-mgmt/v1/org/000000/files/attachment/1/'), null);
        assertRejected(orderId, requestJson('GET', '/order-mgmt/v2/org/' + org + '/orders/123'), null);
        assertRejected(orderId, requestJson('PUT', '/order-mgmt/v2/org/' + org + '/orders/abc'), null);
        assertRejected(orderId, requestJson('PUT', '/order-mgmt/v2/org/' + org + '/orders/1/../2'), null);
        assertRejected(orderId, requestJson('PATCH', casePath(c, 'v2')), null);
        assertRejected(orderId, requestJson('GET', 'shared/v2/relative'), null);
        assertRejected(orderId, requestJson('GET', casePath(c, 'v2') + ' x'), null);
        assertRejected(orderId, requestJson('GET', ''), null);
        assertRejected(orderId, 'not json', null);
        assertRejected(orderId, requestJson('GET', filesPath(c) + '1/'), 'QUJD'); // file on non-POST
        assertRejected(orderId, requestJson('POST', filesPath(c) + 'upload/'), 'QUJD'); // file metadata missing
        assertRejected(orderId, uploadJson(filesPath(c) + 'upload/'), 'abc'); // not valid base64 length
        Test.stopTest();
    }

    @isTest
    static void testProxyApiRequest_uploadsMultipartForEveryPaddingCase()
    {
        Id orderId = createTestOrder();
        ProxyMock mock = new ProxyMock();
        Test.setMock(HttpCalloutMock.class, mock);
        CRBCommunication.WidgetConfig c = CRBCommunication.getWidgetConfig(orderId);
        String path = filesPath(c) + 'upload/';

        Test.startTest();
        for (String content : new List<String>{ 'abc', 'abcd', 'abcde' }) { // 3n, 3n+1, 3n+2 bytes
            CRBCommunication.ProxyResponse r = CRBCommunication.proxyApiRequest(
                orderId, uploadJson(path), EncodingUtil.base64Encode(Blob.valueOf(content))
            );
            System.assertEquals(200, r.statusCode);

            HttpRequest upstream = mock.lastTo('/upload/');
            System.assert(upstream.getHeader('Content-Type').startsWith('multipart/form-data; boundary=----CRB'));
            String sent = upstream.getBodyAsBlob().toString();
            System.assert(sent.contains('name="case_id"\r\n\r\n616614\r\n'), sent);
            System.assert(sent.contains('filename="scan.png"'), sent);
            System.assert(sent.contains('Content-Type: image/png'), sent);
            System.assert(sent.contains('\r\n\r\n' + content + '\r\n--'), 'File bytes must be intact: ' + sent);
            System.assert(sent.endsWith('--\r\n'), sent);
        }
        Test.stopTest();
    }

    @isTest
    static void testProxyApiRequest_rejectsOversizedUpload()
    {
        Id orderId = createTestOrder();
        ProxyMock mock = new ProxyMock();
        Test.setMock(HttpCalloutMock.class, mock);
        CRBCommunication.WidgetConfig c = CRBCommunication.getWidgetConfig(orderId);
        String big = EncodingUtil.base64Encode(Blob.valueOf('a'.repeat(CRBCommunication.MAX_UPLOAD_BYTES + 100)));

        Test.startTest();
        CRBCommunication.ProxyResponse r = CRBCommunication.proxyApiRequest(orderId, uploadJson(filesPath(c) + 'upload/'), big);
        Test.stopTest();

        System.assertEquals(413, r.statusCode);
        System.assert(r.body.contains('file_too_large'));
        System.assertEquals(null, mock.lastTo('/upload/'), 'Nothing must be sent upstream');
    }

    @isTest
    static void testProxyApiRequest_returnsBinaryAsBase64()
    {
        Id orderId = createTestOrder();
        Test.setMock(HttpCalloutMock.class, new ProxyMock());
        CRBCommunication.WidgetConfig c = CRBCommunication.getWidgetConfig(orderId);

        Test.startTest();
        CRBCommunication.ProxyResponse r = CRBCommunication.proxyApiRequest(orderId, requestJson('GET', filesPath(c) + 'download/9/?t=abc'), null);
        Test.stopTest();

        System.assertEquals(200, r.statusCode);
        System.assertEquals('image/png', r.contentType);
        System.assertEquals(EncodingUtil.base64Encode(PNG_BYTES), r.bodyBase64);
        System.assertEquals(null, r.body);
    }

    @isTest
    static void testProxyApiRequest_followsRedirectWithoutCredentials()
    {
        Id orderId = createTestOrder();
        ProxyMock mock = new ProxyMock();
        Test.setMock(HttpCalloutMock.class, mock);
        CRBCommunication.WidgetConfig c = CRBCommunication.getWidgetConfig(orderId);

        Test.startTest();
        CRBCommunication.ProxyResponse r = CRBCommunication.proxyApiRequest(orderId, requestJson('GET', filesPath(c) + 'redirect/9/'), null);
        Test.stopTest();

        System.assertEquals(200, r.statusCode);
        System.assertEquals(EncodingUtil.base64Encode(PNG_BYTES), r.bodyBase64);
        HttpRequest first = mock.lastTo('/redirect/');
        HttpRequest second = mock.lastTo('files.example.com');
        System.assertNotEquals(null, first.getHeader('Authorization'));
        System.assertEquals(null, second.getHeader('Authorization'), 'Credentials must not leave the API host');
    }

    @isTest
    static void testProxyApiRequest_rejectsHugeDownload()
    {
        Id orderId = createTestOrder();
        Test.setMock(HttpCalloutMock.class, new ProxyMock());
        CRBCommunication.WidgetConfig c = CRBCommunication.getWidgetConfig(orderId);

        Test.startTest();
        CRBCommunication.ProxyResponse r = CRBCommunication.proxyApiRequest(orderId, requestJson('GET', filesPath(c) + 'huge/1/'), null);
        Test.stopTest();

        System.assertEquals(413, r.statusCode);
        System.assertEquals(null, r.bodyBase64);
    }
}
