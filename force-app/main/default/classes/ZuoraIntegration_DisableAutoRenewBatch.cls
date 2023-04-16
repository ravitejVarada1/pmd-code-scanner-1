/**
 * BR-1273 - Set Auto Renewal flag on Zuora Subscription Object
 * Queries Contracts that have a matching Auto Renewal Disable Date, calls a helper
 * to generate a Disable Auto Renew amendment message
 * TO be scheduled for 8pm daily
 */

public class ZuoraIntegration_DisableAutoRenewBatch implements Database.Batchable<sObject>, Schedulable{
    
    public void execute(SchedulableContext sc){
        Database.executeBatch(new ZuoraIntegration_DisableAutoRenewBatch());
    }

    public Database.QueryLocator start(Database.BatchableContext bc){
        Date dateToday = System.today();

        string query = 'SELECT Id ' +
                        'FROM Contract ' +
                        'WHERE Auto_Renewal_Disable_Date__c =:dateToday';

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Contract> contracts){
        Map<Id, Contract> contractIdMap = new Map<Id, Contract>(contracts);
        ZuoraIntegration_SupplementOrderHelper.sendAmendTermsMessages(contractIdMap.keySet(), false, true);
    }

    public void finish(Database.BatchableContext bc){
    }
}