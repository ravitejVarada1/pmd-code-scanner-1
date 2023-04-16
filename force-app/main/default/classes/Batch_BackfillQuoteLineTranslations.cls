/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     ralvarez
* created:        09/21/2022
* modified:       
* created jira:   SA-591 Batch to backfill Translations for Name and Descriptions on Quote Lines
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public without sharing class Batch_BackfillQuoteLineTranslations  implements Database.Batchable<sObject>, Database.Stateful {
    public Database.QueryLocator start(Database.BatchableContext BC) {
    
        String query = 'SELECT Id, CreatedDate, SBQQ__Description__c, SBQQ__ProductCode__c, ' +
            'SBQQ__ProductName__c, SBQQ__Quote__r.SBQQ__QuoteLanguage__c, SBQQ__Product__r.Name, ' +
            'SBQQ__Product__r.Description, SBQQ__Product__r.Product_Description_French__c, ' +
            'SBQQ__Product__r.Product_Name_French__c, SBQQ__Existing__c, SBQQ__Quote__r.SBQQ__Type__c ' +
            'FROM SBQQ__QuoteLine__c ' + 
            'WHERE SBQQ__Quote__r.SBQQ__Status__c IN (\'Draft\', \'Pending Pre-Sale Approval\', \'Pre-Sale Rejected\', \'Pre-Sale Approved\', \'Rejected\') ' + 
            'AND SBQQ__ProductCode__c != \'CG-BASE\' ';
            
        return Database.getQueryLocator(query);
    }

    private Set<Id> successes = new Set<Id>();
    private Set<Id> failures = new Set<Id>();
    @testVisible
    private static String result = '';

    public void execute(Database.BatchableContext context, List<SBQQ__QuoteLine__c> scope) {

        for (SBQQ__QuoteLine__c quoteLine : scope) {

            // Set defualt description and name variables (english)
            String desct = quoteLine.SBQQ__Product__r.Description != null ? quoteLine.SBQQ__Product__r.Description : '' ;
            String productName = quoteLine.SBQQ__Product__r.Name;

            if (quoteLine.SBQQ__Quote__r.SBQQ__QuoteLanguage__c == 'English' 
                || quoteLine.SBQQ__Quote__r.SBQQ__QuoteLanguage__c == null ) {

                if (desct.contains('(applicable to services starting 8/18/2022 and later)')) {

                    // If Quote Line is existing one, we'll remove LeadAI and Onsite Ads from the Product Description
                    if (quoteline.SBQQ__Existing__c) {
                        desct = desct.remove('- LeadAI (applicable to services starting 8/18/2022 and later)');
                        desct = desct.remove('- Onsite Ads (applicable to services starting 8/18/2022 and later)');
                    } else {
                        desct = desct.remove('(applicable to services starting 8/18/2022 and later)');
                    }
                }
                if (desct.contains('Includes:')) {
                    desct = desct.replace('Includes:', '<br/> Includes: '); 
                    desct = desct.replace('-', '<br/> -');
                }
            } else if (quoteLine.SBQQ__Quote__r.SBQQ__QuoteLanguage__c  == 'French') {
                // If quote language is French, then get french values from Product2 record
                desct = quoteLine.SBQQ__Product__r.Product_Description_French__c;
                productName = quoteLine.SBQQ__Product__r.Product_Name_French__c;
            }

            quoteLine.Translated_Product_Description__c = desct;
            quoteLine.Translated_Product_Name__c = productName;
        }
        
        //Disable Quote Line and CPQ Triggers
        TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
        SBQQ.TriggerControl.disable();

        List<Database.SaveResult> saveResults = new List<Database.SaveResult>();        
        saveResults = Database.update(scope, false);
        for (Database.SaveResult sr : saveResults) {
            if (sr.isSuccess()) {
                // Only available *across* scope executions because of
                // Database.stateful
                successes.add(sr.id);
            } else {
                // Only available *across* scope executions because of
                // Database.stateful
                failures.add(sr.id);
            }
        
        SBQQ.TriggerControl.enable();
        TriggerHandler.clearAllBypasses();
        }
    }    

	public void finish(Database.BatchableContext bc) {

        Batch_BackfillQuoteLineTranslations.result =
            'Successes: ' +
            successes.size() +
            'Failures: ' +
            failures.size();

        System.debug('Finish Results: ' + Batch_BackfillQuoteLineTranslations.result);

	}

    public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_BackfillQuoteLineTranslations());
	}
}