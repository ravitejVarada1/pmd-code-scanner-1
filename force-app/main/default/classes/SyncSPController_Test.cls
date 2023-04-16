/**
* Test class for SyncSPController
* @author 	Ramiro Alvarez
* @date 	  04/12/2021
* @module   BR-4589
*/

@isTest
public class SyncSPController_Test {
 
    @TestSetup
    static void makeData() {

        // accounts
        List<Account> accs = TestDataFactory.createAccounts(1);
        accs[0].BillingCountryCode = 'US';
        insert accs;
            
        // Service providers
        List<Service_Provider__c> serviceProvider = TestDataFactory.createServiceProviders(1, accs[0].Id);
        serviceProvider[0].Billing_Country__c = 'US';
        insert serviceProvider;
    }

    @isTest
    public static void syncSP_Test() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        List<Service_Provider__c> spl = [SELECT Id,Service_Provider_Id__c FROM Service_Provider__c];
        SyncSPController.syncSP(spl[0].Id);
        Test.stopTest();

    }

    public class MockHttpResponseGenerator implements HttpCalloutMock {
        String body='{"spid":0,"billing_country":"US"}';
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'test/json');
            res.setBody(body);
            res.setStatusCode(200);
            return res;
        }
    }

}


