/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ngoldy
* created:        06/22/2021
* modified:       06/22/2021
* created jira:   BR-2019
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class Batch_AccountProdActivationUpdater_Test {

  @testsetup static void testData() {
    List<Account> testAccs = TestDataFactory.createAccounts(1);
    testAccs[0].Cancellation_Effective_Date__c = System.today().addDays(-58);
    testAccs[0].Product_Activation_Status__c = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_CANCELING57DAYS;
    insert testAccs;
  }

  static testMethod void productActivationStatusUpdateTest() {
    
    Test.startTest();
    Database.executeBatch(new Batch_AccountProductActivationUpdater());
    Test.stopTest();

    Account acc = [
      SELECT Id, Product_Activation_Status__c, Cancellation_Effective_Date__c
      FROM Account
      WHERE Name LIKE 'Test Account%'
      LIMIT 1
    ]; 

    System.assertEquals(ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_RESTRICTEDACTIVATED, acc.Product_Activation_Status__c);
    System.assertEquals(null, acc.Cancellation_Effective_Date__c);

  }

}