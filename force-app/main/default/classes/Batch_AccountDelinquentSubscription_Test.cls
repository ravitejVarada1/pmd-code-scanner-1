@isTest
private class Batch_AccountDelinquentSubscription_Test {
    
    @TestSetup
    static void makeData(){
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].HasDelinquentSubscription__c = true;
        accts[0].Days_Until_Delinquency_Cancellation__c = 57;
        insert accts;

        Product2[] products = TestDataFactory.createProducts(2);
        products[0].SBQQ__SubscriptionPricing__c = 'Fixed Price';
        products[1].SBQQ__SubscriptionPricing__c = 'Fixed Price';
        insert products;

        Contract contract = TestDataFactory.createContract(accts[0].Id);
        contract.EndDate = System.today();
        contract.Auto_Renewal_Disable_Date__c = System.today();
        insert contract;
        contract.Status = 'Activated';
        update contract;

        SBQQ__Subscription__c[] subs = TestDataFactory.createCPQSubsForProducts(products, accts[0].Id);
        subs[0].SBQQ__Contract__c = contract.Id;
        subs[0].SBQQ__SubscriptionPricing__c = 'Fixed Price';
        insert subs;

        Zuora__Subscription__c zuoraSub = new Zuora__Subscription__c(
            Zuora__Account__c = accts[0].Id,
            BillingStatus__c = 'Delinquent',
            TextDelinquencyDate__c = String.valueOf(System.today() - 30)
        );

        insert zuoraSub;

        for (SBQQ__Subscription__c sub : subs) {
            sub.Zuora_Subscription__c = zuoraSub.Id;
        }
        update subs;

    }
    
    static testMethod void testBatch() {
        
        try {
            Test.startTest();
            Database.executeBatch(new Batch_ClearDelinquentAccounts());
            Test.stopTest();
        } catch (Exception e) {
            system.debug(e.getMessage());
        } finally {
            Account account = [SELECT Id, HasDelinquentSubscription__c, Days_Until_Delinquency_Cancellation__c FROM Account LIMIT 1];
            system.assertEquals(true, account.HasDelinquentSubscription__c);
            system.assertEquals(27, account.Days_Until_Delinquency_Cancellation__c);
        }
    }

}