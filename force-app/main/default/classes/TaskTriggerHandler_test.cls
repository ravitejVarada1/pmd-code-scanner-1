/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        01/07/2021
* modified:       01/07/2021
* created jira:   BR-363
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class TaskTriggerHandler_test {
    
    @testSetup
    static void testSetup(){
        Account testAccount = TestDataFactory.createAccounts(1)[0];
        insert testAccount;
        ID accountId = testAccount.Id;
        
        Contact testContact = TestDataFactory.createContacts(1, accountId)[0];
        insert testContact;
        
        Case testCase = TestDataFactory.createCases(1, null)[0];
        testCase.Call_Id__c = '1234';
        testCase.Dialpad_Phone__c = '555-666-7777';
        testCase.AccountId = accountId;
        testCase.Master_Call_Id__c = '5555';
        insert testCase;

        Case testCase2 = TestDataFactory.createCases(1, accountId)[0];
        testCase2.Reason = 'Digital Deal Enrollment';
        testCase2.Origin = 'Onboarding';
        testCase2.Subject = 'Digital Deal Enrollment Survey Data';
        insert testCase2;

        Task t = new Task(
            whatId = testCase2.id,
            subject = 'Test Task',
            Priority = 'Normal',
            Status = 'Open'
        );
        insert t;

        Lead testLead = TestDataFactory.createLeads(1)[0];
        testLead.Call_Id__c = '1234';
        testLead.Phone = '555-666-7777';
        testLead.Master_Call_Id__c = '5555';
        insert testLead;
        
        Dialpad_Call_Event_Log__c log = TestDataFactory.createDialpadCallEventLogs(1)[0];
        insert log;
    }
    
    @isTest static void activityAlreadyMatched(){
        Id testCaseId = [SELECT ID 
                         FROM Case 
                         WHERE Call_Id__c = '1234'
                         LIMIT 1][0].Id;
        
        insertTask(testCaseId);
        
        validateCaseMatch();
    }
    
    @isTest
    static void activityLeadWithPhone(){
        delete [SELECT Id FROM Case];
        
        Lead testLead = [SELECT Id FROM Lead LIMIT 1][0];
        testLead.Master_Call_Id__c = '1111';
        update testLead;
        
        Test.setFixedSearchResults(new List<ID>{testLead.Id});
        
        insertTask();
        
        validateLeadMatch();
    }
    
    @isTest
    static void activityCaseWithPhone(){
        delete [SELECT Id FROM Lead];
        
        Case testCase = [SELECT Id 
                         FROM Case 
                         WHERE Master_Call_Id__c = '5555'
                         LIMIT 1][0];
        testCase.Master_Call_Id__c = '1111';
        testCase.AccountId = null;
        update testCase;
        
        Test.setFixedSearchResults(new List<ID>{testCase.Id});
        
        insertTask();
        
        validateCaseMatch();
    }
    
    
    @isTest
    static void activityCaseOnAccount(){
        delete [SELECT Id FROM Lead][0];
        
        Case testCase = [SELECT Id 
                         FROM Case 
                         WHERE Master_Call_Id__c = '5555'
                         LIMIT 1][0];
        
        testCase.Master_Call_Id__c = '1111';
        update testCase;
        
        insertTask();
        
        validateCaseMatch();
    }
    
    @isTest
    static void activityCaseMatchOnInsert(){
        delete [SELECT Id FROM Lead][0];
        
        Case c = [SELECT Id
                  FROM Case
                  WHERE Master_Call_Id__c = '5555'
                  LIMIT 1][0];
        
        c.AccountId = null;
        
        update c;
        
        insertTask();
        
        validateCaseMatch();
        
        System.assertNotEquals(null, [SELECT AccountId
                                      FROM Case
                                      WHERE Master_Call_Id__c = '5555'
                                      LIMIT 1][0].AccountId);
    }
    
    @isTest
    static void activityLeadMatchOnInsert(){
        delete [SELECT Id 
                FROM Case
                WHERE Master_Call_Id__c = '5555'][0];
        
        insertTask();
        
        validateLeadMatch();
    }

    @isTest
    static void checkForEmailType(){
        Task tk = new Task(
            subject = 'Email: Test subject',
            type = NULL
        );
        insert tk;
// creates a task with the desired perameters of the if statement 
        List<Task> tskListQuery = [
            SELECT Type
            FROM Task
            WHERE subject = 'Email: Test subject'
          ];
//query the list for the task created above
          System.assert(!tskListQuery.isEmpty()); 
          tk = tskListQuery[0]; 
          System.assertEquals(tk.type,'Email'); 


    }

    @isTest
    static void initializeActivityType(){
        Task tsk = new Task(
            subject = 'Test Task Subject', 
            activityDate = date.today(),
            Type = 'Call'
        );
        insert tsk;

        List <Task> taskListQuery = [
            SELECT Type, Activity_Type__c
            FROM Task
            WHERE subject = 'Test Task Subject'
        ];
        
        System.assert(!taskListQuery.isEmpty());
        tsk = taskListQuery[0];
        System.assertEquals(tsk.type, tsk.Activity_Type__c);

        // test update task type part
        tsk.Type = 'Email';
        update tsk;

        // query list again
        taskListQuery = [
            SELECT Type, Activity_Type__c
            FROM Task
            WHERE subject = 'Test Task Subject'
        ];
        tsk = taskListQuery[0];
        System.assertEquals(tsk.type, tsk.Activity_Type__c);
    }

    @isTest
    static void assertTaskFieldPopulation() {
        Task t = [SELECT Id, Related_Account__c, WhatId FROM Task WHERE Subject = 'Test Task'];
        Case c = [SELECT Id, AccountId FROM Case WHERE Id = :t.WhatId];
        System.assertEquals(t.Related_Account__c, c.AccountId);
    }
    
    //- - - Instance variables, methods and collections used in test methods instantiated below - - - 

    private static void validateCaseMatch(){
        Integer tasksWithCaseWhatId = [SELECT COUNT()
                                       FROM Task
                                       WHERE WhatId = :[SELECT Id
                                                        FROM Case
                                                        WHERE Call_Id__c = '1234'
                                                        LIMIT 1][0].Id];
        
        System.assertEquals(1, tasksWithCaseWhatId);
    }
    
    private static void validateLeadMatch(){
        Integer tasksWithLeadWhatId = [SELECT COUNT()
                                       FROM Task
                                       WHERE WhoId = :[SELECT Id
                                                       FROM Lead
                                                       WHERE Call_Id__c = '1234'
                                                       LIMIT 1][0].Id];
        
        System.assertEquals(1, tasksWithLeadWhatId);
    }
    
    private static void insertTask(){
        insertTask(null);
    }
    
    private static void insertTask(ID whatId){
        ID contactId = [SELECT Id FROM Contact LIMIT 1][0].Id;
        
        Task testTask = TestDataFactory.createTasks(1, contactId)[0];
        testTask.Dialpad__IsDialpadCallLog__c = true;
        testTask.Dialpad__CallId__c = '5678';
        testTask.CallType = 'Inbound';
        testTask.WhatId = whatId;
        testTask.WhoId = contactId;
  

        Test.startTest();
        insert testTask;
        Test.stopTest();
    }

    @isTest static void updateFirstActivity(){
        Id testCaseId = [SELECT ID 
                         FROM Case 
                         WHERE Call_Id__c = '1234'
                         LIMIT 1][0].Id;
        
        insertTask(testCaseId);
        
    }
    @isTest
    private static void testUpdateCaseStatus(){
        
        Test.startTest();
        Case testCase = TestDataFactory.createCases(1, null)[0];
        testCase.Status = 'New';
        testCase.RecordTypeId = Utilities.getrecordTypeId('Case', 'Integrity');
        insert testCase;
        
        Task tsk = new Task(
        subject = 'Pending Investigation Alert', 
        WhatId = testCase.Id );
        insert tsk;
        tsk.Status = 'Completed';
        Update tsk;
        
        Test.stopTest();
       System.assertEquals(testCase.Status,'New');
    }
}