@isTest
public class DocusignFunctions_Test {

    @TestSetup
    static void makeData() {
        Account[] accts = TestDataFactory.createAccounts(1);
        insert accts;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 1);
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        insert quotes;

        dsfs__DocuSign_Status__c dss = new dsfs__DocuSign_Status__c(
            dsfs__DocuSign_Envelope_ID__c = '009D968D-5B51-4342-831F-CE0E52A6E069',
            Quote_CPQ__c = quotes[0].Id,
            dsfs__Envelope_Status__c = 'Sent',
            dsfs__Sent_Date_Time__c = System.now(),
            dsfs__Opportunity__c = opps[0].Id
        );
        insert dss;
    }

    @isTest
    static void testDocusignVoid() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Test.startTest();
        List<String> eIds = DocusignFunctions.getOpenEnvelopeIDs([SELECT Id FROM SBQQ__Quote__c]);
        DocusignFunctions.voidMultipleEnvelopes(eIds, 'Test Void');
        Test.stopTest();
    }

    class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('X-DocuSign-Authentication', 'test/json');
            res.setStatusCode(200);
            return res;
        }
    }
}
