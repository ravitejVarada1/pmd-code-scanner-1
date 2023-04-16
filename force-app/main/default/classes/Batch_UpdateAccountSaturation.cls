public class Batch_UpdateAccountSaturation implements Database.Batchable<sObject>, Schedulable {
	public Database.QueryLocator start(Database.BatchableContext bc){
		string query = 	'SELECT Id FROM Account WHERE Is_Ultimate_Parent__C = true';
		return Database.getQueryLocator(query);
	}
	public void execute(Database.BatchableContext bc, List<Account> accounts){
        Set<Id> ultAccountIds = (new Map<Id,Account>(accounts)).keySet();
        AccountTriggerFunctions.processSaturationChanges(ultAccountIds);
	}

	public void finish(Database.BatchableContext bc){
	}

	public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_UpdateAccountSaturation());
	}

}                                      