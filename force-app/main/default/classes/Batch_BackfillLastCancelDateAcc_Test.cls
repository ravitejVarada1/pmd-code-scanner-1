/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     ralvarez
* created:        09/21/2022
* modified:       
* created jira:   SA-176 Test class Batch_BackfillLastCancelDateAcc
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public without sharing class Batch_BackfillLastCancelDateAcc_Test {

    @testSetup
    private static void setup() {
        Account[] accts = TestDataFactory.createAccounts(1);        
        insert accts;

        Contract co = new Contract(
            AccountId = accts[0].Id,
            CurrencyISOCode='USD',
            Name = 'Contract',
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(335),
            ContractTerm = 12,
            Status = 'Cancelled',
            Cancellation_Effective_Date__c = Date.today()
        );
        insert co;

        Product2[] products = TestDataFactory.createProducts(1);
        products[0].ProductCode = 'CG-BASE';
        insert products;
    }

    @isTest
    public static void getCancellationDateTest () {
        Account[] accts = [SELECT Id, Name FROM Account];
        Product2[] prods = [SELECT Id, ProductCode FROM Product2];
        
        Test.startTest();

        Contract[] cts = [SELECT ID, Status, Cancellation_Effective_Date__c FROM Contract];
        cts[0].Status = 'Cancelled';
        update cts;

        SBQQ__Subscription__c[] subs = new List<SBQQ__Subscription__c>();
        subs.addAll(TestDataFactory.createCPQSubsForProducts(prods, accts[0].Id));

        for(SBQQ__Subscription__c cpqsubs : subs) {
            cpqSubs.SBQQ__Contract__c = cts[0].Id;
        }        
        insert subs;
            
        Database.executeBatch(new Batch_BackfillLastCancelDateAcc());
        
        Test.stopTest();

        Account account = [SELECT Id, Last_Cancellation_Effective_Date__c FROM Account WHERE Id = :accts[0].Id LIMIT 1];
        System.assertEquals(cts[0].Cancellation_Effective_Date__c, account.Last_Cancellation_Effective_Date__c, 'Last Cancellation Effective Date got updated');

    }
    
}