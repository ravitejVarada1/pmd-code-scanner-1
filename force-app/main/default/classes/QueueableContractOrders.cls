/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        07/21/2021
* modified:       07/21/2021
* created jira:   BR-3283
* purpose: Checks the contracted box on orders - used by Pending Activation Tracker and Batch_CheckOpportunityPats
* - when an order is to be created. For Amendments, this job contracts just one order, then recursivly calls
* - itself to contract all the other 
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class QueueableContractOrders implements Queueable{
    private Id quoteId;
    
    public QueueableContractOrders(Id quoteId){
        this.quoteId = quoteId;
    }

    public void execute(QueueableContext context){
        
        //Query for just one order that is not contracted yet, if this is an amendment, or query for all orders 
        //if this is not an amendment
        List<Order> ordersToContract = [SELECT Id
                                       FROM Order
                                       WHERE SBQQ__Contracted__c = false
                                       AND SBQQ__Quote__c = :quoteId
                                       LIMIT 1];
        
        if (ordersToContract.isEmpty()){
            Database.executeBatch(new Batch_UpdateOnboardingCaseOwner());    
            return;
        }
        
        for (Order o : ordersToContract){
            o.SBQQ__Contracted__c = true;
        }

        update ordersToContract;
        
        if(!Test.isRunningTest()) {
            System.enqueueJob(new QueueableContractOrders(quoteId));
        }
    }
    
}