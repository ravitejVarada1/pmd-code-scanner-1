// https://cargurus.atlassian.net/browse/CRM-5021
// https://cargurus.atlassian.net/browse/CRM-5093
// test coverage in CG_FeatureSetup_Test
// schedule daily 2am:
// System.schedule('Schedule CG_Batch_UpdateAccountMetadataFields', '0 0 2 ? * 1,2,3,4,5,6,7', new CG_Batch_UpdateAccountMetadataFields());
public class CG_Batch_UpdateAccountMetadataFields implements Database.Batchable<sObject>, Schedulable {

    Set<Id> accountIds;
    String query;

    static final Set<String> FEATURE_COUNTRIES = CG_FeatureHelper.FEATURE_COUNTRIES;

    // schedulable execute method
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new CG_Batch_UpdateAccountMetadataFields(), 20);
    }

    // currently the only metadata source field needing periodic update is the account restricted cap
    // can expand in future if new metadata source fields need scheduled updates
    public CG_Batch_UpdateAccountMetadataFields() {
        this.query = 'SELECT Id FROM Account '+
            'WHERE BillingCountryCode IN :FEATURE_COUNTRIES AND Restricted_Cap__c != null '+
            'AND (Lead_Cap_Update_Date__c = TODAY OR Restricted_Cap_editable__c = null)';
    }

    // constructor to run on supplied account ids
    public CG_Batch_UpdateAccountMetadataFields(Set<Id> accountIds) {
        this.accountIds = accountIds;
        this.query = 'SELECT Id FROM Account WHERE Id IN :accountIds';
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Account> accountList) {
        List<Account> updateAccounts = new List<Account>();

        // requery for relevant account data
        for (Account a : [SELECT Id, Restricted_Cap__c, Restricted_Cap_editable__c 
                FROM Account WHERE Id IN : accountList]) {

            Decimal restrictedCap = a.Restricted_Cap__c;
            
            // check if restricted cap needs updating, and if so update and add to update list
            if (a.Restricted_Cap_editable__c != restrictedCap) {
                a.Restricted_Cap_editable__c = restrictedCap;
                updateAccounts.add(a);
            }
        }

        if (updateAccounts.isEmpty()) {
            return;
        }

        try {
            update updateAccounts;
        } catch (Exception e) {
            System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
            throw e;
        }
    }

    public void finish(Database.BatchableContext bc) {}

}