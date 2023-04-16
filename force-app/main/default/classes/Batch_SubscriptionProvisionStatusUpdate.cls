/** BR-1452
 * Batch looks for Provisioning Status mismatches between Provisioning_Status_Formula__c and 
 * Provisioning_Status__c using a formula field named Provisioning_Status_Mismatch__c.
 * Causes and update on SBQQ Subscription records with mismatches.
 * Trigger handles the rest.
 * 
 * Also Updates the Contract and Account if they are not already in an Activated/Active status
 */

public without sharing class Batch_SubscriptionProvisionStatusUpdate implements Database.Batchable<sObject>, Schedulable {

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_SubscriptionProvisionStatusUpdate());
    }

    public Batch_SubscriptionProvisionStatusUpdate() {}

    public Database.QueryLocator start(Database.BatchableContext BC){
        String query = 'SELECT Id, Provisioning_Status_Formula__c, Provisioning_Status__c, '+
            'Provisioning_Status_Mismatch__c '+
            'FROM SBQQ__Subscription__c '+
            'WHERE Provisioning_Status_Mismatch__c = true';
        
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SBQQ__Subscription__c> cpqSubs) {
        
        if(!cpqSubs.isEmpty()) {
            update cpqSubs;
        }
    }

    public void finish(Database.BatchableContext BC) {
        if(!Test.isRunningTest()) {
            Database.executeBatch(new Batch_ActivatePendingContracts());
        }
    }
}