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
global class Batch_AccountCGR implements Database.Batchable<sObject>, Schedulable {
	
	private Set<Id> accountIds;
	
	global Batch_AccountCGR() {}
    
  	global Batch_AccountCGR(Id accountId) {
		this.accountIds = new Set<Id>{accountId};
	}
	
	global Batch_AccountCGR(Set<Id> accountIds) {
		this.accountIds = accountIds;
	}
	
	global Database.QueryLocator start(Database.BatchableContext BC) {
    List<String> cgrQueryFields = new List<String>(Account_CGR__c.SObjectType.getDescribe().fields.getMap().keySet());
		String query =  'SELECT Id, Name, Type, Data_CMRR__c, Display_CMRR__c, Listings_Base_CMRR__c, Listings_CMRR__c, ' +
                      'Digital_Retail_CMRR__c, PistonHeads_CMRR__c, Website_Inventory_CMRR__c, ' +
                      'Total_CMRR__c, CurrencyIsoCode, Product_Activation_Status__c, ' +
                      '(SELECT '+ String.join(cgrQueryFields, ', ') +
                      ' FROM Account_CGRs__r ORDER BY CreatedDate DESC LIMIT 1) ' +
                    'FROM Account ' +
                    'WHERE (Product_Activation_Status__c IN (\'Active\', \'Canceling – 57 days\') ' +
					'OR (Product_Activation_Status__c = \'Restricted – Activated\' AND Type = \'Former Customer\')) ';

    
    if(accountIds != null && !accountIds.isEmpty()) {
		List<Id> queryIds = new List<Id>(accountIds);
		query += ' AND Id IN :queryIds';
    }
		
		return Database.getQueryLocator(query);
	}
	
	global void execute(Database.BatchableContext BC, List<Account> accounts) {
		try {
			CGR_Functions.createAndUpdateCgrRecords(accounts);
		} catch (Exception e) {
			System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
			throw e;
		}
	}
	
	global void finish(Database.BatchableContext BC) {}
	
	public void execute(SchedulableContext ctx) {
		Database.executeBatch(new Batch_AccountCGR(), 200);
	}

}