/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     ralvarez
* created:        09/21/2022
* modified:       
* created jira:   SA-591 Test Class for Batch_BackfillDefaultSubTranslations
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public without sharing class Batch_BackfillDefaultSubTransl_Test {

    @testSetup
    private static void setup() {
        Account[] accts = TestDataFactory.createAccounts(1);        
        insert accts;

        Contract co = new Contract(
            AccountId = accts[0].Id,
            Name = 'Contract',
            StartDate = Date.newInstance(2022,07,01),
            EndDate = Date.newInstance(2023,07,01),
            ContractTerm = 12            
        );
        insert co;

        Product2[] products = TestDataFactory.createProducts(1);
        products[0].Description = '-Test Product - LeadAI (applicable to services starting 8/18/2022 and later)';
        insert products;
    }

    @isTest
    public static void getSubTranslations_removeLeadAI_Test () {
        Account[] accts = [SELECT Id, Name FROM Account];
        Product2[] prods = [SELECT Id, ProductCode FROM Product2];
        
        
        Test.startTest();
        TriggerHandler.bypass('CPQ_Subscription_TriggerHandler');        
        

        Contract[] cts = [SELECT ID, Status FROM Contract];
        cts[0].Status = 'Activated';
        cts[0].ContractLanguage__c = 'English';
        update cts;

        SBQQ__Subscription__c[] subs = new List<SBQQ__Subscription__c>();
        subs.addAll(TestDataFactory.createCPQSubsForProducts(prods, accts[0].Id));

        for(SBQQ__Subscription__c cpqsubs : subs) {
            cpqSubs.SBQQ__Contract__c = cts[0].Id;
            cpqSubs.SBQQ__Quantity__c = 1;
            cpqSubs.Provisioning_Status__c = 'Activated';
            cpqSubs.SBQQ__SubscriptionStartDate__c = Date.newInstance(2022,07,01);
        }        
        insert subs;

        
        Database.executeBatch(new Batch_BackfillDefaultSubTranslations());
        TriggerHandler.clearAllBypasses();
        Test.stopTest();
        

        SBQQ__Subscription__c sub = [SELECT Id, Translated_Product_Description__c, Translated_Product_Name__c
            FROM SBQQ__Subscription__c WHERE Id = :subs[0].Id LIMIT 1];        
        System.debug('Test subs2: ' + sub);        
        System.assertEquals('-Test Product', sub.Translated_Product_Description__c);

    }

    @isTest
    public static void getSubTranslations_NotRemoveLeadAI_Test () {
        Account[] accts = [SELECT Id, Name FROM Account];
        Product2[] prods = [SELECT Id, ProductCode FROM Product2];       
        
        Test.startTest();

        TriggerHandler.bypass('CPQ_Subscription_TriggerHandler');                

        Contract[] cts = [SELECT ID, Status FROM Contract];
        cts[0].Status = 'Activated';
        cts[0].ContractLanguage__c = 'English';
        update cts;

        SBQQ__Subscription__c[] subs = new List<SBQQ__Subscription__c>();
        subs.addAll(TestDataFactory.createCPQSubsForProducts(prods, accts[0].Id));

        for(SBQQ__Subscription__c cpqsubs : subs) {
            cpqSubs.SBQQ__Contract__c = cts[0].Id;
            cpqSubs.SBQQ__Quantity__c = 1;
            cpqSubs.Provisioning_Status__c = 'Activated';
            cpqSubs.SBQQ__SubscriptionStartDate__c = Date.newInstance(2022,09,01);
        }        
        insert subs;

        Database.executeBatch(new Batch_BackfillDefaultSubTranslations());
        TriggerHandler.clearAllBypasses();
        Test.stopTest();        

        SBQQ__Subscription__c sub = [SELECT Id, Translated_Product_Description__c, Translated_Product_Name__c
            FROM SBQQ__Subscription__c WHERE Id = :subs[0].Id LIMIT 1];
        
        System.assertEquals('-Test Product - LeadAI', sub.Translated_Product_Description__c);
        System.debug('Test2 subs2: ' + sub);

    }
    
    
    
}