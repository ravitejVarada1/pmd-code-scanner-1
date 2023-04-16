@isTest
public class AccountTriggerFunctionsTest {
@testsetup 
    static void testSetup(){
        Id dealerAccountRecordType= Utilities.getRecordTypeId('Account','Dealer_Account');
		Account acc = new Account();
        acc.name = 'TestAcc';
        acc.recordTypeID = dealerAccountRecordType;
        acc.Account_Status__c ='Pending';
        insert acc;
	}
    static testMethod void checkAccTrigger(){
        List<Case> caseList = [SELECT ID, AccountID FROM Case limit 1];
        system.assertEquals(1, caseList.size()); 
	}	
}