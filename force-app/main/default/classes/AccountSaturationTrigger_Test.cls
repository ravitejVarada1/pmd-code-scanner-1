/**
 * @author  Adam LaPlante
 * @date    03/04/21
 * @module  [BR-371] Account Saturation
 */


@isTest
private class AccountSaturationTrigger_Test {

    /**
     * Sets up accounts to be used throughout tests
     */
    
    @testSetup
    static void testSetup(){
        
        // get test accounts
        Account ultimateParentAccount = TestDataFactory.createAccounts(1)[0];
        Account independentAccount = TestDataFactory.createAccounts(1)[0];
        List<Account> childAccounts = TestDataFactory.createAccounts(2);
        
        // get record type id
        ID dealerRecordID = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        ID corporateRecordID = Utilities.getrecordTypeId('Account', 'Corporate_Account');
        
        // setup ultimate parent
        ultimateParentAccount.RecordTypeId = corporateRecordID;
        ultimateParentAccount.Name = 'Test Ultimate Parent Account';
        ultimateParentAccount.Account_Status__c = 'Active';
        
        // setup independent account
        independentAccount.RecordTypeId = dealerRecordID;
        independentAccount.Name = 'Test Independent Account';
        independentAccount.Account_Status__c = 'Active';

        // testing the insertion of a corp account without children
        Test.startTest();
        // insert independent and ultimate parent
        insert new List<Account>{ultimateParentAccount, independentAccount};
        Test.stopTest();

        // loop through children setting required data points
        for (Account acc : childAccounts) {
            acc.ParentId = ultimateParentAccount.Id;
            acc.Ultimate_Parent_Account__c = ultimateParentAccount.Id;
            acc.RecordTypeId = dealerRecordID;
            acc.Account_Status__c = 'Active';
        }
        
        // insert child account
        insert childAccounts;
        
    }

    /**
     * Tests the 'partially sold' saturation status
     */

    @isTest static void testPartiallySold() {
       
   		// get list of accounts
   		List<Account> childDealerAccounts = [SELECT Id, Name, Product_Activation_Status__c 
           FROM Account WHERE Name LIKE 'Test Account %'];

        List<Account> ultimateParentAccount =  [SELECT Id, Name, Product_Activation_Status__c 
            FROM Account WHERE Name LIKE 'Test Ultimate Parent Account'];

		Id ultimateParentId = ultimateParentAccount[0].Id;
        
        // Perform test for partially sold
        Test.startTest();

        // insert child dealer account
        childDealerAccounts[0].Product_Activation_Status__c = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE;
        update childDealerAccounts[0];

        // stop test
        Test.stopTest();

        // Verify 
        List<Account> accounts = [SELECT ID,Name,Account_Saturation_Formula__c, Account_Saturation_Percentage_Formula__c 
        FROM Account WHERE Ultimate_Parent_Account__c=:ultimateParentId OR ID=:ultimateParentId];

        // loop through verifying test passed
        for (Account acc : accounts) {
            System.assertEquals(50.0, acc.Account_Saturation_Percentage_Formula__c, 'Partially Sold test has failed.');
            System.assertEquals('Partially Sold', acc.Account_Saturation_Formula__c,'Partially Sold test has failed.');
        }
    }

    /**
     * Tests the 'fully sold' saturation status
     */

