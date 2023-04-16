/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     ralvarez
* created:        10/06/2021
* modified:       10/06/2021
* created jira:   BR-4265
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
private class ContractTriggerFunctions_Test {

    @TestSetup
    static void testSetup(){

        Account[] accts = TestDataFactory.createAccounts(1);
        insert accts;

        Contact[] cons = TestDataFactory.createContacts(1,accts[0].Id);
        insert cons;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 2);
        opps[1].RecordTypeId = Utilities.getrecordTypeId('Opportunity', 'Retention');
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        insert quotes;

        Attachment attach = new Attachment (Name = 'Test.pdf', ParentId = quotes[0].Id, Description = 'test', Body = Blob.valueOf('Test Attachment Body'));
        insert attach;

        Product2[] prods = new List<Product2>{
            new Product2(Name = 'CG Base Bundle', IsActive = true)
        };
        insert prods;

        Id pricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pricebookId, Product2Id = prods[0].Id, UnitPrice = 1020, IsActive = true);
        insert pbe;

        TriggerHandler.bypass('CPQQuoteLineTriggerHandler');

        SBQQ__QuoteLine__c[] quoteLines = new List<SBQQ__QuoteLine__c>{
            new SBQQ__QuoteLine__c(
                Fulfillment_Account__c = accts[0].Id,
                SBQQ__Product__c = prods[0].Id,
                SBQQ__Quote__c = quotes[0].Id,
                SBQQ__Quantity__c = 1)
        };
        insert quoteLines;

        TriggerHandler.clearAllBypasses();

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

        Contract contractSobject = TestDataFactory.createContract(accts[0].Id);
        contractSobject.SBQQ__Quote__c = quotes[0].Id;
        contractSobject.SBQQ__Order__c = newOrder.ID;
        insert contractSobject;
        
    }
    
    @isTest
    static void test_contractTriggerUpdate() {
        Test.startTest();
        Contract con = [SELECT ID, status FROM Contract LIMIT 1];
        con.Status = 'Activated';
        update con;
        Test.stopTest();
    }

    @isTest
    static void test_getAmendPDF() {
        
        //Query existing contract
        Test.startTest();
        Contract con = [SELECT ID, status FROM Contract LIMIT 1];
        Set<Id> contractIds = new Set<Id> ();
        contractIds.add(con.Id);
        
        // Query acccount and create new oppty and amendment quote
        Account acc = [SELECT Id FROM Account LIMIT 1];        
        Opportunity[] opps = TestDataFactory.createOpps(acc.Id, 1);
        insert opps;

        SBQQ.TriggerControl.disable();
        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(acc.Id, opps[0].Id, 1);        
        quotes[0].SBQQ__MasterContract__c = con.Id;
        quotes[0].SBQQ__Ordered__c = true;
        quotes[0].SBQQ__Type__c = 'Amendment';
        insert quotes;
        SBQQ.TriggerControl.enable();
        
        // Create new Attachment for amendment quote
        Attachment attach = new Attachment (Name = 'Test2.pdf', ParentId = quotes[0].Id, Description = 'test2.pdf', Body = Blob.valueOf('Test Attachment Body2'));
        insert attach;

        // Call static method to create new pdf attachment on Contract
        ContractTriggerFunctions.insertNewPDFonContracts(contractIds);

        // Query attachments
        List<Attachment> attachmentList = [SELECT Id, Name, ParentId FROM Attachment WHERE ParentId = :con.Id];

        System.assertEquals(2, attachmentList.size(), 'There should be two attachment files related to the contract: ' + con.Id);
        
        Test.stopTest();
    
    }

    @isTest
    static void test_checkPreserveBundleCheckbox() {
        
        Test.startTest();
        Contract con = [SELECT Id, SBQQ__PreserveBundleStructureUponRenewals__c FROM Contract LIMIT 1];

        System.assertEquals(true, con.SBQQ__PreserveBundleStructureUponRenewals__c, 'Preserve Bundle Stracture is not true');
        
        Test.stopTest();
    }
}