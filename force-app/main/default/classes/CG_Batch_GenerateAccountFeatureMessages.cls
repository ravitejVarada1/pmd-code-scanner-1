// https://cargurus.atlassian.net/browse/CRM-5021
// batch class to generate account feature messages for supplied account ids or account query
// there is no empty constructor for this, as we always want to operate on a constrained set of accounts
// test coverage in CG_FeatureFramework_Test
public class CG_Batch_GenerateAccountFeatureMessages implements Database.Batchable<sObject>, Database.Stateful {
    
    Set<Id> accountIds;
    String query;
    Integer delayHours = -1;    // by default, messages will be sent immediately

    // constructor takes a set of account ids to process
    public CG_Batch_GenerateAccountFeatureMessages(Set<Id> accountIds) {
        this.accountIds = accountIds;
    }

    // constructor takes a query for account ids to process
    public CG_Batch_GenerateAccountFeatureMessages(String query) {
        this.query = query;
    }

    // constructor takes a set of account ids to process, and hours to delay
    public CG_Batch_GenerateAccountFeatureMessages(Set<Id> accountIds, Integer delayHours) {
        this.accountIds = accountIds;
        this.delayHours = delayHours;
    }

    // constructor takes a query for account ids to process, and hours to delay
    public CG_Batch_GenerateAccountFeatureMessages(String query, Integer delayHours) {
        this.query = query;
        this.delayHours = delayHours;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (query == null) {
            query = 'SELECT Id FROM Account WHERE Id IN :accountIds';
        }
        return Database.getQueryLocator(query);
	}
	
	public void execute(Database.BatchableContext bc, List<Account> accountList) {
        Set<Id> accountIds = new Map<Id,Account>(accountList).keySet();

		try {
            CG_AccountFeatureMessageHelper.delayHours = delayHours;
            CG_AccountFeatureMessageHelper.generateAccountFeatureMessages(accountIds);
		} catch (Exception e) {
			System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
			throw e;
		}
	}
	
    // when this batch process is complete, send any feature messages in the queue
    public void finish(Database.BatchableContext bc) {
        // add code to send integration messages to generic on demand boomi endpoint
    }

}