    @isTest static void testFullySold() {
        
   		// get list of accounts
   		List<Account> childDealerAccounts = [SELECT Id, Name, Product_Activation_Status__c 
           FROM Account WHERE Name LIKE 'Test Account %'];

        Account ultimateParentAccount =  [SELECT Id, Name, Product_Activation_Status__c 
        FROM Account WHERE Name LIKE 'Test Ultimate Parent Account'][0];

		Id ultimateParentId = ultimateParentAccount.Id;

        // Perform test for unsold
        Test.startTest();
        
        // set ultimate parent paying status
        ultimateParentAccount.Product_Activation_Status__c = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE;
        
        // update parent account
        update ultimateParentAccount;
        
        // set children paying status
        for (Account acc: childDealerAccounts) {
            acc.Product_Activation_Status__c = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE;
        }

        // update child dealer accts
  		update childDealerAccounts;

        // stop test
        Test.stopTest();

        // Verify 
        List<Account> accounts = [SELECT ID,Name,Account_Saturation_Formula__c, Account_Saturation_Percentage_Formula__c 
        FROM Account WHERE Ultimate_Parent_Account__c=:ultimateParentId OR ID=:ultimateParentId];

        // loop through verifying test passed
        for (Account acc : accounts) {
            System.assertEquals(100.0, acc.Account_Saturation_Percentage_Formula__c, 'Fully Sold test has failed.');
            System.assertEquals('Fully Sold', acc.Account_Saturation_Formula__c, 'Fully Sold test has failed.');
            
        }
    }

    /**
     * Tests the 'unsold' saturation status
     */

    @isTest static void testUnsold() {

   		// get list of accounts
   		List<Account> childDealerAccounts = [SELECT Id, Name, Product_Activation_Status__c 
           FROM Account WHERE Name LIKE 'Test Account %'];

        Account ultimateParentAccount =  [SELECT Id, Name, Product_Activation_Status__c 
        FROM Account WHERE Name LIKE 'Test Ultimate Parent Account'][0];

		Id ultimateParentId = ultimateParentAccount.Id;

        // Verify 
        List<Account> accounts = [SELECT ID,Name,Account_Saturation_Formula__c, Account_Saturation_Percentage_Formula__c 
        FROM Account WHERE Ultimate_Parent_Account__c=:ultimateParentId OR ID=:ultimateParentId];

        // loop through accounts asserting values
        for (Account acc : accounts) {
            System.assertEquals(0.0, acc.Account_Saturation_Percentage_Formula__c, 'Unsold test has failed.');
            System.assertEquals('Unsold', acc.Account_Saturation_Formula__c, 'Unsold test has failed.');
        }
    }

    /**
     * Tests dealer hierarchies with only a single dealer
     */

    @isTest static void testIndependent() {

        Account independentAccount = ([SELECT Id, Name, Product_Activation_Status__c 
        FROM Account WHERE Name LIKE 'Test Independent Account'])[0];
        
        // Perform test for independent
        Test.startTest();

        // update account
        independentAccount.Product_Activation_Status__c=ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE;
        update independentAccount;

        // stop test
        Test.stopTest();

        // Verify 
        List<Account> accounts = [SELECT ID,Name,Account_Saturation_Formula__c, Account_Saturation_Percentage_Formula__c 
        FROM Account WHERE Ultimate_Parent_Account__c=:independentAccount.ID OR ID=:independentAccount.ID];

        // loop through accounts asserting values
        for (Account acc : accounts) {
            System.assertEquals(100.0, acc.Account_Saturation_Percentage_Formula__c, 'Independent test has failed.');
            System.assertEquals('Fully Sold', acc.Account_Saturation_Formula__c, 'Independent test has failed.');
        }
    }

        @isTest static void testBatch() {

        Account independentAccount = ([SELECT Id, Name, Product_Activation_Status__c 
        FROM Account WHERE Name LIKE 'Test Independent Account'])[0];
        
        // Perform test for independent
        Test.startTest();

        // update account
        independentAccount.Product_Activation_Status__c=ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE;
        update independentAccount;
        Database.executeBatch(new Batch_UpdateAccountSaturation());

        // stop test
        Test.stopTest();

        // Verify 
        List<Account> accounts = [SELECT ID,Name,Account_Saturation_Formula__c, Account_Saturation_Percentage_Formula__c 
        FROM Account WHERE Ultimate_Parent_Account__c=:independentAccount.ID OR ID=:independentAccount.ID];

        // loop through accounts asserting values
        for (Account acc : accounts) {
            System.assertEquals(100.0, acc.Account_Saturation_Percentage_Formula__c, 'Batch test has failed.');
            System.assertEquals('Fully Sold', acc.Account_Saturation_Formula__c, 'Batch test has failed.');
        }


    }
    
}