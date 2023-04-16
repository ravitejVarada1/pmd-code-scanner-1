/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        07/21/2021
* modified:       07/21/2021
* created jira:   BR-3283
* purpose: Locates any  orders where SBQQ__Contracted__c = true but ContractCustom__c is null. Unchecks
* - the SBQQ__Contracted__c box on these orders and sends the quoteId into the QueueableContractOrders job to retry
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class Batch_RetryContractingOrders implements Database.Batchable<sObject>{
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        
        //Looks for quotes (and their orders that have SBQQ__Contracted__c = true but ContractCustom__c is null)
        String query = 'SELECT Id, (SELECT Id ' +
            					   'FROM SBQQ__Orders__r ' +
            					   'WHERE SBQQ__Contracted__c = true ' +
                                   'AND ContractCustom__c = null) ' +
                       'FROM SBQQ__Quote__c ' +
                       'WHERE Id IN (SELECT SBQQ__Quote__c ' +
                                    'FROM Order ' +
                                    'WHERE SBQQ__Contracted__c = true ' +
                                    'AND ContractCustom__c = null)';

        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<SBQQ__Quote__c> quotesToRetryOrderContracting) {

        List<Order> ordersToUnContract = new List<Order>();
        
        for (SBQQ__Quote__c q : quotesToRetryOrderContracting){
            for (Order o : q.SBQQ__Orders__r){
                o.SBQQ__Contracted__c = false;
                ordersToUnContract.add(o);
            }
        }
        
        //This update just makes SBQQ__Contracted__c false
        update ordersToUnContract;

        //Sends the quoteId into the QueueableContractOrders job to retry
        System.enqueueJob(new QueueableContractOrders(
            quotesToRetryOrderContracting[0].Id)
        );
    }
    
    public void finish(Database.BatchableContext bc){
        
    }
}