// https://cargurus.atlassian.net/browse/BR-894
@isTest
public class ZuoraIntegration_Test {

    static final String APPROVALSTATUS_APPROVED = ConstantsUtil.QUOTE_APPROVALSTATUS_APPROVED;
    
    @TestSetup
    static void makeData() {

        // disable triggers and zuora order integration while setting up records
        SBQQ.TriggerControl.disable();
        ZuoraIntegration_OrderHelper.disableZuoraActions = true;

        Test.startTest();

        TriggerHandler.bypass('AccountTriggerHandler');
        TriggerHandler.bypass('CPQQuoteTriggerHandler');
        TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
        TriggerHandler.bypass('CPQ_Subscription_TriggerHandler');

        Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
		adminEscape.Exclude_from_Validation_Rules__c = true;
        upsert adminEscape;
        
        // Accounts
        List<Account> fulfillmentAccounts = 
            ZuoraIntegration_TestDataFactory.createAccountsWithBillingContactData(2, ConstantsUtil.RT_ACCOUNT_DEALER);

        
        insert fulfillmentAccounts;

        //Create contact 1
        Contact tstContact = new Contact(AccountId=fulfillmentAccounts[0].Id, 
            FirstName='zteztfirst', LastName='zteztlast', Email='ztezt@cargurus.com');
        insert tstContact;

        //Create Zuora Account 1
        Zuora__CustomerAccount__c zAccount = new Zuora__CustomerAccount__c(Name='Test', Zuora__Status__c = 'Active', 
            Zuora__Zuora_Id__c ='zuorabilling', Zuora__Account__c = fulfillmentAccounts[0].Id, 
            Zuora__BillToWorkEmail__c = tstContact.Email, Zuora__SoldToWorkEmail__c = tstContact.Email,
            Zuora__DefaultPaymentMethod__c = 'CreditCard');

        insert zAccount;

        fulfillmentAccounts[0].Billing_Account_Zuora__c = zAccount.Id;

        //Create contact 2
        Contact tstContact2 = new Contact(AccountId=fulfillmentAccounts[1].Id, 
            FirstName='zteztfirst2', LastName='zteztlast2', Email='ztezt2@cargurus.com');
        insert tstContact2;

        //Create Zuora Account 2 
        Zuora__CustomerAccount__c zAccount2 = new Zuora__CustomerAccount__c(Name='Test2', Zuora__Status__c = 'Active', 
            Zuora__Zuora_Id__c ='zuorabilling2', Zuora__Account__c = fulfillmentAccounts[1].Id, 
            Zuora__BillToWorkEmail__c = tstContact2.Email, Zuora__SoldToWorkEmail__c = tstContact2.Email,
            Zuora__DefaultPaymentMethod__c = 'CreditCard');

        insert zAccount2;

        fulfillmentAccounts[1].Billing_Account_Zuora__c = zAccount2.Id;
        update fulfillmentAccounts;
        
        // Products
        List<Product2> products = ZuoraIntegration_TestDataFactory.createProductsWithZuoraData(4);
        insert products;

        ZuoraIntegration_TestDataFactory.setBaseBundleProductId(products[0].Id);

        // Pricebook Entries
        List<PricebookEntry> pbeList = ZuoraIntegration_TestDataFactory.createPricebookEntries(products);
        insert pbeList;

        // Opportunities
        List<Opportunity> testOpps = ZuoraIntegration_TestDataFactory.createOpps(fulfillmentAccounts);
        insert testOpps;

        // Quotes
        List<SBQQ__Quote__c> testQuotes = ZuoraIntegration_TestDataFactory.createQuotes(testOpps);
        insert testQuotes;

        // Quote Lines
        List<SBQQ__QuoteLine__c> testQuoteLines = 
            ZuoraIntegration_TestDataFactory.createQuoteLines(testQuotes, pbeList);
        insert testQuoteLines;

        // Orders - will be upserted in createContracts method (to add contract ids)
        List<Order> testOrders = ZuoraIntegration_TestDataFactory.createOrders(testQuotes);

        // Contracts - inserted in method (to get ids and add to orders)
        List<Contract> testContracts = ZuoraIntegration_TestDataFactory.createContracts(testOrders);

        // Order Lines
        List<OrderItem> testOrderItems = ZuoraIntegration_TestDataFactory.createOrderItems(testOrders, testQuoteLines);
        insert testOrderItems;

        // requery so we have product ids
        testOrderItems = [SELECT Id, Product2Id, Fulfillment_Account__c, Billing_Account__c, SBQQ__QuoteLine__c,
            Order.ContractId FROM OrderItem];

        System.debug('Order Item: '+ testOrderItems);

        // cpq subs - insert / update the cpq subs within the create method to establish base bundle relationship
        List<SBQQ__Subscription__c> cpqSubs = ZuoraIntegration_TestDataFactory.createCPQSubs(testOrderItems);

        // create revised subscriptions for testing cancellations and amendments
        List<SBQQ__Subscription__c> revisedCpqSubs = ZuoraIntegration_TestDataFactory.createCPQSubs(testOrderItems);

        // keep track of revised subs by related order item id for updating onto test cpq subs
        Map<Id,Id> orderItemIdCpqSubMap = new Map<Id,Id>();

        // remove order item and quote line relationships from revised subs
        for (SBQQ__Subscription__c rSub : revisedCpqSubs) {
            orderItemIdCpqSubMap.put(rSub.SBQQ__OrderProduct__c, rSub.Id);
            rSub.Zuora_Rate_Plan_Id__c = 'rpnum'+rSub.Id;
            rSub.Zuora_Subscription_Number__c = 'subnum'+rSub.Id;
            rSub.SBQQ__OrderProduct__c = null;
            rSub.SBQQ__QuoteLine__c = null;
        }

        update revisedCpqSubs;

        // update revised subscription ids on to test cpq subscriptions
        for (SBQQ__Subscription__c cpqSub : cpqSubs) {
            cpqSub.SBQQ__RevisedSubscription__c = orderItemIdCpqSubMap.get(cpqSub.SBQQ__OrderProduct__c);
        }

        update cpqSubs;

        // requery so we have names and update to reset z sub status field
        testOrders = [SELECT Id, OrderNumber, AccountId FROM Order];

        // reset activation zuora subscription status field to allow triggering in tests
        for (Order o : testOrders) {
            o.Activation_Zuora_Subscription__c = null;
        }

        update testOrders;

        // zuora subs
        List<Zuora__Subscription__c> zSubs = ZuoraIntegration_TestDataFactory.createZuoraSubs(testOrders);
        insert zSubs;

        // zuora sub rate plans
        List<Zuora__SubscriptionRatePlan__c> zSubRatePlans = 
            ZuoraIntegration_TestDataFactory.createZuoraSubRatePlans(zSubs, products);
        insert zSubRatePlans;

        // zuora sub charges
        List<Zuora__SubscriptionProductCharge__c> zSubCharges = 
            ZuoraIntegration_TestDataFactory.createZuoraSubCharges(zSubRatePlans);
        insert zSubCharges;

        Test.stopTest();

        // re-enable zuora integrations
        ZuoraIntegration_OrderHelper.disableZuoraActions = false;
    }

