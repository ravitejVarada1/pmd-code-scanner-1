/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        06/06/2021
* modified:       06/06/2021
* created jira:   BR-878
* purpose:  	  Checks all open opps for updates to their Pending Activation Tracker record.
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class Batch_CheckOpportunityPats implements Database.Batchable<sObject>, Schedulable{
        
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_CheckOpportunityPats(), 1);
    }
    
    //Select all open opportunities without an "Ordered" quote
    public Database.QueryLocator start(Database.BatchableContext bc) {
        
        String APPROVED = ConstantsUtil.QUOTE_STATUS_APPROVED;
        
        String query = 'SELECT Id, Opportunity_Tracker__c, Opportunity_Tracker__r.QuoteOrderingErrors__c, Opportunity_Tracker__r.Complete__c ' + 
            'FROM Opportunity ' +
            'WHERE IsClosed = false ' +
			'AND Id IN (SELECT SBQQ__Opportunity2__c ' +
            			   'FROM SBQQ__Quote__c ' +
            			   'WHERE SBQQ__Primary__c = true ' +
                           'AND SBQQ__Status__c = :' + APPROVED + ')';

        return Database.getQueryLocator(query);
    }
    
    //Pass the opportunities into the method that checks if all their activation steps are done,
    //and marks the primary quote as "Ordered" (activated), if they are done
    public void execute(Database.BatchableContext BC, List<Opportunity> openOpps) {
        
        if (openOpps.size() > 1){
            return;
        }
        
        Opportunity singleOpp = openOpps[0];
        
        if (singleOpp.Opportunity_Tracker__r.Complete__c){
            
            if (singleOpp.Opportunity_Tracker__r.QuoteOrderingErrors__c != null){                
                update new Opportunity_Tracker__c(
                    Id = singleOpp.Opportunity_Tracker__c,
                    QuoteOrderingErrors__c = null
                );
            }
            
            
            OpportunityTrackerTriggerFunctions.activateOppsFromTrackerIds(new Set<ID>{singleOpp.Opportunity_Tracker__c});
        }else{
            OpportunityPatChecker.checkOpps(new Map<Id,Opportunity>(openOpps).keySet());
        }
    }
    
    public void finish(Database.BatchableContext bc){
        //Schedule batch for 10 mins from now that checks for any orders where SBQQ__Contracted__c = true
        //but they do not have a value in their ContractCustom__c field. (This 100% means contracting failed for some
        //reason). This job simple tries to recontract these orders once.
        String batchName = Test.isRunningTest()
        ? 'Batch_RetryContractingOrders_test'
        : 'Batch_RetryContractingOrders';

        System.scheduleBatch(new Batch_RetryContractingOrders(), batchName, 10, 1);
    }
}