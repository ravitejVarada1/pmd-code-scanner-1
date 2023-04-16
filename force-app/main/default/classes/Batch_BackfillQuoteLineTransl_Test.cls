/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     ralvarez
* created:        09/21/2022
* modified:       
* created jira:   SA-591 Test Class for Batch_BackfillQuoteLineTranslations
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public without sharing class Batch_BackfillQuoteLineTransl_Test {

    @testSetup
    private static void setup() {
        
        SBQQ.TriggerControl.disable();

        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].BillingCountryCode = 'US';
        insert accts;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 1);
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        quotes[0].Billing_Type__c = 'Advance';
        quotes[0].SBQQ__Status__c = 'Draft';
        quotes[0].SBQQ__QuoteLanguage__c = 'English';
        insert quotes;        

        Product2[] products = new List<Product2>();
        products.add(new Product2(
            Name = 'Enhanced Placement',
            IsActive = true,
            ProductCode = 'ENH-PLC',
            Family = 'Listings',
            Product_Category__c = 'Core Products',
            Sub_Category__c = 'Enhanced', 
            Description = '-Test Product - LeadAI (applicable to services starting 8/18/2022 and later)'
        ));

        insert products;
        
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            quotes[0].Id,
            accts[0].Id,
            new Set<Id>{products[0].Id}
        )[0];
        insert testQuoteLine;

    }

    @isTest
    public static void getQuoteLineTranslations_removeLeadAI_Test () {
        
        TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
        SBQQ.TriggerControl.disable();

        Account[] accts = [SELECT Id, Name FROM Account];
        Product2[] prods = [SELECT Id,Description, ProductCode FROM Product2];
        System.debug('Test: ' + prods);

        SBQQ__Quoteline__c quoteLine = [SELECT Id FROM SBQQ__Quoteline__c LIMIT 1];
        quoteLine.SBQQ__Existing__c = true;

        update quoteLine;
        
        Test.startTest();
        Database.executeBatch(new Batch_BackfillQuoteLineTranslations());
        Test.stopTest();

        SBQQ.TriggerControl.enable();
        TriggerHandler.clearAllBypasses();

        quoteLine = [SELECT Id, Translated_Product_Description__c, Translated_Product_Name__c,
            SBQQ__Product__r.Description FROM SBQQ__Quoteline__c LIMIT 1];        
        System.debug('Test quoteLines: ' + quoteLine);
        System.assertEquals('-Test Product', quoteLine.Translated_Product_Description__c);
    }

    @isTest
    public static void getQuoteLineTranslations_NotRemoveLeadAI_Test () {

        TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
        SBQQ.TriggerControl.disable();

        Account[] accts = [SELECT Id, Name FROM Account];
        Product2[] prods = [SELECT Id, ProductCode, Description FROM Product2];
        System.debug('Test: ' + prods);
        
        Test.startTest();
        Database.executeBatch(new Batch_BackfillQuoteLineTranslations());
        Test.stopTest();

        SBQQ.TriggerControl.enable();
        TriggerHandler.clearAllBypasses();

        SBQQ__Quoteline__c quoteLine = [SELECT Id, Translated_Product_Description__c, Translated_Product_Name__c,
            SBQQ__Product__r.Description FROM SBQQ__Quoteline__c LIMIT 1];        
        System.debug('Test quoteLines: ' + quoteLine);
        System.assertEquals('-Test Product - LeadAI', quoteLine.Translated_Product_Description__c);

    }
}