    @isTest
    static void generateZAccountsFromCpqQuotes() {
        List<SBQQ__Quote__c> testQuotes = [SELECT Id FROM SBQQ__Quote__c];

        for (SBQQ__Quote__c q : testQuotes) {
            q.ApprovalStatus__c = APPROVALSTATUS_APPROVED;
        }

        Test.startTest();
        update testQuotes;
        Test.stopTest();
    }

    @isTest
    static void generateZAccountsFromAccounts() {
        List<Account> testAccounts = [SELECT Id, System_BillingContactEmail__c FROM Account];
        Map<Id,String> accountIdEmailString = new Map<Id,String>();

        for (Account a : testAccounts) {
            accountIdEmailString.put(a.Id, a.System_BillingContactEmail__c);
            a.System_BillingContactEmail__c = null;            
        }
        update testAccounts;

        List<SBQQ__Quote__c> testQuotes = [SELECT Id FROM SBQQ__Quote__c];

        for (SBQQ__Quote__c q : testQuotes) {
            q.ApprovalStatus__c = APPROVALSTATUS_APPROVED;
        }
        update testQuotes;

        for (Account a : testAccounts) {
            a.System_BillingContactEmail__c = accountIdEmailString.get(a.Id);            
        }
        
        Test.startTest();
        update testAccounts;
        Test.stopTest();
    }

