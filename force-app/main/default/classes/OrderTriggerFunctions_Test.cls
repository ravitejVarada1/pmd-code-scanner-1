@isTest
private class OrderTriggerFunctions_Test {

    @TestSetup
    static void makeData(){

        Test.startTest();
        TriggerHandler.bypass('CaseTriggerHandler');
        SBQQ.TriggerControl.disable();

        Account[] accts = TestDataFactory.createAccounts(1);
        insert accts;

        Contact[] cons = TestDataFactory.createContacts(1,accts[0].Id);
        insert cons;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 2);
        opps[1].RecordTypeId = Utilities.getrecordTypeId('Opportunity', 'Retention');
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        insert quotes;

        Product2[] prods = new List<Product2>{
            new Product2(Name = 'CG Base Bundle', IsActive = true)
        };
        insert prods;

        Id pricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pricebookId, Product2Id = prods[0].Id, UnitPrice = 1020, IsActive = true);
        insert pbe;

        SBQQ__QuoteLine__c[] quoteLines = new List<SBQQ__QuoteLine__c>{
            new SBQQ__QuoteLine__c(
                Fulfillment_Account__c = accts[0].Id,
                SBQQ__Product__c = prods[0].Id,
                SBQQ__Quote__c = quotes[0].Id,
                SBQQ__Quantity__c = 1)
        };
        insert quoteLines;

        Order newOrder = new Order(
            AccountId = accts[0].Id,
            OpportunityId = opps[0].Id,
            Name = 'Test Order',
            SBQQ__Quote__c = quotes[0].Id,
            Status = 'Draft',
            EffectiveDate = date.today(),
            SBQQ__ContractingMethod__c = 'Single Contract',
            Pricebook2Id = pricebookId
        );
        insert newOrder;

        OrderItem item = new OrderItem(
            OrderId = newOrder.Id,
            Product2Id = prods[0].Id,
            Quantity = 1.00,
            UnitPrice = 10.00,
            PricebookEntryId = pbe.Id
        );
        insert item;

        contract contractSobject = TestDataFactory.createContract(accts[0].Id);
        insert contractSobject;

        Case caseRecord = TestDataFactory.createCases(1, accts[0].Id)[0];
        caseRecord.RecordTypeId = Utilities.getrecordTypeId('Case', 'Cancellations');
        caseRecord.Status = 'New';
        caseRecord.Case_Resolution__c = 'Full Cancellation';
        caseRecord.Related_Opportunity__c = opps[1].Id;
        caseRecord.Related_Contract__c = contractSobject.Id;
        caseRecord.Origin = 'Web';
        caseRecord.Cancel_Override__c = System.today();
        insert caseRecord;

        opps[1].Cancellation_Case__c = caseRecord.Id;
        opps[1].SBQQ__AmendedContract__c = contractSobject.Id;
        update opps[1];
        
        TriggerHandler.clearAllBypasses();
        Test.stopTest();
    }
    
    @isTest
    static void testBatch_RetryContractingOrders(){
        Test.startTest();
        Order testOrder = [SELECT Id
                           FROM Order
                           LIMIT 1][0];
        
        SBQQ.TriggerControl.disable();
        
        testOrder.SBQQ__Contracted__c = true;
        update testOrder;
        
        SBQQ.TriggerControl.enable();
        
        testOrder = [SELECT ContractCustom__c, SBQQ__Contracted__c
                     FROM Order
                     LIMIT 1][0];
        
        Database.executeBatch(new Batch_RetryContractingOrders(), 1);
        Test.stopTest();
    }

    static testMethod void testOrderUpdate() {
        Test.startTest();

        Order[] orders = [SELECT Id, Status, ContractId FROM Order limit 1];
        orders[0].ContractId = null;
        update orders;

        orders = [SELECT Id, Status, ContractId FROM Order limit 1];
        orders[0].Status = 'Activated';
        update orders;

        Test.stopTest();

        orders = [SELECT Id, Status, SBQQ__Contracted__c, ContractId FROM Order limit 1];
        System.assert(orders[0].SBQQ__Contracted__c);

    }

    static testMethod void checkTrigger(){
        Test.startTest();
        Contract con = [SELECT ID, status FROM Contract LIMIT 1];
        con.Status = 'Activated';
        update con;
        Order orderSobject	= [SELECT ID, Status FROM Order LIMIT 1];
        orderSobject.Status = 'Activated';
        update orderSobject;
        Test.stopTest();
    }

    static testMethod void testUpdateRetentionData() {

      Test.startTest();

      Account acc = [SELECT Id FROM Account LIMIT 1][0];
      Opportunity opp = [SELECT Id FROM Opportunity WHERE RecordType.Name = 'Retention' LIMIT 1][0];

      Order ord = new Order(
          AccountId = acc.Id,
          OpportunityId = opp.Id,
          Name = 'Test Retention Order',
          Status = 'Draft',
          Type = 'Amendment',
          EffectiveDate = date.today(),
          SBQQ__ContractingMethod__c = 'Single Contract',
          Pricebook2Id = Test.getStandardPricebookId()
      );
      insert ord;

      Test.stopTest();

      Order orderResult = [
        SELECT Id, OpportunityId
        FROM Order
        WHERE Id = :ord.Id
      ];
      Case caseResult = [
        SELECT Id, Order__c
        FROM Case
        WHERE RecordType.Name = 'Cancellations'
        LIMIT 1
      ];

      System.assertEquals(null, orderResult.OpportunityId);
      System.assertEquals(orderResult.Id, caseResult.Order__c);

    }

}