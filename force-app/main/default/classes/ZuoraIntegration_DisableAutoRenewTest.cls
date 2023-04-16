@isTest
public with sharing class ZuoraIntegration_DisableAutoRenewTest {
    static Schema.DescribeSObjectResult accd = Schema.SObjectType.Account;
	static Map<String,Schema.RecordTypeInfo> rtMapByName = accd.getRecordTypeInfosByName();
	static Schema.RecordTypeInfo corporateAccount =  rtMapByName.get('Corporate Account'); 
    static Schema.RecordTypeInfo dealerAccount = rtMapByName.get('Dealer Account');

    @TestSetup
    static void makeData(){
        
        //Create Products
        Map<String,Product2> testProductsMap = new Map<String, Product2>{
            'CG Base Bundle' => new Product2(Name = 'CG Base Bundle', IsActive = true, ProductCode = 'SKU00001', Family = 'Listings',
                Product_Type__c = 'Bundle', Zuora_Product_Rate_Plan_Id__c = 'zprp100'),
            
            'Featured Package' => new Product2(Name = 'Featured Package', IsActive = true, ProductCode = 'SKU00002', Family = 'Listings',
                Product_Type__c = 'Bundle', Zuora_Product_Rate_Plan_Id__c = 'zprp100') 
        };
        insert testProductsMap.values();

        ID pricebookId = Test.getStandardPricebookId();
        PricebookEntry[] pbeList = new List<PricebookEntry>();
        
        for (Product2 p : testProductsMap.values()) {
            pbeList.add( new PricebookEntry(Product2Id = p.Id, Pricebook2Id = pricebookId, CurrencyIsoCode = 'USD',
                    UnitPrice = 1, IsActive = true)
            );
        }
        insert pbeList;

        //Create Account
        Account tstAccount = new Account(Name = 'Test Account 1', BillingCountryCode = 'US',
            ParentId = null, RecordTypeId = dealerAccount.getRecordTypeId(),
            OwnerId = UserInfo.getUserId());
        insert tstAccount;

        //Create contact
        Contact tstContact = new Contact(AccountId=tstAccount.Id, 
            FirstName='fname1', LastName='lname1', Email='test1@cargurus.com');
        insert tstContact;
        
        // initialize Zuora Billing Accounts
        Zuora__CustomerAccount__c zAccount = new Zuora__CustomerAccount__c(Name='Test BA1', Zuora__Status__c = 'Active', 
            Zuora__Zuora_Id__c ='zuorabilling1', Zuora__Account__c = tstAccount.Id, 
            Zuora__BillToWorkEmail__c = tstContact.Email, Zuora__SoldToWorkEmail__c = tstContact.Email);
        insert zAccount;

        //Create Zuora Subscriptions
        Date subStartDate = Date.today().addMonths(-8);

        Zuora__Subscription__c zs = new Zuora__Subscription__c(Name = 'A-S0001', Zuora__Account__c = zAccount.Zuora__Account__c, 
                    Zuora__CustomerAccount__c = zAccount.Id, Zuora__SubscriptionNumber__c = '0001', 
                    Zuora__SubscriptionStartDate__c = subStartDate, Zuora__ServiceActivationDate__c = subStartDate,
                	Zuora__InvoiceOwner__c = zAccount.Id, Zuora__Status__c = 'Active', 
                    Zuora__SubscriptionEndDate__c = subStartDate.addMonths(12), Zuora__External_Id__c = 'zuorasub1',
                    Zuora__InitialTerm__c = '100 Days', Zuora__AutoRenew__c = true);
        insert zs;

        //Create Contract
        Contract co = new Contract(AccountId = tstAccount.Id, CurrencyISOCode='USD', OwnerId = tstAccount.OwnerId,
            Name = 'Test Contract', StartDate = Date.today().addMonths(-6), EndDate = Date.today().addMonths(-3),
            ContractTerm = 12);
        insert co;

        //Create cpq subs
        List<SBQQ__Subscription__c> cpqSubs = TestDataFactory.createCPQSubsForProducts(testProductsMap.values(), 
            tstAccount.Id);
        for(SBQQ__Subscription__c cpqSub : cpqSubs) {
            cpqSub.Zuora_Subscription__c = zs.Id;
            cpqSub.SBQQ__Contract__c = co.Id;
        }
        insert cpqSubs;
    }

    @IsTest
    static void testDisableAutoRenewBatch() {
        
        List<Contract> cts = [SELECT Id, Auto_Renewal_Disable_Date__c FROM Contract];

        List<SBQQ__Subscription__c> cpqSubs = [SELECT Id, Zuora_Subscription__r.Zuora__Zuora_Id__c, Zuora_Subscription_Number__c, 
                Zuora_Subscription__r.Zuora__AutoRenew__c, Fulfillment_Account__c,
                Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c
                FROM  SBQQ__Subscription__c
                WHERE SBQQ__ProductName__c = 'CG Base Bundle' 
                AND Zuora_Subscription__r.Zuora__AutoRenew__c = true
                AND SBQQ__Contract__c IN :new Map<Id, Contract>(cts).keySet()];

        System.debug(cpqSubs);

        List<Zuora__Subscription__c> updateZSubs = new List<Zuora__Subscription__c>();
        for(Contract ct : cts) {
            ct.Auto_Renewal_Disable_Date__c = Date.today();
        }
        update cts;
        
        Test.startTest();
        Database.executeBatch(new ZuoraIntegration_DisableAutoRenewBatch());
        Test.stopTest();
    }

    @isTest
    static void testScheduleDisableAutoRenewBatch() {
        
        List<Contract> cts = [SELECT Id, Auto_Renewal_Disable_Date__c FROM Contract];

        List<SBQQ__Subscription__c> cpqSubs = [SELECT Id, Zuora_Subscription__r.Zuora__Zuora_Id__c, Zuora_Subscription_Number__c, 
                Zuora_Subscription__r.Zuora__AutoRenew__c, Fulfillment_Account__c,
                Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c
                FROM  SBQQ__Subscription__c
                WHERE SBQQ__ProductName__c = 'CG Base Bundle' 
                AND Zuora_Subscription__r.Zuora__AutoRenew__c = true
                AND SBQQ__Contract__c IN :new Map<Id, Contract>(cts).keySet()];

        System.debug(cpqSubs);

        List<Zuora__Subscription__c> updateZSubs = new List<Zuora__Subscription__c>();
        for(Contract ct : cts) {
            ct.Auto_Renewal_Disable_Date__c = Date.today();
        }
        update cts;
        
        ZuoraIntegration_DisableAutoRenewBatch zDisableAutoRenew = new ZuoraIntegration_DisableAutoRenewBatch();
        String cronString = '0 0 20 * * ?';

        Test.startTest();
        String jobId = System.schedule('Test_ZuoraIntegration_DisableAutoRenewBatch', cronString, zDisableAutoRenew);
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
    }
}