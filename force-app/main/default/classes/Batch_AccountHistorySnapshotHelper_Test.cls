/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ngoldy
* created:        06/14/2021
* modified:       06/14/2021
* created jira:   BR-2045
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class Batch_AccountHistorySnapshotHelper_Test {

  @testsetup static void testUserDataSetup() {
    Profile p = [
      SELECT Id 
      FROM Profile 
      WHERE Name = 'System Administrator'
    ];
    UserRole role = [
      SELECT Id
      FROM UserRole
      WHERE Name = 'System Administrator'
    ];
    User u = TestDataFactory.createUser(true, p);
    u.UserRoleId = role.Id;
    insert u;

    System.runAs(u) {
      Account acc = TestDataFactory.createAccounts(1)[0];
      acc.OwnerId = u.Id;
      acc.BillingCountryCode = 'CA';
      acc.CurrencyIsoCode = 'CAD';
      acc.Account_Category__c = 'Independent - Small';
      acc.Product_Activation_Status__c = 'Active';
      acc.RecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
      insert acc;
      
      List<Service_Provider__c> sps = TestDataFactory.createServiceProviders(3, acc.Id);
      for(Service_Provider__c sp : sps) {
        sp.Inventory_Source__c = 'Inv Source - test';
        sp.Total_New_Inventory_Units__c = 20;
        sp.Total_Used_Inventory_Units__c = 50;
        sp.New_Cars_Fair_Qty__c = 5;
        sp.New_Cars_Good_Qty__c = 5;
        sp.New_Cars_Great_Qty__c = 5;
        sp.New_Cars_High_Qty__c = 5;
        sp.Used_Cars_Missing_Photos_Qty__c = 5;
        sp.Used_Cars_Missing_Price_Qty__c = 1;
        sp.Used_Cars_Missing_Trim_Qty__c = 2;
        sp.Used_Cars_Missing_Trim_Opts_Qty__c = 7;

        if(sp.Name == 'Test SP 2') {
          sp.Account__c = null;
        }
      }
      insert sps;
    }
  }
  
  static testMethod void testAccountHistorySnapshotCreation() {
    
    Test.startTest();

    List<Service_Provider__c> sps = [SELECT Id FROM Service_Provider__c WHERE Include_for_Snapshot__c = TRUE];
    System.assertEquals(2, sps.size());

    Database.executeBatch(new Batch_AccountHistorySnapshot());

    Test.stopTest();

    List<Account_History_Snapshot__c> ahs = [
      SELECT Id, Name, Account__c, Account_Category_formula__c, Product_Activation_Status__c, 
        Total_Inventory_Units_All__c, Total_New_Inventory_Units__c, Total_Used_Inventory_Units__c,
        Snapshot_Date__c, New_Cars_Fair_Qty__c, New_Cars_Good_Qty__c, New_Cars_Great_Qty__c, New_Cars_High_Qty__c,
        Used_Cars_Missing_Photos_Qty__c, Used_Cars_Missing_Price_Qty__c, Used_Cars_Missing_Trim_Qty__c, Used_Cars_Missing_Trim_Opts_Qty__c,
        Fair_Deals__c, Good_Deals__c, Great_Deals__c, High_Price__c, 
        Cars_Missing_Photos_Used__c, with_Photos_Used__c, Cars_Missing_Price_Used__c, with_Pricing_Used__c
      FROM Account_History_Snapshot__c
    ];

    User u = [
      SELECT Id
      FROM User
      WHERE Email = 'standarduser1@testorg.com' LIMIT 1
    ];

    System.assertEquals(1, ahs.size());
    System.assertEquals(System.today(), ahs[0].Snapshot_Date__c);
    System.assertEquals('Independent - Small', ahs[0].Account_Category_formula__c);
    System.assertEquals('Active', ahs[0].Product_Activation_Status__c);
    System.assertEquals(Utilities.getEndOfLastMonth(date.today()), ahs[0].Name);
    System.assertEquals(140, ahs[0].Total_Inventory_Units_All__c);
    System.assertEquals(40, ahs[0].Total_New_Inventory_Units__c);
    System.assertEquals(100, ahs[0].Total_Used_Inventory_Units__c);
    System.assertEquals(10, ahs[0].New_Cars_Fair_Qty__c);
    System.assertEquals(0.25, ahs[0].Fair_Deals__c);
    System.assertEquals(10, ahs[0].New_Cars_Great_Qty__c);
    System.assertEquals(0.25, ahs[0].Great_Deals__c);
    System.assertEquals(10, ahs[0].Used_Cars_Missing_Photos_Qty__c);
    System.assertEquals(0.1, ahs[0].Cars_Missing_Photos_Used__c);
    System.assertEquals(2, ahs[0].Used_Cars_Missing_Price_Qty__c);
    System.assertEquals(0.02, ahs[0].Cars_Missing_Price_Used__c);

  }

  @IsTest
  static void testScheduleAHSBatch() {
    Batch_AccountHistorySnapshot ahsBatch = new Batch_AccountHistorySnapshot();
    String cronString = '0 0 23 * * ?';
    Test.startTest();
    String jobId = System.schedule('TEST_Batch_AccountHistorySnapshot', cronString, ahsBatch);
    Test.stopTest();
    CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
    System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
  }

  @IsTest
  static void testAccountHistorySnapshotCreationForAccounts() {

    Map<Id, Account> accs = new Map<Id, Account>([
      SELECT Id
      FROM Account
      WHERE Name = 'Test Account 0'
    ]);
    
    Test.startTest();
    Database.executeBatch(new Batch_AccountHistorySnapshot(accs.keySet()));
    Test.stopTest();
  }

  @IsTest
  static void testAccountHistorySnapshotCreationForAccount() {

    Account acc = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Account 0' LIMIT 1
    ];
    
    Test.startTest();
    Database.executeBatch(new Batch_AccountHistorySnapshot(acc.Id));
    Test.stopTest();
  }
  
}