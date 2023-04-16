/**
 * Daily batch jobs which handles the updating of HasDelinquentSubscription__c on the account object.
 * 
 * @author: Adam LaPlante
 * @jira: BR-5593
 * @created: 02/10/2022
 * @modified: 
 *   06/29/2022 (SA-211) Adam LaPlante
 */


public class Batch_AccountDelinquentSubscriptionCheck implements Database.Batchable<sObject>, Schedulable {

	public Database.QueryLocator start(Database.BatchableContext bc){
		// query to pass to execute function
		string query = 	
			'SELECT Billing_Account__c, Fulfillment_Account__c, Days_Until_Auto_Cancellation__c ' +
			'FROM SBQQ__Subscription__c ' +
			'WHERE Billing_Status__c = \'Delinquent\'';
			
		return Database.getQueryLocator(query);
	}
    
	public void execute(Database.BatchableContext bc, List<SBQQ__Subscription__c> delinquentSubscriptions) {
        system.debug('delinquentSubs::' + delinquentSubscriptions);
		// initialize id sets
		Map<Id, Decimal> delinquentBillingAccountMap = new Map<Id, Decimal>();
		Map<Id, Decimal> delinquentFulfillmentAccountMap = new Map<Id, Decimal>();
		Set<Id> delinquentAccountIds = new Set<Id>();
		Set<Id> payingAccountIds = new Set<Id>();
		List<Account> accountsToUpdate = new List<Account>();

		// establish sets that contains ids of delinquent billing & fulfillment accounts
		for (SBQQ__Subscription__c delinquentSub : delinquentSubscriptions) {
			delinquentBillingAccountMap.put(delinquentSub.Billing_Account__c, delinquentSub.Days_Until_Auto_Cancellation__c);
			delinquentFulfillmentAccountMap.put(delinquentSub.Fulfillment_Account__c, delinquentSub.Days_Until_Auto_Cancellation__c);
		}


		// if there are delinquent billing  accounts
		if (!delinquentBillingAccountMap.isEmpty()) {
			// loop on account id
			for (Id accountId : delinquentBillingAccountMap.keySet()) {
				// add account to upsert list with has delinquent subscription checked
                if (accountId != null) {
                    accountsToUpdate.add(
                        new Account(
                            Id = accountId,
                            HasDelinquentSubscription__c = true,
                            Days_Until_Delinquency_Cancellation__c = delinquentBillingAccountMap.get(accountId)
                        )
                    );
                }
				// to avoid double insertion, 
				// if  same account exists in fulfillment account set, remove from set
				if (delinquentFulfillmentAccountMap.containsKey(accountId)) {
					delinquentFulfillmentAccountMap.remove(accountId);
				}
			}
		}

		// if there are delinquent fulfillment accounts
		if (!delinquentFulfillmentAccountMap.isEmpty()) {
			// loop on account id
			for (Id accountId : delinquentFulfillmentAccountMap.keySet()) {
				// add account to upsert list with has delinquent subscription checked
                if (accountId != null) {
                    accountsToUpdate.add(
                        new Account(
                            Id = accountId,
                            HasDelinquentSubscription__c = true,
                            Days_Until_Delinquency_Cancellation__c = delinquentFulfillmentAccountMap.get(accountId)
                        )
                    );
                }
            }
		}


		if (!accountsToUpdate.isEmpty()) {
			try {
				update accountsToUpdate;
			} catch (DMLException e) {
				system.debug('Error upserting accounts::' + e.getMessage());
				//	Utilities.sendSimpleErrorEmail('Batch_AccountDelinquentSubscriptionCheck', e.getMessage());
			}
		}
    }

	public void finish(Database.BatchableContext bc){
	}

	public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_AccountDelinquentSubscriptionCheck());
	}

}