/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         alaplante
* modifiedBy:     alaplante
* created:        06/08/2021
* modified:       06/08/2021
* created jira:   BR-2564
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class AccountLanguageDefaulting_Test {    
    
    @testSetup
    static void testSetup(){

        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        List<Account> testAccounts = new List<Account>();
        
        Account testAccount1 = TestDataFactory.createSingleAccount(dealerAccountRecordTypeId);
        testAccount1.Name = 'Test Account 1';
        testAccount1.BillingCountryCode = 'CA';
        testAccount1.BillingCity = 'Quebec';
        testAccounts.add(testAccount1);

        Account testAccount2 = TestDataFactory.createSingleAccount(dealerAccountRecordTypeId);
        testAccount2.Name = 'Test Account 2';
        testAccount2.BillingCountryCode = 'CA';
        testAccount2.BillingStateCode = 'QC';
        testAccounts.add(testAccount2);
        
        insert testAccounts;
    }

    @isTest
    static void checkInsertDefaultingCity() {
        // grab test account 1
        Account dealerAccount = [SELECT Id, Preferred_Language__c
                                 FROM Account
                                 WHERE BillingCity = 'Quebec'
                                 LIMIT 1];
    
        // preferred language should be french
        System.assertEquals('French', dealerAccount.Preferred_Language__c, 'Language was not set to French');
    }
    
    @isTest
    static void checkInsertDefaultingProvince() {
        // grab test account 2
        Account dealerAccount = [SELECT Id, Preferred_Language__c
                                 FROM Account
                                 WHERE BillingStateCode = 'QC'
                                 LIMIT 1];
    
        // preferred language should be french
        System.assertEquals('French', dealerAccount.Preferred_Language__c, 'Language was not set to French');
    }
}