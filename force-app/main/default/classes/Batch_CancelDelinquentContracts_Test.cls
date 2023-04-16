@isTest
private class Batch_CancelDelinquentContracts_Test {
    
    @TestSetup
    static void makeData(){
        Account[] accts = TestDataFactory.createAccounts(1);
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
        subs[0].Provisioning_Status__c = 'Delinquent';
        insert subs;

        Zuora__Subscription__c zuoraSub = new Zuora__Subscription__c(
            Zuora__Account__c = accts[0].Id,
            TextDelinquencyDate__c = String.valueOf(System.today() - 58),
            BillingStatus__c = 'Delinquent'
        );

        insert zuoraSub;
        subs[0].Zuora_Subscription__c = zuoraSub.Id;
        update subs;

    }
    
    static testMethod void testDelinquencyDays() {
        
		List<SBQQ__Subscription__c> cpqSubs = [SELECT Id, Delinquent_Date__c, Delinquent_Days__c FROM SBQQ__Subscription__c];
   		Zuora__Subscription__c[] zuoraSubs = [SELECT Id, TextDelinquencyDate__c FROM Zuora__Subscription__c];
        
        System.assertEquals(String.valueOf(System.today()-58), zuoraSubs[0].TextDelinquencyDate__c);
        System.assertEquals(System.today()-58, cpqSubs[0].Delinquent_Date__c);
        System.assertEquals(58.00, cpqSubs[0].Delinquent_Days__c);
        
    
    }

    static testMethod void testBatch() {
        
        try {
            Test.startTest();
            Database.executeBatch(new Batch_CancelDelinquentContracts());
            Test.stopTest();
        } catch (Exception e) {
            system.debug(e.getMessage());
        } finally {
            Contract[] contracts = [SELECT Id, Status, Cancellation_Effective_Date__c FROM Contract];
            system.assertEquals(System.today(), contracts[0].Cancellation_Effective_Date__c);
        }
    }

    static testMethod void testBatchScheduler() {

        Batch_CancelDelinquentContracts b = new Batch_CancelDelinquentContracts();
        String cronString = '0 0 23 * * ?';
        Test.startTest();
        String jobId = System.schedule('TEST_Batch_CancelDelinquentContracts', cronString, b);
        Test.stopTest();
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
    }

}