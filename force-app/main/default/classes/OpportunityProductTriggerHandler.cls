public class OpportunityProductTriggerHandler extends TriggerHandler {
    private List<OpportunityLineItem> newOppList;
    private Map<ID,OpportunityLineItem> newOppMap;
    private List<OpportunityLineItem> oldOppList;
    private Map<ID,OpportunityLineItem> oldOppMap;
    
    public OpportunityProductTriggerHandler(){
        this.newOppList = (List<OpportunityLineItem>) Trigger.new;
        this.newOppMap  = (Map<Id,OpportunityLineItem>) Trigger.newMap;
        this.oldOppList = (List<OpportunityLineItem>) Trigger.old;
        this.oldOppMap  = (Map<Id,OpportunityLineItem>) Trigger.oldMap;
    }

    public override void afterInsert(){
        OpportunityProductTriggerFunctions.replaceProductsOnRenewal(newOppList);
    }

    public override void afterDelete(){
        OpportunityProductTriggerFunctions.recreateNegativeLines(oldOppList);
    }
}