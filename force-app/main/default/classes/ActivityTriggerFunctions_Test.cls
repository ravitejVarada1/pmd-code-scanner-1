/**
 * https://cargurus.atlassian.net/browse/BR-3942
 * Log last activity by the account owner
 */
 
@isTest
public without sharing class ActivityTriggerFunctions_Test {

    //create user - to prevent duplicate uesrname errors during releases, 
    //create a unique username
    static String uniqueName = UserInfo.getOrganizationId();

    @testSetup
    static void testSetup(){
        List<Profile> profiles = [SELECT Id, Name FROM Profile WHERE Name = 'Sales User'];
        
        User testuser = TestDataFactory.createUser(true, profiles.get(0));
        testuser.Username = uniqueName + '@test' + uniqueName + '.org';
        insert testuser;
        Account testAccount = TestDataFactory.createAccounts(1)[0];
        testAccount.ownerId = testuser.Id;
        insert testAccount;

        List<String> teamRole = new List<String>{'Account Manager'};
        List<Id> userList = new List<Id>{testuser.Id};    
        List<AccountTeamMember> teamMemberList = TestDataFactory.createAccountTeamMember(testAccount.Id, TeamRole, userList);
        insert teamMemberList;

        //To satisfy ownership rules, insert both Acc and Opp as this test user
        System.runAs(testuser) {
            ID accountId = testAccount.Id;
            
            Contact testContact = TestDataFactory.createContacts(1, accountId)[0];
            insert testContact;

            Opportunity opp = new Opportunity(
                Name = 'test opp',
                StageName = 'Discover/Qualify',
                AccountId = accountId,
                CloseDate = Date.today(),
                OwnerId = testuser.Id
            );
            insert opp;
        }
    }

    @isTest
    public static void createTaskTest() {
        //Find the test user
        String uname = uniqueName + '@test' + uniqueName + '.org';
        User u = [SELECT Id FROM User WHERE Username = :uname];

        Account acc = [SELECT Id, OwnerId FROM Account LIMIT 1];

        Contact ct = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        
        System.runAs(u) {
            Task tsk =  TestDataFactory.createTasks(1, ct.Id)[0];
            tsk.WhatId = acc.Id;
            tsk.Status = 'Completed';
            tsk.OwnerId = u.Id;
            tsk.Type = 'Call';
            tsk.TaskSubtype = 'Call';
            insert tsk;
        }

        Test.stopTest();
        
        Account act = [SELECT Id, Last_Activity_Account_Owner__c, Last_Activity_By_Account_Manager__c FROM Account LIMIT 1];
        System.assert(act.Last_Activity_Account_Owner__c != null);
        System.assert(act.Last_Activity_By_Account_Manager__c != null); //EA-131
    }

    @isTest
    public static void createEventTest() {
        //Find the test user
        String uname = uniqueName + '@test' + uniqueName + '.org';
        User u = [SELECT Id FROM User WHERE Username = :uname];

        Account acc = [SELECT Id, OwnerId FROM Account LIMIT 1];

        Contact ct = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        
        System.runAs(u) {
            Event evt =  new Event(
                WhatId = acc.Id,
                Type = 'Email',
                OwnerId = u.Id,
                ActivityDateTime = Datetime.now(),
                DurationInMinutes = 5
            );
            insert evt;
        }

        Test.stopTest();
        
        Account act = [SELECT Id, Last_Activity_Account_Owner__c,Last_Activity_By_Account_Manager__c FROM Account LIMIT 1];
        //BR-5317 should be null since this field will only be updated for a Task of type "Call"
        System.assert(act.Last_Activity_Account_Owner__c == null);
        System.assert(act.Last_Activity_By_Account_Manager__c == null); //EA-131
    }
}
