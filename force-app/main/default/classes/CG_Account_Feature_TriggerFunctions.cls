// https://cargurus.atlassian.net/browse/CRM-5092
// https://cargurus.atlassian.net/browse/CRM-5021
public without sharing class CG_Account_Feature_TriggerFunctions {
    
    public static void setCGAccountFeatureUniqueIds(List<CG_Account_Feature__c> cgafList) {
        for (CG_Account_Feature__c cgaf : cgafList) {
            cgaf.Unique_Id__c = cgaf.Account__c+'_'+cgaf.CG_Feature__c;
        }
    }

}