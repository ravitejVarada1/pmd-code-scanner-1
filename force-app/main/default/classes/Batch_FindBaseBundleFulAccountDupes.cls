/**
 * BR-9384 - mark contracts that have the same fulfilllment accounts with different
 * Base Bundle CPQ Subs
 * 
 */

public without sharing class Batch_FindBaseBundleFulAccountDupes implements Database.Batchable<sObject> {
    
    //default constructor
    public Batch_FindBaseBundleFulAccountDupes() {}

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM Contract WHERE Status = \'Activated\'';
        return Database.getQueryLocator(query);
    }

    
    public void execute(Database.BatchableContext bc, List<Contract> contracts) {
        Set<Id> contract_ids = new Set<Id>();
        Map<Id, Set<String>> contract_fulaccount_keys = new Map<Id, Set<String>>();

        for(SBQQ__Subscription__c cpq_sub : [
            SELECT Id, Product_Code__c, Fulfillment_Account__c, SBQQ__Contract__c  
            FROM SBQQ__Subscription__c 
            WHERE SBQQ__Contract__c IN :contracts 
            AND Product_Code__c = 'CG-BASE' 
            AND Provisioning_Status__c = 'Activated'
        ]) {
                
            Id contract_id = cpq_sub.SBQQ__Contract__c;
            String key = cpq_sub.Product_Code__c + cpq_sub.Fulfillment_Account__c;
            if(!contract_fulaccount_keys.containsKey(contract_id)) {
                contract_fulaccount_keys.put(contract_id, new Set<String>{key});
            } else {
                Set<String> key_set = contract_fulaccount_keys.get(contract_id);
                if(key_set.contains(key)) {
                    contract_ids.add(contract_id);
                } else {
                    key_set.add(key);
                }
            }
        }

        if(!contract_ids.isEmpty()) {
            List<Contract> contracts_to_udpate = new List<Contract>();
            for(Id cid : contract_ids) {
                Contract ct = new Contract(
                    Id = cid,
                    Review_Subscriptions__c = true
                );
                contracts_to_udpate.add(ct);
            }

            update contracts_to_udpate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        
    }
}
