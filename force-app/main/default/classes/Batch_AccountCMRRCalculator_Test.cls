/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ngoldy
* created:        06/21/2021
* modified:       06/21/2021
* created jira:   BR-1834
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class Batch_AccountCMRRCalculator_Test {

  @testsetup static void testUserDataSetup() {
    List<Account> accounts = new List<Account>();
    Account acc_CA = TestDataFactory.createAccounts(1)[0];
    acc_CA.BillingCountryCode = 'CA';
    acc_CA.CurrencyIsoCode = 'CAD';
    acc_CA.Account_Category__c = 'Independent - Small';
    acc_CA.Product_Activation_Status__c = 'Active';
    acc_CA.RecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
    accounts.add(acc_CA);
    Account acc_GB = TestDataFactory.createAccounts(1)[0];
    acc_GB.BillingCountryCode = 'GB';
    acc_GB.CurrencyIsoCode = 'GBP';
    acc_GB.Account_Category__c = 'Independent - Small';
    acc_GB.Product_Activation_Status__c = 'Active';
    acc_GB.RecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
    accounts.add(acc_GB);
    Account acc_US = TestDataFactory.createAccounts(1)[0];
    acc_US.BillingCountryCode = 'US';
    acc_US.CurrencyIsoCode = 'USD';
    acc_US.Account_Category__c = 'Independent - Small';
    acc_US.Product_Activation_Status__c = 'Active';
    acc_US.RecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
    accounts.add(acc_US);
    insert accounts;

    List<Product2> products = TestDataFactory.createProducts(9);
    products[0].Name = 'CG Base Bundle';
    products[0].ProductCode = 'CG-BASE';
    products[1].Name = 'Enhanced';
    products[2].Name = 'Display';
    products[3].Name = 'Area Boost';
    products[4].Name = 'PistonHeads - Enhanced Placement';
    products[5].Name = 'LeadAI';
    products[6].Name = 'Highlight';
    products[7].Name = '360VinSpin';
    products[8].Name = 'Convert';
    products[0].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
    products[1].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
    products[2].Family = ConstantsUtil.PRODUCT_DIGITAL_ADVERTISING;
    products[3].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
    products[4].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
    products[4].Source__c = ConstantsUtil.PRODUCT_PISTONHEADS;
    products[5].Family = ConstantsUtil.PRODUCT_FAMILY_DATA;
    products[6].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
    products[7].Family = ConstantsUtil.PRODUCT_FAMILY_WEBSITE_AND_INVENTORY;
    products[8].Family = ConstantsUtil.PRODUCT_DIGITAL_RETAIL;
    products[1].Product_Category__c = ConstantsUtil.PRODUCT_CATEGORY_CORE;
    products[2].Product_Category__c = ConstantsUtil.PRODUCT_DIGITAL_ADVERTISING;
    products[3].Product_Category__c = ConstantsUtil.PRODUCT_CATEGORY_ADDON;
    products[4].Product_Category__c = ConstantsUtil.PRODUCT_CATEGORY_CORE;
    products[5].Product_Category__c = ConstantsUtil.PRODUCT_FAMILY_DATA;
    products[6].Product_Category__c = ConstantsUtil.PRODUCT_CATEGORY_ADDON;
    products[7].Product_Category__c = ConstantsUtil.PRODUCT_FAMILY_WEBSITE_AND_INVENTORY;
    products[8].Product_Category__c = ConstantsUtil.PRODUCT_DIGITAL_RETAIL;
    products[1].Sub_Category__c = 'Enhanced';
    products[3].Sub_Category__c = 'Area Boost';
    products[4].Sub_Category__c = 'Enhanced';
    products[5].Sub_Category__c = ConstantsUtil.PRODUCT_FAMILY_DATA;
    products[6].Sub_Category__c = 'Highlight';
    products[7].Sub_Category__c = ConstantsUtil.PRODUCT_FAMILY_WEBSITE_AND_INVENTORY;
    products[8].Sub_Category__c = ConstantsUtil.PRODUCT_DIGITAL_RETAIL;
    // set Display Focus subcategory picklist via getDescribe to avoid strange issue of picklist complaining
    Schema.DescribeFieldResult subCategoryDescription = Product2.Sub_Category__c.getDescribe();
      List<Schema.PicklistEntry> subCategoryValues = subCategoryDescription.getPicklistValues();
      for (Schema.PicklistEntry subCategory : subCategoryValues) {
        if (subCategory.getValue().contains('Display') && subCategory.getValue().contains('Focus')) {
          products[2].Sub_Category__c = subCategory.getValue();
          continue;
      }
    }
    insert products;

    // set up one contract + subscription for each account
    List<Contract> contracts = new List<Contract>();
    for(Account acc : accounts) {
      Contract con = TestDataFactory.createContract(acc.Id);
      con.StartDate = System.today();
      con.EndDate = System.today().addMonths(5).toStartOfMonth().addDays(-1);
      con.CurrencyIsoCode = acc.CurrencyIsoCode;
      contracts.add(con);
    }
    insert contracts;

    List<SBQQ__Subscription__c> subs = new List<SBQQ__Subscription__c>();
    Map<String,Id> baseBundleByCurrencyMap = new Map<String,Id>();
    for(Contract con : contracts) {
      con.Status = 'Activated';

      List<Product2> productsPerCountry = new List<Product2>();
      if(con.CurrencyIsoCode == 'USD') {
        productsPerCountry.add(products[0]);
        productsPerCountry.add(products[1]);
        productsPerCountry.add(products[2]);
        productsPerCountry.add(products[3]);
        productsPerCountry.add(products[5]);
        productsPerCountry.add(products[6]);
        productsPerCountry.add(products[7]);
        productsPerCountry.add(products[8]);
      }
      if(con.CurrencyIsoCode == 'CAD') {
        productsPerCountry.add(products[0]);
        productsPerCountry.add(products[1]);
        productsPerCountry.add(products[2]);
        productsPerCountry.add(products[3]);
      }
      if(con.CurrencyIsoCode == 'GBP') {
        productsPerCountry.add(products[0]);
        productsPerCountry.add(products[4]);
        productsPerCountry.add(products[2]);
        productsPerCountry.add(products[3]);
      }

      for(SBQQ__Subscription__c sub : TestDataFactory.createCPQSubsForProducts(productsPerCountry, con.AccountId)) {
        sub.SBQQ__Contract__c = con.Id;
        sub.Provisioning_Status__c = 'Activated';
        sub.CurrencyIsoCode = con.CurrencyIsoCode;
        if(sub.SBQQ__Product__c == products[1].Id) sub.SBQQ__NetPrice__c = 1200;
        if(sub.SBQQ__Product__c == products[2].Id) sub.SBQQ__NetPrice__c = 2000;
        if(sub.SBQQ__Product__c == products[3].Id) sub.SBQQ__NetPrice__c = 1000;
        if(sub.SBQQ__Product__c == products[4].Id) sub.SBQQ__NetPrice__c = 1500;
        if(sub.SBQQ__Product__c == products[5].Id) sub.SBQQ__NetPrice__c = 700;
        if(sub.SBQQ__Product__c == products[6].Id) sub.SBQQ__NetPrice__c = 150;
        if(sub.SBQQ__Product__c == products[7].Id) sub.SBQQ__NetPrice__c = 500;
        if(sub.SBQQ__Product__c == products[8].Id) sub.SBQQ__NetPrice__c = 400;
        subs.add(sub);
      }
      List<Product2> additionalProdList = new List<Product2>{products[1]};
      SBQQ__Subscription__c futureDatedSub = TestDataFactory.createCPQSubsForProducts(additionalProdList, con.AccountId)[0];
      futureDatedSub.SBQQ__SubscriptionStartDate__c = System.today().addDays(15);
      futureDatedSub.SBQQ__Contract__c = con.Id;
      futureDatedSub.SBQQ__NetPrice__c = 1000;
      subs.add(futureDatedSub);
    }
    update contracts;
    insert subs;

    for(SBQQ__Subscription__c sub : subs) {
      if(sub.SBQQ__Product__c == products[0].Id) {
        baseBundleByCurrencyMap.put(sub.CurrencyIsoCode, sub.Id);
      }
    }

    for(SBQQ__Subscription__c sub : subs) {
      if((sub.SBQQ__Product__c != products[0].Id)
        && (sub.SBQQ__SubscriptionStartDate__c == null || sub.SBQQ__SubscriptionStartDate__c <= System.today())
      ) {
        sub.SBQQ__RequiredById__c = baseBundleByCurrencyMap.get(sub.CurrencyIsoCode);
      }
    }
    update subs;

  }
  
  static testMethod void testCMRRCalculationCA() {

    Account acc0 = [
      SELECT Id 
      FROM Account
      WHERE Name LIKE 'Test Account%' AND BillingCountryCode = 'CA'
      LIMIT 1
    ];

    Test.startTest();
    Database.executeBatch(new Batch_AccountCMRRCalculator(acc0.Id));
    Test.stopTest();

    Account acc = [
      SELECT Id, Name, Listings_CMRR__c, Listings_Base_CMRR__c, Digital_Retail_CMRR__c,
        Display_CMRR__c, Data_CMRR__c, PistonHeads_CMRR__c, Website_Inventory_CMRR__c, Total_CMRR__c
      FROM Account
      WHERE Id = :acc0.Id
      LIMIT 1
    ];

    System.assertEquals(1200, acc.Listings_Base_CMRR__c);
    System.assertEquals(2200, acc.Listings_CMRR__c);
    System.assertEquals(2000, acc.Display_CMRR__c);
    System.assertEquals(0, acc.Data_CMRR__c);
    System.assertEquals(0, acc.Digital_Retail_CMRR__c);
    System.assertEquals(0, acc.PistonHeads_CMRR__c);
    System.assertEquals(0, acc.Website_Inventory_CMRR__c);
    System.assertEquals(4200, acc.Total_CMRR__c);
  }

  static testMethod void testCMRRCalculationGB() {

    Account acc0 = [
      SELECT Id 
      FROM Account
      WHERE Name LIKE 'Test Account%' AND BillingCountryCode = 'GB'
      LIMIT 1
    ];

    Test.startTest();
    Database.executeBatch(new Batch_AccountCMRRCalculator(acc0.Id));
    Test.stopTest();

    Account acc = [
      SELECT Id, Name, Listings_CMRR__c, Listings_Base_CMRR__c, Digital_Retail_CMRR__c,
        Display_CMRR__c, Data_CMRR__c, PistonHeads_CMRR__c, Website_Inventory_CMRR__c, Total_CMRR__c
      FROM Account
      WHERE Id = :acc0.Id
      LIMIT 1
    ];

    System.assertEquals(0, acc.Listings_Base_CMRR__c);
    System.assertEquals(1000, acc.Listings_CMRR__c);
    System.assertEquals(2000, acc.Display_CMRR__c);
    System.assertEquals(0, acc.Data_CMRR__c);
    System.assertEquals(0, acc.Digital_Retail_CMRR__c);
    System.assertEquals(1500, acc.PistonHeads_CMRR__c);
    System.assertEquals(0, acc.Website_Inventory_CMRR__c);
    System.assertEquals(4500, acc.Total_CMRR__c);
  }

  static testMethod void testCMRRCalculationUS() {

    Account acc0 = [
      SELECT Id 
      FROM Account
      WHERE Name LIKE 'Test Account%' AND BillingCountryCode = 'US'
      LIMIT 1
    ];

    Test.startTest();
    Database.executeBatch(new Batch_AccountCMRRCalculator(acc0.Id));
    Test.stopTest();

    Account acc = [
      SELECT Id, Name, Listings_CMRR__c, Listings_Base_CMRR__c, Digital_Retail_CMRR__c,
        Display_CMRR__c, Data_CMRR__c, PistonHeads_CMRR__c, Website_Inventory_CMRR__c, Total_CMRR__c
      FROM Account
      WHERE Id = :acc0.Id
      LIMIT 1
    ];

    System.assertEquals(1200, acc.Listings_Base_CMRR__c);
    System.assertEquals(2350, acc.Listings_CMRR__c);
    System.assertEquals(2000, acc.Display_CMRR__c);
    System.assertEquals(700, acc.Data_CMRR__c);
    System.assertEquals(400, acc.Digital_Retail_CMRR__c);
    System.assertEquals(0, acc.PistonHeads_CMRR__c);
    System.assertEquals(500, acc.Website_Inventory_CMRR__c);
    System.assertEquals(5950, acc.Total_CMRR__c);
  }

  @IsTest
  static void testScheduleCMRRBatch() {
    Batch_AccountCMRRCalculator b = new Batch_AccountCMRRCalculator();
    String cronString = '0 0 23 * * ?';
    Test.startTest();
    String jobId = System.schedule('TEST_Batch_AccountCMRRCalculator', cronString, b);
    Test.stopTest();
    CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
    System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
  }
  
  static void setupCanadaDataAccountWithContract() {
    
  }
}