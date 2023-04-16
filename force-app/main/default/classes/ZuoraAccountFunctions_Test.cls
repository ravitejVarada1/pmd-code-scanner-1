@isTest
public class ZuoraAccountFunctions_Test {
    @testsetup 
    static void testSetup(){
        List<Account> accList = TestDataFactory.createAccounts(1);
        insert accList;
        List<Zuora__CustomerAccount__c> zacList = TestDataFactory.createZuoraAccount(1,accList[0]);
        insert zacList;
        Zuora__CustomerAccount__c zac = zacList[0];
        zac.Zuora__Status__c = 'Cancelled';
        update zac;
	}
	static testMethod void checkTrigger(){
		Account ac = [SELECT ID, Name ,Billing_Account_Zuora__r.Name FROM Account WHERE BillingCountryCode = 'US'];
        system.assertNotEquals(ac.Billing_Account_Zuora__r.Name, 'testZac');
	}	

}