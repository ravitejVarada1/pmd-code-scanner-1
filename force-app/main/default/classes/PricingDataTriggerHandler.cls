/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        05/21/2021
* modified:       05/21/2021
* created jira:   BR-1843
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class PricingDataTriggerHandler extends TriggerHandler{

    private List<Pricing_Data__c> newPdList;
    private Map<ID,Pricing_Data__c> newPdMap;
    private List<Pricing_Data__c> oldPdList;
    private Map<ID,Pricing_Data__c> oldPdMap;
    
    public PricingDataTriggerHandler(){
        this.newPdList = (List<Pricing_Data__c>) Trigger.new;
        this.newPdMap  = (Map<Id,Pricing_Data__c>) Trigger.newMap;
        this.oldPdList = (List<Pricing_Data__c>) Trigger.old;
        this.oldPdMap  = (Map<Id,Pricing_Data__c>) Trigger.oldMap;
    }
    
    public override void beforeInsert(){
        PricingDataTriggerFunctions.checkForDuplicates(newPdList);
    }
    
    public override void beforeUpdate(){
        PricingDataTriggerFunctions.checkForDuplicates(newPdList);
    }
    
}