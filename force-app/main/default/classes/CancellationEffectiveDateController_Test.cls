@isTest
private class CancellationEffectiveDateController_Test {

    @TestSetup
    static void makeData(){
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Active';
        insert accts;
      
        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 2);
        opps[1].RecordTypeId = Utilities.getrecordTypeId('Opportunity', 'Retention');
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        quotes[0].SBQQ__StartDate__c = System.today();  
        insert quotes;
        
        Product2[] products = TestDataFactory.createProducts(2);
        products[0].Name = 'CG Base Bundle';
        products[0].ProductCode = 'CG-BASE';
        products[1].Name = 'Enhanced';
        products[1].Family = 'Listings';
        products[1].product_category__c = 'Core Products';

        insert products;        

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
        contr.StartDate = system.today();
        insert contr;
  
    }

    @istest
    public static void setEffectiveDate_test() {

        Test.startTest();
        Contract contract = [SELECT Id FROM Contract LIMIT 1];
        contract.Status = 'Activated';
        update contract;
        
        SBQQ__Quote__c q = [Select id from SBQQ__Quote__c LIMIT 1];
       	q.SBQQ__MasterContract__c = contract.Id;
        q.Cancellation_Quote__c = true;
        Update q;
        String msg = SetCancellationEffectiveDateController.setEffectiveDate(Contract.Id, system.Today());
        Test.stopTest();
        
        System.assertEquals('updated successfully',msg);

    }

}