/**
 * @description       : Test class for Batch_DeactivateCoopOnAccounts
 * @author            : Lawrence Zhao
 * @last modified on  : 11-15-2021
 * @last modified by  : LZhao
**/
@isTest
private inherited sharing class Batch_DeactivateCoopOnAccounts_Test {
    @TestSetup
    static void makeData() {

        Date cancelDate = System.today()-3;
        Account[] accts = TestDataFactory.createAccounts(1);
        insert accts;

        Co_Op_Detail__c coopDetail = new Co_Op_Detail__c (
            Account__c = accts[0].id,
            Active__c = true
        );
        insert coopDetail;

        Contract contract = TestDataFactory.createContract(accts[0].Id);
        contract.EndDate = cancelDate;
        contract.Cancellation_Effective_Date__c = cancelDate;
        insert contract;
        contract.Status = 'Cancelled';
        update contract;

        List<Product2> products = TestDataFactory.createProducts(1);
        products[0].ProductCode = 'CG-BASE';
        insert products;

        List<Zuora__Subscription__c> zsubs = TestDataFactory.createZSubscriptions(accts[0].Id, 1);
        zsubs[0].Zuora__AutoRenew__c = true;
        insert zsubs;

        List<SBQQ__Subscription__c> subs = TestDataFactory.createCPQSubsForProducts(products, accts[0].Id);
        subs[0].Zuora_Subscription__c = zsubs[0].Id;
        subs[0].SBQQ__Contract__c =  contract.Id;
        subs[0].Fulfillment_Account__c = accts[0].Id;
        insert subs;
    }

    static testMethod void testCoOpDeactivation() {
        Test.startTest();
        Database.executeBatch(new Batch_DeactivateCoopOnAccounts());
        Test.stopTest();
        List<Co_Op_Detail__c> checkCoopDetail = [SELECT ID, Active__c, Account__c FROM Co_Op_Detail__c WHERE Active__c = TRUE];
        System.assert(checkCoopDetail.size() == 0, 'There are active Co-Op Detail records');
    }

    
    static testMethod void testSchedulable() {
        Test.startTest();
        String cronString = Utilities.getCronExpressionMinutesFromNow(10);
        String jobId = System.schedule('testBatch_DeactivateCoopOnAccounts', cronString, new Batch_DeactivateCoopOnAccounts());
        Test.stopTest();
        
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
    }
}