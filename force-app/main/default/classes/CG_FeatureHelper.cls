// https://cargurus.atlassian.net/browse/CRM-5021
// helper methods to deal cg feature data
// test coverage in CG_FeatureFramework_Test
public without sharing class CG_FeatureHelper {

    public static final Set<String> FEATURE_COUNTRIES = new Set<String>{'US','CA','GB'};
    public static final String FEATURE_STATUS_ACTIVE = 'A';
    public static final String FEATURE_STATUS_INACTIVE = 'I';
    
    // map of feature records by salesforce id, including related feature metadata, lazy load with get method
    static Map<Id,CG_Feature__c> featureSFIdMap;
    
    // query for all active features and setup a map of sf record id to feature record, including related metadata setup
    public static Map<Id,CG_Feature__c> getFeatureSFIdMap() {
        if (featureSFIdMap == null) {
            featureSFIdMap = new Map<Id,CG_Feature__c>(
                [SELECT Id, Name, CG_Feature_Id__c,
                    (SELECT Id, CG_Feature__c, Country__c, Key__c, Overrideable__c, Product_Activation_Status__c, 
                    Source_Field__c, Source_Field_Multiplier__c, Source_Object__c, Type__c, Value__c 
                    FROM CG_Feature_Metadata__r) 
                FROM CG_Feature__c WHERE Active__c = true]
            );
        }
        return featureSFIdMap;
    }

    // map of feature records by cg feature id, lazy load with get method
    static Map<Integer,Id> featureCGIdSFIdMap;

    public static Map<Integer,Id> getFeatureCGIdSFIdMap() {
        if (featureCGIdSFIdMap == null) {
            featureCGIdSFIdMap = new Map<Integer,Id>();
            for (CG_Feature__c cgf : getFeatureSFIdMap().values()) {
                featureCGIdSFIdMap.put((Integer)cgf.CG_Feature_Id__c, cgf.Id);
            }
        }
        return featureCGIdSFIdMap;
    }

    // map of sets of feature ids by product id and country, lazy load with get method
    static Map<String,Map<Id,Set<Id>>> productFeatureIdsCountryMap;
    
    public static Map<String,Map<Id,Set<Id>>> getProductFeatureIdsCountryMap() {
        if (productFeatureIdsCountryMap == null) {
            productFeatureIdsCountryMap = new Map<String,Map<Id,Set<Id>>>();

            for (CG_Product_Feature__c pf : [SELECT Id, Product__c, Country__c,
                    CG_Feature__c, CG_Feature__r.CG_Feature_Id__c FROM CG_Product_Feature__c]) {
                
                Id productId = pf.Product__c;
                Id featureId = pf.CG_Feature__c;

                for (String countryCode : pf.Country__c.split(';')) {
                    if (!productFeatureIdsCountryMap.containsKey(countryCode)) {
                        productFeatureIdsCountryMap.put(countryCode, new Map<Id,Set<Id>>());
                    }
                    Map<Id,Set<Id>> productFeatureIdsMap = productFeatureIdsCountryMap.get(countryCode);

                    if (!productFeatureIdsMap.containsKey(productId)) {
                        productFeatureIdsMap.put(productId, new Set<Id>());
                    }
                    productFeatureIdsMap.get(productId).add(featureId);
                }
            }
        }
        return productFeatureIdsCountryMap;
    }

    // return map of sf feature ids by product id for supplied country
    public static Map<Id,Set<Id>> getProductFeatureIdsMapByCountry(String countryCode) {
        if (!getProductFeatureIdsCountryMap().containsKey(countryCode)) {
            return new Map<Id,Set<Id>>();
        }
        return getProductFeatureIdsCountryMap().get(countryCode);
    }

    // map of product activation status features by status and country, lazy load with get method
    static Map<String,Map<String,Set<Id>>> statusFeatureIdsCountryMap;

    public static Map<String,Map<String,Set<Id>>> getStatusFeatureIdsCountryMap() {
        if (statusFeatureIdsCountryMap == null) {
            statusFeatureIdsCountryMap = new Map<String,Map<String,Set<Id>>>();

            for (CG_Status_Feature__c cgsf : [SELECT Id, Product_Activation_Status__c, CG_Feature__c, Country__c
                    FROM CG_Status_Feature__c]) {
                
                String productActivationStatus = cgsf.Product_Activation_Status__c;

                for (String countryCode : cgsf.Country__c.split(';')) {
                    if (!statusFeatureIdsCountryMap.containsKey(countryCode)) {
                        statusFeatureIdsCountryMap.put(countryCode, new Map<String,Set<Id>>());
                    }
                    Map<String,Set<Id>> statusFeaturesMap = statusFeatureIdsCountryMap.get(countryCode);

                    if (!statusFeaturesMap.containsKey(productActivationStatus)) {
                        statusFeaturesMap.put(productActivationStatus, new Set<Id>());
                    }
                    statusFeaturesMap.get(productActivationStatus).add(cgsf.CG_Feature__c);
                }
            }
        }
        return statusFeatureIdsCountryMap;
    }

    // return map of sf feature ids by product activation status for supplied country
    public static Map<String,Set<Id>> getStatusFeatureIdsMapByCountry(String countryCode) {
        if (!getStatusFeatureIdsCountryMap().containsKey(countryCode)) {
            return new Map<String,Set<Id>>();
        }
        return getStatusFeatureIdsCountryMap().get(countryCode);
    }

    // return list of feature metadata records for supplied cg feature, country, and product activation status
    public static List<CG_Feature_Metadata__c> getFeatureMetadata(Id sfFeatureId, String countryCode, 
            String productActivationStatus) {

        List<CG_Feature_Metadata__c> returnList = new List<CG_Feature_Metadata__c>();

        for (CG_Feature_Metadata__c cgfm : getFeatureSFIdMap().get(sfFeatureId).CG_Feature_Metadata__r) {
            if (cgfm.Country__c.split(';').contains(countryCode) && cgfm.Product_Activation_Status__c == productActivationStatus) {
                returnList.add(cgfm);
            }
        }

        return returnList;
    }

    // override to get feature metadata for null product activation status, which applies to active contract
    public static List<CG_Feature_Metadata__c> getFeatureMetadata(Id sfFeatureId, String countryCode) {
        return getFeatureMetadata(sfFeatureId, countryCode, null);
    }

    // map of country code to cg region, lazy load with get method
    static Map<String,String> countryRegionMap;

    public static Map<String,String> getCountryRegionMap() {
        if (countryRegionMap == null) {
            countryRegionMap = new Map<String,String>();
            for (CG_Country_Region_Settings__mdt cgcrs : CG_Country_Region_Settings__mdt.getAll().values()) {
                countryRegionMap.put(cgcrs.DeveloperName, cgcrs.Region_Code__c);
            }
        }
        return countryRegionMap;
    }

}