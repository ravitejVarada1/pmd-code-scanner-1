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
public class DialpadTaskRelationBatch_test {
    @testSetup
    static void testSetup(){
        Case testCase = TestDataFactory.createCases(1, null)[0];
        testCase.Call_Id__c = '1234';
        testCase.Master_Call_Id__c = '5555';
        insert testCase;
        
        Lead testLead = TestDataFactory.createLeads(1)[0];
        testLead.Call_Id__c = '1234';
        testLead.Master_Call_Id__c = '5555';
        insert testLead;
        
        Dialpad_Call_Event_Log__c log = TestDataFactory.createDialpadCallEventLogs(1)[0];
        insert log;
        
        Task testTask = TestDataFactory.createTasks(1, null)[0];
        testTask.Dialpad__IsDialpadCallLog__c = true;
        testTask.Dialpad__CallId__c = '5678';
        testTask.CallType = 'Inbound';
        
        TaskTriggerFunctions.skipDialpadMatch = true;
        
        insert testTask;
    }

    @isTest
    static void testBatchWithCase(){
        Delete [SELECT Id FROM Lead][0];
        
        Test.startTest();
        DialpadTaskRelationBatch batch = new DialpadTaskRelationBatch();
        Database.executeBatch(batch);
        Test.stopTest();

        validateCaseMatch();
    }

    @isTest
    static void testBatchWithLead(){
        Test.startTest();
        DialpadTaskRelationBatch batch = new DialpadTaskRelationBatch();
        Database.executeBatch(batch);
        Test.stopTest();
        validateLeadMatch();
    }

    @isTest
    static void testSchedule(){
        Test.startTest();
        String cronString = Utilities.getCronExpressionMinutesFromNow(10);
        System.schedule('testSchedule_DialpadTaskRelationBatch', cronString, 
                        new DialpadTaskRelationBatch());
        Test.stopTest();
    }
    
    @isTest
    static void testSetConstructor(){
        Set<ID> taskIds = new Map<ID,Task>([SELECT Id FROM TASK]).keySet();
        
        Test.startTest();
        DialpadTaskRelationBatch batch = new DialpadTaskRelationBatch(taskIds);
        Database.executeBatch(batch);
        Test.stopTest();
        
        validateLeadMatch();
    }
    
    @isTest
    static void testStringConstructor(){
        Test.startTest();
        DialpadTaskRelationBatch batch = new DialpadTaskRelationBatch('7');
        Database.executeBatch(batch);
        Test.stopTest();
        
        validateLeadMatch();
    }

    //- - - Instance variables, methods and collections used in test methods instantiated below - - - 

    private static void validateCaseMatch(){
        Integer tasksWithCaseWhatId = [SELECT COUNT()
                                       FROM Task
                                       WHERE WhatId IN :[SELECT Id
                                                        FROM Case]];
        
        System.assertEquals(1, tasksWithCaseWhatId);
    }
    
    private static void validateLeadMatch(){
        Integer tasksWithLeadWhatId = [SELECT COUNT()
                                       FROM Task
                                       WHERE WhoId = :[SELECT Id
                                                       FROM Lead
                                                       LIMIT 1][0].Id];
        
        System.assertEquals(1, tasksWithLeadWhatId);
    }

}