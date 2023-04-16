/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     ralvarez
* created:        09/21/2022
* modified:       
* created jira:   SA-591 Batch to backfill Translations for Name and Descriptions on Subs
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public without sharing class Batch_BackfillDefaultSubTranslations implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
    
        String query = 'SELECT Id, SBQQ__Contract__r.ContractLanguage__c, SBQQ__Contract__r.Status, SBQQ__StartDate__c, ' +
            'Translated_Product_Description__c, Translated_Product_Name__c, SBQQ__Product__r.Description, SBQQ__Product__r.Name, ' +
            'SBQQ__Product__r.Product_Description_French__c, SBQQ__Product__r.Product_Name_French__c ' +
            'FROM SBQQ__Subscription__c ' + 
            'WHERE SBQQ__Contract__r.Status = \'Activated\' ' + 
            'AND SBQQ__Contract__r.ContractLanguage__c != NULL ' +
            'AND Provisioning_Status__c = \'Activated\' ' + 
            'AND SBQQ__Quantity__c > 0 ' + 
            'AND Product_Code__c != \'CG-BASE\' ' ;
                        

        System.debug('Batch_BackfillDefaultSubTranslations query: '+ query);
    
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<SBQQ__Subscription__c> scope) {

        for (SBQQ__Subscription__c sub : scope) {

            // Set defualt description and name variables (english)
            String desct = sub.SBQQ__Product__r.Description != null ? sub.SBQQ__Product__r.Description : '' ;
            String productName = sub.SBQQ__Product__r.Name;

            if (sub.SBQQ__Contract__r.ContractLanguage__c == 'English') {

                if (desct.contains('(applicable to services starting 8/18/2022 and later)')) {

                    // If sub Start Date is less than 2022-08-18, we need to remove LeadAI and Onsite Ads from the Product Description
                    if (sub.SBQQ__StartDate__c < Date.newInstance(2022,08,18)) {
                        desct = desct.remove('- LeadAI (applicable to services starting 8/18/2022 and later)');
                        desct = desct.remove('- Onsite Ads (applicable to services starting 8/18/2022 and later)');
                    } // If sub Start Date is greater or equal than 2022-08-18, we want to keep LeadAI and Onsite Ads but without the legal wording
                     else {
                        desct = desct.remove('(applicable to services starting 8/18/2022 and later)');
                    }
                }
                if (desct.contains('Includes:')) {
                    desct = desct.replace('Includes:', '<br/> Includes: '); 
                    desct = desct.replace('-', '<br/> -');
                }
            } else if (sub.SBQQ__Contract__r.ContractLanguage__c == 'French') {
                // If contract language is French, then get french values from Product2 record
                desct = sub.SBQQ__Product__r.Product_Description_French__c;
                productName = sub.SBQQ__Product__r.Product_Name_French__c;
            }

            sub.Translated_Product_Description__c = desct;
            sub.Translated_Product_Name__c = productName;
        }
        
        TriggerHandler.bypass('CPQ_Subscription_TriggerHandler');
        update scope;
        TriggerHandler.clearAllBypasses();
    }

	public void finish(Database.BatchableContext bc) {

	}
}