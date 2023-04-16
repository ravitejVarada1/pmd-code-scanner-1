@IsTest
public class ContactTriggerFunctions_Test {

    @testsetup 
    static void testData() {
        List<Account> accs = TestDataFactory.createAccounts(1);
        accs[0].Name = 'Account 1';
        accs[0].BillingCountryCode = 'US';
        insert accs;

        List<Contact> contactList1 = TestDataFactory.createContacts(1, accs[0].id);
        insert contactList1;
        contactList1[0].Code_of_Conduct_Violation__c = 'Tier 1';
        update contactList1;

    }
    
    static testMethod void setCurrencyCodeTest() {
        Account a = [SELECT id,BillingCountry,CurrencyIsoCode FROM Account LIMIT 1];
        
        Test.startTest();
        Contact c = [SELECT id,accountId,CurrencyIsoCode FROM Contact LIMIT 1];
        system.assertEquals(a.CurrencyIsoCode, c.CurrencyIsoCode);
      
        Test.stopTest();
    }

    @isTest 
    static void checkConductViolationSingleContact(){
    
        contact ctWithViolation = [SELECT accountId, Code_of_Conduct_Violation__c FROM Contact WHERE Code_of_Conduct_Violation__c != NULL LIMIT 1]; 
    
        account account1 = [SELECT id, Code_of_Conduct_Chkbox__c FROM Account WHERE id =: ctWithViolation.AccountID LIMIT 1]; 

        Test.startTest();
        system.assertEquals(true, account1.Code_of_Conduct_Chkbox__c);

        Test.stopTest();
    }

    @isTest
    static void checkCVViolationRemoved(){
    
       //test 2
        
       

        //query contact
        contact ctRemoved = [SELECT accountId, Code_of_Conduct_Violation__c FROM Contact WHERE Code_of_Conduct_Violation__c != NULL LIMIT 1];
        ctRemoved.Code_of_Conduct_Violation__c = NULL;
        update ctRemoved;

        // update contaact with violation
        //assert violation
        Test.startTest();
        account account1 = [SELECT id, Code_of_Conduct_Chkbox__c FROM Account WHERE id =: ctRemoved.AccountID LIMIT 1];
        system.assertEquals(account1.Code_of_Conduct_Chkbox__c, false);
        // remove violation from contact
        // assert violation
        Test.stopTest();
    }
    
    @isTest
    static void testContactDelete() {

        Profile p = [SELECT Id FROM Profile WHERE Name='Consumer and Dealer Support Rep'];
        User userSobject = TestDataFactory.createUser(true,p);
        insert userSobject;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'AccountMerge'];
        insert new PermissionSetAssignment(AssigneeId = userSobject.id, PermissionSetId = ps.Id);

        String errorMessage = 'You do not have permissions to delete contacts. Contact your administrator for help.';

        System.runAs(userSobject) {
            try
                {
                    Account testAccount1 = [SELECT Id from Account LIMIT 1];
                    List<Contact> contactToDelete = TestDataFactory.createContacts(1, testAccount1.id);
                    insert contactToDelete;
                    Test.startTest();
                    delete contactToDelete;
                    Test.stopTest();
                }
            catch(Exception e) 
                {
                    Boolean expectedExceptionThrown =  e.getMessage().contains(errorMessage) ? true : false;
                    System.assertEquals(expectedExceptionThrown, true);
                }
        }
        
    }
  
}