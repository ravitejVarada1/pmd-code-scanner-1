// https://cargurus.atlassian.net/browse/CRM-5092
// https://cargurus.atlassian.net/browse/CRM-5021
public class CG_Account_Feature_TriggerHandler extends TriggerHandler {
    
    private List<CG_Account_Feature__c> newList;
    private Map<ID,CG_Account_Feature__c> newMap;
    private List<CG_Account_Feature__c> oldList;
    private Map<ID,CG_Account_Feature__c> oldMap;

    public CG_Account_Feature_TriggerHandler() {
        this.newList= (List<CG_Account_Feature__c>) Trigger.new;
        this.newMap = (Map<Id,CG_Account_Feature__c>) Trigger.newMap;
        this.oldList = (List<CG_Account_Feature__c>) Trigger.old;
        this.oldMap = (Map<Id,CG_Account_Feature__c>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        CG_Account_Feature_TriggerFunctions.setCGAccountFeatureUniqueIds(newList);
    }

    public override void beforeUpdate() {
        CG_Account_Feature_TriggerFunctions.setCGAccountFeatureUniqueIds(newList);
    }

}