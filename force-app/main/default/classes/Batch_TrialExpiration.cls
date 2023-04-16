public class Batch_TrialExpiration implements Database.Batchable<sObject>, Schedulable {
    
    private String query;

    public Batch_TrialExpiration() {}

    public Database.QueryLocator start(Database.BatchableContext BC) {
        query = 'SELECT Id, Account__c, Opportunity__c, End_Date__c FROM Trial__c ' +
            'WHERE End_Date__c <= TODAY AND Expired__c = false';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<Trial__c> trials) {
        expireTrials(trials);
    }

    public void finish(Database.BatchableContext BC) {}

    public void execute (SchedulableContext sc) {
        Database.executeBatch(new Batch_TrialExpiration());
    }

    public static void expireTrials(Trial__c[] trials) {
        
        Set<Id> acctIds = new Set<Id>();
        Account[] updateList = new List<Account>();

        for (Trial__c t : trials) {
            acctIds.add(t.Account__c);
        }

        Map<Id,Account> acctMap = new Map<Id,Account>(
                [SELECT Id, Product_Activation_Status__c 
                FROM Account WHERE Id IN: acctIds]);
        
        for (Trial__c t : trials) {
            Account a = acctMap.get(t.Account__c);
            if (a.Product_Activation_Status__c == 'Trial') {
                a.Product_Activation_Status__c = 'Restricted – Activated';
                updateList.add(a);
            }
            t.Expired__c = true;
        }

        if (!updateList.isEmpty()) { update updateList; }
        update trials;
    }

}