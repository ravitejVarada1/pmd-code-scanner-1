/**
 * @description       : 
 * @author            : LZhao
 * @group             : 
 * @last modified on  : 11-18-2021
 * @last modified by  : LZhao
**/
@IsTest
private class OrderProductTriggerFunctions_Test {

    @testsetup
    static void testData() {

        Test.startTest();
        List<Account> accs = TestDataFactory.createAccounts(2);
        accs[0].BillingCountryCode = 'US';
        accs[1].BillingCountryCode = 'CA';
        accs[1].Type = 'Prospect';
        insert accs;

        Contract cont = TestDataFactory.createContract(accs[0].id);
        insert cont;

        List<Product2> product = TestDataFactory.createProducts(1);
        product[0].Name = 'Area Boost - 300 Miles';
        product[0].Activation_Case_Queue__c ='Area Boost Activation Case Queue';
        product[0].Deactivation_Case_Queue__c ='Area Boost Activation Case Queue';
        product[0].Manually_Provisioned__c = true;
        product[0].Product_Provisioning_Behavior__c = 'Manual Rec / Manual Prov';
        
        product.add(
            new Product2(Name = 'CG Base Bundle', IsActive = true, ProductCode = 'CG-BASE')
        );
        insert product; 

        //Instantiate the Pricebook2 record with StandardPricebookId
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        //Execute an update DML on the Pricebook2 record, to make IsStandard to true
        update standardPricebook;

        List<PricebookEntry> pbes = new List<PricebookEntry>();
        pbes.add(TestDataFactory.createPriceBookEntry(standardPricebook.Id, product[0].Id));
        pbes.add(TestDataFactory.createPriceBookEntry(standardPricebook.Id, product[1].Id));
        insert pbes;

        List<Order> orders = TestDataFactory.createOrders(1, accs[0].Id, null, standardPricebook.Id);
        insert orders;

        // opportunities
        Opportunity[] opps = TestDataFactory.createOpps(accs[1].Id,1);
        opps[0].RecordTypeId = Utilities.getRecordTypeId('Opportunity','Standard_Opportunity');
        opps.add(TestDataFactory.createOpps(accs[0].Id,1)[0]);
        opps[1].RecordTypeId = [SELECT Id FROM RecordType WHERE sObjectType = 'Opportunity' AND Name = 'Retention'][0].Id;
        opps[1].OwnerId = UserInfo.getUserId();
        insert opps;

        // quotes
        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accs[1].Id, opps[0].Id, 1);
        quotes[0].SBQQ__Type__c = 'Quote';
        insert quotes;

        // quote lines
        SBQQ__QuoteLine__c[] quoteLines = new List<SBQQ__QuoteLine__c>{
            new SBQQ__QuoteLine__c(
                Fulfillment_Account__c = accs[1].Id,
                SBQQ__Product__c = product[1].Id,
                SBQQ__Quote__c = quotes[0].Id,
                SBQQ__Quantity__c = 1
            )
        };
        insert quoteLines;
        
        List<Order> orders2 = TestDataFactory.createOrders(1, accs[1].Id, null, standardPricebook.Id);
        insert orders2;
        List<OrderItem> orderItems = TestDataFactory.createOrderItems(orders2[0].Id, product, standardPricebook.Id);
        for(OrderItem oi : orderItems) {
            oi.SBQQ__Status__c = 'Draft';
            oi.PricebookEntryId = pbes[1].Id;
            oi.Fulfillment_Account__c = accs[1].Id;
            oi.SBQQ__QuoteLine__c = quoteLines[0].Id;
        }
        insert orderItems;
        
