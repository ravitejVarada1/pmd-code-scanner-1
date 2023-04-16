/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     ralvarez
* created:        09/21/2022
* modified:       
* created jira:   SA-176 Batch to Backfill Last_Cancellation_Effective_Date__c on Account
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public without sharing class Batch_BackfillLastCancelDateAcc implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
    
        String query = 'SELECT Id, SBQQ__Contract__c, SBQQ__Contract__r.Cancellation_Effective_Date__c, Fulfillment_Account__c FROM SBQQ__Subscription__c ' + 
        'WHERE SBQQ__Contract__r.Status = \'Cancelled\' ' + 
        'AND Product_Code__c = \'CG-BASE\' ' +
        'AND SBQQ__Contract__r.Cancellation_Effective_Date__c != NULL ' +
        'ORDER BY SBQQ__Contract__c, SBQQ__Contract__r.Cancellation_Effective_Date__c DESC ';

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<SBQQ__Subscription__c> scope) {

        //Map to store Fulfillment account Id and greatest Cancellation Effective Date
        Map<Id, Date> accToCancellationDateMap = new Map<Id, Date>();
        for (SBQQ__Subscription__c sub : scope) {
    
            // Get fulfillment account Id and Cancellation Effective Date from Contract
            Id ffAccountId = sub.Fulfillment_Account__c;
            Date contractCancelEffDate = sub.SBQQ__Contract__r.Cancellation_Effective_Date__c;
    
            if(!accToCancellationDateMap.containsKey(ffAccountId)) {
                accToCancellationDateMap.put(ffAccountId, contractCancelEffDate);
            } else {
                Date cancellationDate = accToCancellationDateMap.get(ffAccountId);
                if(cancellationDate < contractCancelEffDate) {
                    accToCancellationDateMap.put(ffAccountId, contractCancelEffDate);
                }
            }
        }        
    
        List<Account> accountListToUpd = new List<Account> ();
        // Loop through map and set Last_Cancellation_Effective_Date__c on account
        for (Id accId : accToCancellationDateMap.keySet()) {
            accountListToUpd.add(new Account(Id = accId, Last_Cancellation_Effective_Date__c = accToCancellationDateMap.get(accId)));
        }

        if (!accountListToUpd.isEmpty()) {
            // bypass Account Trigger
            TriggerHandler.bypass('AccountTriggerHandler');
            update accountListToUpd;
            TriggerHandler.clearAllBypasses();
        }
    }

	public void execute(SchedulableContext sc) {
		Database.executeBatch(new Batch_BackfillLastCancelDateAcc());
	}
    
    public void finish(Database.BatchableContext bc) {
	}
}