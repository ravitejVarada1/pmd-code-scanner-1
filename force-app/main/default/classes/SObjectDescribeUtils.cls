/**
 * Utility class provides describe services for SObject fields, record types, etc
 * 
 */

public without sharing class SObjectDescribeUtils {
    
    private static List<String> types = new List<String>{
        'Account', 'Case', 'Opportunity', 'Survey_Results__c','SBQQ__Quote__c'
    };

    private static Map<String, Schema.DescribeSobjectResult> descResultsMap = new Map<String, Schema.DescribeSobjectResult>();

    static {
        Schema.DescribeSobjectResult[] results = Schema.describeSObjects(types);
        for(Schema.DescribeSobjectResult res : results) {
            descResultsMap.put(res.getLabel(), res);
        }
    }
    
    public static Id getRecordTypeIdByName(String sobjLabel, String rtName) {
        if(descResultsMap.containsKey(sobjLabel)) {
            return descResultsMap.get(sobjLabel).getRecordTypeInfosByName().get(rtName).getRecordTypeId();
        }
        return null;
    }

    public static Id getRecordTypeIdByDevName(String sobjLabel, String rtDevName) {
        if(descResultsMap.containsKey(sobjLabel)) {
            return descResultsMap.get(sobjLabel).getRecordTypeInfosByDeveloperName().get(rtDevName).getRecordTypeId();
        }
        return null;
    }

    //SA-1495 - KS - Added to get picklist values by field dev name. Call this method and iterate through the returned list to get the label, value, etc.
    public static List<Schema.PicklistEntry> getPicklistValuesByField(String sobjLabel, String fieldName) {
        if(descResultsMap.containsKey(sobjLabel)) {
            Map<String,Schema.SObjectField> fields = descResultsMap.get(sobjLabel).fields.getMap();
            Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
            return fieldResult.getPicklistValues();
        }
        return null;
    }
}