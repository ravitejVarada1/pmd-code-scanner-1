// https://cargurus.atlassian.net/browse/CRM-5092
// https://cargurus.atlassian.net/browse/CRM-5021
public class Zuora_Subscription_TriggerHandler extends TriggerHandler {
    
    private List<Zuora__Subscription__c> newList;
    private Map<ID,Zuora__Subscription__c> newMap;
    private List<Zuora__Subscription__c> oldList;
    private Map<ID,Zuora__Subscription__c> oldMap;

    public Zuora_Subscription_TriggerHandler() {
        this.newList= (List<Zuora__Subscription__c>) Trigger.new;
        this.newMap = (Map<Id,Zuora__Subscription__c>) Trigger.newMap;
        this.oldList = (List<Zuora__Subscription__c>) Trigger.old;
        this.oldMap = (Map<Id,Zuora__Subscription__c>) Trigger.oldMap;
    }

    public override void afterInsert() {
       // Zuora_Subscription_TriggerFunctions.delinquencyTaskEvaluation(newList, null); // BR-1299
    }

    public override void afterUpdate() {
        Zuora_Subscription_TriggerFunctions.delinquencyTaskEvaluation(newList, oldMap); // BR-1299
    }

}