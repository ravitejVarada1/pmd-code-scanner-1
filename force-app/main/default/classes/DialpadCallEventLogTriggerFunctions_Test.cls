@isTest
public class DialpadCallEventLogTriggerFunctions_Test {

    @TestSetup
    static void makeData(){

        List<Account> testConsumerAccount = TestDataFactory.createPersonalAccounts(1);
        insert testConsumerAccount;

        Case testCase = TestDataFactory.createCSCase(1, testConsumerAccount)[0];
        testCase.Master_Call_Id__c = '55555789';
        testCase.Dialpad_Phone__c = '+15556667777';
        insert testCase;

        
        List<Task> testTasks = TestDataFactory.createTasks(2, null);

        testTasks[0].Dialpad__IsDialpadCallLog__c = true;
        testTasks[0].Dialpad__CallId__c = '5678';
        testTasks[0].Dialpad_Caller_Phone__c = '15556667777';
        testTasks[0].Subject = 'With Caller Phone';
        testTasks[0].CallType = 'Inbound';
        testTasks[0].Dialpad_Matched__c = false;


        //Wam transfer second agent task without caller Phone
        testTasks[1].Dialpad__IsDialpadCallLog__c = true;
        testTasks[1].Dialpad__CallId__c = '5678';
        testTasks[1].Subject = 'Without Caller Phone';
        testTasks[1].CallType = 'Inbound';
        testTasks[1].Dialpad_Matched__c = false;
        
        insert testTasks;
        
        }

    static testMethod void testpopulateMissingDialpadCallerPhone() {
        Id dialpadCaseId = [SELECT Id FROM Case WHERE Dialpad_Phone__c = '+15556667777' LIMIT 1].Id;

        Test.setFixedSearchResults(new List<ID>{dialpadCaseId});
        Test.startTest(); 
 
        Dialpad_Call_Event_Log__c testLog = TestDataFactory.createDialpadCallEventLogs(1)[0];
        testLog.State__c = 'CONNECTED';
        testLog.External_Number__c = '15556667777';
        insert testLog;

        Dialpad_Call_Event_Log__c createdLog = [SELECT Id, createddate, Call_Id__c, External_Number__c FROM Dialpad_Call_Event_Log__c WHERE Call_Id__c = '5678' LIMIT 1];
        Task noCallerPhoneTask = [SELECT Id, createdDate, whatId, Dialpad_Caller_Phone__c FROM Task WHERE Dialpad__CallId__c =: createdLog.Call_Id__c AND Subject = 'Without Caller Phone' LIMIT 1];
       
        DateTime logCreatedDate = createdLog.createdDate;
        DateTime taskCreatedDate = noCallerPhoneTask.createdDate;

        Test.stopTest();
        
        System.assertEquals(logCreatedDate >= taskCreatedDate, true);
        System.assertEquals(noCallerPhoneTask.Dialpad_Caller_Phone__c, createdLog.External_Number__c);
        System.assertEquals(noCallerPhoneTask.whatId, dialpadCaseId);
    }    
}
