// https://cargurus.atlassian.net/browse/CRM-5092
// https://cargurus.atlassian.net/browse/CRM-5021
// batch process to compare current feature map for accounts to their related service provider feature maps on cg
// actual code to compare and create mismatch records is in the class CG_AccountFeatureComparison
// test coverage in CG_FeatureFramework_Test
// schedule daily 3am:
// System.schedule('Schedule CG_Batch_UpdateAccountMetadataFields', '0 0 3 ? * 1,2,3,4,5,6,7', new CG_Batch_AccountFeatureDiscrepancies());
public class CG_Batch_AccountFeatureDiscrepancies implements Database.Batchable<sObject>, Database.AllowsCallouts, 
        Schedulable {
    
    // by default, empty constructor will set cutoff to past 18 hours
    static final Integer DEFAULT_CUTOFF_HOURS = -18;

    // if cutoff specified, only check accounts with changes to a related cpq sub or account feature override
    public Datetime cutoff; // allow cutoff datetime to be specified
    public String query;    // allow an account query to be specified
    public Set<Id> accountIds;  // allow a set of account ids to be specified
    public Set<String> productActivationStatuses;  // allow included product activation statuses to be specified
    public Integer queryLimit;  // allow query limit to be specified (for testing)

    static final String PRODUCTACTIVATIONSTATUS_ACTIVE = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE;
    //static final String SP_ACTIVEREVIEWSTATUS = CG_FeatureIntegrationHelper.SP_ACTIVEREVIEWSTATUS;
    static final Set<String> SP_ALLOWREVIEWSTATUS = CG_FeatureIntegrationHelper.SP_ALLOWREVIEWSTATUS;
    static final Set<String> FEATURE_COUNTRIES = CG_FeatureHelper.FEATURE_COUNTRIES;

    // schedulable execute method uses defaults
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new CG_Batch_AccountFeatureDiscrepancies(), 20);
    }

    // empty constructor sets default cutoff datetime
    public CG_Batch_AccountFeatureDiscrepancies() {
        this.cutoff = System.now().addHours(DEFAULT_CUTOFF_HOURS);
    }

    // constructor sets supplied number of hours for cutoff datetime
    public CG_Batch_AccountFeatureDiscrepancies(Integer cutoffHours) {
        this.cutoff = System.now().addHours(-cutoffHours);
    }

    // constructor sets account Ids to process
    public CG_Batch_AccountFeatureDiscrepancies(Set<Id> accountIds) {
        this.accountIds = accountIds;
    }

    // constructor takes set of product activation status strings
    public CG_Batch_AccountFeatureDiscrepancies(Set<String> productActivationStatuses) {
        this.productActivationStatuses = productActivationStatuses;
    }

    // constructor takes string for account query
    public CG_Batch_AccountFeatureDiscrepancies(String query) {
        this.query = query;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (query == null) {

            // set up list of query filters - by default limit to feature countries and accounts with active sps
            List<String> queryFilters = new List<String>{
                'BillingCountryCode IN :FEATURE_COUNTRIES',
                'Id IN (SELECT Account__c FROM Service_Provider__c '+
                    'WHERE reviewStatus__c IN :SP_ALLOWREVIEWSTATUS AND Can_host_inventory__c = \'Yes\')'
            };

            // if account ids not supplied, check for supplied product activation status and/or cutoff datetime
            if (accountIds == null) {
                if (productActivationStatuses != null) {   // set up filter on product activation statuses if supplied
                    queryFilters.add('Product_Activation_Status__c IN :productActivationStatuses');
                }
    
                // get account ids with related record changes if cutoff datetime is set
                // we need to query separately for these because this is a related object 'or'
                if (cutoff != null) {
                    String subQuery = 'SELECT Id FROM Account WHERE '+String.join(queryFilters, ' AND ')+' AND Id IN '+
                        '(SELECT Fulfillment_Account__c FROM SBQQ__Subscription__c WHERE LastModifiedDate > :cutoff) '+
                        'LIMIT '+(Limits.getLimitQueryRows()-Limits.getQueryRows());

                    System.debug('subQuery: '+subQuery);

                    // initially set up list as a new set, as if just the map keyset it will be read only (addAll fails)
                    accountIds = new Set<Id>(new Map<Id,Account>((List<Account>)Database.query(subQuery)).keySet());

                    subQuery = 'SELECT Id FROM Account WHERE '+String.join(queryFilters, ' AND ')+' AND Id IN '+
                        '(SELECT Account__c FROM CG_Account_Feature__c WHERE LastModifiedDate > :cutoff) '+
                        'LIMIT '+(Limits.getLimitQueryRows()-Limits.getQueryRows());
                    
                    System.debug('subQuery: '+subQuery);
                    accountIds.addAll(new Map<Id,Account>((List<Account>)Database.query(subQuery)).keySet());
                }
            }

            // set up filter on account ids if supplied or generated from related object queries
            if (accountIds != null) {
                queryFilters.add('Id IN :accountIds');
            }

            // pull all filters into query string
            query = 'SELECT Id FROM Account WHERE '+String.join(queryFilters, ' AND ');
        }

        // if limit supplied, apply to query string
        if (queryLimit != null) {
            query += ' LIMIT '+queryLimit;
        }

        System.debug('query: '+query);

        return Database.getQueryLocator(query);
	}
	
	public void execute(Database.BatchableContext bc, List<Account> accountList) {
        try {
            CG_AccountFeatureComparison.processFeatureComparison(new Map<Id,Account>(accountList).keySet());
		} catch (Exception e) {
			System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
			throw e;
		}
	}
	
    public void finish(Database.BatchableContext bc) {}
    
}