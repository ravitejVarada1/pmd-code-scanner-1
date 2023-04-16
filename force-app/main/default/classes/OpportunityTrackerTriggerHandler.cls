/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        05/10/2021
* modified:       05/10/2021
* created jira:   BR-878
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class OpportunityTrackerTriggerHandler extends TriggerHandler{
    private List<Opportunity_Tracker__c> newOptList;
    private Map<ID,Opportunity_Tracker__c> newOptMap;
    private List<Opportunity_Tracker__c> oldOptList;
    private Map<ID,Opportunity_Tracker__c> oldOptMap;
    
    public OpportunityTrackerTriggerHandler(){
        this.newOptList = (List<Opportunity_Tracker__c>) Trigger.new;
        this.newOptMap  = (Map<Id,Opportunity_Tracker__c>) Trigger.newMap;
        this.oldOptList = (List<Opportunity_Tracker__c>) Trigger.old;
        this.oldOptMap  = (Map<Id,Opportunity_Tracker__c>) Trigger.oldMap;
    }
    
    public override void beforeUpdate(){
        OpportunityTrackerTriggerFunctions.checkNewlyCompletedTrackersBefore(newOptList, oldOptMap);
    }
    
    public override void afterUpdate(){
        OpportunityTrackerTriggerFunctions.checkNewlyCompletedTracker(newOptList, oldOptMap);
    }
}