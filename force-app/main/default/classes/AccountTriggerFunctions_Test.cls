/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        03/11/2021
* modified:       03/11/2021
* created jira:   BR-367 & BR-368
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class AccountTriggerFunctions_Test {    
    private static final String CORP_ACCOUNT_NAME = 'CORP';
    private static final STring DEALER_ACCOUNT_NAME = 'DEALER';
    
    @testSetup
    static void testSetup(){

        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
    	ID corpAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Corporate_Account');
        
        Account corpAccount = TestDataFactory.createSingleAccount(corpAccountRecordTypeId);
        corpAccount.Name = CORP_ACCOUNT_NAME;
        insert corpAccount;
        ID corpAccountId = corpAccount.Id;
        
        List<Account> dealerAccounts = TestDataFactory.createAccounts(3, dealerAccountRecordTypeId, corpAccountId);
        
        for (Integer i=0; i<dealerAccounts.size(); i++){
            Account a = dealerAccounts[i];
            a.Name = DEALER_ACCOUNT_NAME + ' ' + i;
            a.ParentId = corpAccountId;
           // a.Ultimate_Parent_Account__c = corpAccountId;
        }
        insert dealerAccounts;
        
        List<Service_Provider__c> testSpids = new List<Service_Provider__c>();
        for (Account a : dealerAccounts){
            Service_Provider__c spid = TestDataFactory.createSingleServiceProvider(a.Id);
            spid.Used_Inventory_Avg__c = 5;
            spid.Dealer_Type__c = AccountCategoryCalculator.DEALER_TYPE_NEW;
            testSpids.add(spid);
        }

        insert testSpids;
    }

    // Jira: BR-1510 | Method: AccountTriggerFunctions.setUltimateParent
    // Purpose: Verifies that ultimate parent is automatically being set when an account is inserted

    @isTest
    static void checkUltimateParentSet(){
        Account[] dealerAccounts = [SELECT Id, Ultimate_Parent_Account__c FROM Account WHERE ParentId != null];
        Account ultAccount = [SELECT Id FROM Account WHERE ParentId = null];

        for (Account acc : dealerAccounts) {
            System.assertEquals(ultAccount.Id, acc.Ultimate_Parent_Account__c);
        }
    }
    
    //- Jira: BR-367 & BR-368 | Method: AccountTriggerFunctions.ultParentChangedDataCleanup
    //- Purpose: Verifies the cleanup method that fires whe an ultimate parent reference is changed
    @isTest
    static void checkParentChangedNull(){
        Account dealerAccount = [SELECT Id
                                 FROM Account
                                 WHERE Is_Ultimate_Parent__c = false
                                 LIMIT 1];
        
        dealerAccount.ParentId = null;
        dealerAccount.Ultimate_Parent_Account__c = null;
        dealerAccount.Dealer_Type__c = AccountCategoryCalculator.DEALER_TYPE_USED;
        
        Test.startTest();
        update dealerAccount;
        Test.stopTest();
        
        dealerAccount = [SELECT Id, Account_Category__c
                         FROM Account
                         WHERE Id = :dealerAccount.Id
                         LIMIT 1];
        
        System.assertEquals('Independent - Extra Small', dealerAccount.Account_Category__c);
    }
    
    //- Jira: BR-367 & BR-368 | Method: AccountTriggerFunctions.ultParentChangedDataCleanup
    //- Purpose: Verifies the cleanup method that fires whe an ultimate parent reference is changed
    @isTest
    static void checkParentChangedNew(){
        
        ID corpAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Corporate_Account');
        
        Account newCorpAccount = TestDataFactory.createSingleAccount(corpAccountRecordTypeId);
        insert newCorpAccount;
        ID newCorpAccountId = newCorpAccount.Id;
        
        Account dealerAccount = [SELECT Id
                                 FROM Account
                                 WHERE Is_Ultimate_Parent__c = false
                                 LIMIT 1];
        
        dealerAccount.Ultimate_Parent_Account__c = newCorpAccountId;
        dealerAccount.Dealer_Type__c = AccountCategoryCalculator.DEALER_TYPE_USED;
        dealerAccount.ParentId = newCorpAccountId;
        
        Test.startTest();
        update dealerAccount;
        Test.stopTest();
        
        Account corpAccount = [SELECT Id, Account_Category__c
                               FROM Account
                               WHERE Id = :newCorpAccountId
                               LIMIT 1];
        
        System.assertEquals('Independent - Extra Small', corpAccount.Account_Category__c);
    }
    
    //- Jira: BR-367 & BR-368 | Method: AccountCategoryCalculator().execute
    //- Purpose: Verifies that the account category changed on a spid insert
    @isTest
    static void accountCategoryCalc_Insert(){
        Account corpAccount = [SELECT Id, Account_Category__c
                                 FROM Account
                                 WHERE Is_Ultimate_Parent__c = true
                                 LIMIT 1];
        
        System.assertEquals('Franchise - Small', corpAccount.Account_Category__c);
    }
    
    //- Jira: BR-367 & BR-368 | Method: AccountCategoryCalculator().execute
    //- Purpose: Verifies that the account category changed on an account update
    @isTest
    static void accountCategoryCalc_Update(){
        List<Account> accountsToUpdate = [SELECT Id
                                          FROM Account
                                          WHERE Is_Ultimate_Parent__c = false
                                          LIMIT 2];
        
        for (Account a : accountsToUpdate){
            a.Dealer_Type__c = AccountCategoryCalculator.DEALER_TYPE_USED;
        }
        
        Test.startTest();
        update accountsToUpdate;
        Test.stopTest();
        
        Account corpAccount = [SELECT Account_Category__c
                              FROM Account
                              WHERE Name = :CORP_ACCOUNT_NAME
                              LIMIT 1];
        
        System.assertEquals('Independent - Small', corpAccount.Account_Category__c);           
    }
    
    //- Jira: BR-367 & BR-368 | Method: AccountCategoryCalculator().execute
    //- Purpose: Verifies that the account category changed on an account update
    @isTest
    static void accountCategoryCalc_Delete(){
        Account accountToUpdate;
        List<Account> accountsToDelete = new List<Account>();
        
        Integer i = 0;
        for (Account a : [SELECT Id
                          FROM Account
                          WHERE Is_Ultimate_Parent__c = false])
        {
            switch on i{
                when 0{
                    a.Dealer_Type__c = AccountCategoryCalculator.DEALER_TYPE_USED;
                    accountToUpdate = a;
                }when else{
                    accountsToDelete.add(a);
                }
            }
            
            i++;
        }
        
        update accountToUpdate;
        
        Delete [SELECT Id
                FROM Case];
        
        Test.startTest();
        delete accountsToDelete;
        undelete accountsToDelete;
        Test.stopTest();
        
        Account corpAccount = [SELECT Account_Category__c
                              FROM Account
                              WHERE Name = :CORP_ACCOUNT_NAME
                              LIMIT 1];
        
        System.assertEquals('Franchise - Small', corpAccount.Account_Category__c);           
    }
    
    //- Jira: BR-367 & BR-368 | Method: Batch_AccountCategoryUpdateChecker.execute
    //- Purpose: Verifies that the account category changed by Batch_AccountCategoryUpdateChecker
    //- batch uses spid last mod date
    @isTest
    static void BatchTest_AccountCategoryUpdateChecker_Spid(){

        Account corpAccount = [SELECT Id
                               FROM Account
                               WHERE Is_Ultimate_Parent__c = true
                               LIMIT 1];
        
        corpAccount.Account_Category__c = 'Independent - Medium';
        
        update corpAccount;
        
        Test.startTest();
        Database.executeBatch(new Batch_AccountCategoryUpdateChecker());
        Test.stopTest();
        
        Account dealerAccount = [SELECT Id, Account_Category_Formula__c, Dealer_Type__c
                                 FROM Account
                                 WHERE Is_Ultimate_Parent__c = false
                                 LIMIT 1];
        
        System.assertEquals('Franchise - Small', dealerAccount.Account_Category_Formula__c);
        
        //Just getting code coverage for constructor that takes integer
        new Batch_AccountCategoryUpdateChecker(1);
    }
    
    //- Jira: BR-367 & BR-368 | Method: Batch_AccountCategoryUpdateChecker.execute
    //- Purpose: Verifies that the account category changed by Batch_AccountCategoryUpdateChecker
    //- batch uses acocunt last mod date
    @isTest
    static void BatchTest_AccountCategoryUpdateChecker_Account(){

        Account corpAccount = [SELECT Id
                               FROM Account
                               WHERE Is_Ultimate_Parent__c = true
                               LIMIT 1];
        
        corpAccount.Account_Category__c = 'Independent - Medium';
        
        update corpAccount;
        
        Test.startTest();
        Database.executeBatch(new Batch_AccountCategoryUpdateChecker(true, 1));
        Test.stopTest();
        
        Account dealerAccount = [SELECT Id, Account_Category_Formula__c, Dealer_Type__c
                                 FROM Account
                                 WHERE Is_Ultimate_Parent__c = false
                                 LIMIT 1];
        
        System.assertEquals('Franchise - Small', dealerAccount.Account_Category_Formula__c);
        
        //Just getting code coverage for constructor that takes integer
        new Batch_AccountCategoryUpdateChecker(1);
    }
    
    @isTest
    static void ScheduleTest_AccountCategoryUpdateChecker(){
        Test.startTest();
        String cronString = Utilities.getCronExpressionMinutesFromNow(10);
        
        System.schedule('testSchedule_Batch_AccountCategoryUpdateChecker', cronString, 
                        new Batch_AccountCategoryUpdateChecker());
        
        Test.stopTest();
    }
    
    //- Jira: BR-367 & BR-368 | Method: AccountCategoryCalculator().execute
    //- Purpose: Verifies all other permutations of Account Category calculation
    //- Works in a dynamic way by querying the metadata records
    @isTest
    static void checkAllCategoryTypes(){
        
        String DEFAULT_COUNTRY = 'DEFAULT';
        
        Integer NEW_176 = 176;
        String CORRECT_CAT_NEW_176;
        
        Integer USED_10 = 10;
        String CORRECT_CAT_USED_10;
        
        Integer USED_60 = 60;
        String CORRECT_CAT_USED_60;
        
        Integer USED_61 = 61;
        String CORRECT_CAT_USED_61;
        
        
        //Loop through all the default rules, sorted by Max Inventory, in order to populate the constant strings above.
        for (Account_Category_Rule__mdt rule : [SELECT Majority_Dealer_Type__c, Max_Inventory__c, Category__c,
                                                Country_Code__c 
                                                FROM Account_Category_Rule__mdt
                                                WHERE Country_Code__c = :DEFAULT_COUNTRY
                                                ORDER BY Majority_Dealer_Type__c, Max_Inventory__c NULLS LAST])
        {
            Decimal maxInventory = rule.Max_Inventory__c;
            String category = rule.Category__c;

            switch on rule.Majority_Dealer_Type__c{
                when 'New'{
                    if (CORRECT_CAT_NEW_176  == null){
                        if (maxInventory == null || NEW_176 <= maxInventory){
                            CORRECT_CAT_NEW_176 = category;
                        }
                    }
                }when 'Used'{
                    if (CORRECT_CAT_USED_10 == null){
                        if (maxInventory == null || USED_10 <= maxInventory){
                            CORRECT_CAT_USED_10 = category;
                        }
                    }
                    
                    if (CORRECT_CAT_USED_60 == null){
                        if (maxInventory == null || USED_60 <= maxInventory){
                            CORRECT_CAT_USED_60 = category;
                        }
                    }
                    
                    if (CORRECT_CAT_USED_61 == null){
                        if (maxInventory == null || USED_61 <= maxInventory){
                            CORRECT_CAT_USED_61 = category;
                        }
                    }
                }
            }
        }
                
        Account corpAccount =  [SELECT Id, Dealer_Type__c, BillingCountryCode, 
                                						   (SELECT Dealer_Type__c
                                                            FROM Accounts_Descendents__r)
                                FROM Account
                                WHERE Is_Ultimate_Parent__c = true
                                LIMIT 1];
        
        AccountCategoryCalculator.checkSpecificUltAccount(corpAccount, NEW_176);
        System.assertEquals(CORRECT_CAT_NEW_176, corpAccount.Account_Category__c);

        for (Account dealer : corpAccount.Accounts_Descendents__r){
            dealer.Dealer_Type__c = AccountCategoryCalculator.DEALER_TYPE_USED;
        }
        corpAccount.BillingCountryCode = DEFAULT_COUNTRY;

        AccountCategoryCalculator.checkSpecificUltAccount(corpAccount, USED_10);
        System.assertEquals(CORRECT_CAT_USED_10, corpAccount.Account_Category__c);
        
        AccountCategoryCalculator.checkSpecificUltAccount(corpAccount, USED_60);
        System.assertEquals(CORRECT_CAT_USED_60, corpAccount.Account_Category__c);
        
        AccountCategoryCalculator.checkSpecificUltAccount(corpAccount, USED_61);
        System.assertEquals(CORRECT_CAT_USED_61, corpAccount.Account_Category__c);
    }
     static testMethod void setRenewalRecordStatusTest(){
        Id dealerAccountRecordType= Utilities.getRecordTypeId('Account','Dealer_Account');
        Account acc = new Account();
        acc.name = 'TestAcc';
        acc.recordTypeID = dealerAccountRecordType;
        acc.Account_Status__c ='Pending';
        acc.Renewal_Eligible__c = true;
        acc.Renewal_Period__c = system.today();
        acc.type = 'Customer';
        insert acc;
        acc.Renewal_Period__c= null;
        acc.Renewal_Status__c='Renewal Price Change Approved';
        update acc; 
        Account acc1 = [SELECT ID,Renewal_Eligible__c FROM Account WHERE Id =: acc.id limit 1  ];
        system.assertEquals(True, acc1.Renewal_Eligible__c);     
    }

    @isTest
    static void validateOEMMakes(){
        Id dealerAccountRecordType= Utilities.getRecordTypeId('Account','Dealer_Account');
        Account acc = new Account();
        acc.name = 'TestAcc';
        acc.recordTypeID = dealerAccountRecordType;
        acc.Account_Status__c ='Pending';
        acc.Renewal_Eligible__c = true;
        acc.Renewal_Period__c = system.today();
        acc.Co_Op_Program_Opt_In__c = 'GM Turnkey Billing';
        acc.type = 'Customer';
        insert acc;

        List<Service_Provider__c> testSpids = new List<Service_Provider__c>();
        
        Service_Provider__c spid = TestDataFactory.createSingleServiceProvider(acc.Id);
        spid.Used_Inventory_Avg__c = 5;
        spid.New_Makes_Sold__c = 'Buick,Chevrolet';
        spid.Dealer_Type__c = AccountCategoryCalculator.DEALER_TYPE_NEW;
        testSpids.add(spid);
        insert testSpids;
        
    }

    static testMethod void setAccountStatusTest(){
        Id dealerAccountRecordType= Utilities.getRecordTypeId('Account','Dealer_Account');
        Account acc = new Account();
        acc.name = 'TestAcc';
        acc.recordTypeID = dealerAccountRecordType;
        acc.Account_Status__c ='Active - Unsellable';
        acc.Account_Status_Reason__c = 'New Only';   
        insert acc;
        acc.Account_Status_Reason__c= null;
        update acc; 
        Account acc1 = [SELECT ID,Account_Status__c FROM Account WHERE Id =: acc.Id limit 1];
        system.assertEquals('Active', acc1.Account_Status__c);     
    }

    static testMethod void createTurnkeyCancellationCaseTest() {

        Test.startTest();
        Id dealerAccountRecordType = Utilities.getRecordTypeId('Account','Dealer_Account');
        Account acc = new Account();
        acc.name = 'TestAcc';
        acc.recordTypeID = dealerAccountRecordType;
        acc.Account_Status__c = 'Pending';
        acc.Co_Op_Program_Opt_In__c = 'GM Turnkey Billing';
        acc.Enrollment_Status__c = 'Active';
        acc.type = 'Customer';
        insert acc;

        Contract con = TestDataFactory.createContract(acc.Id);
        con.StartDate = System.today();
        con.EndDate = System.today().addMonths(5).toStartOfMonth().addDays(-1);
        con.Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
        insert con;

        con.Status = 'Activated';
        update con;

        acc.Enrollment_Status__c = 'Inactive';
        acc.Withdrawal_Date__c = System.today();
        update acc;        

        Test.stopTest();
        Id cancellationRTId = Utilities.getRecordTypeId('Case','Cancellations');

        List<Case> turnkeyCancellationCases = [
            SELECT Id, Reason
            FROM Case
            WHERE AccountId = :acc.Id
            AND RecordTypeId = :cancellationRTId
            AND Reason = 'GM Turnkey Billing'
        ];

        System.assertEquals(1, turnkeyCancellationCases.size());
        
    }

    static testMethod void updateContractEndDateRenewalTest() {

        Test.startTest();
        Id dealerAccountRecordType= Utilities.getRecordTypeId('Account','Dealer_Account');
        Account acc = new Account();
        acc.name = 'TestAcc';
        acc.recordTypeID = dealerAccountRecordType;
        acc.Account_Status__c ='Pending';
        acc.Renewal_Eligible__c = true;
        acc.Renewal_Period__c = system.today();
        acc.type = 'Customer';
        acc.Renewal_Status__c = 'Renewal Review In-progress';
        insert acc;

        // initialize Zuora Billing Accounts
        Zuora__CustomerAccount__c zAccount = new Zuora__CustomerAccount__c(Name='Test BA1', Zuora__Status__c = 'Active', 
            Zuora__Zuora_Id__c ='zuorabilling1', Zuora__Account__c = acc.Id, 
            Zuora__BillToWorkEmail__c = 'test123@cargurus.com.invalid', Zuora__SoldToWorkEmail__c = 'test123@cargurus.com.invalid',
            Zuora__AccountNumber__c = 'TEST-001', Zuora__DefaultPaymentMethod__c = 'CreditCard');
        insert zAccount;

        acc.Billing_Account_Zuora__c = zAccount.Id;
        update acc;


        Product2[] products = TestDataFactory.createProducts(1);
        products[0].Name = 'CG Base Bundle';
        products[0].ProductCode = 'CG-BASE';
        insert products;

        Contract con = TestDataFactory.createContract(acc.Id);
        con.StartDate = Date.newInstance(Date.today().year(), Date.today().month(), 1); // first day of current month
        con.EndDate = System.today().addMonths(1).toStartofMonth().addDays(-1); //Last day of current month
        insert con;      


        SBQQ__Subscription__c[] subs = TestDataFactory.createCPQSubsForProducts(products, acc.Id);
        for(SBQQ__Subscription__c sub : subs) {
          sub.SBQQ__Contract__c = con.Id;
          sub.SBQQ__Account__c = acc.Id;
          sub.Billing_Account__c = acc.Id;
          sub.Zuora_Subscription_Number__c = 'TEST';
        }

        insert subs;

        con.Status = 'Activated'; 
        update con;
        
        acc.Renewal_Status__c = 'Renewal Price Change Approved';
        update acc; 

        Test.stopTest();
        
        Date firstDayOfNextMonth = System.today().addMonths(1).toStartOfMonth();        
        Date lastDayOfNextMonth = firstDayOfNextMonth.addDays(Date.daysInMonth(firstDayOfNextMonth.year(), firstDayOfNextMonth.month())-1);
        Contract contract = [SELECT Id, EndDate FROM Contract WHERE Id = :con.Id];
        
        System.assertEquals(lastDayOfNextMonth, contract.EndDate);

    }
}