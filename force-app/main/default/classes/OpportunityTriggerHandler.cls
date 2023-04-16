/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         amitul
* modifiedBy:     amitul
* created:        02/26/2021
* modified:       02/26/2021
* created jira:   BR-501
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class OpportunityTriggerHandler extends TriggerHandler {
    private List<Opportunity> newOppList;
    private Map<ID,Opportunity> newOppMap;
    private List<Opportunity> oldOppList;
    private Map<ID,Opportunity> oldOppMap;
    
    public OpportunityTriggerHandler(){
        this.newOppList = (List<Opportunity>) Trigger.new;
        this.newOppMap  = (Map<Id,Opportunity>) Trigger.newMap;
        this.oldOppList = (List<Opportunity>) Trigger.old;
        this.oldOppMap  = (Map<Id,Opportunity>) Trigger.oldMap;
    }

    public override void beforeInsert(){
        OpportunitySplitHandler.setSkipControls(true);
        OpportunityTriggerFunctions.populateAutoCloseDate(newOppList);
        OpportunityTriggerFunctions.createTrackerRecords(newOppList);
        OpportunityTriggerFunctions.setDefaultValuesOnAmend(newOppList); //SA-682
        OpportunityTriggerFunctions.setManagerEmail(newOppList, oldOppMap); //SA-436
    }
    
    public override void beforeUpdate() {
        OpportunitySplitHandler.setSkipControls(true);
        CG_OppOwnership.updateOppOwnerToRetention(newOppMap, oldOppMap);
        OpportunityTriggerFunctions.updateClosedDateOnLost(newOppList, oldOppMap); //SA-289
        OpportunityTriggerFunctions.setManagerEmail(newOppList, oldOppMap); //SA-436
    }

    public override void beforeDelete() {
        OpportunitySplitHandler.setSkipControls(true);
    }
    
    public override void afterInsert(){
        OpportunitySplitHandler.setSkipControls(true);
        AccountOwnershipOppCreateEvent.opportunityCreateEvents(newOppMap);
        OpportunityTriggerFunctions.createContactRole(null, newOppMap, true);
        OpportunityTriggerFunctions.getAccountsForOppStatUpdate(newOppList, null);
    }
         
    public override void afterUpdate() {
        OpportunitySplitHandler.setSkipControls(true);
        OpportunityTriggerFunctions.stopCancellationProcessingIfRetentionOppWon(oldOppMap, newOppMap);
        OpportunityTriggerFunctions.createOppSplitsForCommissions(newOppList,oldOppMap);
        AccountOwnershipOppClosedEvent.handleOpportunityUpdates(newOppMap, oldOppMap);
        OpportunityTriggerFunctions.stampOpportunitySplit(newOppList, oldOppMap);
        OpportunityTriggerFunctions.setRenewalDeltaLineItems(newOppList); //BR-4143
        OpportunityTriggerFunctions.setRenewalEligibleToFalse(newOppList);
        OpportunityTriggerFunctions.createContactRole(oldOppMap, newOppMap, false);
        OpportunityTriggerFunctions.getAccountsForOppStatUpdate(newOppList, oldOppMap);
    }

    public override void afterDelete() {
        OpportunitySplitHandler.setSkipControls(true);
    }
}