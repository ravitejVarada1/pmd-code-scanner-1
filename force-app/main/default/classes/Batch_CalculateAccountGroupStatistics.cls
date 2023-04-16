/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         alaplante
* modifiedBy:     
* created:        10/04/2021
* modified:       
* created jira:   BR-4251
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class Batch_CalculateAccountGroupStatistics implements Database.Batchable<sObject>, Schedulable {

    //Select all ultimate parents
    public Database.QueryLocator start(Database.BatchableContext BC) {
        String accountQuery = 'SELECT Id FROM Account WHERE Is_Ultimate_Parent__c = true ';
        return Database.getQueryLocator(accountQuery);
    }
    
    // calculate groups statistics fields
    public void execute(Database.BatchableContext BC, List<Account> accounts) {

        Set<Id> accIds = new Set<Id> ();
        for (Account acc : accounts) {
            accIds.add(acc.Id);
        }

        List<Account> ultimateAccs = [
            SELECT Id, Name, Type, Used_Inventory_Avg__c, Total_Used_Inventory__c, Total_New_Inventory__c, 
                Open_Opps_Owned_By_Acq_SUM__c, Open_Opps_Owned_By_DR_SUM__c,Total_CMRR__c,
                (SELECT Id, Name, Type, Used_Inventory_Avg__c, Total_Used_Inventory__c, Total_New_Inventory__c,
                Open_Opps_Owned_By_Acq_SUM__c, Open_Opps_Owned_By_DR_SUM__c, Total_CMRR__c
                FROM Accounts_Descendents__r),
                (SELECT Id, Account__c, reviewStatus__c
                FROM All_Hierarchy_Service_Providers__r)        
            FROM Account WHERE Id IN :accIds];

        AccountGroupStatisticsCalculator.calculateAndUpdateGroupStatistics(ultimateAccs);
    }
    
    public void finish(Database.BatchableContext BC) {

    }
    
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_CalculateAccountGroupStatistics(), 200);
    }
}