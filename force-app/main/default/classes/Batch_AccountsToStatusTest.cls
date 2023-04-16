@isTest
public without sharing class Batch_AccountsToStatusTest {
    
    @TestSetup
    static void makeData(){
        Test.startTest();
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Active';
        insert accts;

        //Create contact
        Contact tstContact = new Contact(AccountId=accts[0].Id, 
            FirstName='fname1', LastName='lname1', Email='test1@cargurus.com');
        insert tstContact;

        Product2[] products = TestDataFactory.createProducts(2);
        products[0].Name = 'CG Base Bundle';
        products[0].ProductCode = 'CG-BASE';
        products[1].Name = 'Enhanced';
        products[1].Family = 'Listings';
        products[1].product_category__c = 'Core Products';
        insert products;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 2);
        opps[1].RecordTypeId = Utilities.getrecordTypeId('Opportunity', 'Retention');
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        quotes[0].Payment_Method__c = 'Credit Card';
        insert quotes;        

        Id pricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pricebookId, Product2Id = products[0].Id, UnitPrice = 1020, IsActive = true);
        insert pbe;

        SBQQ__QuoteLine__c[] quoteLines = new List<SBQQ__QuoteLine__c>{
            new SBQQ__QuoteLine__c(
                Fulfillment_Account__c = accts[0].Id,
                SBQQ__Product__c = products[0].Id,
                SBQQ__Quote__c = quotes[0].Id,
                SBQQ__Quantity__c = 1)
        };
        insert quoteLines;
        
        Contract contr = TestDataFactory.createContract(accts[0].Id);
        contr.EndDate = Date.today().addMonths(1);
        contr.SBQQ__Quote__c = quotes[0].Id;
        contr.Cancellation_Effective_Date__c = null;
        insert contr;

        // initialize Zuora Billing Accounts
        Zuora__CustomerAccount__c zAccount = new Zuora__CustomerAccount__c(Name='Test BA1', Zuora__Status__c = 'Active', 
            Zuora__Zuora_Id__c ='zuorabilling1', Zuora__Account__c = accts[0].Id, 
            Zuora__BillToWorkEmail__c = tstContact.Email, Zuora__SoldToWorkEmail__c = tstContact.Email,
            Zuora__AccountNumber__c = 'TEST-001', Zuora__DefaultPaymentMethod__c = 'CreditCard');
        insert zAccount;

        accts[0].Billing_Account_Zuora__c = zAccount.Id;
        update accts;

        //Create Zuora Subscriptions
        Date subStartDate = Date.today().addMonths(-8);

        Zuora__Subscription__c zs = new Zuora__Subscription__c(Name = 'A-S0001', Zuora__Account__c = zAccount.Zuora__Account__c, 
                    Zuora__CustomerAccount__c = zAccount.Id, Zuora__SubscriptionNumber__c = '0001', 
                    Zuora__SubscriptionStartDate__c = subStartDate, Zuora__ServiceActivationDate__c = subStartDate,
                	Zuora__InvoiceOwner__c = zAccount.Id, Zuora__Status__c = 'Active', 
                    Zuora__SubscriptionEndDate__c = subStartDate.addMonths(12), Zuora__External_Id__c = 'zuorasub1',
                    Zuora__InitialTerm__c = '100 Days', Zuora__AutoRenew__c = true);
        insert zs;

        SBQQ__Subscription__c[] subs = TestDataFactory.createCPQSubsForProducts(products, accts[0].Id);
        for(SBQQ__Subscription__c sub : subs) {
          sub.SBQQ__Contract__c = contr.Id;
          sub.SBQQ__Account__c = accts[0].Id;
          sub.Billing_Account__c = accts[0].Id;
          sub.Zuora_Subscription_Number__c = 'TEST';
          sub.SBQQ__SubscriptionEndDate__c = Date.today().addDays(-1);
        }
        insert subs;

        subs[1].SBQQ__RequiredById__c = subs[0].Id;
        subs[0].Zuora_Subscription__c = zs.Id;
        subs[0].SBQQ__QuoteLine__c = quoteLines[0].Id;
        update subs;
        Test.stopTest();
    }

    @isTest
    static void testAccountsToCanceling() {

        SBQQ__Subscription__c sub = [
          SELECT Id, Fulfillment_Account__c, SBQQ__Contract__c, SBQQ__ProductName__c, SBQQ__RevisedSubscription__c,
            SBQQ__Quantity__c, SBQQ__TerminatedDate__c, SBQQ__RequiredById__c, SBQQ__Account__c,
            SBQQ__Product__r.Family, SBQQ__Product__r.product_category__c, SBQQ__Product__r.Sub_Category__c,
            Provisioning_Status__c
          FROM SBQQ__Subscription__c
          WHERE SBQQ__ProductName__c != 'CG Base Bundle'
          LIMIT 1
        ];
  
        SBQQ__Subscription__c removalSub = sub.clone(false, true, false, false);
        removalSub.SBQQ__Quantity__c = -1;
        removalSub.SBQQ__RevisedSubscription__c = sub.Id;
        removalSub.SBQQ__TerminatedDate__c = System.today().addDays(-1);
        removalSub.Provisioning_Status__c = 'De-activated';
  
        SBQQ__Subscription__c bundleSub = [
          SELECT Id, Fulfillment_Account__c, SBQQ__Contract__c, SBQQ__ProductName__c, SBQQ__RevisedSubscription__c,
            SBQQ__Quantity__c, SBQQ__TerminatedDate__c, SBQQ__RequiredById__c, SBQQ__Account__c,
            SBQQ__Product__r.Family, SBQQ__Product__r.product_category__c, SBQQ__Product__r.Sub_Category__c,
            Provisioning_Status__c
          FROM SBQQ__Subscription__c
          WHERE SBQQ__ProductName__c = 'CG Base Bundle'
          LIMIT 1
        ];
  
        SBQQ__Subscription__c removalBundleSub = bundleSub.clone(false, true, false, false);
        removalBundleSub.SBQQ__Quantity__c = -1;
        removalBundleSub.SBQQ__RevisedSubscription__c = bundleSub.Id;
        removalBundleSub.SBQQ__TerminatedDate__c = System.today().addDays(-1);
        removalBundleSub.Provisioning_Status__c = 'De-activated';
        insert removalBundleSub;

        //setting dependency before inserting
        removalSub.SBQQ__RequiredById__c = removalBundleSub.Id;
        insert removalSub;
  
        //update the terminated date of the original subs
        sub.SBQQ__TerminatedDate__c = System.today().addDays(-1);
        sub.Provisioning_Status__c = 'De-activated';
        
        bundleSub.SBQQ__TerminatedDate__c = System.today().addDays(-1);
        bundleSub.Provisioning_Status__c = 'De-activated';

        List<SBQQ__Subscription__c> updateOriginalSubs = new List<SBQQ__Subscription__c>{
            sub,
            bundleSub
        };
        update updateOriginalSubs;

        Contract ct = [SELECT Id, Status, Cancellation_Effective_Date__c FROM Contract LIMIT 1];
        ct.Status = 'Cancelled';
        ct.Cancellation_Effective_Date__c = Date.today().addDays(-1);
        update ct;
  
        Test.startTest();
            Database.executeBatch(new Batch_AccountsToCanceling());
        Test.stopTest();
  
        SBQQ__Subscription__c[] subsRequery = [
          SELECT Id, SBQQ__Product__c, SBQQ__Account__c, Provisioning_Status__c
          FROM SBQQ__Subscription__c
          WHERE Fulfillment_Account__c = :sub.Fulfillment_Account__c AND SBQQ__Contract__c = :sub.SBQQ__Contract__c
        ];
       
        System.assertEquals(4, subsRequery.size());
  
        Account acc = [
          SELECT Id, Product_Activation_Status__c, Type
          FROM Account
          WHERE Id = :sub.SBQQ__Account__c
        ];
        System.assertEquals('Former Customer', acc.Type);
        System.assertEquals(ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_CANCELING57DAYS, acc.Product_Activation_Status__c);
    }

    @isTest
    static void testAccountsToRestricted() {

        Account act = [SELECT Id, Product_Activation_Status__c, Type FROM Account LIMIT 1];
        act.Type = 'Former Customer';
        act.Product_Activation_Status__c = 'Canceling – 57 days';
        update act;

        SBQQ__Subscription__c sub = [
          SELECT Id, Fulfillment_Account__c, SBQQ__Contract__c, SBQQ__ProductName__c, SBQQ__RevisedSubscription__c,
            SBQQ__Quantity__c, SBQQ__TerminatedDate__c, SBQQ__RequiredById__c, SBQQ__Account__c,
            SBQQ__Product__r.Family, SBQQ__Product__r.product_category__c, SBQQ__Product__r.Sub_Category__c,
            Provisioning_Status__c
          FROM SBQQ__Subscription__c
          WHERE SBQQ__ProductName__c != 'CG Base Bundle'
          LIMIT 1
        ];
  
        SBQQ__Subscription__c removalSub = sub.clone(false, true, false, false);
        removalSub.SBQQ__Quantity__c = -1;
        removalSub.SBQQ__RevisedSubscription__c = sub.Id;
        removalSub.SBQQ__TerminatedDate__c = System.today().addDays(-58);
        removalSub.Provisioning_Status__c = 'De-activated';
  
        SBQQ__Subscription__c bundleSub = [
          SELECT Id, Fulfillment_Account__c, SBQQ__Contract__c, SBQQ__ProductName__c, SBQQ__RevisedSubscription__c,
            SBQQ__Quantity__c, SBQQ__TerminatedDate__c, SBQQ__RequiredById__c, SBQQ__Account__c,
            SBQQ__Product__r.Family, SBQQ__Product__r.product_category__c, SBQQ__Product__r.Sub_Category__c,
            Provisioning_Status__c
          FROM SBQQ__Subscription__c
          WHERE SBQQ__ProductName__c = 'CG Base Bundle'
          LIMIT 1
        ];
  
        SBQQ__Subscription__c removalBundleSub = bundleSub.clone(false, true, false, false);
        removalBundleSub.SBQQ__Quantity__c = -1;
        removalBundleSub.SBQQ__RevisedSubscription__c = bundleSub.Id;
        removalBundleSub.SBQQ__TerminatedDate__c = System.today().addDays(-58);
        removalBundleSub.Provisioning_Status__c = 'De-activated';
        insert removalBundleSub;

        //setting dependency before inserting
        removalSub.SBQQ__RequiredById__c = removalBundleSub.Id;
        insert removalSub;
  
        //update the terminated date of the original subs
        sub.SBQQ__TerminatedDate__c = System.today().addDays(-58);
        sub.Provisioning_Status__c = 'De-activated';
        
        bundleSub.SBQQ__TerminatedDate__c = System.today().addDays(-58);
        bundleSub.Provisioning_Status__c = 'De-activated';

        List<SBQQ__Subscription__c> updateOriginalSubs = new List<SBQQ__Subscription__c>{
            sub,
            bundleSub
        };
        update updateOriginalSubs;

        Contract ct = [SELECT Id, Status, Cancellation_Effective_Date__c FROM Contract LIMIT 1];
        ct.Status = 'Cancelled';
        ct.Cancellation_Effective_Date__c = Date.today().addDays(-58);
        update ct;
  
        Test.startTest();
            Database.executeBatch(new Batch_AccountsToRestrictedActivated());
        Test.stopTest();
  
        SBQQ__Subscription__c[] subsRequery = [
          SELECT Id, SBQQ__Product__c, SBQQ__Account__c, Provisioning_Status__c
          FROM SBQQ__Subscription__c
          WHERE Fulfillment_Account__c = :sub.Fulfillment_Account__c AND SBQQ__Contract__c = :sub.SBQQ__Contract__c
        ];
        
        System.assertEquals(4, subsRequery.size());
  
        Account acc = [
          SELECT Id, Product_Activation_Status__c, Type
          FROM Account
          WHERE Id = :sub.SBQQ__Account__c
        ];
        System.assertEquals('Former Customer', acc.Type);
        System.assertEquals(ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_RESTRICTEDACTIVATED, acc.Product_Activation_Status__c);
    }
}
