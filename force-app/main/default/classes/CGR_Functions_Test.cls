/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ngoldy
* created:        06/23/2021
* modified:       06/23/2021
* created jira:   BR-1844
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
public class CGR_Functions_Test {

  @TestSetup
  static void testSetup() {
    Profile p = [
      SELECT Id 
      FROM Profile 
      WHERE Name = 'Sales User'
    ];
    User u = TestDataFactory.createUser(true, p);
    u.FirstName = 'John';
    insert u;
    User u2 = TestDataFactory.createUser(true, p); 
    u2.Username += '_tst';
    u2.FirstName = 'James';
    insert u2;

    Account acc = TestDataFactory.createAccounts(1)[0];
    acc.BillingCountryCode = 'CA';
    acc.CurrencyIsoCode = 'CAD';
    acc.Account_Category__c = 'Independent - Small';
    acc.Product_Activation_Status__c = 'Active';
    acc.RecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
    acc.Listings_Base_CMRR__c = 1000;
    acc.Listings_CMRR__c = 1500;
    acc.Display_CMRR__c = 800;
    acc.Data_CMRR__c = 0;
    acc.Website_Inventory_CMRR__c = 0;
    insert acc;

    AccountTeamMember atm = new AccountTeamMember(
      AccountId = acc.Id,
      TeamMemberRole = 'Dealer Relations',
      UserId = u.Id
    );
    insert atm;
    AccountTeamMember atm2 = new AccountTeamMember(
      AccountId = acc.Id,
      TeamMemberRole = 'Field Rep',
      UserId = u2.Id
    );
    insert atm2;
  }

  @IsTest
  static void testCreateCgrRecords() {

    Account acc0 = [
      SELECT Id 
      FROM Account
      WHERE Name LIKE 'Test Account%'
      LIMIT 1
    ];

    Test.startTest();
    Database.executeBatch(new Batch_AccountCGR(acc0.Id));
    Test.stopTest();

    List<Account_CGR__c> cgrs = [
      SELECT Id, Account__c, Name, Current_Quarter__c, CGR_Start_Date__c,
        Starting_Amount_Listings__c, Starting_Amount_Display__c, Starting_Amount_Data__c,
        Ending_Amount_Listings__c, Ending_Amount_Display__c, Ending_Amount_Data__c 
      FROM Account_CGR__c
      WHERE Account__c = :acc0.Id
      ORDER BY Name ASC
    ];

    System.assertEquals(2, cgrs.size());
    Account_CGR__c previousCgr = cgrs[0];
    Account_CGR__c currentCgr = cgrs[1];
    System.assertEquals(System.today().addMonths(-3), previousCgr.CGR_Start_Date__c);
    System.assertEquals(System.today(), currentCgr.CGR_Start_Date__c);
    System.assertEquals(0, previousCgr.Starting_Amount_Listings__c);
    System.assertEquals(0, previousCgr.Starting_Amount_Display__c);
    System.assertEquals(0, previousCgr.Starting_Amount_Data__c);
    System.assertEquals(1500, previousCgr.Ending_Amount_Listings__c);
    System.assertEquals(800, previousCgr.Ending_Amount_Display__c);
    System.assertEquals(0, previousCgr.Ending_Amount_Data__c);
    System.assertEquals(1500, currentCgr.Starting_Amount_Listings__c);
    System.assertEquals(800, currentCgr.Starting_Amount_Display__c);
    System.assertEquals(0, currentCgr.Starting_Amount_Data__c);

    System.debug(currentCgr);
  }