    @isTest
    static void generateZAccountsFromBatch() {
        List<SBQQ__Quote__c> testQuotes = [SELECT Id FROM SBQQ__Quote__c];

        for (SBQQ__Quote__c q : testQuotes) {
            q.ApprovalStatus__c = APPROVALSTATUS_APPROVED;
        }
        update testQuotes;

        delete [SELECT Id FROM Integration_Message__c];

        Test.startTest();
        Database.executeBatch(new ZuoraIntegration_AccountBatch());
        Test.stopTest();
    }

    @isTest
    static void runZAccountBatchWithMessagesInProgress() {
        List<SBQQ__Quote__c> testQuotes = [SELECT Id FROM SBQQ__Quote__c];

        for (SBQQ__Quote__c q : testQuotes) {
            q.ApprovalStatus__c = APPROVALSTATUS_APPROVED;
        }
        update testQuotes;

        Test.startTest();
        Database.executeBatch(new ZuoraIntegration_AccountBatch());
        Test.stopTest();
    }

    @IsTest
    static void testScheduleZAccountBatch() {
        ZuoraIntegration_AccountBatch zAccountBatch = new ZuoraIntegration_AccountBatch();
        String cronString = '0 0 23 * * ?';

        Test.startTest();
        String jobId = System.schedule('TEST_ZuoraIntegration_AccountBatch', cronString, zAccountBatch);
        Test.stopTest();
        
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
    }

    @isTest
    static void generateZuoraOrderFromRawCPQSubs() {
        List<SBQQ__Subscription__c> cpqSubList = [SELECT Id FROM SBQQ__Subscription__c 
            WHERE SBQQ__OrderProduct__c != null];

        for (SBQQ__Subscription__c cpqSub : cpqSubList) {
            cpqSub.SBQQ__RevisedSubscription__c = null;
            cpqSub.Zuora_Rate_Plan_Id__c = null;
            cpqSub.Zuora_Subscription_Number__c = null;
        }

        update cpqSubList;

        Id testAccountId = [SELECT Id FROM Account LIMIT 1].Id;

        String query = 'SELECT '+String.join(ZuoraIntegration_OrderHelper.CPQSUB_QUERY_FIELDS, ', ')+
            ' FROM SBQQ__Subscription__c WHERE Fulfillment_Account__c = :testAccountId';
        
        Map<Id,SBQQ__Subscription__c> cpqSubMap = 
            new Map<Id,SBQQ__Subscription__c>((List<SBQQ__Subscription__c>)Database.query(query));
        
        SBQQ__Subscription__c baseCPQSub = cpqSubMap.values()[0];
        cpqSubMap.remove(baseCPQSub.Id);

        Test.startTest();
        System.debug(
            ZuoraIntegration_Order.serializeJSON(baseCPQSub, cpqSubMap.values())
        );
        Test.stopTest();
    }

    @isTest
    static void generateZuoraOrdersFromCPQOrders() {
        List<SBQQ__Subscription__c> cpqSubList = [SELECT Id FROM SBQQ__Subscription__c 
            WHERE SBQQ__OrderProduct__c != null];

        for (SBQQ__Subscription__c cpqSub : cpqSubList) {
            cpqSub.SBQQ__RevisedSubscription__c = null;
            cpqSub.Zuora_Rate_Plan_Id__c = null;
            cpqSub.Zuora_Subscription_Number__c = null;
        }

        update cpqSubList;
        
        List<Order> oList = [SELECT Id FROM Order];

        for (Order o : oList) {
            o.Activation_Zuora_Subscription__c = ConstantsUtil.ACTIVATION_STATUS_PENDING;
        }

        Test.startTest();
        update oList;
        Test.stopTest();
    }

