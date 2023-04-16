// https://cargurus.atlassian.net/browse/CRM-5021
// handles account postsave trigger related to cg feature framework
// test coverage in CG_FeatureFramework_Test
public without sharing class CG_AccountHelper {

    private static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;
    
    // if any of these fields change value, the related account feature maps should be regenerated and sent to cg
    private static final Set<String> ACCOUNTCHECKCHANGEFIELDS = 
        CG_AccountFeatureMapHelper.queryFieldsMap.get(CG_AccountFeatureMapHelper.METADATA_SOURCE_OBJECT_ACCOUNT);

    // determine which accounts should have feature maps generated and sent to cg
    public static void processAccountFeatureUpdates(List<Account> accountList, Map<Id,Account> oldAccountMap) {

        // if switch is off for feature updates driven by account, skip
        if (!INTEGRATION_CONTROLS.Feature_Update_from_Account_Changes__c) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();

        for (Account a : accountList) {
            Id accountId = a.Id;

            // no need to do this for newly inserted accounts, only updates where a relevant field changes
            if (oldAccountMap != null && accountFieldChanged(a, oldAccountMap.get(accountId))) {
                accountIds.add(accountId);
            }
        }

        if (!accountIds.isEmpty()) {
            CG_AccountFeatureMessageHelper.generateAccountFeatureMessages(accountIds, true);
        }
    }

    // check if any relevant fields have changed for the supplied new / old version of the account
    private static Boolean accountFieldChanged(Account newAccount, Account oldAccount) {
        for (String fieldName : ACCOUNTCHECKCHANGEFIELDS) {
            if (newAccount.get(fieldName) != oldAccount.get(fieldName)) {
                return true;
            }
        }
        return false;
    }

}