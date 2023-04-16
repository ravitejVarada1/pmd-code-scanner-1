public class ZuoraAccountTriggerHandler extends TriggerHandler {
    private List<Zuora__CustomerAccount__c> newZacList;
    private Map<ID,Zuora__CustomerAccount__c> newZacMap;
    private List<Zuora__CustomerAccount__c> oldZacList;
    private Map<ID,Zuora__CustomerAccount__c> oldZacMap;

    public ZuoraAccountTriggerHandler(){
        this.newZacList = (List<Zuora__CustomerAccount__c>) Trigger.new;
        this.newZacMap  = (Map<Id,Zuora__CustomerAccount__c>) Trigger.newMap;
        this.oldZacList = (List<Zuora__CustomerAccount__c>) Trigger.old;
        this.oldZacMap  = (Map<Id,Zuora__CustomerAccount__c>) Trigger.oldMap;
    }

    public override void afterInsert(){
        ZuoraAccountTriggerFunctions.updateDealerAccount(newZacList);
        ZuoraAccountTriggerFunctions.sendIntegrationMessageForChildren(newZacList, null);
    }

    public override void afterUpdate(){
        ZuoraAccountTriggerFunctions.updateActiveBillingAcc(newZacList, oldZacMap);
        ZuoraAccountTriggerFunctions.sendIntegrationMessageForChildren(newZacList, oldZacMap);
    }
    
}