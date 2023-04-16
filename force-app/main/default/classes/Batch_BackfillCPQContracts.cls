public without sharing class Batch_BackfillCPQContracts implements Database.Batchable<sObject> {
    Set<ID> accountIds;
    Integer queryLimit;
    String billingCountryCode;
        
    public Batch_BackfillCPQContracts() {}

    public Batch_BackfillCPQContracts(Set<ID> accountIds) {
        this.accountIds = new Map<Id,Account>([select Id, ParentId, Ultimate_Parent_Account__c
            from Account where Id in : accountIds or Ultimate_Parent_Account__c in : accountIds]).keySet();
    }

    public Batch_BackfillCPQContracts(Integer queryLimit) {
        this.queryLimit = queryLimit;
    }

    public Batch_BackfillCPQContracts(Id accountId) {
        this.accountIds = new Map<Id,Account>([select Id, ParentId, Ultimate_Parent_Account__c
            from Account where Id = : accountId or Ultimate_Parent_Account__c = : accountId]).keySet();
    }

    public Batch_BackfillCPQContracts(String billingCountryCode) {
        this.billingCountryCode = billingCountryCode;
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC){
        Set<String> zSubStatuses = new Set<String>{'Active'};
		
        String query = 'SELECT Id, ParentId, Ultimate_Parent_Account__c FROM Account '+
            'WHERE '+(accountIds != null ? 'Id IN : accountIds AND ' : '')+
                (billingCountryCode != null? 'BillingCountryCode = :billingCountryCode AND ' : '')+
                ' Id IN '+
                '(SELECT Zuora__Account__c FROM Zuora__Subscription__c WHERE '+
                'SalesforceLegacyContractId__c != null AND SalesforceLegacyAccountId__c != null '+
                'AND Zuora__Status__c IN : zSubStatuses)'+
            (queryLimit != null ? ' LIMIT '+queryLimit : '');

		System.debug('Batch_BackfillCPQContracts query: '+query);
		
		return Database.getQueryLocator(query);
	}
	
	public void execute(Database.BatchableContext BC, Account[] accountList) {
        System.debug('Account List:'+accountList.size());
		try {
			//Batch_BackfillCPQContracts.processBatch(accountList);
            BackfillCPQContractsHelper bch = new BackfillCPQContractsHelper();
			bch.processBatch(accountList);
		} catch (Exception e) {
			System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
			throw e;
		}
	}
	
	public void finish(Database.BatchableContext BC) {

    }
}