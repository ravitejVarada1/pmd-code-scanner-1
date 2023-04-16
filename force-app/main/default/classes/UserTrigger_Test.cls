/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         amitul
* modifiedBy:     amitul
* created:        04/05/2021
* modified:       04/05/2021
* created jira:   BR-864
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class UserTrigger_Test {

    @testsetup static void testData() {
        Profile p = [SELECT Id 
                     FROM Profile 
                     WHERE Name='Standard User'];
      	User u = TestDataFactory.createUser(true, p); 
      	insert u;
        User u1 = TestDataFactory.createUser(true, p);
        u1.Username = 'standarduser2345@testorg.com';
        u1.ManagerId = u.id;
      	insert u1;
      
    }

    static testMethod void testUserTriggerFunctions() {
		User u = [SELECT Id, IsActive , Termination_Date__c
                  FROM User 
                  WHERE Username = 'standarduser234@testorg.com' 
                  LIMIT 1];
        u.IsActive = false;
        update u;
        Test.startTest();
        u.IsActive = true;
        update u;
        Test.stopTest();
        User u1 = [SELECT id,Termination_Date__c 
                   FROM User 
                   LIMIT 1];
        system.assertEquals(null, u1.Termination_Date__c);
       
    } 
    public static testMethod void testBatchFreezeUser() {
        User u = [SELECT Id, IsActive , Termination_Date__c
                  FROM User 
                  WHERE Username = 'standarduser234@testorg.com' 
                  LIMIT 1];
        
        u.Termination_Date__c=System.today();
        update u;
  
        Test.startTest();
        database.executeBatch(new Batch_FreezeUser());
        Test.stopTest();
        User u1 = [SELECT id,Termination_Date__c 
                   FROM User 
                   WHERE Username = 'standarduser234@testorg.com' 
                   LIMIT 1];
        UserLogin uLogin1 = [SELECT Id, IsFrozen 
                             FROM UserLogin 
                             WHERE UserId =: u1.id];
        system.assertEquals(true,uLogin1.IsFrozen);
            
    }
    
    public static testMethod void testcheckFinalApproverCondition(){
        test.startTest();
         User u = [SELECT Id, IsActive , Is_Final_Approver__c
                  FROM User 
                  WHERE Username = 'standarduser2345@testorg.com' 
                  LIMIT 1];
        u.Is_Final_Approver__c = true;
        update u;
        test.stopTest();
    }
}