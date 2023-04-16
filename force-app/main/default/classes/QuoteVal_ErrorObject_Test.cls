@isTest
private class QuoteVal_ErrorObject_Test {
    @isTest
    static void test1() {
        Map<Id,Quote_Validation_Settings_Product__mdt> metadataMap = new Map<Id,Quote_Validation_Settings_Product__mdt>();
        for(Quote_Validation_Settings_Product__mdt vProd : Quote_Validation_Settings_Product__mdt.getAll().values()) {
            if(vProd.Active__c) {
                metadataMap.put(vProd.Id, vProd);
            }
        }
        System.AssertEquals(metadataMap.size(), QuoteVal_ErrorObject.VALIDATION_PROD_MAP.size());
    }

    @isTest
    static void test2() {
        List<Quote_Validation_Setting__mdt> vSettings = new List<Quote_Validation_Setting__mdt>();

        for(Quote_Validation_Setting__mdt vSetting : Quote_Validation_Setting__mdt.getAll().values()) {
            if(!vSetting.Active__c || vSetting.Quote_Validation_Error__c == null) {
                continue;
            }
            vSettings.add(vSetting);
        }

        Map<String,QuoteVal_ErrorObject> errObject = QuoteVal_ErrorObject.VALIDATION_ERROR_MAP;

        if(vSettings.size() == 0) {
            System.assertEquals(false, errObject.size() == 0);
        } else {
            System.assertEquals(true, errObject.size() > 0);
        }
    }
}