        List<Service_Provider__c> testSpids = TestDataFactory.createServiceProviders(1, accs[1].Id);
        testSpids[0].New_Makes_Sold__c = 'BMW';
        insert testSpids;
        Test.stopTest();
    }

    static testMethod void createCaseTestForPositiveLineItem(){

        Test.startTest();

        List<Product2> products = [SELECT Id FROM Product2 WHERE Manually_Provisioned__c = true LIMIT 1];
        Id productId = products[0].Id;
        List<Order> orders = [SELECT Id FROM Order WHERE Account.BillingCountryCode = 'US' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productId LIMIT 1];
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];

        List<OrderItem> orderProducts = TestDataFactory.createOrderItems(orders[0].Id, products);
        orderProducts[0].PricebookEntryId = pbe.id;
        orderProducts[0].SBQQ__QuoteLine__c = quoteLine.Id;
        insert orderProducts;
        
        Test.stopTest();
        
        List<Case> case1 = [SELECT Id, Order__c, Subject, Order_Product__c FROM Case WHERE Order__c != null];
        System.debug('Case == '+case1);
        System.assert(case1.size() == 1);
    }

    static testMethod void createCaseTestForNegativeLineItem(){

        Test.startTest();

        List<Product2> products = [SELECT Id FROM Product2 WHERE Manually_Provisioned__c = true LIMIT 1];
        Id productId = products[0].Id;
        List<Order> orders = [SELECT Id FROM Order WHERE Account.BillingCountryCode = 'US' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productId LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id, SBQQ__Type__c FROM SBQQ__Quote__c LIMIT 1];
        quote.SBQQ__Type__c = 'Amendment';
        update quote;
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];
        
        List<OrderItem> orderProducts = TestDataFactory.createOrderItems(orders[0].Id, products);
        orderProducts[0].PricebookEntryId = pbe.id;
        orderProducts[0].Quantity = -1 ;
        orderProducts[0].SBQQ__QuoteLine__c = quoteLine.Id;
        insert orderProducts;

        Test.stopTest();

        List<Case> case1 = [SELECT Id, Order__c FROM Case WHERE Order__c != null];
        System.assert(case1.size() == 1);

    }
	
    static testMethod void setOrderStatusToActivation(){

        Test.startTest();

        List<Product2> products = [SELECT Id,Manually_Provisioned__c FROM Product2 LIMIT 1];
        products[0].Manually_Provisioned__c = true;
        update products[0];

        List<Order> orders = [SELECT Id, Status FROM Order WHERE Account.BillingCountryCode = 'US' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        List<OrderItem> orderProducts = TestDataFactory.createOrderItems(orders[0].Id, products);
        orderProducts[0].PricebookEntryId = pbe.id;
        orderProducts[0].Quantity = 1 ;
        insert orderProducts;

        orderProducts[0].SBQQ__Status__c = 'Activated';
        update orderProducts[0];

        Test.stopTest();

        OrderItem oProd = [SELECT Id,SBQQ__Status__c FROM OrderItem WHERE Order.Account.BillingCountryCode = 'US'  LIMIT 1 ];
        System.assertEquals('Pending Activation', oProd.SBQQ__Status__c);
    }

	//OrderProductTriggerFunctions.checkOrderContractId | Jira: BR-1909
	@isTest 
    static void testCheckOrderContractIdInsert(){

        Test.startTest();

        OrderItem testOrderItem = TestDataFactory.createOrderItems([SELECT Id FROM Order][0].Id, [SELECT Id FROM Product2])[0];
        testOrderItem.SBQQ__Contract__c = [SELECT Id FROM Contract][0].Id;
        testOrderItem.PricebookEntryId = [SELECT Id FROM PricebookEntry][0].Id;

        insert testOrderItem;
        ID contractId = [SELECT Id FROM Contract LIMIT 1].Id;

        Test.stopTest();
        
        System.assertEquals(contractId, [SELECT ContractCustom__c FROM Order LIMIT 1].ContractCustom__c);
    }
		
	//OrderProductTriggerFunctions.checkOrderContractId | Jira: BR-1909
	@isTest 
	static void testCheckOrderContractIdUpdate(){

        Test.startTest();

        OrderItem testOrderItem = TestDataFactory.createOrderItems([SELECT Id FROM Order][0].Id, [SELECT Id FROM Product2])[0];
        testOrderItem.SBQQ__Contract__c = [SELECT Id FROM Contract][0].Id;
        testOrderItem.PricebookEntryId = [SELECT Id FROM PricebookEntry][0].Id;

        insert testOrderItem;
        
        ID contractId = [SELECT Id FROM Contract LIMIT 1].Id;
        Order ord = [SELECT Id FROM Order WHERE Account.BillingCountryCode = 'US' LIMIT 1];
        
        ord.ContractCustom__c = null;
        update ord;

        OrderItem ordItem = [SELECT Id, OrderId FROM OrderItem WHERE OrderId = :ord.Id LIMIT 1];
        
        ordItem.SBQQ__Contract__c = null;
        update ordItem;
        
        ordItem.SBQQ__Contract__c = contractId;
        update ordItem;

        Test.stopTest();

        Order ordRequeried = [SELECT ContractCustom__c FROM Order WHERE Account.BillingCountryCode = 'US' LIMIT 1];
        System.assertEquals(contractId, ordRequeried.ContractCustom__c);
	}

    @isTest 
	static void testOnboardingCaseCreation(){

        Test.startTest();
        Order o = [SELECT Id, Status, AccountId FROM Order WHERE Account.BillingCountryCode = 'CA' LIMIT 1];
        o.Status = 'Activated';
        update o;
        List<OrderItem> ois = [SELECT Id, SBQQ__Status__c FROM OrderItem WHERE OrderId = :o.Id];
        for(OrderItem oi : ois) {
            oi.SBQQ__Status__c = 'Activated';
            oi.Transaction_Type__c = 'New Business';
        }
        update ois;
        Test.stopTest();

        List<Case> onboardingCases = [
            SELECT Id
            FROM Case
            WHERE AccountId = :o.AccountId
                AND RecordType.Name = 'Onboarding'
        ];
        System.assert(onboardingCases.size() > 0);
    }

    @isTest
    static void testCoopCase(){

        Test.startTest();
        Order o = [SELECT Id, Status, AccountId FROM Order WHERE Account.BillingCountryCode = 'CA' LIMIT 1];
        o.Status = 'Activated';
        update o;
        List<OrderItem> ois = [SELECT Id, SBQQ__Status__c FROM OrderItem WHERE OrderId = :o.Id];
        for(OrderItem oi : ois) {
            oi.Potential_Co_Op_Eligible__c = true;
            oi.SBQQ__Status__c = 'Activated';
        }
        update ois;
        Test.stopTest();

        List<Case> coopCase = [
        SELECT Id
        FROM Case
        WHERE AccountId = :o.AccountId
            AND RecordType.Name = 'Co-Op'
        ];
        System.assert(coopCase.size() > 0);
    }

    static testMethod void testManualProvisionProduct(){

        List<Product2> products = [SELECT Id FROM Product2 WHERE Manually_Provisioned__c = true LIMIT 1];
        Id productId = products[0].Id;
        List<Order> orders = [SELECT Id FROM Order WHERE Account.BillingCountryCode = 'US' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productId LIMIT 1];
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];

        Test.startTest();
        List<OrderItem> orderProducts = TestDataFactory.createOrderItems(orders[0].Id, products);
        orderProducts[0].PricebookEntryId = pbe.id;
        orderProducts[0].SBQQ__QuoteLine__c = quoteLine.Id;
        insert orderProducts;

        orders[0].Status = 'Activated';
        update orders;

        orderProducts[0].SBQQ__Status__c = 'Activated';
        update orderProducts;
        
        Test.stopTest();
        
        List<Case> case1 = [SELECT Id, Order__c, Subject, Order_Product__c, Order_Product__r.SBQQ__Status__c, Order_Product__r.SBQQ__Contracted__c FROM Case WHERE Order__c != null];
        OrderItem oi = [SELECT Id, SBQQ__Status__c FROM OrderItem WHERE Id = :case1[0].Order_Product__c];
        oi.SBQQ__Status__c = 'Activated';
        update oi;

        Database.executeBatch(new Batch_ManualProvisionOrderProductCheck());
        OrderItem oiAfter = [SELECT Id, SBQQ__Status__c, Activation_Zuora_RevPro__c FROM OrderItem WHERE Id = :case1[0].Order_Product__c];

        System.assert(oiAfter.SBQQ__Status__c == 'Activated');
        System.assert(oiAfter.Activation_Zuora_RevPro__c == null);

    }
}