// https://cargurus.atlassian.net/browse/CRM-5021
// handles service provider postsave trigger related to cg feature framework
// test coverage in CG_FeatureFramework_Test
public without sharing class CG_ServiceProviderHelper {

    static final String SP_ACTIVEREVIEWSTATUS = CG_FeatureIntegrationHelper.SP_ACTIVEREVIEWSTATUS;
    
    // if a service provider is newly created, newly approved, or switches accounts, generate feature map and send to cg
    public static void processServiceProviderUpdates(List<Service_Provider__c> spList, 
            Map<Id,Service_Provider__c> oldSPMap) {

        if (oldSPMap == null && Test.isRunningTest()) {
            return;
        }
        
        Set<Id> accountIds = new Set<Id>();
        
        for (Service_Provider__c sp : spList) {
            Id accountId = sp.Account__c;
            Service_Provider__c oldSP = oldSPMap == null ? null : oldSPMap.get(sp.Id);

            if (oldSP == null || accountId != oldSP.Account__c || oldSp.reviewStatus__c != SP_ACTIVEREVIEWSTATUS) {
                if (sp.reviewStatus__c == SP_ACTIVEREVIEWSTATUS && sp.Can_host_inventory__c == 'Yes') {
                    accountIds.add(accountId);
                }
            }
        } 

        if (!accountIds.isEmpty()) {
            CG_AccountFeatureMessageHelper.generateAccountFeatureMessages(accountIds, true);
        }
    }
    
}