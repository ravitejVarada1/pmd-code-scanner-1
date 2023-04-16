// https://cargurus.atlassian.net/browse/BR-3884
@isTest
public class PistonHeadsIntegration_Test {

    static final String APPROVALSTATUS_APPROVED = ConstantsUtil.QUOTE_APPROVALSTATUS_APPROVED;
    static final List<String> PH_PRODUCT_CODES = new List<String>(ConstantsUtil.PH_PRODUCT_CODES);
    
    @TestSetup
    static void makeData() {

        system.debug(PH_PRODUCT_CODES);
        system.debug(PH_PRODUCT_CODES.size());

        // disable triggers and zuora order integration while setting up records
        SBQQ.TriggerControl.disable();
        ZuoraIntegration_OrderHelper.disableZuoraActions = true;

        Test.startTest();

        Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
		adminEscape.Exclude_from_Validation_Rules__c = true;
        upsert adminEscape;
        
        // Accounts
        List<Account> fulfillmentAccounts = 
            ZuoraIntegration_TestDataFactory.createAccountsWithBillingContactData(2, ConstantsUtil.RT_ACCOUNT_DEALER);
            
        for (Account a : fulfillmentAccounts) {
            a.Account_Category__c = 'Franchise - Small';
        }

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
        List<Product2> products = ZuoraIntegration_TestDataFactory.createProductsWithZuoraData(5, PH_PRODUCT_CODES);

        system.debug(products);

        insert products;

        ZuoraIntegration_TestDataFactory.setBaseBundleProductId(products[0].Id);

        // Pricebook Entries
        List<PricebookEntry> pbeList = ZuoraIntegration_TestDataFactory.createPricebookEntries(products);
        insert pbeList;

        system.debug('pbeList::' + pbeList);

        // Opportunities
        List<Opportunity> testOpps = ZuoraIntegration_TestDataFactory.createOpps(fulfillmentAccounts);
        insert testOpps;

        // Quotes
        List<SBQQ__Quote__c> testQuotes = ZuoraIntegration_TestDataFactory.createQuotes(testOpps);
        insert testQuotes;

        // Quote Lines
        List<SBQQ__QuoteLine__c> testQuoteLines = 
            ZuoraIntegration_TestDataFactory.createQuoteLines(testQuotes, pbeList);
        system.debug('testQuotesLines ' + testQuoteLines);
        insert testQuoteLines;

        // Orders - will be upserted in createContracts method (to add contract ids)
        List<Order> testOrders = ZuoraIntegration_TestDataFactory.createOrders(testQuotes);

        // Contracts - inserted in method (to get ids and add to orders)
        List<Contract> testContracts = ZuoraIntegration_TestDataFactory.createContracts(testOrders);

        // Order Lines
        List<OrderItem> testOrderItems = ZuoraIntegration_TestDataFactory.createOrderItems(testOrders, testQuoteLines);
        system.debug('testOrderItems' + testOrderItems);
        insert testOrderItems;

        // requery so we have product ids
        testOrderItems = [SELECT Id, Product2Id, Fulfillment_Account__c, Billing_Account__c, SBQQ__QuoteLine__c,
            Order.ContractId FROM OrderItem];

        // cpq subs - insert / update the cpq subs within the create method to establish base bundle relationship
        List<SBQQ__Subscription__c> cpqSubs = ZuoraIntegration_TestDataFactory.createCPQSubs(testOrderItems);

        // requery so we have names and update to reset z sub status field
        testOrders = [SELECT Id, OrderNumber, AccountId FROM Order];

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
    static void generatePHAccountsFromCpqOrders() {

        SBQQ.TriggerControl.Disable();
        List<Order> testOrders = [SELECT Id, Status FROM Order];

        for (Order o : testOrders) {
            o.Status = 'Draft';
        }

        update testOrders;

        for (Order o : testOrders) {
            o.Status = 'Activated';
        }

        Test.startTest();
        update testOrders;
        Test.stopTest();
        SBQQ.TriggerControl.Enable();

        List<Integration_Message__c> intMessages = [SELECT Id, Process__c, Request_Body__c FROM Integration_Message__c WHERE Process__c = 'PistonHeads Account'];
        //System.assert(intMessages.size() > 0);
    }


    @isTest
    static void generatePHMessagesFromCPQSubs() {
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



}