@IsTest 
public class BatchUpdateFinalApproverTest {
    @testsetup static void testData() {
        Profile p = [SELECT Id 
                     FROM Profile 
                     WHERE Name = 'Standard User'];
      	User u = TestDataFactory.createUser(true, p); 
      	insert u;
        User u1 = TestDataFactory.createUser(true, p);
        u1.Username = 'testFinalApprover@gmail.com';
        u1.ManagerId = null;
      	insert u1;
      
    }
    
    public static testMethod void testMethodFinalApproverCondition(){
        user u2 = [SELECT ID, ManagerID, Is_Final_Approver__c FROM user WHERE username = 'testFinalApprover@gmail.com'];
        u2.ManagerID = null;
        U2.Is_Final_Approver__c = false;
        update u2;
        database.executeBatch(new BatchUpdateFinalApprover());
        System.schedule('BatchUpdateFinalApprover', '0 0 1 * * ?', new BatchUpdateFinalApprover());
		
    }

}