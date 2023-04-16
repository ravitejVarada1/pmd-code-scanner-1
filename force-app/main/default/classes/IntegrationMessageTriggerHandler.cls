public class IntegrationMessageTriggerHandler extends TriggerHandler {
    
    private List<Integration_Message__c> newList;
    private Map<Id,Integration_Message__c> newMap;
    private List<Integration_Message__c> oldList;
    private Map<Id,Integration_Message__c> oldMap;

    public IntegrationMessageTriggerHandler(){
        this.newList= (List<Integration_Message__c>) Trigger.new;
        this.newMap = (Map<Id,Integration_Message__c>) Trigger.newMap;
        this.oldList = (List<Integration_Message__c>) Trigger.old;
        this.oldMap = (Map<Id,Integration_Message__c>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        
    }

    public override void beforeUpdate() {
        
    }

    public override void beforeDelete() {

    }

    public override void afterInsert() {

    }

    public override void afterUpdate() {
        IntegrationMessageTriggerFunctions.processMessageResponses(newMap.keySet());
    }

    public override void afterDelete() {

    }

}
