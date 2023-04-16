// https://cargurus.atlassian.net/browse/CRM-4804
// helper methods to deal with account to feature data
// test coverage in CG_FeatureFramework_Test
public class CG_AccountFeatureMapHelper {

    static final Set<String> SP_ALLOWREVIEWSTATUS = CG_FeatureIntegrationHelper.SP_ALLOWREVIEWSTATUS;
    static final String SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE;
    static final String SUBSCRIPTION_PROVISIONINGSTATUS_PENDING = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_PENDING;
    static final Set<String> SUBSCRIPTION_QUERY_STATUSES = 
        new Set<String>{
            SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE,
            ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_INACTIVE,
            ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_DELINQUENT
        };
    static final String FEATURE_STATUS_ACTIVE = CG_FeatureHelper.FEATURE_STATUS_ACTIVE;
    static final String FEATURE_STATUS_INACTIVE = CG_FeatureHelper.FEATURE_STATUS_INACTIVE;
    static final String PRODUCTACTIVATIONSTATUS_ACTIVE = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE;
    static final Set<String> NUMERIC_TYPES = new Set<String>{'Integer','Decimal'};

    // set up strings to match options in metadata source object picklist
    public static final String METADATA_SOURCE_OBJECT_ACCOUNT = 'Account';
    public static final String METADATA_SOURCE_OBJECT_CPQSUB = 'CPQ Subscription';
    
    // set up map of fields to query on account and cpq subscription, to be augmented with configured source fields
    public static Map<String,Set<String>> queryFieldsMap = new Map<String,Set<String>>{
        METADATA_SOURCE_OBJECT_ACCOUNT => 
            new Set<String>{
                'Id',
                'Name',
                'BillingCountryCode',
                'Product_Activation_Status__c',
                'Listings_CMRR_Without_Cancellations__c',
                'Restricted_Cap_editable__c'
            },
        METADATA_SOURCE_OBJECT_CPQSUB => 
            new Set<String>{
                'Id',
                'Provisioning_Status__c',
                'SBQQ__Product__c',
                'SBQQ__ProductName__c',
                'SBQQ__Quantity__c',
                'SBQQ__StartDate__c',
                'SBQQ__EndDate__c',
                'SBQQ__NetPrice__c'
            }
    };

    // add account and cpq sub query fields needed for metadata calculations
    static {
        for (CG_Feature_Metadata__c cgFM : [SELECT Id, Source_Object__c, Source_Field__c 
                FROM CG_Feature_Metadata__c WHERE Source_Object__c != null]) {
            
            queryFieldsMap.get(cgFM.Source_Object__c).add(cgFM.Source_Field__c);
        }
    }

    // for provided single account id, generate and return map of account features
    public static CG_AccountFeatureMap generateAccountFeaturesInstance(Id accountId) {
        Map<Id,Account> accountMap = getAccountFeatureCPQSubMap(new Set<Id>{accountId});

        if (accountMap.isEmpty()) {
            return null;
        }

        return new CG_AccountFeatureMap(accountMap.values()[0]);
    }

    // for provided account ids, generate map of account features by account id
    public static Map<Id,CG_AccountFeatureMap> generateAccountFeaturesMap(Set<Id> accountIds) {
        Map<Id,CG_AccountFeatureMap> accountFeatureMap = new Map<Id,CG_AccountFeatureMap>();

        for (Account a : getAccountFeatureCPQSubMap(accountIds).values()) {
            accountFeatureMap.put(a.Id, new CG_AccountFeatureMap(a));
        }

        return accountFeatureMap;
    }

