/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ngoldy
* created:        06/22/2021
* modified:       06/22/2021
* created jira:   BR-1844
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
global class Batch_AccountCGRReps implements Database.Batchable<sObject>, Schedulable {
    
  private Set<Id> accountIds;
	
	global Batch_AccountCGRReps() {}
    
  global Batch_AccountCGRReps(Id accountId) {
		this.accountIds = new Set<Id>{accountId};
	}
	
	global Batch_AccountCGRReps(Set<Id> accountIds) {
		this.accountIds = accountIds;
	}
	
	global Database.QueryLocator start(Database.BatchableContext BC) {
		List<String> cgrQueryFields = new List<String>(Account_CGR__c.SObjectType.getDescribe().fields.getMap().keySet());
		String query =  'SELECT '+ String.join(cgrQueryFields, ', ') + ' ' +
                    'FROM Account_CGR__c ' +
                    'WHERE CreatedDate = THIS_MONTH';
    
    if(accountIds != null && !accountIds.isEmpty()) {
      List<Id> queryIds = new List<Id>(accountIds);
      query += ' AND Account__c IN :queryIds';
    }
		
		return Database.getQueryLocator(query);
	}
	
	global void execute(Database.BatchableContext BC, List<Account_CGR__c> cgrList) {
		try {
			// create and insert CGR Rep records
      CGR_Functions.createCgrRepRecords(cgrList);
		} catch (Exception e) {
			System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
			throw e;
		}
	}
	
	global void finish(Database.BatchableContext BC) {}

  public void execute(SchedulableContext ctx) {
      Database.executeBatch(new Batch_AccountCGRReps(), 200);
  }
    
}