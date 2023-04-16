
@IsTest
public without sharing class OrderItemTransactionTypes_Test {
    
    @TestSetup
    static void testSetup(){
        SBQQ.TriggerControl.disable();

        //Product setup
        Map<String,Product2> testProductMap = new Map<String,Product2>();
       
        testProductMap.put('CG Base Bundle', new Product2(Name = 'CG Base Bundle', IsActive = true, ProductCode = 'CG-BASE', Family = 'Listings',
                Product_Type__c = 'Bundle'
        ));
        
        testProductMap.put('Featured Placement', new Product2(Name = 'Featured Placement', IsActive = true, ProductCode = 'SKU00001', Family = 'Listings',
                Product_Category__c = 'Core Products', Sub_Category__c = 'Featured'
        ));
            
        testProductMap.put('Enhanced Placement', new Product2(Name = 'Enhanced Placement', IsActive = true, ProductCode = 'SKU00003', Family = 'Listings',
                Product_Category__c = 'Core Products', Sub_Category__c = 'Enhanced'
        ));
        
        testProductMap.put('Display - Focus - Enhanced', new Product2(Name = 'Display - Focus - Enhanced', IsActive = true, ProductCode = 'SKU00004', Family = 'Display',
                Product_Category__c = 'Digital Advertising', Sub_Category__c = 'Display_Focus'
        ));

        testProductMap.put('Display - Focus - Featured', new Product2(Name = 'Display - Focus - Featured', IsActive = true, ProductCode = 'SKU00005', Family = 'Display',
                Product_Category__c = 'Digital Advertising', Sub_Category__c = 'Display_Focus'
        ));
        insert testProductMap.values();
        
        ID pricebookId = Test.getStandardPricebookId();
        Map<String, PricebookEntry> priceBookEntryMap = new Map<String, PricebookEntry>();
        
        for (Product2 p : testProductMap.values()) {
            priceBookEntryMap.put(
                p.Name, new PricebookEntry(
                    Product2Id = p.Id,
                    Pricebook2Id = pricebookId,
                    CurrencyIsoCode = 'USD',
                    UnitPrice = 100,
                    IsActive = true
                )
            );
        }
        insert priceBookEntryMap.values();

        //Create Account
        Account acc = TestDataFactory.createSingleAccount(null);
        insert acc;

        //Create contract
        Contract crt = TestDataFactory.createContract(acc.Id);
        insert crt;

        crt.Status = 'Activated';
        update crt;

        Map<String, SBQQ__Subscription__c> cpqSubMap = new Map<String, SBQQ__Subscription__c>();
        cpqSubMap.put('Enhanced Placement', new SBQQ__Subscription__c( SBQQ__Quantity__c = 1.00, SBQQ__Product__c = testProductMap.get('Enhanced Placement').Id,
            Fulfillment_Account__c = acc.Id, SBQQ__SubscriptionStartDate__c = Date.today().addDays(-30),
            SBQQ__SubscriptionEndDate__c = Date.today().addDays(335)
        ));

        cpqSubMap.put('Featured Placement', new SBQQ__Subscription__c( SBQQ__Quantity__c = 1.00, SBQQ__Product__c = testProductMap.get('Featured Placement').Id,
            Fulfillment_Account__c = acc.Id, SBQQ__SubscriptionStartDate__c = Date.today().addDays(-30),
            SBQQ__SubscriptionEndDate__c = Date.today().addDays(335)
        ));

        cpqSubMap.put('Display - Focus - Enhanced', new SBQQ__Subscription__c( SBQQ__Quantity__c = 1.00, SBQQ__Product__c = testProductMap.get('Display - Focus - Enhanced').Id,
            Fulfillment_Account__c = acc.Id, SBQQ__SubscriptionStartDate__c = Date.today().addDays(-30),
            SBQQ__SubscriptionEndDate__c = Date.today().addDays(335)
        ));

        cpqSubMap.put('Display - Focus - Featured', new SBQQ__Subscription__c( SBQQ__Quantity__c = 1.00, SBQQ__Product__c = testProductMap.get('Display - Focus - Featured').Id,
            Fulfillment_Account__c = acc.Id, SBQQ__SubscriptionStartDate__c = Date.today().addDays(-30),
            SBQQ__SubscriptionEndDate__c = Date.today().addDays(335)
        ));
        insert cpqSubMap.values();

        for(SBQQ__Subscription__c cpqsub : cpqSubMap.values()) {
            cpqsub.Provisioning_Status__c = 'Activated';
        }
        update cpqSubMap.values();

        Order ord = TestDataFactory.createOrders(1, acc.Id, crt.Id, pricebookId)[0];
        ord.Type = 'Amendment';
        insert ord;

        List<OrderItem> orderItems = new List<OrderItem>();
        orderItems.add(new OrderItem( OrderId = ord.Id, Quantity = -1.00, UnitPrice = 100,
            Product2Id = testProductMap.get('Enhanced Placement').Id, PricebookEntryId = priceBookEntryMap.get('Enhanced Placement').Id,
            Fulfillment_Account__c = acc.Id, SBQQ__Subscription__c = cpqSubMap.get('Enhanced Placement').Id,
            SBQQ__ContractAction__c = 'Cancel', ListPrice = 100.00
        ));

        orderItems.add(new OrderItem( OrderId = ord.Id, Quantity = 1.00, UnitPrice = 200,
            Product2Id = testProductMap.get('Featured Placement').Id, PricebookEntryId = priceBookEntryMap.get('Featured Placement').Id,
            Fulfillment_Account__c = acc.Id, SBQQ__Subscription__c = cpqSubMap.get('Featured Placement').Id,
            SBQQ__ContractAction__c = 'New', ListPrice = 100.00
        ));

        orderItems.add(new OrderItem( OrderId = ord.Id, Quantity = -1.00, UnitPrice = 100,
            Product2Id = testProductMap.get('Display - Focus - Enhanced').Id, PricebookEntryId = priceBookEntryMap.get('Display - Focus - Enhanced').Id,
            Fulfillment_Account__c = acc.Id, SBQQ__Subscription__c = cpqSubMap.get('Display - Focus - Enhanced').Id,
            SBQQ__ContractAction__c = 'Cancel', ListPrice = 100.00
        ));

        orderItems.add(new OrderItem( OrderId = ord.Id, Quantity = 1.00, UnitPrice = 200,
            Product2Id = testProductMap.get('Display - Focus - Featured').Id, PricebookEntryId = priceBookEntryMap.get('Display - Focus - Featured').Id,
            Fulfillment_Account__c = acc.Id, SBQQ__Subscription__c = cpqSubMap.get('Display - Focus - Featured').Id,
            SBQQ__ContractAction__c = 'New', ListPrice = 100.00
        ));

        insert orderItems;

    }

    @IsTest
    static void testTransactionTypeAmendment() {
        
        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        update ord;
        Test.stopTest();

        List<OrderItem> orderItems = [SELECT Id, Transaction_Type__c, Product2Id FROM OrderItem WHERE OrderId = :ord.Id];
        for(OrderItem oi : orderItems) {
            System.assertEquals(oi.Transaction_Type__c, 'Existing Business', 'Oh oh, marked the wrong transaction type');
        }
    }

    @IsTest
    static void testTransactionTypeNewStore() {
        Account acc = TestDataFactory.createSingleAccount(null);
        insert acc;
        AccountTeamMember newTeam = new AccountTeamMember(AccountId = acc.ID,
		TeamMemberRole = 'Account Manager',UserId = userInfo.getuserId());
		insert newTeam;
        Order ord = [SELECT Id, Type FROM Order LIMIT 1];
        ord.Type = 'New';
        update ord;

        List<OrderItem> oItems = [SELECT Id, Fulfillment_Account__c FROM OrderItem];
        for(OrderItem oi : oItems) {
            oi.Fulfillment_Account__c = acc.Id;
            oi.Quantity = 1;
            oi.Transaction_Type__c = null;
        }
        update oItems;

        Test.startTest();
        update ord;
        Test.stopTest();

        List<OrderItem> orderItems = [SELECT Id, Transaction_Type__c, Product2Id FROM OrderItem WHERE OrderId = :ord.Id];
        for(OrderItem oi : orderItems) {
            System.assertEquals(oi.Transaction_Type__c, 'New Business', 'Oh oh, marked the wrong transaction type');
        }
    }


    @IsTest
    static void testTransactionTypeRateReduction() {
        Order ord = [SELECT Id, Type FROM Order LIMIT 1];

        List<OrderItem> oItems = [SELECT Id, Fulfillment_Account__c FROM OrderItem];
        for(OrderItem oi : oItems) {
            oi.Quantity = -1;
            oi.Transaction_Type__c = null;
        }
        update oItems;

        Test.startTest();
        update ord;
        Test.stopTest();

        List<OrderItem> orderItems = [SELECT Id, Transaction_Type__c, Product2Id FROM OrderItem WHERE OrderId = :ord.Id];
        for(OrderItem oi : orderItems) {
            System.assertEquals(oi.Transaction_Type__c, 'Rate Reduction', 'Oh oh, marked the wrong transaction type');
        }
    }
}
