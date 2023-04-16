/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        01/07/2021
* modified:       01/07/2021
* created jira:   BR-348
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class RestDialpadCallRouter_test {
    
    private static final String UNKNOWN_US;
    private static final String SUPPORT_US;
    private static final String SUPPORTNONPAYING_US;
    private static final String SUPPORTPAYING_US;
    private static final String BILLING_US;
    private static final String COLLECTIONS_US;
    private static final String SALES_US;
    private static final String DEFAULT_LEAD_QUEUE_NAME;
    private static final String DEFAULT_CASE_QUEUE_NAME_BILLING;
    private static final String DEFAULT_CASE_QUEUE_NAME_COLLECTIONS;
    private static final String DEFAULT_CASE_QUEUE_NAME_SUPPORT_UNKNOWN;
    private static final String DEFAULT_CASE_QUEUE_NAME_SUPPORT_PAYING;
    private static final String DEFAULT_CASE_QUEUE_NAME_SUPPORT_NONPAYING;
    private static final String DEFAULT_CASE_QUEUE_NAME_UNKNOWN;
    private static final Set<String> DEFAULT_CASE_QUEUE_NAMES;
    
    static{
        for (Dialpad_Target__mdt dpt : [SELECT MasterLabel, Target_ID__c, Default_Lead_Queue__c, Default_Case_Queue__c
                                        FROM Dialpad_Target__mdt
                                        WHERE Country_Code__c = 'US'])
        {
            Switch on dpt.MasterLabel{
                when 'Unknown_US'{
                    UNKNOWN_US = dpt.Target_ID__c;
                    DEFAULT_CASE_QUEUE_NAME_UNKNOWN = dpt.Default_Case_Queue__c;
                }
                when 'SupportNonPaying_US'{
                    SUPPORTNONPAYING_US = dpt.Target_ID__c;
                    DEFAULT_CASE_QUEUE_NAME_SUPPORT_NONPAYING = dpt.Default_Case_Queue__c;
                }
                when 'SupportPaying_US' {
                    SUPPORTPAYING_US = dpt.Target_ID__c;
                    DEFAULT_CASE_QUEUE_NAME_SUPPORT_PAYING = dpt.Default_Case_Queue__c;
                }
                when 'Support_US' {
                    SUPPORT_US = dpt.Target_ID__c;
                    DEFAULT_CASE_QUEUE_NAME_SUPPORT_UNKNOWN = dpt.Default_Case_Queue__c;
                }
                when 'Billing_US'{
                    BILLING_US = dpt.Target_ID__c;
                    DEFAULT_CASE_QUEUE_NAME_BILLING = dpt.Default_Case_Queue__c;
                }
                when 'Sales_US'{
                    SALES_US = dpt.Target_ID__c;
                    DEFAULT_LEAD_QUEUE_NAME = dpt.Default_Lead_Queue__c;
                }
                when 'Collections_US'{
                    COLLECTIONS_US = dpt.Target_ID__c;
                    DEFAULT_CASE_QUEUE_NAME_COLLECTIONS = dpt.Default_Case_Queue__c;
                }
            }
        }
        
    }
    
    private static final ID DEFAULT_LEAD_QUEUE = [SELECT Id
                                                  FROM Group
                                                  WHERE Type = 'Queue'
                                                  AND DeveloperName =: DEFAULT_LEAD_QUEUE_NAME][0].Id;
    
    @testSetup 
    static void setupMatchedAccount(){
        
        ID accountOwnerId;
        ID opportunityOwnerId;
        
        Integer i=0;
        for (User u : [SELECT Id
                       FROM User
                       WHERE UserType = 'Standard'
                       AND IsActive = true
                       AND Automation_User__c = false
                       AND Dialpad_Id__c != null
                       LIMIT 2])
        {
            Switch on i{
                when 0{
                    accountOwnerId = u.Id;
                }when 1{
                    opportunityOwnerId = u.Id;
                }
            }
            
            i++;
        }
        
        Account testAccount = TestDataFactory.createAccounts(1)[0];
        testAccount.type = 'Customer';
        insert testAccount;
        ID testAccountId = testAccount.Id;
        testAccount = [SELECT ID, Type, Account_Saturation_Percentage_Formula__c FROM Account WHERE Id =: testAccountId];
        
        Contact testContact = TestDataFactory.createContacts(1, testAccountId)[0];
        insert testContact;

        Id defaultedQueueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName =: DEFAULT_CASE_QUEUE_NAME_SUPPORT_NONPAYING][0].Id;
        
        Case testCase = TestDataFactory.createCases(1, testAccountId)[0];
        testCase.Subject = 'Customer support call from phone number';
        testCase.Reason = 'Support';
        testCase.OwnerId = defaultedQueueId;
        insert testCase;
        
        Lead testLead = TestDataFactory.createLeads(1)[0];
        testLead.Phone = '14151231234';
        testLead.LastName = 'Inbound Call';
        testLead.OwnerId = DEFAULT_LEAD_QUEUE;
        testLead.Lead_Account__c = testAccountId;
        insert testLead;
        
        Campaign testCampaign = TestDataFactory.createCampaign(1)[0];
        testCampaign.Campaign_Phone_Number__c = '15556667777';
        insert testCampaign;
    }
    
    @isTest
    static void marketingKnownExistingContact(){
        ID accountOwnerId;
        String accountOwnerDialpadId ;
        for (User u : [SELECT Id, Dialpad_Id__c
                       FROM User
                       WHERE UserType = 'Standard'
                       AND IsActive = true
                       AND Automation_User__c = false
                       AND Dialpad_Id__c != null
                       LIMIT 1])
        {
            accountOwnerId = u.Id;
            accountOwnerDialpadId = u.Dialpad_Id__c;
        }
        Account testAccount = [SELECT Id
                               FROM Account
                               LIMIT 1];
        testAccount.ownerId = accountOwnerId;
        update testAccount;
        
        setupRestRequest(ENDPOINT + 'MARKETING/US');
        
        Test.startTest();
        setupSOSLResults(false, true, false, false, true);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();

        System.assertEquals(accountOwnerDialpadId, response.target_id);

        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND createdLeadId__c = null
                        AND foundContacts__c = true
                        AND createdCampaignMemberId__c != null].isEmpty());
    }
    
    @isTest
    static void marketingUnnownCreatedLead(){
        setupRestRequest(ENDPOINT + 'MARKETING/US');
        
        delete [SELECT Id
               FROM Lead]; 

        Test.startTest();
        setupSOSLResults(false, false, false, false, true);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();

        System.assertEquals(SALES_US, response.target_id);
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND createdLeadId__c != null
                        AND createdCampaignMemberId__c != null].isEmpty());
    }
    
    @isTest
    static void marketingUnnownNoCampaign(){
        setupRestRequest(ENDPOINT + 'MARKETING/US');
        
        delete [SELECT Id
                FROM Lead]; 
        
        delete [SELECT Id
               FROM Campaign];

        Test.startTest();
        setupSOSLResults(false, false, false, false, false);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();

        System.assertEquals(SALES_US, response.target_id);
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND createdLeadId__c != null
                        AND createdCampaignMemberId__c = null].isEmpty());
    }
    
    @isTest
    static void marketingKnownExistingLead(){
        ID accountOwnerId;
        String accountOwnerDialpadId ;
        for (User u : [SELECT Id, Dialpad_Id__c
                       FROM User
                       WHERE UserType = 'Standard'
                       AND IsActive = true
                       AND Automation_User__c = false
                       AND Dialpad_Id__c != null
                       LIMIT 1])
        {
            accountOwnerId = u.Id;
            accountOwnerDialpadId = u.Dialpad_Id__c;
        }
        Account testAccount = [SELECT Id
                              FROM Account
                              LIMIT 1];
        testAccount.ownerId = accountOwnerId;
        update testAccount;
        
        setupRestRequest(ENDPOINT + 'MARKETING/US');

        Test.startTest();
        setupSOSLResults(true, false, false, true, true);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();

        System.assertEquals(accountOwnerDialpadId, response.target_id);
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND createdLeadId__c = null
                        AND foundLeads__c = true
                        AND createdCampaignMemberId__c != null].isEmpty());
    }
    
    @isTest
    static void marketingKnownExistingLeadAndCampaignMember(){
        ID accountOwnerId;
        String accountOwnerDialpadId ;
        for (User u : [SELECT Id, Dialpad_Id__c
                       FROM User
                       WHERE UserType = 'Standard'
                       AND IsActive = true
                       AND Automation_User__c = false
                       AND Dialpad_Id__c != null
                       LIMIT 1])
        {
            accountOwnerId = u.Id;
            accountOwnerDialpadId = u.Dialpad_Id__c;
        }
        Account testAccount = [SELECT Id
                              FROM Account
                              LIMIT 1];
        testAccount.ownerId = accountOwnerId;
        update testAccount;
        
        
        setupRestRequest(ENDPOINT + 'MARKETING/US');
        
        CampaignMember testCampaignMember = new CampaignMember(
            CampaignId = [SELECT Id FROM Campaign LIMIT 1][0].Id,
            LeadId = [SELECT Id FROM Lead LIMIT 1][0].Id
        );
        
        insert testCampaignMember;
        
        Test.startTest();
        setupSOSLResults(true, false, false, true, true);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();
        
        System.assertEquals(accountOwnerDialpadId, response.target_id);
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND createdLeadId__c = null
                        AND foundLeads__c = true
                        AND createdCampaignMemberId__c = null].isEmpty());
    }
    
    @isTest
    static void salesUnknown(){
        setupRestRequest(ENDPOINT + 'SALES/US');
        
        delete [SELECT Id
               FROM Lead];
        
        Test.startTest();
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();
        
        validateWithLead(SALES_US, response.target_id);
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND createdLeadId__c != null].isEmpty());
    }

    @isTest
    static void salesUnknownLeadExists(){
        ID accountOwnerId;
        String accountOwnerDialpadId ;
        for (User u : [SELECT Id, Dialpad_Id__c
                       FROM User
                       WHERE UserType = 'Standard'
                       AND IsActive = true
                       AND Automation_User__c = false
                       AND Dialpad_Id__c != null
                       LIMIT 1])
        {
            accountOwnerId = u.Id;
            accountOwnerDialpadId = u.Dialpad_Id__c;
        }
        Account testAccount = [SELECT Id
                              FROM Account
                              LIMIT 1];
        testAccount.ownerId = accountOwnerId;
        update testAccount;
        
        setupRestRequest(ENDPOINT + 'SALES/US');

        Test.startTest();
        setupSOSLResults(false, false, false, true, false);
        
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();
        
        
        System.assertEquals(accountOwnerDialpadId, response.target_id);
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND createdLeadId__c = null
                        AND foundLeads__c = true].isEmpty());
    }

    @isTest
    static void salesKnownOwnedByRep(){
        ID accountOwnerId;
        String accountOwnerDialpadId ;

        for (User u : [SELECT Id, Dialpad_Id__c
                       FROM User
                       WHERE UserType = 'Standard'
                       AND IsActive = true
                       AND Automation_User__c = false
                       AND Dialpad_Id__c != null
                       LIMIT 1])
        {
            accountOwnerId = u.Id;  
            accountOwnerDialpadId = u.Dialpad_Id__c;
        }

        Account testAccount = [SELECT Id
                              FROM Account
                              LIMIT 1];
        
        testAccount.ownerId = accountOwnerId;
        update testAccount;
        
        setupRestRequest(ENDPOINT + 'SALES/US');
        
        Test.startTest();

        setupSOSLResults(true, false, false, false, false);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();
        
        System.assertEquals(accountOwnerDialpadId, response.target_id);

        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND accountId__c != null].isEmpty());
    }
    
    @isTest
    static void salesKnownOwnedByAutomation(){
        setupRestRequest(ENDPOINT + 'SALES/US');
        
        User u = [SELECT Id
                  FROM User
                  WHERE Id = :[SELECT OwnerId
                              FROM Account
                              LIMIT 1][0].OwnerId];
        
        u.Automation_User__c = true;
        u.Employee_Number_Workday__c = 'CG'+String.valueOf(Math.random());
        update u;
        
        Test.startTest();
        setupSOSLResults(true, false, false, false, false);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();
        
        System.assertEquals(SALES_US, response.target_id);
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND accountId__c != null].isEmpty());
    }
    
    @isTest
    static void supportUnknownCaseNeeded(){
        setupRestRequest(ENDPOINT + 'SUPPORT/US');
        delete [SELECT Id FROM Case];
        Test.startTest();
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();

        Id queueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName =: DEFAULT_CASE_QUEUE_NAME_SUPPORT_UNKNOWN][0].Id;
        
        validateWithCase(SUPPORT_US, response.target_id, queueId);
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND createdCaseId__c != null
                        AND foundCases__c != true].isEmpty());
    }

    @isTest
    static void supportKnownCaseNeeded(){
        setupRestRequest(ENDPOINT + 'SUPPORT/US');
        delete [SELECT Id FROM Case];
        
        Test.startTest();
        setupSOSLResults(true, false, false, false, false);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();

        Id queueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName =: DEFAULT_CASE_QUEUE_NAME_SUPPORT_NONPAYING][0].Id;
        
        validateWithCase(SUPPORTNONPAYING_US, response.target_id, queueId);   
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND accountId__c != null
                        AND createdCaseId__c != null
                       AND foundCases__c != true].isEmpty());
    }
    
    @isTest
    static void supportCaseExists(){
        setupRestRequest(ENDPOINT + 'SUPPORT/US');
        
        Test.startTest();
        setupSOSLResults(true, false, true, false, false);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();

        Id queueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName =: DEFAULT_CASE_QUEUE_NAME_SUPPORT_NONPAYING][0].Id;
        
        validateWithCase(SUPPORTNONPAYING_US, response.target_id, queueId); 
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND accountId__c != null
                        AND createdCaseId__c = null
                        AND foundCases__c = true].isEmpty());
    }

    @isTest
    static void billingKnownCaseNeeded(){
        setupRestRequest(ENDPOINT + 'BILLING/US');
        delete [SELECT Id FROM Case];
        
        Test.startTest();
        setupSOSLResults(true, false, false, false, false);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();

        Id queueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName =: DEFAULT_CASE_QUEUE_NAME_BILLING][0].Id;
        
        validateWithCase(BILLING_US, response.target_id, queueId); 
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND accountId__c != null
                        AND createdCaseId__c != null
                        AND foundCases__c != true].isEmpty());
    }
    
    @isTest
    static void collectionsKnownCaseNeeded(){
        setupRestRequest(ENDPOINT + 'COLLECTIONS/US');
        delete [SELECT Id FROM Case];
        
        Test.startTest();
        setupSOSLResults(true, false, false, false, false);
        RestDialpadCallRouter.Response response = RestDialpadCallRouter.doPost();
        Test.stopTest();

        Id queueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName =: DEFAULT_CASE_QUEUE_NAME_COLLECTIONS][0].Id;
        
        validateWithCase(COLLECTIONS_US, response.target_id, queueId); 
        
        System.assert(![SELECT Id
                        FROM Dialpad_Router_Log__c
                        WHERE externalNumber__c = '+14151231234'
                        AND accountId__c != null
                        AND createdCaseId__c != null
                        AND foundCases__c != true].isEmpty());
    }
    
    @isTest
    static void completeFallBack(){
        setupSOSLResults(true, true, false, false, false);
        
        DialpadUtilities.ExpandedCallPayload expandedPayload = new DialpadUtilities.ExpandedCallPayload();
        expandedPayload.path = 'badPath';
        expandedPayload.phoneSearches = '5555555555';
        expandedPayload.region = 'US';
        
        DialPadCallRouterHandler handlerObject = new DialPadCallRouterHandler(expandedPayload);
        
        handlerObject.findRoutingId();
    }
    
    //- - - Instance variables, methods and collections used in test methods instantiated below - - - 
    
    public static void validateWithLead(String expectedTargetId, String actualTargetId){
        ID ownerId = [SELECT OwnerId
                      FROM Lead
                      WHERE LastName = 'Inbound Call'][0].OwnerId;
        
        System.assertEquals(ownerId, DEFAULT_LEAD_QUEUE);
        System.assertEquals(expectedTargetId, actualTargetId);
    }
    
    public static void validateWithCase(String expectedTargetId, String actualTargetId, Id queueId){

        ID ownerId = [SELECT OwnerId
                      FROM Case
                      WHERE Subject LIKE 'Customer support call from phone number%'][0].OwnerId;
        
        System.assertEquals(ownerId, queueId);
        System.assertEquals(expectedTargetId, actualTargetId);
    }
    
    private static final RestDialpadCallRouter.rawPayloadWrap REST_REQUEST = new RestDialpadCallRouter.rawPayloadWrap(
        '+15556667777',
        null,
        'testContactType',
        'testContactId',
        'testCallId',
        '2000-01-01',
        '+14151231234'
    );

    private static void setupRestRequest(String uri){     
        RestContext.request = new RestRequest();
        RestContext.request.requestUri = uri;
        RestContext.request.requestBody = blob.valueOf(JSON.serialize(REST_REQUEST));
    }
    
    private static void setupSOSLResults(Boolean addAccount, Boolean addContact, Boolean addCase, Boolean addLead,
                                        Boolean addCampaign)
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
        
        ID testLeadId;
        for (Lead l : [SELECT Id
                       FROM Lead
                       LIMIT 1])
        {
            testLeadId = l.Id;
        }

        ID testCampaignId;
        for (Campaign ca : [SELECT Id
                            FROM Campaign
                            LIMIT 1])
        {
            testCampaignId = ca.Id;
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
        
        if (addLead){
            searchResultIds.add(testLeadId);
        }
        
        if (addCampaign){
            searchResultIds.add(testCampaignId);
        }
        
        Test.setFixedSearchResults(searchResultIds);
    }
    
    private static void setupCampaignSOSLResults(){
        Test.setFixedSearchResults(new List<ID>{[SELECT Id FROM Campaign LIMIT 1].Id});
    }
    
    private static final String ENDPOINT = '/callrouter/';
}