@isTest
public without sharing class Batch_BackfillCPQContractsTest {
    static Schema.DescribeSObjectResult accd = Schema.SObjectType.Account;
	static Map<String,Schema.RecordTypeInfo> rtMapByName = accd.getRecordTypeInfosByName();
	static Schema.RecordTypeInfo corporateAccount =  rtMapByName.get('Corporate Account');
    static Schema.RecordTypeInfo dealerAccount = rtMapByName.get('Dealer Account');

    private static Map<String,Product2> testProductMap;
    private static Map<String,Zuora__Product__c> testZProductMap;
    
	private static void setupTestProductData() {
        
        // initialize Products
        Date productStartDate = Date.today().addYears(-1);
        Date productEndDate = Date.today().addYears(1);
        //Integer i = 0;
        testProductMap = new Map<String,Product2>();
        testZProductMap = new Map<String,Zuora__Product__c>();
       
        testProductMap.put('CG Base Bundle', new Product2(Name = 'CG Base Bundle', IsActive = true, ProductCode = 'SKU00001', Family = 'Listings',
                Product_Type__c = 'Bundle', Zuora_Product_Rate_Plan_Id__c = 'zprp100'
        ));
        testZProductMap.put('CG Base Bundle', new Zuora__Product__c(Name='CG Base Bundle', Zuora__SKU__c='SKU00001', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------//
        

        testProductMap.put('Featured Package', new Product2(Name = 'Featured Package', IsActive = true, ProductCode = 'SKU00002', Family = 'Listings',
                Product_Type__c = 'Bundle', Zuora_Product_Rate_Plan_Id__c = 'zprp100'
        ));
        testZProductMap.put('Featured Package', new Zuora__Product__c(Name='Featured Package', Zuora__SKU__c='SKU00004', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------//
        
        testProductMap.put('Featured Placement', new Product2(Name = 'Featured Placement', IsActive = true, ProductCode = 'SKU00003', Family = 'Listings',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp101'
        ));
        testZProductMap.put('Featured Placement', new Zuora__Product__c(Name='Featured Placement', Zuora__SKU__c='SKU00003', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------//    
            
        testProductMap.put('Enhanced Placement', new Product2(Name = 'Enhanced Placement', IsActive = true, ProductCode = 'SKU00004', Family = 'Listings',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp102'
        ));
        testZProductMap.put('Enhanced Placement', new Zuora__Product__c(Name='Enhanced Placement', Zuora__SKU__c='SKU00004', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------// 
        
        testProductMap.put('CarGurus Managed Text/Chat', new Product2(Name = 'CarGurus Managed Text/Chat', IsActive = true, ProductCode = 'SKU00005', Family = 'Add Ons',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp103'
        ));
        testZProductMap.put('CarGurus Managed Text/Chat', new Zuora__Product__c(Name='CarGurus Managed Text/Chat', Zuora__SKU__c='SKU00005', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------// 
        
        testProductMap.put('Dealer Branding', new Product2(Name = 'Dealer Branding', IsActive = true, ProductCode = 'SKU00006', Family = 'None',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp104'
        ));
        testZProductMap.put('Dealer Branding', new Zuora__Product__c(Name='Dealer Branding', Zuora__SKU__c='SKU00006', Zuora__EffectiveEndDate__c =productEndDate));
        
        //-----------------------------// 
        
        testProductMap.put('CarGurus Delivery', new Product2(Name = 'CarGurus Delivery', IsActive = true, ProductCode = 'SKU00007', Family = 'Listings',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp105'
        ));
        testZProductMap.put('CarGurus Delivery', new Zuora__Product__c(Name='CarGurus Delivery', Zuora__SKU__c='SKU00007', Zuora__EffectiveEndDate__c =productEndDate));
        
        //-----------------------------//
        

        testProductMap.put('CarGurus Delivery - 300 Miles', new Product2(Name = 'CarGurus Delivery - 300 Miles', IsActive = true, ProductCode = 'SKU00008', Family = 'Listings',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp106'
        ));
        testZProductMap.put('CarGurus Delivery - 300 Miles', new Zuora__Product__c(Name='CarGurus Delivery - 300 Miles', Zuora__SKU__c='SKU00008', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------//
        

        testProductMap.put('CarGurus Delivery - 500 Miles', new Product2(Name = 'CarGurus Delivery - 500 Miles', IsActive = true, ProductCode = 'SKU00009', Family = 'Listings',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp107'
        ));
        testZProductMap.put('CarGurus Delivery - 500 Miles', new Zuora__Product__c(Name='CarGurus Delivery - 500 Miles', Zuora__SKU__c='SKU00009', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------//
        

        testProductMap.put('CarGurus Delivery - 1500 Miles', new Product2(Name = 'CarGurus Delivery - 1500 Miles', IsActive = true, ProductCode = 'SKU000010', Family = 'Listings',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp108'
        ));
        testZProductMap.put('CarGurus Delivery - 1500 Miles', new Zuora__Product__c(Name='CarGurus Delivery - 1500 Miles', Zuora__SKU__c='SKU000010', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------//
        
        testProductMap.put('Highlight', new Product2(Name = 'Highlight', IsActive = true, ProductCode = 'SKU000011', Family = 'Listings',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp109'
        ));
        testZProductMap.put('Highlight', new Zuora__Product__c(Name='Highlight', Zuora__SKU__c='SKU000011', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------// 
        
         testProductMap.put('CarGurus SEM', new Product2(Name = 'CarGurus SEM', IsActive = true, ProductCode = 'SKU000012', Family = 'Display',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp110'
        ));
        testZProductMap.put('CarGurus SEM', new Zuora__Product__c(Name='CarGurus SEM', Zuora__SKU__c='SKU000012', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------//
        
        testProductMap.put('Display - Focus', new Product2(Name = 'Display - Focus - Enhanced', IsActive = true, ProductCode = 'SKU000013', Family = 'Display',
                Product_Type__c = 'Standalone', Zuora_Product_Rate_Plan_Id__c = 'zprp1111'
        ));
        testZProductMap.put('Display - Focus', new Zuora__Product__c(Name='Display - Focus - Featured', Zuora__SKU__c='SKU000013', Zuora__EffectiveEndDate__c =productEndDate));
        //-----------------------------//
        
        for(Product2 p : testProductMap.values()) {
            System.debug(p.Name);
        }
        insert testProductMap.values();
        insert testZProductMap.values();
        
        ID pricebookId = Test.getStandardPricebookId();
        PricebookEntry[] pbeList = new List<PricebookEntry>();
        
        for (Product2 p : testProductMap.values()) {
            pbeList.add(
                new PricebookEntry(
                    Product2Id = p.Id,
                    Pricebook2Id = pricebookId,
                    CurrencyIsoCode = 'USD',
                    UnitPrice = 1,
                    IsActive = true
                )
            );
        }
        insert pbeList;
        
        //create product options
		List<SBQQ__ProductOption__c> productOptions = new List<SBQQ__ProductOption__c>();
        productOptions.add(new SBQQ__ProductOption__c(SBQQ__ConfiguredSKU__c=testProductMap.get('CG Base Bundle').Id, SBQQ__OptionalSKU__c=testProductMap.get('Featured Package').Id, SBQQ__Number__c=10));
        productOptions.add(new SBQQ__ProductOption__c(SBQQ__ConfiguredSKU__c=testProductMap.get('Featured Package').Id, SBQQ__OptionalSKU__c=testProductMap.get('Featured Placement').Id, SBQQ__Number__c=1));
        productOptions.add(new SBQQ__ProductOption__c(SBQQ__ConfiguredSKU__c=testProductMap.get('Featured Package').Id, SBQQ__OptionalSKU__c=testProductMap.get('Dealer Branding').Id, SBQQ__Number__c=2));
        productOptions.add(new SBQQ__ProductOption__c(SBQQ__ConfiguredSKU__c=testProductMap.get('Featured Package').Id, SBQQ__OptionalSKU__c=testProductMap.get('CarGurus Managed Text/Chat').Id, SBQQ__Number__c=3));
        productOptions.add(new SBQQ__ProductOption__c(SBQQ__ConfiguredSKU__c=testProductMap.get('CG Base Bundle').Id, SBQQ__OptionalSKU__c=testProductMap.get('Enhanced Placement').Id, SBQQ__Number__c=1));
        productOptions.add(new SBQQ__ProductOption__c(SBQQ__ConfiguredSKU__c=testProductMap.get('CG Base Bundle').Id, SBQQ__OptionalSKU__c=testProductMap.get('CarGurus Delivery').Id, SBQQ__Number__c=10));
        productOptions.add(new SBQQ__ProductOption__c(SBQQ__ConfiguredSKU__c=testProductMap.get('CG Base Bundle').Id, SBQQ__OptionalSKU__c=testProductMap.get('Highlight').Id, SBQQ__Number__c=10));
        //productOptions.add(new SBQQ__ProductOption__c(SBQQ__ConfiguredSKU__c=testProductMap.get('CG Base Bundle').Id, SBQQ__OptionalSKU__c=testProductMap.get('CarGurus SEM').Id, SBQQ__Number__c=1));
        insert productOptions;
        
        for(SBQQ__ProductOption__c sbpo : productOptions) {
            Map<Id, Id> optional = new Map<Id, Id>{
                sbpo.SBQQ__OptionalSKU__c=>sbpo.Id
            };
            
            BackfillCPQContractsHelper.productBundleOptionMap.put(sbpo.SBQQ__ConfiguredSKU__c, optional);
        }
    }
    
    private static String zSubKeyPrefix = '';
    
    private static void setupTestAccountSpecificData() {
        setupTestProductData();
        
        // set up test accounts
        Account[] testAccounts = new List<Account>();
        
        Account legacyAccount = new Account(Name = 'Test Legacy Account', BillingCountryCode = 'US', 
        RecordTypeId = corporateAccount.getRecordTypeId(), OwnerId = UserInfo.getUserId());
        insert legacyAccount;

        Account ultimateParent = new Account(Name = 'Test Account Ultimate Parent', BillingCountryCode = 'US', 
            RecordTypeId = corporateAccount.getRecordTypeId(), Legacy_Id__c = legacyAccount.Id,
            OwnerId = UserInfo.getUserId());
        insert ultimateParent;
         
        testAccounts.add(new Account(Name = 'Test Account 1', BillingCountryCode = 'US',
                	ParentId = ultimateParent.Id, RecordTypeId = dealerAccount.getRecordTypeId(),
                    OwnerId = UserInfo.getUserId()));
        testAccounts.add(new Account(Name = 'Test Account 2', BillingCountryCode = 'US',
                	ParentId = ultimateParent.Id, RecordTypeId = dealerAccount.getRecordTypeId(),
                    OwnerId = UserInfo.getUserId()));
        testAccounts.add(new Account(Name = 'Test Account 3', BillingCountryCode = 'US',
                	ParentId = ultimateParent.Id, RecordTypeId = dealerAccount.getRecordTypeId(),
                    OwnerId = UserInfo.getUserId()));
        
        insert testAccounts;
        
        
        setupTestAccountSpecificData(testAccounts, legacyAccount);
    }
    
    // initialize dateTime object to be in the last 2 hours to set on the subscription
    //private static DateTime zsubLastModDateTime = Datetime.now().addHours(-1);
    private static Date subStartDate = Date.today().addMonths(-8);
    
    private static void setupTestAccountSpecificData(Account[] testAccounts, Account legAcc) {
        
        //setupTestProductData();
        
        //set up test Contacts
        Integer i = 0;
        Contact[] testContacts = new List<Contact>();
        testContacts.add(new Contact(AccountId=testAccounts[0].Id, FirstName='fname1', LastName='lname1', Email='test1@cargurus.com'));
        testContacts.add(new Contact(AccountId=testAccounts[0].Id, FirstName='fname2', LastName='lname2', Email='test2@cargurus.com'));
        testContacts.add(new Contact(AccountId=testAccounts[1].Id, FirstName='fname3', LastName='lname3', Email='test3@cargurus.com'));
        testContacts.add(new Contact(AccountId=testAccounts[1].Id, FirstName='fname4', LastName='lname4', Email='test4@cargurus.com'));
        testContacts.add(new Contact(AccountId=testAccounts[2].Id, FirstName='fname5', LastName='lname5', Email='test5@cargurus.com'));                
                
        insert testContacts;
        
        // initialize Zuora Billing Accounts
        Zuora__CustomerAccount__c[] zAccountList = new List<Zuora__CustomerAccount__c>();
        zAccountList.add(new Zuora__CustomerAccount__c(Name='Test BA1', Zuora__Status__c = 'Active', Zuora__Zuora_Id__c ='zuorabilling1',
                    Zuora__Account__c = testAccounts[0].Id, Zuora__BillToWorkEmail__c = testContacts[0].Email, Zuora__SoldToWorkEmail__c = testContacts[0].Email));
        zAccountList.add(new Zuora__CustomerAccount__c(Name='Test BA2', Zuora__Status__c = 'Active', Zuora__Zuora_Id__c ='zuorabilling2',
                    Zuora__Account__c = testAccounts[1].Id, Zuora__BillToWorkEmail__c = testContacts[2].Email, Zuora__SoldToWorkEmail__c = testContacts[2].Email));
        zAccountList.add(new Zuora__CustomerAccount__c(Name='Test BA3', Zuora__Status__c = 'Active', Zuora__Zuora_Id__c ='zuorabilling3',
                    Zuora__Account__c = testAccounts[2].Id, Zuora__BillToWorkEmail__c = testContacts[4].Email, Zuora__SoldToWorkEmail__c = testContacts[4].Email));
        insert zAccountList;
        
        //Insert a Contract to fetch a SalesforceLegacyContractId
        Contract co = new Contract(
            AccountId = legAcc.Id,
            CurrencyISOCode='USD',
            OwnerId = legAcc.OwnerId,
            Name = 'Legacy-Contract',
            StartDate = Date.today().addMonths(-6),
            EndDate = Date.today().addMonths(-3),
            ContractTerm = 12
        );
        insert co;

        // initialize Subscriptions
        Zuora__Subscription__c[] zSubList = new List<Zuora__Subscription__c>();
        zSubList.add(new Zuora__Subscription__c(Name = 'A-S0001', Zuora__Account__c = zAccountList[0].Zuora__Account__c, 
                    Zuora__CustomerAccount__c = zAccountList[0].id, Zuora__SubscriptionNumber__c = '0001', 
                    Zuora__SubscriptionStartDate__c = subStartDate, Zuora__ServiceActivationDate__c = subStartDate,
                	Zuora__InvoiceOwner__c = zAccountList[0].Id, Zuora__Status__c = 'Active', 
                    Zuora__SubscriptionEndDate__c = subStartDate.addMonths(12), Zuora__External_Id__c = 'zuorasub1', 
                    SalesforceLegacyContractId__c = co.Id, SalesforceLegacyAccountId__c = legAcc.Id,
                    Zuora__InitialTerm__c = '100 Days'));
        zSubList.add(new Zuora__Subscription__c(Name = 'A-S0002', Zuora__Account__c = zAccountList[1].Zuora__Account__c, 
                    Zuora__CustomerAccount__c = zAccountList[1].id,
                    Zuora__SubscriptionNumber__c = '0002', Zuora__SubscriptionStartDate__c = subStartDate, 
                    Zuora__ServiceActivationDate__c = subStartDate,
                	Zuora__InvoiceOwner__c = zAccountList[1].Id, Zuora__Status__c = 'Active', 
                    Zuora__SubscriptionEndDate__c = subStartDate.addMonths(12), Zuora__External_Id__c = 'zuorasub2',
                    SalesforceLegacyContractId__c = co.Id, SalesforceLegacyAccountId__c = legAcc.Id,
                    Zuora__InitialTerm__c = '100 Days'));
       	zSubList.add(new Zuora__Subscription__c(Name = 'A-S0003', Zuora__Account__c = zAccountList[2].Zuora__Account__c, 
                    Zuora__CustomerAccount__c = zAccountList[2].id,
                    Zuora__SubscriptionNumber__c = '0003', Zuora__SubscriptionStartDate__c = subStartDate, 
                    Zuora__ServiceActivationDate__c = subStartDate, Zuora__InvoiceOwner__c = zAccountList[2].Id, 
                    Zuora__SubscriptionEndDate__c = subStartDate.addMonths(12), Zuora__Status__c = 'Active', Zuora__External_Id__c = 'zuorasub3',
                    SalesforceLegacyContractId__c = co.Id, SalesforceLegacyAccountId__c = legAcc.Id,
                    Zuora__InitialTerm__c = '100 Days'));
                
        insert zSubList;
        
        // initialize Subscription Rate Plans
        Zuora__SubscriptionRatePlan__c[] zSubRatePlanList = new List<Zuora__SubscriptionRatePlan__c>();
                
        //Featured Package for Account[0]
        zSubRatePlanList.add(new Zuora__SubscriptionRatePlan__c(
            Name = 'Monthly Fee', 
            Zuora__Account__c = zSubList[0].Zuora__Account__c,
            Zuora__Subscription__c = zSubList[0].Id, 
            Zuora__OriginalProductRatePlanId__c =  testProductMap.get('Featured Package').Zuora_Product_Rate_Plan_Id__c,
            Zuora__External_Id__c = 'zuorasubrateplan1'
            ));

        zSubRatePlanList.add(new Zuora__SubscriptionRatePlan__c(Name = 'Monthly Fee', 
            Zuora__Account__c = zSubList[0].Zuora__Account__c,
            Zuora__Subscription__c = zSubList[0].Id, 
            Zuora__OriginalProductRatePlanId__c =  testProductMap.get('Featured Placement').Zuora_Product_Rate_Plan_Id__c,
            Zuora__External_Id__c = 'zuorasubrateplan2'));

        //Enhanced Package for Account[1]
        zSubRatePlanList.add(new Zuora__SubscriptionRatePlan__c(Name = 'Monthly Fee', Zuora__Account__c = zSubList[1].Zuora__Account__c,
                    Zuora__Subscription__c = zSubList[1].Id, 
                    Zuora__OriginalProductRatePlanId__c = testProductMap.get('Enhanced Placement').Zuora_Product_Rate_Plan_Id__c,
                    Zuora__External_Id__c = 'zuorasubrateplan5'));
        
        insert zSubRatePlanList;
        
        // initialize Subscription Rate Plan Charges
		//String prodName = prpZuoraIdMap.get(zrp.Zuora__OriginalProductRatePlanId__c).Name;
                
        Zuora__SubscriptionProductCharge__c[] subProdChargeList = 
            new List <Zuora__SubscriptionProductCharge__c>();
        
        //Featured Package - Account 0
        subProdChargeList.add(new Zuora__SubscriptionProductCharge__c(Zuora__Account__c = zSubRatePlanList[0].Zuora__Account__c,
            Zuora__SubscriptionRatePlan__c = zSubRatePlanList[0].Id, Zuora__Subscription__c = zSubRatePlanList[0].Zuora__Subscription__c,
            Zuora__RatePlanId__c = zSubRatePlanList[0].Zuora__External_Id__c, Zuora__Product__c = testZProductMap.get('Featured Package').Id,
            Zuora__Type__c='Recurring', Name = 'Monthly Fee', Zuora__Model__c = 'Flat Fee Pricing',Zuora__Price__c = 250.00, 
			Zuora__ExtendedAmount__c = 250.00, Zuora__EffectiveStartDate__c = subStartDate, Zuora__Quantity__c = 1.0, 
			Zuora__Upto_How_Many_Periods__c = null));

        //Featured Package - Account 0
        subProdChargeList.add(new Zuora__SubscriptionProductCharge__c(Zuora__Account__c = zSubRatePlanList[0].Zuora__Account__c,
            Zuora__SubscriptionRatePlan__c = zSubRatePlanList[0].Id, Zuora__Subscription__c = zSubRatePlanList[0].Zuora__Subscription__c,
            Zuora__RatePlanId__c = zSubRatePlanList[0].Zuora__External_Id__c, Zuora__Product__c = testZProductMap.get('Featured Package').Id,
            Name = 'Intro-Discount', Zuora__Model__c = 'Discount-Percentage',Zuora__Price__c = 250.00, 
			Zuora__ExtendedAmount__c = 250.00, Zuora__EffectiveStartDate__c = subStartDate, Zuora__EffectiveEndDate__c = subStartDate.addMonths(1),
            Zuora__Quantity__c = 1.0, Zuora__Upto_How_Many_Periods__c = 1)); 
           
        //Enhanced placement - account 1
        subProdChargeList.add(new Zuora__SubscriptionProductCharge__c(Zuora__Account__c = zSubRatePlanList[1].Zuora__Account__c,
            Zuora__SubscriptionRatePlan__c = zSubRatePlanList[1].Id, Zuora__Subscription__c = zSubRatePlanList[1].Zuora__Subscription__c,
            Zuora__RatePlanId__c = zSubRatePlanList[1].Zuora__External_Id__c, Zuora__Product__c = testZProductMap.get('Enhanced Placement').Id,
            Zuora__Type__c='Recurring', Name = 'Monthly Fee', Zuora__Model__c = 'Flat Fee Pricing',Zuora__Price__c = 250.00, 
			Zuora__ExtendedAmount__c = 250.00, Zuora__EffectiveStartDate__c = subStartDate, Zuora__Quantity__c = 1.0, 
			Zuora__Upto_How_Many_Periods__c = null));
        
        //Enhanced placement - account 1
        subProdChargeList.add(new Zuora__SubscriptionProductCharge__c(Zuora__Account__c = zSubRatePlanList[2].Zuora__Account__c,
            Zuora__SubscriptionRatePlan__c = zSubRatePlanList[2].Id, Zuora__Subscription__c = zSubRatePlanList[2].Zuora__Subscription__c,
            Zuora__RatePlanId__c = zSubRatePlanList[2].Zuora__External_Id__c, Zuora__Product__c = testZProductMap.get('Highlight').Id,
            Zuora__Type__c='One Time', Name = 'Intro Discount Amount', Zuora__Model__c = 'Discount-Fixed Amount',Zuora__Price__c = 250.00, 
			Zuora__ExtendedAmount__c = 650.00, Zuora__EffectiveStartDate__c = subStartDate, Zuora__Quantity__c = 1.0, 
			Zuora__Upto_How_Many_Periods__c = null));
        insert subProdChargeList; 
                
        Zuora__SubscriptionProductCharge__c[] subProdChargeList2 = [SELECT Id, Zuora__Product__r.Name FROM Zuora__SubscriptionProductCharge__c];
        for(Zuora__SubscriptionProductCharge__c pc : subProdChargeList2){
			System.debug(pc.Zuora__Product__r.Name);
        }        
    }
    
    @isTest
    static void testBackfill() {
        setupTestAccountSpecificData();
        
        Test.startTest();
        database.executeBatch(new Batch_BackfillCPQContracts());
        Test.stopTest();

        List<Contract> ct = [SELECT Id FROM Contract];

        System.assert(ct.size() > 0);
    }
    
    @isTest
    static void testBackfillSingleAccount() {
        setupTestAccountSpecificData();
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Account Ultimate Parent' LIMIT 1];
        Test.startTest();
        database.executeBatch(new Batch_BackfillCPQContracts(a.Id));
        Test.stopTest();

        List<Contract> ct = [SELECT Id FROM Contract];

        System.assert(ct.size() > 0);
    }
    
    @isTest
    static void testBackfillSetAccount() {
        setupTestAccountSpecificData();

        Map<Id, Account> accMap = new Map<Id, Account>([SELECT Id FROM Account 
            WHERE Ultimate_Parent_Account__r.Name = 'Test Account Ultimate Parent']);

        Set<Id> accIds = accMap.keySet();
        Test.startTest();
        database.executeBatch(new Batch_BackfillCPQContracts(accIds));
        Test.stopTest();

        List<Contract> ct = [SELECT Id FROM Contract];

        System.assert(ct.size() > 0);
    }
    
    @isTest
    static void testBackfillQueryLimit() {
        setupTestAccountSpecificData();
        
        Test.startTest();
        database.executeBatch(new Batch_BackfillCPQContracts(100));
        Test.stopTest();

        List<Contract> ct = [SELECT Id FROM Contract];

        System.assert(ct.size() > 0);
    }

    @isTest
    static void testBackfillCountryCode() {
        setupTestAccountSpecificData();

        Test.startTest();
        database.executeBatch(new Batch_BackfillCPQContracts('US'));
        Test.stopTest();

        List<Contract> ct = [SELECT Id FROM Contract];

        System.assert(ct.size() > 0);
    }
    
    @isTest
    static void testBackfillErrorTask() {
        setupTestAccountSpecificData();
        Account a = [SELECT Id, Name, OwnerId FROM Account WHERE Name = 'Test Account Ultimate Parent' LIMIT 1];
        
        Test.startTest();
        BackfillCPQContractsHelper.setErrorTask(a.Id, 'Bump up coverage');
        Test.stopTest();

        List<Contract> ct = [SELECT Id FROM Contract];

        System.assert(ct.size() > 0);
    }
}