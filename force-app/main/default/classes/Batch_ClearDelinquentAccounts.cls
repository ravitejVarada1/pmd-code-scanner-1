/**
 * Daily batch jobs which handles the updating of HasDelinquentSubscription__c on the account object.
 * 
 * @author: Adam LaPlante
 * @jira: BR-5593
 * @created: 02/10/2022
 * @modifed:
 * @modifiedBy:
 */


public class Batch_ClearDelinquentAccounts implements Database.Batchable<sObject>, Schedulable {

	public Database.QueryLocator start(Database.BatchableContext bc){
		// query to pass to execute function
		string query = 	
			'SELECT Id, HasDelinquentSubscription__c,Days_Until_Delinquency_Cancellation__c  ' +
			'FROM Account ' +
			'WHERE HasDelinquentSubscription__c = true';

		return Database.getQueryLocator(query);
	}
    
	public void execute(Database.BatchableContext bc, List<Account> delinquentAccounts) {
        // loop on accounts, set has delinquent subscription to false
		for (Account acc : delinquentAccounts) {
            acc.HasDelinquentSubscription__c = false;
			acc.Days_Until_Delinquency_Cancellation__c  = null;
        }
        update delinquentAccounts;
	}

	public void finish(Database.BatchableContext bc){
		Database.executeBatch(new Batch_AccountDelinquentSubscriptionCheck());
	}

	public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_ClearDelinquentAccounts());
	}

}                                      