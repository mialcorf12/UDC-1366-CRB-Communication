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

    @isTest
    static void testProxyApiRequest_forwardsMatchingPath()
    {
        Id orderId = createTestOrder();
        Test.setMock(HttpCalloutMock.class, new CalloutRouterMock());
        CRBCommunication.WidgetConfig config = CRBCommunication.getWidgetConfig(orderId);
        String path = '/shared/v1/org/' + config.orgId + '/patients/' + config.patientId + '/txplans/' + config.caseId + '/messages';

        Test.startTest();
        CRBCommunication.ProxyResponse response = CRBCommunication.proxyApiRequest(orderId, 'GET', path, null);
        Test.stopTest();

        System.assertEquals(200, response.statusCode);
        System.assertNotEquals(null, response.body);
    }

    @isTest
    static void testProxyApiRequest_rejectsMismatchedPath()
    {
        Id orderId = createTestOrder();

        Test.startTest();
        try {
            CRBCommunication.proxyApiRequest(orderId, 'GET', '/shared/v1/org/000000/patients/0/txplans/0/messages', null);
            System.assert(false, 'Expected an AuraHandledException for a mismatched path');
        } catch (AuraHandledException e) {
            // expected
        }
        Test.stopTest();
    }
}