    // query accounts with all data needed to generate current feature list
    public static Map<Id,Account> getAccountFeatureCPQSubMap(Set<Id> accountIds) {
        List<String> accountQueryFields = new List<String>(queryFieldsMap.get(METADATA_SOURCE_OBJECT_ACCOUNT));
        List<String> cpqSubQueryFields = new List<String>(queryFieldsMap.get(METADATA_SOURCE_OBJECT_CPQSUB));

        String query = 'SELECT '+String.join(accountQueryFields, ', ')+', '+
            '(SELECT Id, Name, Service_Provider_Id__c FROM Service_Provider__r '+
                'WHERE reviewStatus__c IN :SP_ALLOWREVIEWSTATUS AND Can_host_inventory__c = \'Yes\'), '+
            '(SELECT Id, Account__c , CG_Feature__c, Status__c, Status_Override__c, Metadata__c, Metadata_Override__c '+
                'FROM CG_Account_Features__r), '+
            '(SELECT '+String.join(cpqSubQueryFields, ', ')+' FROM CPQ_Subscriptions_Fulfillment__r '+
                'WHERE (Provisioning_Status__c IN :SUBSCRIPTION_QUERY_STATUSES AND SBQQ__Quantity__c > 0) '+
                'OR ( SBQQ__Product__r.Pending_Activation_Generate_Metadata__c = true AND Provisioning_Status__c = :SUBSCRIPTION_PROVISIONINGSTATUS_PENDING AND SBQQ__Quantity__c > 0 ) '+
                'ORDER BY Provisioning_Status__c ASC, SBQQ__NetPrice__c DESC) '+ // status desc because it goes by picklist order
            'FROM Account WHERE Id IN :accountIds';                 // and we need active to sort before pending                 

        return new Map<Id,Account>((List<Account>)Database.query(query));
    }

    // gets a map of features specific to the passed account and cpq sub
    public static Map<Integer,CG_AccountFeature> getAccountFeaturesForCPQSubMap(Account a, 
            SBQQ__Subscription__c cpqSub, Set<Integer> existingCGFeatureIds) {
        
        Map<Integer,CG_AccountFeature> afReturnMap = new Map<Integer,CG_AccountFeature>();
                
        // get a map of all features by product id applicable to the current account country
        Map<Id,Set<Id>> productFeatureIdsMap = CG_FeatureHelper.getProductFeatureIdsMapByCountry(a.BillingCountryCode);
        Id productId = cpqSub.SBQQ__Product__c;

        // if the current cpq sub product has no features for the account country, return an empty map
        if (!productFeatureIdsMap.containsKey(productId)) {
            return afReturnMap;
        }

        // set up account id, and feature status based on a) whether the account is paying, and b) cpq sub status
        // ***************** will have to fix CPQ Sub query to use Status when available
        Id accountId = a.Id;
        String statusString = (a.Product_Activation_Status__c == PRODUCTACTIVATIONSTATUS_ACTIVE 
        && cpqSub.Provisioning_Status__c == SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE) ? 
        FEATURE_STATUS_ACTIVE : FEATURE_STATUS_INACTIVE;

        // fo through all of the features related to the cpq sub product
        for (Id sfFeatureId : productFeatureIdsMap.get(productId)) {
            CG_AccountFeature cgaf = new CG_AccountFeature(sfFeatureId, a, statusString);
            Integer cgFeatureId = cgaf.cgFeatureId;
            
            // only add to map if it doesn't already contain it, so as not to overwrite valid metadata
            if (!existingCGFeatureIds.contains(cgFeatureId)) {
                cgaf.setFeatureMetadataString(generateFeatureMetadataString(sfFeatureId, a, cpqSub));
                afReturnMap.put(cgFeatureId, cgaf);    
            }
        }

        return afReturnMap;
    }

    // get map of cg feature id to account feature for supplied account id, status, and country
    public static Map<Integer,CG_AccountFeature> getAccountFeatureForStatusMap(Account a) {
        Map<Integer,CG_AccountFeature> afReturnMap = new Map<Integer,CG_AccountFeature>();

        // get a map of all features by product activation status for the current account country
        Map<String,Set<Id>> statusFeatureIdsMap = 
            CG_FeatureHelper.getStatusFeatureIdsMapByCountry(a.BillingCountryCode);
        
        String productActivationStatus = a.Product_Activation_Status__c;

        // if the account product activation status has related features, set them up in the return map as active
        if (statusFeatureIdsMap.containsKey(productActivationStatus)) {
            for (Id sfFeatureId : statusFeatureIdsMap.get(productActivationStatus)) {
                CG_AccountFeature cgaf = new CG_AccountFeature(sfFeatureId, a, FEATURE_STATUS_ACTIVE);
                afReturnMap.put(cgaf.cgFeatureId, cgaf);
            }
        }

        return afReturnMap;
    }

    // generates a feature metadata string for the supplied feature and account, where no cpq sub exists
    public static String generateFeatureMetadataString(Id sfFeatureId, Account a) {
        return generateFeatureMetadataString(sfFeatureId, a, null);
    }

