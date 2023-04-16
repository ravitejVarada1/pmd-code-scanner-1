// https://cargurus.atlassian.net/browse/BR-1144
// batch class to find accounts ready to push to zuora based on billing contact info and quote approval status
// and kick off zuora account integration
public without sharing class ZuoraIntegration_AccountBatch implements Database.Batchable<sObject>, Schedulable, 
        Database.AllowsCallouts 
{
    // schedulable execute method uses defaults
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new ZuoraIntegration_AccountBatch());
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String approvalStatusApproved = ConstantsUtil.QUOTE_APPROVALSTATUS_APPROVED;

        // query for accounts with an integration message in progress for exclusion
        Set<Id> excludeAccountIds = ZuoraIntegration_AccountHelper.getAccountIdsInProgress();

        // list of criteria for batch query
        List<String> quoteLineCriteria = new List<String>{
            'SBQQ__ProductOption__c = null',
            'Billing_Account__c != null',
            'Fulfillment_Account__c != null',
            '(Billing_Account__c NOT IN :excludeAccountIds OR Fulfillment_Account__c NOT IN :excludeAccountIds)',
            '(Billing_Account__r.Billing_Account_Zuora__c = null OR Fulfillment_Account__r.Billing_Account_Zuora__c = null)'
        };

        String query = 'SELECT Id FROM SBQQ__Quote__c '+
            'WHERE ApprovalStatus__c = :approvalStatusApproved AND Id IN '+
            '(SELECT SBQQ__Quote__c FROM SBQQ__QuoteLine__c WHERE '+String.join(quoteLineCriteria, ' AND ')+')';
        
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SBQQ__Quote__c> quoteList) {
        Set<Id> quoteIds = new Map<Id,SBQQ__Quote__c>(quoteList).keySet();
        try {
            ZuoraIntegration_AccountHelper.createAndSendZAccountMessages(quoteIds);
		} catch (Exception e) {
			System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
			throw e;
		}
	}
	
    public void finish(Database.BatchableContext bc) {}
    
}