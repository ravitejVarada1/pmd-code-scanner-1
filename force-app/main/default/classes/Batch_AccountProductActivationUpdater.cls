/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ngoldy
* created:        06/22/2021
* modified:       06/22/2021
* created jira:   BR-2019
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class Batch_AccountProductActivationUpdater implements Database.Batchable<sObject>, Schedulable{

    public Batch_AccountProductActivationUpdater() {}

    // Select accounts that have a cancellation effective date that's 57 days in the past
    public Database.QueryLocator start(Database.BatchableContext BC) {
        Date todayMinus57days = System.today().addDays(-57);
        String accountQuery = 'SELECT Id, Product_Activation_Status__c, Cancellation_Effective_Date__c ' +
                              'FROM Account ' +
                              'WHERE Cancellation_Effective_Date__c != null ' +
                                'AND Cancellation_Effective_Date__c <= :todayMinus57days ';

        return Database.getQueryLocator(accountQuery);
    }
    
    public void execute(Database.BatchableContext BC, List<Account> accounts) {
        for(Account acc : accounts) {
            acc.Product_Activation_Status__c = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_RESTRICTEDACTIVATED;
        }
        update accounts;
    }
    
    public void finish(Database.BatchableContext BC) {

    }
    
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_AccountProductActivationUpdater(), 200);
    }
}