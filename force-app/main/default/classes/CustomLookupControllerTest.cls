/**
* Test class for Custom Lookup Controller (CustomLookupControllerTest)
* @date 	  11/03/2021
* @module   BR-3733
*/

@isTest
public class CustomLookupControllerTest {
    @isTest
    static void searchBillingAccountsTest() {
        List<Id> fixedResults = new List<Id>(1);

        // Create an account
        Test.startTest();
        List<Account> accounts = TestDataFactory.createAccounts(1);
        insert accounts;

        List<Zuora__CustomerAccount__c> zAccs = TestDataFactory.createZuoraAccount(1, accounts[0]);
        insert zAccs;

        accounts[0].Billing_Account_Zuora__c = zAccs[0].Id;
        update accounts;

        Test.stopTest();

        fixedResults.add(accounts[0].Id);
        
        Test.setFixedSearchResults(fixedResults);
        List<String> selectedIds = new List<String>();

        List<LookupSearchResult> results = CustomLookupController.searchBillingAccounts('Test',selectedIds);
        System.debug('Result: ' + results);

        System.assertEquals(1, results.size());
        
    }

}