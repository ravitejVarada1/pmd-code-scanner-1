/**
 * https://cargurus.atlassian.net/browse/CRM-5021
 * 
 * Feature Framework Test Data
 */
@isTest
public class CG_FeatureFramework_TestData {

    // CRM-5021
    public static List<CG_Feature__c> createCGFeature(Integer qty) {
        List<CG_Feature__c> returnList = new List<CG_Feature__c>();
        
        for (Integer i = 0; i < qty; i++) {
            returnList.add(new CG_Feature__c(CG_Feature_Id__c=i,Active__c=true));
        }
        
        return returnList;
    }

    // CRM-5021
    public static CG_Feature_Metadata__c createFeatureMetadata(Id featureId, String type, String key, String value,
        Boolean overrideable) {
        
        return createFeatureMetadata(featureId, null, null, null, type, key, value, overrideable);
    }

    // CRM-5021
    public static CG_Feature_Metadata__c createFeatureMetadata(Id featureId, String sourceObject, String sourceField,
        Decimal sourceFieldMultiplier, String type, String key, String value, Boolean overrideable) {

        return new CG_Feature_Metadata__c(
            CG_Feature__c = featureId,
            Source_Object__c = sourceObject,
            Source_Field__c = sourceField,
            Source_Field_Multiplier__c = sourceFieldMultiplier,
            Type__c = type,
            Key__c = key,
            Value__c = value,
            Overrideable__c = overrideable,
            Country__c = 'US;CA;GB'
        );
    }

    // CRM-5021
    public static CG_Product_Feature__c createProductFeature(Id productId, Id featureId) {
        return new CG_Product_Feature__c(
            Product__c = productId,
            CG_Feature__c = featureId,
            Country__c = 'US;CA;GB'
        );
    }

    // CRM-5021
    public static CG_Status_Feature__c createStatusFeature(Id featureId, String salesStatus) {
        return new CG_Status_Feature__c(
            CG_Feature__c = featureId,
            Product_Activation_Status__c = salesStatus,
            Country__c = 'US;CA;GB'
        );
    }

    // CRM-5021
    public static CG_Account_Feature__c createFeatureStatusOverride(Id featureId, Id accountId, String status) {
        return new CG_Account_Feature__c(
            CG_Feature__c = featureId,
            Account__c = accountId,
            Status_Override__c = true,
            Status__c = status
        );
    }

    //CRM-5021
    public static CG_Account_Feature__c createFeatureMetadataOverride(Id featureId, Id accountId, Map<String, Object> metadata) {
        return new CG_Account_Feature__c(
            CG_Feature__c = featureId,
            Account__c = accountId,
            Metadata_Override__c = true,
            Metadata__c = JSON.serialize(metadata)
        );
    }

}
