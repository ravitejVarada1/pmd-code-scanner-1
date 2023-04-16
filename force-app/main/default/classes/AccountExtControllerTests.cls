@isTest
private class AccountExtControllerTests {

    @testSetup
    static void testSetup(){

        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        Account dealerAccount = TestDataFactory.createSingleAccount(dealerAccountRecordTypeId);
        dealerAccount.Name = 'DEALER';
        insert dealerAccount;
    }
    
    testMethod static void testSubmit() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        AccountExtController con = new accountExtController(new ApexPages.StandardController(account));
        con.onSubmit();
        account = [SELECT ApprovalStatus__c FROM Account WHERE Id = :account.Id LIMIT 1];
        Test.stopTest();
        
        System.assertEquals('Approved', account.ApprovalStatus__c);
    }
    
    testMethod static void testRecall() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        accountExtController con = new accountExtController(new ApexPages.StandardController(account));
        con.onRecall();
        account = [SELECT ApprovalStatus__c FROM Account WHERE Id = :account.Id LIMIT 1];
        Test.stopTest();
        
        System.assertEquals('Recalled', account.ApprovalStatus__c);
    }
}
