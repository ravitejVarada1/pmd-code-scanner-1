// https://cargurus.atlassian.net/browse/CRM-5021
// handles cpq subscription postsave trigger related to cg feature framework
// test coverage in CG_FeatureFramework_Test
public without sharing class CG_CPQSubscriptionHelper {

    private static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;
    
    // if any of these fields change value, the related account feature maps should be regenerated and sent to cg
    private static final Set<String> CPQSUBCHECKCHANGEFIELDS = 
        CG_AccountFeatureMapHelper.queryFieldsMap.get(CG_AccountFeatureMapHelper.METADATA_SOURCE_OBJECT_CPQSUB);

    // determine which accounts should have feature maps generated and sent to cg
    public static void processAccountFeatureUpdates(List<SBQQ__Subscription__c> cpqSubs, 
            Map<Id,SBQQ__Subscription__c> oldCPQSubMap) {

        // if switch is off for feature updates driven by cpq subs skip
        if (!INTEGRATION_CONTROLS.Feature_Update_from_CPQ_Sub_Changes__c) {
            return;
        }
        
        Set<Id> accountIds = new Set<Id>();

        // include both modified and newly inserted cpq subs
        for (SBQQ__Subscription__c cpqSub : cpqSubs) {
            if (oldCPQSubMap == null || cpqSubFieldChanged(cpqSub, oldCPQSubMap.get(cpqSub.Id))) {
                accountIds.add(cpqSub.Fulfillment_Account__c);
            }
        }

        if (!accountIds.isEmpty()) {
            CG_AccountFeatureMessageHelper.generateAccountFeatureMessages(accountIds, true);
        }
    }

    // check if any relevant fields have changed for the supplied new / old version of the cpq subscription
    private static Boolean cpqSubFieldChanged(SBQQ__Subscription__c newCPQSub, SBQQ__Subscription__c oldCPQSub) {
        for (String fieldName : CPQSUBCHECKCHANGEFIELDS) {
            if (newCPQSub.get(fieldName) != oldCPQSub.get(fieldName)) {
                return true;
            }
        }
        return false;
    }

}