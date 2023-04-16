// object to capture data from quote validation custom metadata into a usable format
// each instance of this class contain information needed to validation a single configured quote error
// static methods serve to compile configuration metadata into constant maps for use in processing

public without sharing class QuoteVal_ErrorObject {

    // instance variables
    public Map<String,Set<Id>> vProdTypeIdMap = new Map<String,Set<Id>>();
    public String vErrorName;
    public String vErrorType;
    public String vErrorMessage;

    // maps to capture data from quote validation custom metadata into a usable format
    public static final Map<Id,Quote_Validation_Settings_Product__mdt> VALIDATION_PROD_MAP = getValidationProductMap();
    public static final Map<String,QuoteVal_ErrorObject> VALIDATION_ERROR_MAP = getValidationErrorMap();

    public static final String VPRODTYPE_SELECTED = 'Selected';
    public static final String VPRODTYPE_REQUIRED = 'Required';
    public static final String VPRODTYPE_EXCLUDED = 'Excluded';

    // instance method to return validation product ids by type (selected, required, excluded)
    public Set<Id> getVProdIdsByType(String vProdType) {
        if (!vProdTypeIdMap.containsKey(vProdType)) {
            return new Set<Id>();
        } else {
            return new Set<Id>(vProdTypeIdMap.get(vProdType));
        }
    }

    // instance method to populate validation product ids by type, used in initialization of instance
    void addVProductIdToType(String vProdType, Id vProdId) {
        if (!vProdTypeIdMap.containsKey(vProdType)) {
            vProdTypeIdMap.put(vProdType, new Set<Id>());
        }
        vProdTypeIdMap.get(vProdType).add(vProdId);
    }

    static Map<Id,Quote_Validation_Settings_Product__mdt> getValidationProductMap() {
        Map<Id,Quote_Validation_Settings_Product__mdt> returnMap = new Map<Id,Quote_Validation_Settings_Product__mdt>();
        for(Quote_Validation_Settings_Product__mdt vProd : Quote_Validation_Settings_Product__mdt.getAll().values()) {
            if(vProd.Active__c) {
                returnMap.put(vProd.Id, vProd);
            }
        }
        return returnMap;
    }

    // static method to set up validation error object instance map constant
    static Map<String,QuoteVal_ErrorObject> getValidationErrorMap() {

        Map<String,QuoteVal_ErrorObject> returnMap = new Map<String,QuoteVal_ErrorObject>();

        // Go through all the quote validation settings to create an instance of this QuoteVal_ErrorObject and add all 
        // the validation product's ids along with the type (Required, Selected, etc)
        for(Quote_Validation_Setting__mdt vSetting : Quote_Validation_Setting__mdt.getAll().values()) {

            Quote_Validation_Settings_Error__mdt vError;

            if(vSetting.Quote_Validation_Error__c != null) {
                vError = Quote_Validation_Settings_Error__mdt.getInstance(vSetting.Quote_Validation_Error__c);
            }

            if(!vSetting.Active__c || !vError.Active__c || vSetting.Quote_Validation_Error__c == null) {
                continue;
            }

            String vErrorName = vError.DeveloperName;
            String vErrorType = vError.Type__c;

            Id vProdId = vSetting.Product__c;
            String vProdType = vSetting.Product_Type__c == null ? VPRODTYPE_SELECTED : vSetting.Product_Type__c;

            if(!returnMap.keySet().contains(vErrorName)) {
                returnMap.put(vErrorName, createQValErrorObj(vErrorName, vErrorType, vError.Error_Message__c));
            }

            returnMap.get(vErrorName).addVProductIdToType(vProdType, vProdId);
        }

        // Go through all the quote validation settings errors to ensure all the errors have been added. 
        // There are errors without any settings therefore the above loop will not catch them all.
        for(Quote_Validation_Settings_Error__mdt vError : Quote_Validation_Settings_Error__mdt.getAll().values()) {

            String vErrorName = vError.DeveloperName;
            String vErrorType = vError.Type__c;

            if(vError.Active__c && !returnMap.keySet().contains(vErrorName)) {
                returnMap.put(vErrorName, createQValErrorObj(vErrorName, vErrorType, vError.Error_Message__c));
            }
        }

        System.debug('Returning map from getValidationErrorMap : '+returnMap);
        return returnMap;
    }

    private static QuoteVal_ErrorObject createQValErrorObj(String vErrorName, String vErrorType, String vErrorMsg) {
        QuoteVal_ErrorObject errObj = new QuoteVal_ErrorObject();
        errObj.vErrorName = vErrorName;
        errObj.vErrorType = vErrorType;
        errObj.vErrorMessage = vErrorMsg;
        return errObj;
    }
}