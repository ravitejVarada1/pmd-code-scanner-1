public class ZuoraSubChargeTriggerHandler extends TriggerHandler {
    
    private List<Zuora__SubscriptionProductCharge__c> newList;
    private Map<Id,Zuora__SubscriptionProductCharge__c> newMap;
    private List<Zuora__SubscriptionProductCharge__c> oldList;
    private Map<Id,Zuora__SubscriptionProductCharge__c> oldMap;

    public ZuoraSubChargeTriggerHandler() {
        this.newList= (List<Zuora__SubscriptionProductCharge__c>) Trigger.new;
        this.newMap = (Map<Id,Zuora__SubscriptionProductCharge__c>) Trigger.newMap;
        this.oldList = (List<Zuora__SubscriptionProductCharge__c>) Trigger.old;
        this.oldMap = (Map<Id,Zuora__SubscriptionProductCharge__c>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        
    }

    public override void beforeUpdate() {
        
    }

    public override void beforeDelete() {

    }

    public override void afterInsert() {
        ZuoraSubChargeTriggerFunctions.relateToCpqRecords(newMap.keySet()); // BR-1144
    }

    public override void afterUpdate() {
        ZuoraSubChargeTriggerFunctions.relateToCpqRecords(newMap.keySet()); // BR-1144
    }

    public override void afterDelete() {

    }

}
