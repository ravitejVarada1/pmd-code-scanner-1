/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ngoldy
* created:        06/21/2021
* modified:       06/21/2021
* created jira:   BR-1834
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class Batch_AccountCMRRCalculator implements Database.Batchable<sObject>, Schedulable {

    private List<Id> accountIds;
    
    public Batch_AccountCMRRCalculator() {}

    public Batch_AccountCMRRCalculator(Id accountId) {
        this.accountIds = new List<Id>();
        this.accountIds.add(accountId);
    }

    public Batch_AccountCMRRCalculator(List<Id> accIds) {
        this.accountIds = accIds;
    }

    //Select all ultimate parents with a service provider somewhere in the hierarchy that 
    //was modified in the past <daysBack> days (default is 3)
    public Database.QueryLocator start(Database.BatchableContext BC) {
        String accountCondition1 = accountIds != null && !accountIds.isEmpty() ? 'AND Fulfillment_Account__c IN :accountIds ' : '';
        String accountCondition2 = accountIds != null && !accountIds.isEmpty() ? 'AND Id IN :accountIds ' : '';
        String accountQuery = 'SELECT Id, Name, Type, Product_Activation_Status__c, ' + 
                              'Cancellation_Effective_Date__c, BillingCountryCode, (' +
                                'SELECT Id, Name, Fulfillment_Account__c, SBQQ__ProductName__c, SBQQ__Product__c,  Canceling_57_days__c, ' +
                                'SBQQ__Contract__c, SBQQ__Product__r.IsActive, SBQQ__Product__r.Family, Activation_Status__c, ' +
                                'SBQQ__Product__r.Product_Category__c, SBQQ__Product__r.Sub_Category__c, SBQQ__SubscriptionStartDate__c, ' +
                                'SBQQ__Contract__r.Status, SBQQ__Contract__r.Cancellation_Effective_Date__c, SBQQ__StartDate__c, ' +
                                'SBQQ__RequiredById__c, Commission_CGR_Payout__c, CreatedDate, SBQQ__TerminatedDate__c, SBQQ__Product__r.Source__c ' +
                                'FROM CPQ_Subscriptions_Fulfillment__r ' +
                                'WHERE Fulfillment_Account__c != NULL ' +
                                  accountCondition1 +
                                  'AND SBQQ__Quantity__c > 0  ' +
                                  'AND SBQQ__StartDate__c <= TODAY ' +
                                  'AND (SBQQ__TerminatedDate__c = NULL OR Canceling_57_days__c > TODAY) ' +
                                  'AND SBQQ__Product__r.ProductCode != \'CG-BASE\' ' +
                                'ORDER BY SBQQ__Contract__c, CreatedDate DESC ' +
                              ') ' +
                              'FROM Account ' +
                              'WHERE RecordType.Name = \'Dealer Account\' ' + accountCondition2;
        return Database.getQueryLocator(accountQuery);
    }
    
    // calculate CMRR fields for the queried accounts
    public void execute(Database.BatchableContext BC, List<Account> accounts) {
        AccountCMRRCalculator.calculateAndUpdateCMRR(accounts);
    }
    
    public void finish(Database.BatchableContext BC) {

    }
    
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_AccountCMRRCalculator(), 200);
    }
}