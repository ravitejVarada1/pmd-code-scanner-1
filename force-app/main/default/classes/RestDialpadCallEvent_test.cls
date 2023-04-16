/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        01/07/2021
* modified:       01/07/2021
* created jira:   BR-360
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class RestDialpadCallEvent_test {
    
    private static final String NAME_STRING = 'INBOUND%';
    
    @testSetup
    public static void testSetup(){
        Account testAccount = TestDataFactory.createAccounts(1)[0];
        insert testAccount;
        ID testAccountId = testAccount.Id;
        
        Case testCase = TestDataFactory.createCases(1, testAccountId)[0];
        insert testCase;
        ID testCaseId = testCase.Id;
        
        Dialpad_Router_Log__c theLog = new Dialpad_Router_Log__c(
            masterCallId__c = '1234',
            createdCaseId__c = testCaseId
        );
        insert theLog;
        
    }

    @isTest
    public static void inboundCallEvent(){
        
        setupRestRequest();
        Test.startTest();
        RestDialpadCallEvent.doPost();
        Test.stopTest();
        
        Integer numDialpadCallEventLogs = [SELECT Count()
                                           FROM Dialpad_Call_Event_Log__c 
                                           WHERE Name LIKE :NAME_STRING];
        
        System.assertEquals(1, numDialpadCallEventLogs, 'Expected a call event log to be created');
    }
    
    @isTest
    public static void inboundConnectedCallSuccess(){
        REST_REQUEST.state = 'CONNECTED';
        


        setupRestRequest();
        
        Test.startTest();
        RestDialpadCallEvent.doPost();
        Test.stopTest();
        
        Integer numDialpadCallEventLogs = [SELECT Count()
                                           FROM Dialpad_Call_Event_Log__c 
                                           WHERE Name LIKE :NAME_STRING];
        
        System.assertEquals(1, numDialpadCallEventLogs, 'Expected a call event log to be created');
    }
    
     @isTest
    public static void inboundConnectedCallSuccessExistingCase(){
        REST_REQUEST.state = 'CONNECTED';

        Dialpad_Router_Log__c theLog = [SELECT Id, createdCaseId__c
                                        FROM Dialpad_Router_Log__c
                                        LIMIT 1];
        
        
        theLog.foundCaseIds__c = theLog.createdCaseId__c;
        theLog.createdCaseId__c = null;
        update theLog;

        setupRestRequest();
        
        Test.startTest();
        RestDialpadCallEvent.doPost();
        Test.stopTest();
        
        Integer numDialpadCallEventLogs = [SELECT Count()
                                           FROM Dialpad_Call_Event_Log__c 
                                           WHERE Name LIKE :NAME_STRING];
        
        System.assertEquals(1, numDialpadCallEventLogs, 'Expected a call event log to be created');
    }
    
    @isTest
    public static void inboundConnectedCallEventFailure(){
        REST_REQUEST.state = 'CONNECTED';
        setupRestRequest();
        
        Test.startTest();
        DialpadCallEventHandler.testStatusCode = 404;
        RestDialpadCallEvent.doPost();
        Test.stopTest();
        
        Integer numDialpadCallEventLogs = [SELECT Count()
                                           FROM Dialpad_Call_Event_Log__c 
                                           WHERE Name LIKE :NAME_STRING];
        
        System.assertEquals(1, numDialpadCallEventLogs, 'Expected a call event log to be created');
    }
    
    @isTest
    public static void inboundConnectedCallEventNoLog(){
        REST_REQUEST.state = 'CONNECTED';
        setupRestRequest();
        
        delete [SELECT Id
               FROM Dialpad_Router_Log__c];
        
        Test.startTest();
        RestDialpadCallEvent.doPost();
        Test.stopTest();
        
        Integer numDialpadCallEventLogs = [SELECT Count()
                                           FROM Dialpad_Call_Event_Log__c 
                                           WHERE Name LIKE :NAME_STRING];
        
        System.assertEquals(1, numDialpadCallEventLogs, 'Expected a call event log to be created');
    }
    
    @isTest
    public static void outboundCallEvent(){
        REST_REQUEST.direction = 'OUTBOUND';
        setupRestRequest();
        
        Test.startTest();
        RestDialpadCallEvent.doPost();
        Test.stopTest();
        
        Integer numDialpadCallEventLogs = [SELECT Count()
                                           FROM Dialpad_Call_Event_Log__c];
        
        System.assertEquals(0, numDialpadCallEventLogs, 'Expected no call event logs to be created');
    }
    
    public static RestDialpadCallEvent.rawPayloadWrap REST_REQUEST 
        = new RestDialpadCallEvent.rawPayloadWrap(
            '1234',
            '5678',
            '555666-7777',
            'inbound',
            'calling'
        );
    
    public static void setupRestRequest(){   
        RestDialpadCallEvent.Target target = new RestDialpadCallEvent.Target();
        target.type_Z = 'User';
        target.id = [SELECT Dialpad_Id__c
                     FROM User
                     WHERE IsActive = true
                     AND Dialpad_Id__c != null
                     LIMIT 1][0].Dialpad_Id__c;
        
        REST_REQUEST.target = target;
        
        RestContext.request = new RestRequest();
        RestContext.request.requestUri = ENDPOINT;
        RestContext.request.requestBody = blob.valueOf(JSON.serialize(REST_REQUEST));
    }
    
    private static final String ENDPOINT = '/callevent/';

}