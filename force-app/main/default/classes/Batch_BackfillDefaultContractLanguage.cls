/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     ralvarez
* created:        09/21/2022
* modified:       
* created jira:   SA-591 Batch to backfill Contract Language on Contracts
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public without sharing class Batch_BackfillDefaultContractLanguage  implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
    
        String query = 'SELECT Id, Account.BillingCountryCode, Account.Preferred_Language__c, ' +
            'ContractLanguage__c, Legacy_Contract__c, SBQQ__Quote__r.SBQQ__QuoteLanguage__c '+
        'FROM Contract ' +
        'WHERE Status = \'Activated\'';

        System.debug('Batch_BackfillCPQContracts query: '+ query);
    
        return Database.getQueryLocator(query);
    }    

	public void finish(Database.BatchableContext bc) {

	}

    public void execute(Database.BatchableContext context, List<Contract> scope) {

        for (Contract contract : scope) {
            if (contract.Account.BillingCountryCode == 'US' || contract.Account.BillingCountryCode == 'GB') {
                contract.ContractLanguage__c = 'English';
            } else if (contract.Account.BillingCountryCode == 'CA' && contract.SBQQ__Quote__r.SBQQ__QuoteLanguage__c != null) {
                contract.ContractLanguage__c = contract.SBQQ__Quote__r.SBQQ__QuoteLanguage__c;
            } else {
                contract.ContractLanguage__c = contract.Account.Preferred_Language__c != null ? contract.Account.Preferred_Language__c : 'English';
            }
        }

        TriggerHandler.bypass('ContractTriggerHandler');
        update scope;
        TriggerHandler.clearAllBypasses();

    }

	public void execute(SchedulableContext sc) {
		Database.executeBatch(new Batch_BackfillDefaultContractLanguage());
	}

}