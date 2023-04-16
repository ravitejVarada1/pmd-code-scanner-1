@IsTest
private class Zuora_REST_GetBillingCRMIdForSPId_Test {

    @TestSetup
    static void makeData(){
        
        Test.startTest();

        //create Accounts
        List<Account> acctInsert = TestDataFactory.createAccounts(2);
        insert acctInsert;

        //create SPs
        List<Service_Provider__c> spInsert = TestDataFactory.createServiceproviders(acctInsert);
        for (Service_Provider__c sp : spInsert) {
            sp.Billing_Country__c = 'US';
        }
        insert spInsert;

        //create zuora billing account
        List<Zuora__CustomerAccount__c> zAccts = TestDataFactory.createZuoraAccount(1, acctInsert[0]);
        insert zAccts;

        Test.stopTest();

    }

    static testMethod void testBooleanFalse() {

        List<Account> accts = [SELECT Id, (SELECT Id, Service_Provider_Id__c FROM Service_Provider__r) FROM Account WHERE Billing_Account_Zuora__c != null];
        List<Service_Provider__c> sps = accts[0].Service_Provider__r;

        GetBillingCRMId REST_REQUEST = new GetBillingCRMId(Integer.valueOf(sps[0].Service_Provider_Id__c), 'US', 'false');

        setupRestRequest(ENDPOINT, REST_REQUEST);

        Map<String,String> response = Zuora_REST_GetBillingCRMIdForSPId.doPost_getBillingCRMIdForSPId(Integer.valueOf(sps[0].Service_Provider_Id__c), 'US', 'false');

        System.assert(response.get('crmId') == accts[0].Id);

    }

    static testMethod void testBooleanTrue() {

        List<Account> accts = [SELECT Id, (SELECT Id, Service_Provider_Id__c FROM Service_Provider__r) FROM Account WHERE Billing_Account_Zuora__c = null];
        List<Service_Provider__c> sps = accts[0].Service_Provider__r;

        GetBillingCRMId REST_REQUEST = new GetBillingCRMId(Integer.valueOf(sps[0].Service_Provider_Id__c), 'US', 'true');

        setupRestRequest(ENDPOINT, REST_REQUEST);

        Map<String,String> response = Zuora_REST_GetBillingCRMIdForSPId.doPost_getBillingCRMIdForSPId(Integer.valueOf(sps[0].Service_Provider_Id__c), 'US', 'true');

        System.assert(response.get('crmId') == accts[0].Id);

    }

    static testMethod void testBooleanNull() {

        List<Account> accts = [SELECT Id, (SELECT Id, Service_Provider_Id__c FROM Service_Provider__r) FROM Account WHERE Billing_Account_Zuora__c = null];
        List<Service_Provider__c> sps = accts[0].Service_Provider__r;

        GetBillingCRMId REST_REQUEST = new GetBillingCRMId(Integer.valueOf(sps[0].Service_Provider_Id__c), 'US', null);

        setupRestRequest(ENDPOINT, REST_REQUEST);

        Map<String,String> response = Zuora_REST_GetBillingCRMIdForSPId.doPost_getBillingCRMIdForSPId(Integer.valueOf(sps[0].Service_Provider_Id__c), 'US', null);

        System.assert(response.get('crmId') == null);

    }



    public class GetBillingCRMId {
        Integer serviceProviderId;
        String countryCode;
        String skipZuoraAccountCheck;

        public GetBillingCRMId(Integer spId, String cc, String skipZuora) {
            this.serviceProviderId = spId;
            this.countryCode = cc;
            this.skipZuoraAccountCheck = skipZuora;
        }
    }

    private static final String ENDPOINT = '/getZuoraBillingCRMIdForSpId/';

    private static void setupRestRequest(String uri, GetBillingCRMId request){     
        RestContext.request = new RestRequest();
        RestContext.request.requestUri = uri;
        RestContext.request.requestBody = blob.valueOf(JSON.serialize(request));
    }

}