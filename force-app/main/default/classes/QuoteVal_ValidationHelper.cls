public without sharing class QuoteVal_ValidationHelper {

    // maps to capture data from quote validation custom metadata into a usable format
    static final Map<Id,Quote_Validation_Settings_Product__mdt> VALIDATION_PROD_MAP = QuoteVal_ErrorObject.VALIDATION_PROD_MAP;

    // get matching validation product ids for supplied quote lines
    public static Set<Id> getMatchingValidationProductIds(SBQQ__QuoteLine__c quoteLine) {
        return getMatchingValidationProductIds(
            quoteLine.SBQQ__ProductCode__c, 
            quoteLine.Product_Category__c,
            quoteLine.SBQQ__Product__r.Sub_Category__c,
            quoteLine.SBQQ__ProductFamily__c
        );
    }

    // get matching validation product ids for supplied cpq subscriptions
    public static Set<Id> getMatchingValidationProductIds(SBQQ__Subscription__c cpqSub) {
        return getMatchingValidationProductIds(
            cpqSub.Product_Code__c,
            cpqSub.SBQQ__Product__r.Product_Category__c,
            cpqSub.SBQQ__Product__r.Sub_Category__c,
            cpqSub.SBQQ__Product__r.Family
        );
    }

    // get matching validation product ids for supplied parameters
    public static Set<Id> getMatchingValidationProductIds(String prodCode, String category, String subCategory, String family) {

        Set<Id> returnIds = new Set<Id>();
        for (Quote_Validation_Settings_Product__mdt vProd : VALIDATION_PROD_MAP.values()) {
            String vProdCode = vProd.Product_Code__c;
            String vCategory = vProd.Product_Category__c;
            String vSubCategory = vProd.Product_Sub_Category__c;
            String vFamily = vProd.Product_Family__c;

            if ((vProdCode == null || vProdCode == prodCode) &&
                (vSubCategory == null || vSubCategory == subCategory) && 
                (vCategory == null || vCategory == category) &&
                (vFamily == null || vFamily == family)) {
                
                returnIds.add(vProd.Id);
            }
        }

        return returnIds;
    }
}