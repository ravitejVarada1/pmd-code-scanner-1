public class TrialTriggerHandler extends TriggerHandler{
    private List<Trial__c> newList;
    private Map<ID,Trial__c> newMap;
    private List<Trial__c> oldList;
    private Map<ID,Trial__c> oldMap;

    public TrialTriggerHandler(){
        this.newList = (List<Trial__c>) Trigger.new;
        this.newMap  = (Map<Id,Trial__c>) Trigger.newMap;
        this.oldList = (List<Trial__c>) Trigger.old;
        this.oldMap  = (Map<Id,Trial__c>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        TrialTriggerFunctions.populateEndDate(newList);
        TrialTriggerFunctions.checkTrial(newList, null);
    }

    public override void beforeUpdate() {
        TrialTriggerFunctions.checkTrial(newList, oldMap);
    }

    public override void afterInsert() {
        TrialTriggerFunctions.updateAccountType(newList);
    }
}