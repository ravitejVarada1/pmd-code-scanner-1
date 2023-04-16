/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     ralvarez
* created:        09/21/2022
* modified:       
* created jira:   SA-591 Test Class for Batch_BackfillDefaultContractLanguage
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public without sharing class Batch_BackfillDefaultContractLang_Test {

    @testSetup
    private static void setup() {
        Account[] accts = TestDataFactory.createAccounts(1);        
        insert accts;

        Contract co = new Contract(
            AccountId = accts[0].Id,
            Name = 'Contract',
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(335),
            ContractTerm = 12            
        );
        insert co;

        Product2[] products = TestDataFactory.createProducts(1);
        products[0].ProductCode = 'CG-BASE';
        insert products;
    }

    @isTest
    public static void getContractLanguageEng_Test () {
        Account[] accts = [SELECT Id, Name FROM Account];
        Product2[] prods = [SELECT Id, ProductCode FROM Product2];
        
        Test.startTest();

        Contract[] cts = [SELECT ID, Status, Cancellation_Effective_Date__c FROM Contract];
        cts[0].Status = 'Activated';
        update cts;
            
        Database.executeBatch(new Batch_BackfillDefaultContractLanguage());
        
        Test.stopTest();

        Contract contract = [SELECT Id, ContractLanguage__c FROM Contract WHERE Id = :cts[0].Id LIMIT 1];
        System.assertEquals('English', contract.ContractLanguage__c, 'Contract Language was set to English');

    }
    
    @isTest
    public static void getContractLanguageFrench_Test () {
        
        Test.startTest();
        Account[] accts = [SELECT Id, Name FROM Account];
        Contract[] cts = [SELECT ID, Status FROM Contract];

        accts[0].BillingCountryCode = 'CA';
        update accts;

        // Amendment oppty
        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 1);
        insert opps;

        // Amendmet quote
        SBQQ__Quote__c quote = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1)[0];
        quote.Contract_Commitment_Term_Months__c = '12';
        quote.SBQQ__QuoteLanguage__c = 'French';

        insert quote;

        cts[0].Status = 'Activated';
        cts[0].SBQQ__Quote__c = quote.Id;
        update cts;
            
        Database.executeBatch(new Batch_BackfillDefaultContractLanguage());
        
        Test.stopTest();

        Contract contract = [SELECT Id, ContractLanguage__c FROM Contract WHERE Id = :cts[0].Id LIMIT 1];
        System.assertEquals('French', contract.ContractLanguage__c, 'Contract Language was set to French');
    }
    
}