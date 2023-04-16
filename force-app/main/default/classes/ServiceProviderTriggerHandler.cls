/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        03/11/2021
* modified:       03/11/2021
* created jira:   BR-367 & BR-368
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class ServiceProviderTriggerHandler extends TriggerHandler {
    private List<Service_Provider__c> newSpList;
    private Map<ID,Service_Provider__c> newSpMap;
    private List<Service_Provider__c> oldSpList;
    private Map<ID,Service_Provider__c> oldSpMap;

    public ServiceProviderTriggerHandler(){
        this.newSpList = (List<Service_Provider__c>) Trigger.new;
        this.newSpMap  = (Map<Id,Service_Provider__c>) Trigger.newMap;
        this.oldSpList = (List<Service_Provider__c>) Trigger.old;
        this.oldSpMap  = (Map<Id,Service_Provider__c>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        ServiceProviderTriggerFunctions.createDealerAccount(newSpList);
        ServiceProviderTriggerFunctions.updateUltimateParentRef(newSpList, null);
    }

    public override void beforeUpdate() {
        ServiceProviderTriggerFunctions.updateUltimateParentRef(newSpList, oldSpMap);
    }

    public override void afterInsert() {
        ServiceProviderTriggerFunctions.checkAccountFieldsInsAndDel(newSpList);
        CG_ServiceProviderHelper.processServiceProviderUpdates(newSpList, oldSpMap);    //CRM-4123
    }

    public override void afterUpdate() {
        ServiceProviderTriggerFunctions.checkAccountFieldsUpdate(newSpList, oldSpMap);
        CG_ServiceProviderHelper.processServiceProviderUpdates(newSpList, oldSpMap);    //CRM-4123
        ServiceProviderTriggerFunctions.checkSPDenyUndenyScenarios(newSpList, oldSpMap);//SA-255
    }
    
    public override void afterDelete(){
        ServiceProviderTriggerFunctions.checkAccountFieldsInsAndDel(oldSpList);
    }
    
    public override void afterUndelete(){
        ServiceProviderTriggerFunctions.checkAccountFieldsInsAndDel(newSpList);
    }
    
}