    @isTest
    static void processIntegrationMessageAndZSubChargeUpdates() {
        
        List<Order> oList = [SELECT Id, AccountId, OrderNumber FROM Order];
        List<Integration_Message__c> intMsgList = new List<Integration_Message__c>();

        for (Order o : oList) {
            ZuoraIntegration_OrderResponse orderResponse = new ZuoraIntegration_OrderResponse();
            orderResponse.success = true;
            orderResponse.orderNumber = o.OrderNumber;
            orderResponse.status = 'Completed';
            orderResponse.subscriptionNumbers = new List<String>{o.OrderNumber};
            
            intMsgList.add(
                new Integration_Message__c(
                    Account__c = o.AccountId,
                    CPQ_Order__c = o.Id,
                    Process__c = Integrations.PROCESS_ZORDER,
                    Request_Status__c = Integrations.REQUEST_STATUS_SUCCESS,
                    Response_Status__c = Integrations.RESPONSE_STATUS_NEW,
                    Response_Body__c = JSON.serialize(orderResponse, true)
                )
            );
        }
        insert intMsgList;

        List<Zuora__SubscriptionProductCharge__c> zSubCharges = [SELECT Id FROM Zuora__SubscriptionProductCharge__c];

        Test.startTest();
        update intMsgList;
        update zSubCharges;
        Test.stopTest();
    }

    @isTest
    static void preventAutoInvoice() {

        List<SBQQ__Quote__c> quoteList = [SELECT Id FROM SBQQ__Quote__c];
        for (SBQQ__Quote__c q : quoteList) {
            q.Prevent_Automated_Initial_Invoice__c = true;
        }
        update quoteList;
        
        List<Order> oList = [SELECT Id, AccountId, OrderNumber FROM Order];

        for (Order o : oList) {
            o.Activation_Zuora_Invoice__c = ConstantsUtil.ACTIVATION_STATUS_PENDING;
        }

        Test.startTest();
        update oList;
        Test.stopTest();
    }

    @isTest
    static void cancelSubscription() {

        List<SBQQ__Subscription__c> cpqSubList = [SELECT Id FROM SBQQ__Subscription__c 
            WHERE SBQQ__OrderProduct__c != null AND SBQQ__RequiredById__c = null];

        for (SBQQ__Subscription__c cpqSub : cpqSubList) {
            cpqSub.Zuora_Rate_Plan_Id__c = null;
            cpqSub.Zuora_Subscription_Number__c = null;
        }

        update cpqSubList;

        List<Order> oList = [SELECT Id FROM Order];

        for (Order o : oList) {
            o.Activation_Zuora_Subscription__c = ConstantsUtil.ACTIVATION_STATUS_PENDING;
        }

        Test.startTest();
        update oList;
        Test.stopTest();
    }

    @isTest
    static void amendSubscription() {

        List<SBQQ__Subscription__c> cpqSubList = [SELECT Id FROM SBQQ__Subscription__c 
            WHERE SBQQ__OrderProduct__c != null AND SBQQ__RequiredById__c = null];

        for (SBQQ__Subscription__c cpqSub : cpqSubList) {
            cpqSub.SBQQ__RevisedSubscription__c = null;
        }

        update cpqSubList;

        List<Order> oList = [SELECT Id FROM Order];

        for (Order o : oList) {
            o.Activation_Zuora_Subscription__c = ConstantsUtil.ACTIVATION_STATUS_PENDING;
        }

        Test.startTest();
        update oList;
        Test.stopTest();
    }

    @isTest
    static void generateZRevproMessagesFromBatch() {
      final String CLOSED = 'Closed';
      final String ACTIVATED = 'Activated';
      final String PENDING = 'Pending';

      List<OrderItem> ois = [
        SELECT Id, OrderId, Activation_Zuora_RevPro__c, SBQQ__Status__c
        FROM OrderItem
      ];

      List<Id> orderIds = new List<Id>();
      for(OrderItem oi : ois) {
        if(orderIds.indexOf(oi.OrderId) == -1) {
          oi.Activation_Zuora_RevPro__c = PENDING;
          oi.SBQQ__Status__c = ACTIVATED;
          oi.Manual_Activation_Date__c = System.now().date();
          orderIds.add(oi.OrderId);
        }
      }
      update ois;

      Test.startTest();
      Database.executeBatch(new ZuoraIntegration_RevproBatch());
      Test.stopTest();
    }

    @IsTest
    static void testScheduleZRevproBatch() {
      ZuoraIntegration_RevproBatch zRevproBatch = new ZuoraIntegration_RevproBatch();
      String cronString = '0 0 23 * * ?';

      Test.startTest();
      String jobId = System.schedule('TEST_ZuoraIntegration_RevproBatch', cronString, zRevproBatch);
      Test.stopTest();
      
      CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
      System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
    }

}