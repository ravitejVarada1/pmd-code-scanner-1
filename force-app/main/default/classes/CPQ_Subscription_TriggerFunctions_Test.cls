@isTest
private class CPQ_Subscription_TriggerFunctions_Test {

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
        contr.SBQQ__Quote__c = quotes[0].Id;
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
        }
        insert subs;

        subs[1].SBQQ__RequiredById__c = subs[0].Id;
        subs[0].Zuora_Subscription__c = zs.Id;
        subs[0].SBQQ__QuoteLine__c = quoteLines[0].Id;
        update subs;
        Test.stopTest();
    }

    static testMethod void testCPQSubInsert() {

        Account[] accts = [SELECT ID FROM Account];
        Product2[] prods = [SELECT ID FROM Product2];

        Contract c = TestDataFactory.createContract(accts[0].Id);
        c.Status = 'Activated';
        insert c;

        Test.startTest();

        SBQQ__Subscription__c[] subs = TestDataFactory.createCPQSubsForProducts(prods, accts[0].Id);
        subs[0].SBQQ__Contract__c = c.Id;
        insert subs;

        Test.stopTest();

        subs = [SELECT ID, Provisioning_Status__c FROM SBQQ__Subscription__c WHERE Id in: subs];
        System.assertEquals(subs[0].Provisioning_Status__c,'Pending Activation');
        
        accts = [SELECT Id, Type FROM Account];
        System.assertEquals(accts[0].Type,'Customer');
    }

    static testMethod void testAccountTypeDeActivation() {
        
        Test.startTest();

        Contract[] contracts = [SELECT Id FROM Contract];
        for (Contract con : contracts) {
            con.EndDate = date.today().addDays(-1);
            con.Status = 'Cancelled';
        }
        update contracts;

        SBQQ__Subscription__c[] subs = [SELECT Id FROM SBQQ__Subscription__c];
        for (SBQQ__Subscription__c s : subs) {
            s.SBQQ__TerminatedDate__c = Date.today().addDays(-1);
        }
        update subs;

        Test.stopTest();

        Account[] accts = [SELECT Id, Type FROM Account];
        System.assertEquals(accts[0].Type, 'Former Customer');
    }

    static testMethod void evaluateCancellingBundleRemovalTest() {

      SBQQ__Subscription__c sub = [
        SELECT Id, Fulfillment_Account__c, SBQQ__Contract__c, SBQQ__ProductName__c, SBQQ__RevisedSubscription__c,
          SBQQ__Quantity__c, SBQQ__TerminatedDate__c, SBQQ__RequiredById__c, SBQQ__Account__c,
          SBQQ__Product__r.Family, SBQQ__Product__r.product_category__c, SBQQ__Product__r.Sub_Category__c 
        FROM SBQQ__Subscription__c
        WHERE SBQQ__ProductName__c != 'CG Base Bundle'
        LIMIT 1
      ];

      SBQQ__Subscription__c removalSub = sub.clone(false, true, false, false);
      removalSub.SBQQ__Quantity__c = -1;
      removalSub.SBQQ__RevisedSubscription__c = sub.Id;

      SBQQ__Subscription__c bundleSub = [
        SELECT Id, Fulfillment_Account__c, SBQQ__Contract__c, SBQQ__ProductName__c, SBQQ__RevisedSubscription__c,
          SBQQ__Quantity__c, SBQQ__TerminatedDate__c, SBQQ__RequiredById__c, SBQQ__Account__c,
          SBQQ__Product__r.Family, SBQQ__Product__r.product_category__c, SBQQ__Product__r.Sub_Category__c 
        FROM SBQQ__Subscription__c
        WHERE SBQQ__ProductName__c = 'CG Base Bundle'
        LIMIT 1
      ];

      SBQQ__Subscription__c removalBundleSub = bundleSub.clone(false, true, false, false);
      removalBundleSub.SBQQ__Quantity__c = -1;
      removalBundleSub.SBQQ__RevisedSubscription__c = bundleSub.Id;

      sub.SBQQ__TerminatedDate__c = System.today();
      bundleSub.SBQQ__TerminatedDate__c = System.today();
      removalSub.SBQQ__TerminatedDate__c = System.today();
      removalBundleSub.SBQQ__TerminatedDate__c = System.today();
      
      insert removalBundleSub;
      removalSub.SBQQ__RequiredById__c = removalBundleSub.Id;
      insert removalSub;
      
      Map<Id,SBQQ__Subscription__c> subsMap = new Map<Id,SBQQ__Subscription__c>();
      subsMap.put(removalBundleSub.Id, removalBundleSub);
      subsMap.put(removalSub.Id, removalSub);

      Test.startTest();
        CPQ_Subscription_TriggerFunctions.evaluateCancellingBundles(subsMap, subsMap);
      Test.stopTest();

      SBQQ__Subscription__c[] subsRequery = [
        SELECT Id, SBQQ__Product__c, SBQQ__Account__c
        FROM SBQQ__Subscription__c
        WHERE Fulfillment_Account__c = :sub.Fulfillment_Account__c AND SBQQ__Contract__c = :sub.SBQQ__Contract__c
      ];

      System.assertEquals(4, subsRequery.size());

      Account acc = [
        SELECT Id, Product_Activation_Status__c, Cancellation_Effective_Date__c
        FROM Account
        WHERE Id = :sub.SBQQ__Account__c
      ];

      System.assertEquals(ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE, acc.Product_Activation_Status__c);
    }

    static testMethod void evaluateCancellingBundleRateReductionTest() {
      
      SBQQ__Subscription__c sub = [
        SELECT Id, Fulfillment_Account__c, SBQQ__Contract__c, SBQQ__ProductName__c, SBQQ__RevisedSubscription__c,
          SBQQ__Quantity__c, SBQQ__TerminatedDate__c, SBQQ__RequiredById__c, SBQQ__Account__c,
          SBQQ__Product__r.Family, SBQQ__Product__r.product_category__c, SBQQ__Product__r.Sub_Category__c 
        FROM SBQQ__Subscription__c
        WHERE SBQQ__ProductName__c != 'CG Base Bundle'
        LIMIT 1
      ];

      SBQQ__Subscription__c removalSub = sub.clone(false, true, false, false);
      removalSub.SBQQ__Quantity__c = -1;
      removalSub.SBQQ__RevisedSubscription__c = sub.Id;

      SBQQ__Subscription__c bundleSub = [
        SELECT Id, Fulfillment_Account__c, SBQQ__Contract__c, SBQQ__ProductName__c, SBQQ__RevisedSubscription__c,
          SBQQ__Quantity__c, SBQQ__TerminatedDate__c, SBQQ__RequiredById__c, SBQQ__Account__c,
          SBQQ__Product__r.Family, SBQQ__Product__r.product_category__c, SBQQ__Product__r.Sub_Category__c 
        FROM SBQQ__Subscription__c
        WHERE SBQQ__ProductName__c = 'CG Base Bundle'
        LIMIT 1
      ];

      SBQQ__Subscription__c removalBundleSub = bundleSub.clone(false, true, false, false);
      removalBundleSub.SBQQ__Quantity__c = -1;
      removalBundleSub.SBQQ__RevisedSubscription__c = bundleSub.Id;

      sub.SBQQ__TerminatedDate__c = System.today();
      bundleSub.SBQQ__TerminatedDate__c = System.today();
      removalSub.SBQQ__TerminatedDate__c = System.today();
      removalBundleSub.SBQQ__TerminatedDate__c = System.today();

      SBQQ__Subscription__c replacementSub = sub.clone(false, true, false, false);
      replacementSub.SBQQ__Quantity__c = 1;
      replacementSub.SBQQ__Contract__c = sub.SBQQ__Contract__c;
      SBQQ__Subscription__c replacementBundleSub = bundleSub.clone(false, true, false, false);
      replacementBundleSub.SBQQ__Quantity__c = 1;
      replacementBundleSub.SBQQ__Contract__c = sub.SBQQ__Contract__c;

      update sub;
      update bundleSub;
      
      insert replacementBundleSub;
      replacementSub.SBQQ__RequiredById__c = replacementBundleSub.Id;
      insert replacementSub;

      insert removalBundleSub;
      removalSub.SBQQ__RequiredById__c = removalBundleSub.Id;
      insert removalSub;
      
      Map<Id,SBQQ__Subscription__c> subsMap = new Map<Id,SBQQ__Subscription__c>();
      subsMap.put(removalBundleSub.Id, removalBundleSub);
      subsMap.put(removalSub.Id, removalSub);
      subsMap.put(replacementBundleSub.Id, replacementBundleSub);
      subsMap.put(replacementSub.Id, replacementSub);

      Test.startTest();
        CPQ_Subscription_TriggerFunctions.evaluateCancellingBundles(subsMap, subsMap);
      Test.stopTest();

      SBQQ__Subscription__c[] subsRequery = [
        SELECT Id, SBQQ__Product__c, SBQQ__Account__c
        FROM SBQQ__Subscription__c
        WHERE Fulfillment_Account__c = :sub.Fulfillment_Account__c AND SBQQ__Contract__c = :sub.SBQQ__Contract__c
      ];

      System.assertEquals(6, subsRequery.size());

      Account acc = [
        SELECT Id, Product_Activation_Status__c, Cancellation_Effective_Date__c
        FROM Account
        WHERE Id = :sub.SBQQ__Account__c
      ];

      System.assertEquals(ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE, acc.Product_Activation_Status__c);
    }

    @istest
    public static void validateChangeOwnerStatusTest() {

      Test.startTest();

        Contract contract = [SELECT Id FROM Contract LIMIT 1];        
        
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Active';
        accts[0].Name = 'New Billing Accout';
        insert accts;

        //Create contact
        Contact tstContact = new Contact(AccountId=accts[0].Id, 
            FirstName='Fame2', LastName='lname2', Email='test2@cargurus.com');
        insert tstContact;

        Zuora__CustomerAccount__c zAccount = new Zuora__CustomerAccount__c(Name='Test 2', Zuora__Status__c = 'Active', 
            Zuora__Zuora_Id__c ='zuorabilling2', Zuora__Account__c = accts[0].Id, 
            Zuora__BillToWorkEmail__c = tstContact.Email, Zuora__SoldToWorkEmail__c = tstContact.Email,
            Zuora__DefaultPaymentMethod__c = 'CreditCard');
        insert zAccount;

        List<SBQQ__Subscription__c> subList = [SELECT Id, Billing_Account__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__QuoteLine__r.SBQQ__ProductCode__c = 'CG-BASE'
            AND Zuora_Subscription__c != NULL];
        
        subList[0].Billing_Account__c = accts[0].Id;
        update subList;        

        List<SBQQ__Subscription__c> subListAfterUpd = [SELECT Id, Billing_Account__c, Invoice_Change_Status__c,
        Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__QuoteLine__r.SBQQ__ProductCode__c = 'CG-BASE'
            AND Zuora_Subscription__c != NULL];

        List<SBQQ__Subscription__c> childSubListAfterUpd = [SELECT Id, Billing_Account__c, Invoice_Change_Status__c,
        Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__QuoteLine__r.SBQQ__ProductCode__c != 'CG-BASE'];

        Test.stopTest();

        System.assertEquals(1, subListAfterUpd.size());
        System.assertEquals(null, subListAfterUpd[0].Invoice_Change_Status__c, 'Invoice Change Status should be blank after completed');
        System.assertEquals(childSubListAfterUpd[0].Billing_Account__c, accts[0].Id, 'Billing Account on Child Subs properly updated');

    }

    @istest
    public static void validateChangeOwnerStatusMigratedContractTest() {

      Test.startTest();

        Contract contract = [SELECT Id FROM Contract LIMIT 1];
        contract.SBQQ__Quote__c = null;
        update contract;
        
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Active';
        accts[0].Name = 'New Billing Account';
        insert accts;

        //Create contact
        Contact tstContact = new Contact(AccountId=accts[0].Id, 
            FirstName='Fame2', LastName='lname2', Email='test2@cargurus.com');
        insert tstContact;

        Zuora__CustomerAccount__c zAccount = new Zuora__CustomerAccount__c(Name='Test 2', Zuora__Status__c = 'Active', 
            Zuora__Zuora_Id__c ='zuorabilling2', Zuora__Account__c = accts[0].Id, 
            Zuora__BillToWorkEmail__c = tstContact.Email, Zuora__SoldToWorkEmail__c = tstContact.Email,
            Zuora__DefaultPaymentMethod__c = 'CreditCard');
        insert zAccount;

        List<SBQQ__Subscription__c> subList = [SELECT Id, Billing_Account__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__QuoteLine__r.SBQQ__ProductCode__c = 'CG-BASE'
            AND Zuora_Subscription__c != NULL];
        
        subList[0].Billing_Account__c = accts[0].Id;
        update subList;        

        List<SBQQ__Subscription__c> subListAfterUpd = [SELECT Id, Billing_Account__c, Invoice_Change_Status__c,
        Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__QuoteLine__r.SBQQ__ProductCode__c = 'CG-BASE'
            AND Zuora_Subscription__c != NULL];

        List<SBQQ__Subscription__c> childSubListAfterUpd = [SELECT Id, Billing_Account__c, Invoice_Change_Status__c,
        Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__QuoteLine__r.SBQQ__ProductCode__c != 'CG-BASE'];

        Test.stopTest();

        System.assertEquals(1, subListAfterUpd.size());
        System.assertEquals(null, subListAfterUpd[0].Invoice_Change_Status__c, 'Invoice Change Status should be blank after completed');
        System.assertEquals(childSubListAfterUpd[0].Billing_Account__c, accts[0].Id, 'Billing Account on Child Subs properly updated');

    }

    @istest
    public static void submitSubOwnerChangeForApprovalTest() {

        Test.startTest();
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Active';
        accts[0].Name = 'New Billing Accout';
        insert accts;

        //Create contact
        Contact tstContact = new Contact(AccountId=accts[0].Id, 
            FirstName='Fame2', LastName='lname2', Email='test2@cargurus.com');
        insert tstContact;

        Zuora__CustomerAccount__c zAccount = new Zuora__CustomerAccount__c(Name='Test 2', Zuora__Status__c = 'Active', 
            Zuora__Zuora_Id__c ='zuorabilling2', Zuora__Account__c = accts[0].Id, 
            Zuora__BillToWorkEmail__c = tstContact.Email, Zuora__SoldToWorkEmail__c = tstContact.Email,
            Zuora__DefaultPaymentMethod__c = 'CreditCard');
        insert zAccount;

        List<SBQQ__Subscription__c> subList = [SELECT Id, Billing_Account__c
              FROM SBQQ__Subscription__c
              WHERE SBQQ__QuoteLine__r.SBQQ__ProductCode__c = 'CG-BASE'
              AND Zuora_Subscription__c != NULL];

        subList[0].Billing_Account__c = accts[0].Id;
        subList[0].Invoice_Change_Status__c = 'Rejected by Collections';
        
        update subList;

        subList[0].Invoice_Change_Status__c = 'Pending Collections Approval';

        update subList;
        Test.stopTest();

    }

    @istest
    public static void sendAmendTransferOwnerMessagesTest() {     

      List<SBQQ__Subscription__c> subList = [SELECT Id, Billing_Account__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__QuoteLine__r.SBQQ__ProductCode__c = 'CG-BASE'
            AND Zuora_Subscription__c != NULL];

      Set<Id> subIds = new Set<Id>();
      for (SBQQ__Subscription__c sub : subList){
        subIds.add(sub.Id);
      }      

      ZuoraIntegration_SupplementOrderHelper.sendAmendTransferOwnerMessages(subIds, true);

    }

/*
    @istest
    public static void getZTermsCommitmentAmendMessagesTest() {     

      List<SBQQ__Subscription__c> subList = [SELECT Id, Billing_Account__c,
        SBQQ__Contract__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__QuoteLine__r.SBQQ__ProductCode__c = 'CG-BASE'
            AND Zuora_Subscription__c != NULL];

      Set<Id> contractIds = new Set<Id>();
      Map<Id, Id> 
      for (SBQQ__Subscription__c sub : subList){
        contractIds.add(sub.SBQQ__Contract__c);
      }      

      ZuoraIntegration_SupplementOrderHelper.getZTermsCommitmentAmendMessages(contractIds, true);
      
    } */

}