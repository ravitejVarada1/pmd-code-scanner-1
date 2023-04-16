/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        03/11/2021
* modified:       03/11/2021
* created jira:   BR-367 & BR-368
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class Batch_AccountCategoryUpdateChecker implements Database.Batchable<sObject>, Schedulable{
    private Integer hoursBack = 36;
    private DateTime cutoffDateTime = DateTime.now().addHours(-hoursBack);
    private Boolean useAccountLastModDate = false;
    
    public Batch_AccountCategoryUpdateChecker(Integer hoursBack){
        this.hoursBack = hoursBack;
    }
    
    public Batch_AccountCategoryUpdateChecker(Boolean useAccountLastModDate, Integer hoursBack){
        this.useAccountLastModDate = useAccountLastModDate;
        this.hoursBack = hoursBack;
    }

    public Batch_AccountCategoryUpdateChecker(){}
    
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_AccountCategoryUpdateChecker());
    }

    //Select all ultimate parents with a service provider somewhere in the hierarchy that 
    //was modified in the past <daysBack> days (default is 3)
    public Database.QueryLocator start(Database.BatchableContext BC){
        String accountQuery = 'SELECT Id ' +
            				  'FROM Account ';
        
        if (useAccountLastModDate){
            accountQuery += 'WHERE LastModifiedDate > :cutoffDateTime';
        }else{
            accountQuery +='WHERE Id IN (SELECT Ultimate_Parent_Account__c ' +
                           'FROM Service_Provider__c ' +
                		   'WHERE LastModifiedDate > :cutoffDateTime )';
        }

        return Database.getQueryLocator(accountQuery);
    }
    
    //Run the accountCategoryCalc method on the ultAccountsToRecalc
    public void execute(Database.BatchableContext BC, List<Account> ultAccounts) {
        AccountCategoryCalculator.execute(new Map<Id,Account>(ultAccounts).keySet());
    }
    
    public void finish(Database.BatchableContext BC) {

    }
}