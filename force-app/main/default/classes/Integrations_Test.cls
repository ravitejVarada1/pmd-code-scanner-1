// https://cargurus.atlassian.net/browse/BR-884
@isTest
public class Integrations_Test {

    @TestSetup
    static void makeData() {
        Test.startTest();
        insert new List<Integration_Message__c>{
            new Integration_Message__c(Process__c = Integrations.PROCESS_ZACCOUNT),
            new Integration_Message__c(Process__c = Integrations.PROCESS_ZACCOUNT),
            new Integration_Message__c(Process__c = Integrations.PROCESS_ZACCOUNT)
        };
        Test.stopTest();
    }

    @isTest
    static void testIntegrations() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Test.startTest();
        Integrations.sendMessageIdsToBoomi([SELECT Id FROM Integration_Message__c]);
        Test.stopTest();
    }

    @isTest
    static void testIntegrationOverride() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Test.startTest();
        Integrations.sendMessageIdsToBoomi(
            new List<Id>(new Map<Id,Integration_Message__c>([SELECT Id FROM Integration_Message__c]).keySet())
        );
        Test.stopTest();
    }

    @isTest
    static void testIntegrationsQueueable() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Test.startTest();
        sendMessagesFuture(
            new List<Id>(new Map<Id,Integration_Message__c>([SELECT Id FROM Integration_Message__c]).keySet())
        );
        Test.stopTest();
    }

    @isTest
    static void testIntegrationsError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());

        Test.startTest();
        Integrations.sendMessageIdsToBoomi([SELECT Id FROM Integration_Message__c]);
        Test.stopTest();
    }

    @future
    static void sendMessagesFuture(List<Id> messageIds) {
        Integrations.sendMessageIdsToBoomi(messageIds);
    }

    class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'test/json');
            res.setStatusCode(200);
            return res;
        }
    }

    class MockHttpResponseError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'test/json');
            res.setStatusCode(503);
            return res;
        }
    }

}
