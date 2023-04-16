// https://cargurus.atlassian.net/browse/CRM-5092
// https://cargurus.atlassian.net/browse/CRM-5021
// https://cargurus.atlassian.net/browse/BR-884
public class CPQ_Subscription_TriggerHandler extends TriggerHandler {
    
    private List<SBQQ__Subscription__c> newList;
    private Map<ID,SBQQ__Subscription__c> newMap;
    private List<SBQQ__Subscription__c> oldList;
    private Map<ID,SBQQ__Subscription__c> oldMap;

    public CPQ_Subscription_TriggerHandler() {
        this.newList= (List<SBQQ__Subscription__c>) Trigger.new;
        this.newMap = (Map<Id,SBQQ__Subscription__c>) Trigger.newMap;
        this.oldList = (List<SBQQ__Subscription__c>) Trigger.old;
        this.oldMap = (Map<Id,SBQQ__Subscription__c>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        CPQ_Subscription_TriggerFunctions.initialSetup(newList);
    }

    public override void beforeUpdate() {
        CPQ_Subscription_TriggerFunctions.setProvisioningStatusOnMismatch(newList); //BR-1452
        CPQ_Subscription_TriggerFunctions.validateChangeOnBillingAccount(oldMap,newList); //BR-3733
    }

    public override void afterInsert() {
        //CPQ_Subscription_TriggerFunctions.updateAccountType(newList,null); //commented for BR-7299
        CG_CPQSubscriptionHelper.processAccountFeatureUpdates(newList, oldMap); // CRM-5021
        CPQ_Subscription_TriggerFunctions.evaluateCancellingBundles(oldMap, newMap);
        CPQ_Subscription_TriggerFunctions.aggregateNetPrice(newList);
    }
  
    public override void afterUpdate() {
        CPQ_Subscription_TriggerFunctions.updateAccountType(newList, oldMap);
        CG_CPQSubscriptionHelper.processAccountFeatureUpdates(newList, oldMap); // CRM-5021
        CPQ_Subscription_TriggerFunctions.processPHIntegrationUpdates(newList, oldMap);
        CPQ_Subscription_TriggerFunctions.setOrdersPending(newList); // BR-3884
        CPQ_Subscription_TriggerFunctions.changeOwnerSendCollectionsApproval(oldMap,newList); // BR-3733
        CPQ_Subscription_TriggerFunctions.changeZuoraOwner(oldMap,newList); //BR-3733
        CPQ_Subscription_TriggerFunctions.updateBillingAccountOnChildSubs(oldMap,newList); //BR-3733
        CPQ_Subscription_TriggerFunctions.aggregateNetPrice(newList);
    }

}