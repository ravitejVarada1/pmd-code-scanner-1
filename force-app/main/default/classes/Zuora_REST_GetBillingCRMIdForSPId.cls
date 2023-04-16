// https://cargurus.atlassian.net/browse/CRM-3061
// https://cargurus.atlassian.net/browse/CRM-3076
// https://cargurus.atlassian.net/browse/BR-2572
// https://cargurus.atlassian.net/browse/BR-5504
@RestResource(urlMapping='/getZuoraBillingCRMIdForSpId/*')
global class Zuora_REST_GetBillingCRMIdForSPId {

/*
/services/apexrest/getZuoraBillingCRMIdForSpId
{
	"spId": 12345,
	"countryCode" : "US",
    "ignoreZuoraAccountCheck" : true (or) false     //added with BR-5504
}
*/

    @HttpPost
	global static Map<String,String> doPost_getBillingCRMIdForSPId(Integer spId, String countryCode, String ignoreZuoraAccountCheck) {
		return getBillingCRMIdForSPId(spId, countryCode, ignoreZuoraAccountCheck);
	}

    private static Map<String,String> getBillingCRMIdForSPId(Integer spId, String countryCode, String ignoreZuoraAcctCheck) {
        Map<String,String> returnMap = new Map<String,String>{'crmId' => null};

        if (spId == null || countryCode == null) {
            return returnMap;
        }

        String spIdString = String.valueOf(spId);
        //determine if billing account check is necessary
        Boolean ignoreZuoraAccountCheck = ignoreZuoraAcctCheck != null ? Boolean.valueOf(ignoreZuoraAcctCheck) : false;

        List<Account> spAccountList =  [select Id, Billing_Account_Zuora__c from Account where Id in (select Account__c from Service_Provider__c where Service_Provider_Id__c = : spId and Billing_Country__c = : countryCode)];

        if (!spAccountList.isEmpty()) {
            if (ignoreZuoraAccountCheck) {
                returnMap.put('crmId', spAccountList[0].Id);
            } else {
                if (spAccountList[0].Billing_Account_Zuora__c != null) {
                    returnMap.put('crmId', spAccountList[0].Id);
                }
            }
        }

        return returnMap;
    }

}