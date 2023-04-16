@isTest
private class Batch_TransferDataToPHAdminCentre_Test {
    
    @TestSetup
    static void makeData(){

        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].HasDelinquentSubscription__c = true;
        accts[0].Days_Until_Delinquency_Cancellation__c = 57;
        accts[0].PH_Admin_Centre_Id__c = '123456';
        insert accts;

        Product2[] products = TestDataFactory.createProducts(2);
        products[0].SBQQ__SubscriptionPricing__c = 'Fixed Price';
        products[1].SBQQ__SubscriptionPricing__c = 'Fixed Price';
        products[1].Provisioning_Platform__c = 'PistonHeads';
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
            BillingStatus__c = 'Paying'
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
            Database.executeBatch(new Batch_TransferDataToPHAdminCentre());
            Test.stopTest();
        } catch (Exception e) {
            system.debug(e.getMessage());
        } finally {
            Integration_Message__c[] integrationMessage = [SELECT Id FROM Integration_Message__c WHERE Process__c = 'PistonHeads Account'];
            system.assertEquals(integrationMessage.size(), 1);
        }
    }

}