/**
* Test class for Batch_SubscriptionProvisionStatusUpdate.cls
* BR-1452
 */

@isTest
public without sharing class Batch_SubscriptionProvisionStatusTest {
    
    @testSetup
    private static void setup() {
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Restricted – Activated';
        insert accts;

        Contract co = new Contract(
            AccountId = accts[0].Id,
            CurrencyISOCode='USD',
            Name = 'Contract',
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(335),
            ContractTerm = 12
        );
        insert co;

        Product2[] products = TestDataFactory.createProducts(1);
        insert products;
    }

    @isTest
    public static void testMismatchBatchUpdate () {
        Account[] accts = [SELECT ID FROM Account];
        Product2[] prods = [SELECT ID FROM Product2];
        Contract[] cts = [SELECT ID FROM Contract];

        SBQQ__Subscription__c[] subs = new List<SBQQ__Subscription__c>();
        subs.addAll(TestDataFactory.createCPQSubsForProducts(prods, accts[0].Id));

        for(SBQQ__Subscription__c cpqsubs : subs) {
            cpqSubs.SBQQ__Contract__c = cts[0].Id;
        }
        insert subs;
        
        String cronString = Utilities.getCronExpressionMinutesFromNow(10);
    
        Test.startTest();
        System.schedule('Test_Sched_Batch_SubscriptionProvisionStatusUpdate', cronString, 
                        new Batch_SubscriptionProvisionStatusUpdate());   
        //Database.executeBatch(new Batch_SubscriptionProvisionStatusUpdate());
        
        Test.stopTest();
    }

    @isTest
    public static void testActivateContract () {
        Account[] accts = [SELECT ID FROM Account];
        Product2[] prods = [SELECT ID FROM Product2];
        Contract[] cts = [SELECT ID FROM Contract];

        SBQQ__Subscription__c[] subs = new List<SBQQ__Subscription__c>();
        subs.addAll(TestDataFactory.createCPQSubsForProducts(prods, accts[0].Id));

        for(SBQQ__Subscription__c cpqsubs : subs) {
            cpqSubs.SBQQ__Contract__c = cts[0].Id;
        }
        insert subs;

        Test.startTest();
            
        Database.executeBatch(new Batch_ActivatePendingContracts());
        
        Test.stopTest();
    }
    
}