  @IsTest
  static void testCreateAndUpdateCgrRecords() {

    Account acc0 = [
      SELECT Id 
      FROM Account
      WHERE Name LIKE 'Test Account%'
      LIMIT 1
    ];

    Account_CGR__c prevCgr = new Account_CGR__c(
      Account__c = acc0.Id, 
      Name = '2021 - Q1', 
      CGR_Start_Date__c = System.today().addMonths(-3), 
      Starting_Amount_Listings__c = 1000, 
      Starting_Amount_Display__c = 0, 
      Starting_Amount_Data__c = 0,
      Starting_Amount_Website_Inventory__c = 0
    );
    insert prevCgr;

    Test.startTest();
    Database.executeBatch(new Batch_AccountCGR(acc0.Id));
    Test.stopTest();

    List<Account_CGR__c> cgrs = [
      SELECT Id, Account__c, Name, Current_Quarter__c, CGR_Start_Date__c,
        Starting_Amount_Listings__c, Starting_Amount_Display__c, Starting_Amount_Data__c,
        Ending_Amount_Listings__c, Ending_Amount_Display__c, Ending_Amount_Data__c 
      FROM Account_CGR__c
      WHERE Account__c = :acc0.Id
      ORDER BY Name ASC
    ];

    System.assertEquals(2, cgrs.size());
    Account_CGR__c previousCgr = cgrs[0];
    Account_CGR__c currentCgr = cgrs[1];
    System.assertEquals(System.today().addMonths(-3), previousCgr.CGR_Start_Date__c);
    System.assertEquals(System.today(), currentCgr.CGR_Start_Date__c);
    System.assertEquals(1000, previousCgr.Starting_Amount_Listings__c);
    System.assertEquals(0, previousCgr.Starting_Amount_Display__c);
    System.assertEquals(0, previousCgr.Starting_Amount_Data__c);
    System.assertEquals(1500, previousCgr.Ending_Amount_Listings__c);
    System.assertEquals(800, previousCgr.Ending_Amount_Display__c);
    System.assertEquals(0, previousCgr.Ending_Amount_Data__c);
    System.assertEquals(1500, currentCgr.Starting_Amount_Listings__c);
    System.assertEquals(800, currentCgr.Starting_Amount_Display__c);
    System.assertEquals(0, currentCgr.Starting_Amount_Data__c);

    System.debug(currentCgr);
  }

  @IsTest
  static void testcreateCgrRepRecords() {

    Account acc0 = [
      SELECT Id 
      FROM Account
      WHERE Name LIKE 'Test Account%'
      LIMIT 1
    ];

    Account_CGR__c currentCgr = new Account_CGR__c(
      Account__c = acc0.Id, 
      Name = '2021 - Q2', 
      CGR_Start_Date__c = System.today(), 
      Starting_Amount_Listings__c = 1500, 
      Starting_Amount_Display__c = 800, 
      Starting_Amount_Data__c = 0,
      Starting_Amount_Website_Inventory__c = 0
    );
    insert currentCgr;


    Test.startTest();
    Database.executeBatch(new Batch_AccountCGRReps(acc0.Id));
    Test.stopTest();

    List<Account_CGR_Rep__c> cgrReps = [
      SELECT Id, Name, Account_CGR__c, CGR_Rep__c, CGR_Rep__r.FirstName, CGR_Role__c,
        CGR_Eligible_Listings__c, CGR_Eligible_Display__c, CGR_Eligible_Data__c, CGR_Eligible_Website_Inventory__c,
        CGR_Rep_Starting_Amount__c, CGR_Rep_Ending_Amount__c, CGR_Rep_Delta__c
      FROM Account_CGR_Rep__c
      ORDER BY CGR_Role__c ASC
    ];

    System.assertEquals(2, cgrReps.size());
    Account_CGR_Rep__c drRep = cgrReps[0];
    Account_CGR_Rep__c fieldRep = cgrReps[1];
    System.assertEquals('Dealer Relations', drRep.CGR_Role__c);
    System.assertEquals('Field Rep', fieldRep.CGR_Role__c);
    System.assertEquals('John', drRep.CGR_Rep__r.FirstName);
    System.assertEquals('James', fieldRep.CGR_Rep__r.FirstName);
    System.assertEquals(currentCgr.Id, drRep.Account_CGR__c);
    System.assertEquals(currentCgr.Id, fieldRep.Account_CGR__c);
    System.assertEquals(true, drRep.CGR_Eligible_Listings__c);
    System.assertEquals(true, fieldRep.CGR_Eligible_Listings__c);
    System.assertEquals(true, drRep.CGR_Eligible_Display__c);
    System.assertEquals(true, fieldRep.CGR_Eligible_Display__c);
    System.assertEquals(false, drRep.CGR_Eligible_Website_Inventory__c);
    System.assertEquals(false, fieldRep.CGR_Eligible_Website_Inventory__c);
    System.assertEquals(2300, drRep.CGR_Rep_Starting_Amount__c);
    System.assertEquals(2300, fieldRep.CGR_Rep_Starting_Amount__c);
  }

  @IsTest
  static void testScheduleCgrBatch() {
    Batch_AccountCGR ndrBatch = new Batch_AccountCGR();
    String cronString = '0 0 23 * * ?';
    Test.startTest();
    String jobId = System.schedule('TEST_Batch_AccountCGR', cronString, ndrBatch);
    Test.stopTest();
    CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
    System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
  }

  @IsTest
  static void testScheduleCgrRepBatch() {
    Batch_AccountCGRReps cgrRepBatch = new Batch_AccountCGRReps();
    String cronString = '0 0 23 * * ?';
    Test.startTest();
    String jobId = System.schedule('TEST_Batch_AccountCGRReps', cronString, cgrRepBatch);
    Test.stopTest();
    CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
    System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
  }

}