    // generates a feature metadata string for the supplied feature, account, and cpq sub (if it exists)
    public static String generateFeatureMetadataString(Id sfFeatureId, Account a, SBQQ__Subscription__c cpqSub) {
        
        List<CG_Feature_Metadata__c> featureMetadataList = new List<CG_Feature_Metadata__c>();

        String countryCode = a.BillingCountryCode;
        String productActivationStatus = a.Product_Activation_Status__c;

        // if the product activation status is anything other than paying, get the status-related metadata
        if (productActivationStatus != PRODUCTACTIVATIONSTATUS_ACTIVE) {
            featureMetadataList = CG_FeatureHelper.getFeatureMetadata(sfFeatureId, countryCode, productActivationStatus);
        }

        // if product activation status = active, or pending cpq sub and no status metadata, get cpq sub metadata
        if (productActivationStatus == PRODUCTACTIVATIONSTATUS_ACTIVE 
                || (featureMetadataList.isEmpty() && cpqSub != null)) {
            
            featureMetadataList = CG_FeatureHelper.getFeatureMetadata(sfFeatureId, countryCode);
        }

        System.debug('featureMetadataList: '+featureMetadataList);

        // if there is no metadata to process, return null string
        if (featureMetadataList.isEmpty()) {
            return null;
        }

        Map<String,String> metadataMap = new Map<String,String>();

        // populate metadata map with each element with a non-blank value
        for (CG_Feature_Metadata__c cgfm : featureMetadataList) {

            // based on metadata setup, derive from default, account / cpq sub field, configured multiplier
            String mdString = processMetadata(cgfm, a, cpqSub);
            
            if (!String.isBlank(mdString)) {
                metadataMap.put(cgfm.Key__c, mdString);
            }
        }

        // if the resulting map is empty, return null string
        if (metadataMap.isEmpty()) {
            return null;
        }

        // serialize metadata map into a formatted string and return
        String metadataString = JSON.serializePretty(metadataMap);
        System.debug('metadataString: '+metadataString);

        return metadataString;
    }

    // based on metadata setup, get value based on default, account / cpq sub field, and configured multiplier
    private static String processMetadata(CG_Feature_Metadata__c cgfm, Account a, SBQQ__Subscription__c cpqSub) {
        
        String mdType = cgfm.Type__c;
        String sourceObject = cgfm.Source_Object__c;
        String defaultValue = cgfm.Value__c;
        
        // if a numeric value drawn from source object...
        if (NUMERIC_TYPES.contains(mdType) && sourceObject != null) {
            Decimal numberValue;
            
            // check source object (account or cpq sub) for source field value
            if (sourceObject == METADATA_SOURCE_OBJECT_ACCOUNT) {
                numberValue = (Decimal)a.get(cgfm.Source_Field__c);
            }
            else if (sourceObject == METADATA_SOURCE_OBJECT_CPQSUB && cpqSub != null) {
                numberValue = (Decimal)cpqSub.get(cgfm.Source_Field__c);
            }

            // if source field is null, return default value
            if (numberValue == null) {
                return defaultValue;
            }

            // if source field contains a value, multiply it by the source field multiplier (if configured)
            Decimal sourceMultiplier = cgfm.Source_Field_Multiplier__c;

            if (sourceMultiplier != null) {
                numberValue *= sourceMultiplier;
            }

            // return the number formatted as either an integer or decimal string, based on configured type
            return String.valueOf(mdType == 'Integer' ? numberValue.intValue() : numberValue);

        } // if this is a non-numeric value pulled from the account, fetch the source field value
        else if (sourceObject == METADATA_SOURCE_OBJECT_ACCOUNT && a.get(cgfm.Source_Field__c) != null) {

            // format as a date if that is the configured type
            if (mdType == 'Date') {
                return String.valueOf((Date)a.get(cgfm.Source_Field__c));
            }
            return String.valueOf(a.get(cgfm.Source_Field__c));

        } // if this is a non-numeric value pulled from the cpq subscription, fetch the source field value
        else if (sourceObject == METADATA_SOURCE_OBJECT_CPQSUB && cpqSub?.get(cgfm.Source_Field__c) != null) {
            
            // format as a date if that is the configured type
            if (mdType == 'Date') {
                return String.valueOf((Date)cpqSub.get(cgfm.Source_Field__c));
            }
            return String.valueOf(cpqSub.get(cgfm.Source_Field__c));
        }

        // if this value is not derived from a source object, return the default value
        return defaultValue;
    }

}