@isTest
public class RestDialpadCSCallRouter_Test {
    
        @testSetup 
    static void setupMatchedAccount(){
        
        List<Account> testAccount = TestDataFactory.createPersonalAccounts(1);
        insert testAccount;

        List<Case> testCase = TestDataFactory.createCSCase(1, testAccount);
    }
    
        @isTest
    static void consumerSupport(){
        
        setupRestRequest(ENDPOINT + 'CONSUMERSUPPORT');
        
        Test.startTest();
        setupSOSLResults(true, true, true);
        //RestDialpadCallRouter RSC = new RestDialpadCallRouter();
        RestDialpadConsumerSupportCallRouter.doPost();
        Test.stopTest();

	
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231289'
                 ].isEmpty());

    }
    
            @isTest
    static void fallbackSupport(){

        
        setupRestRequest(ENDPOINT + 'CONSUMERSUPPORT');
        
        Test.startTest();
        setupSOSLResults(false, false, false);
        RestDialpadConsumerSupportCallRouter.doPost();
        Test.stopTest();
	
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231289'
                 ].isEmpty());

    }
    
        private static final RestDialpadConsumerSupportCallRouter.rawPayloadWrap REST_REQUEST = new RestDialpadConsumerSupportCallRouter.rawPayloadWrap(
        '+15556667777',
        null,
        'testContactType',
        'testContactId',
        'testCallId',
        '2000-01-01',
        '+14151231289'
    );
    
     private static void setupRestRequest(String uri){     
        RestContext.request = new RestRequest();
        RestContext.request.requestUri = uri;
        RestContext.request.requestBody = blob.valueOf(JSON.serialize(REST_REQUEST));
    }
    
    private static void setupSOSLResults(Boolean addAccount, Boolean addContact, Boolean addCase)
    {
        
        Contact testContact = [SELECT Id, AccountId
                               FROM Contact
                               LIMIT 1][0];
        
        ID testCaseId;
        for (Case c : [SELECT Id
                       FROM Case
                       LIMIT 1])
        {
            testCaseId = c.Id;
        }
        
        
        List<ID> searchResultIds = new List<ID>();
        
        if (addAccount){
            searchResultIds.add(testContact.AccountId);
        }
        
        if (addContact){
            searchResultIds.add(testContact.Id);
        }
        
        if (addCase){
            searchResultIds.add(testCaseId);
        }

        Test.setFixedSearchResults(searchResultIds);
    }
    
    private static final String ENDPOINT = '/cscallrouter/';

}