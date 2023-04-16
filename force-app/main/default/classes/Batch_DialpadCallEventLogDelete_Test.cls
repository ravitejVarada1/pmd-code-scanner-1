/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        09/27/2021
* modified:       09/27/2021
* created jira:   BR-4209
* purpose:  	  Tests batch that deletes Dialpad Call Event Logs more than 7 days old. Tests both
* - constructors and the schedulable method
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
@isTest
public class Batch_DialpadCallEventLogDelete_Test {
    
    //Just create two logs - one that will get deleted by the batch (8 days old), 
    //and one that will not (7 days old)
    @testSetup
    static void createLog(){
        Date todaysDate = Date.today();
        
        List<Dialpad_Call_Event_Log__c> testLogs = TestDataFactory.createDialpadCallEventLogs(2);
        insert testLogs;
        
        Test.setCreatedDate(testLogs[0].Id, todaysDate-8);
        Test.setCreatedDate(testLogs[1].Id, todaysDate-7);
    }
    
    //Test schedulable
    @isTest
    static void testBatchSchedule(){
        Test.startTest();
        
        String cronString = Utilities.getCronExpressionMinutesFromNow(10);
        
        System.schedule(
            'testSchedule_Batch_DialpadCallEventLogDelete', 
            cronString, 
            new Batch_DialpadCallEventLogDelete()
        );
        
        Test.stopTest();
    }
    
    //Test base constructor. 1 log should be deleted, as cutOffDate is set to 7./
    @isTest
    static void testBatchBaseConstructor(){
        Test.startTest();
        Database.executeBatch(new Batch_DialpadCallEventLogDelete());
        Test.stopTest();
        
        
        System.assertEquals(1, [SELECT Count()
                                FROM Dialpad_Call_Event_Log__c]);
    }
    
    //Test date constructor. 2 logs should be deleted, as cutOffDate is passed in as Date.today()-6
    @isTest
    static void testBatchDateConstructor(){
        Test.startTest();
        Database.executeBatch(new Batch_DialpadCallEventLogDelete(Date.today()-6));
        Test.stopTest();
        
        
        System.assertEquals(0, [SELECT Count()
                                FROM Dialpad_Call_Event_Log__c]);
    }

}