/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*   https://cargurus.atlassian.net/browse/CRM-2916
*   Test rest endpoint to provide Salesforce AccountId to CG Developers
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Dylan Morrill
* @modifiedBy     Dylan Morrill
* @created        Jul-2019
* @modified       12/03/2019
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/


@RestResource(urlMapping='/retrieveAccountInfo/*')
global class CG_RestRetrieveAccountInfo {
    
    private static InComingAccountInfo inComingInfo;
    
    @HttpPost
    global static void doPost() {
        
        //JSON VALIDATION SECTION
        try{
            inComingInfo = (InComingAccountInfo)JSON.deserialize(RestContext.request.requestBody.toString(), InComingAccountInfo.class);
            //Make sure the JSON payload had a value for b oth countrycode and serviceProviderId - if it didn't, set response and return
            if (inComingInfo.countryCode == null || inComingInfo.serviceProviderId == null){
                setErrorResponse(400, 'NULL_VALUES', 'The JSON payload recieved contained at least one null value');
                return;
            }
        }catch(JSONException jse){
            setErrorResponse(400, 'JSON_EXCEPTION', jse.getMessage());
            return;
        }
        //END JSON VALIDATION SECTION
        
        List <OutgoingAccountInfo> returnedAccountInfo = new List <OutgoingAccountInfo>();
        
        //If we locate matched records, return those matched records in the response body
        if (retrieveAndReturnAccountInfo(returnedAccountInfo)){
            RestContext.response.responseBody = Blob.valueOf(json.serialize(returnedAccountInfo));
            RestContext.response.addHeader('Content-Type', 'application/json');
        } 
    }
    
    private static Boolean retrieveAndReturnAccountInfo(List <OutgoingAccountInfo> returnedAccountInfo){
        
        //  added to support project mason data updates due to the fact that not all 
        //  accounts have AMs so we dont want to disrupt the payload for CG Dashboard
        if(inComingInfo.countryCode == 'US'){
            Map<Id,Id> atmMap = new Map<Id,Id>();
            List <Account> usAccounts = new List<Account>();
            
            for (AccountTeamMember atm : [SELECT Id, UserId, AccountId
                          FROM AccountTeamMember 
                          WHERE AccountId IN (SELECT Account__c
                            FROM Service_Provider__c
                            WHERE Service_Provider_Id__c = :inComingInfo.serviceProviderId
                            AND Billing_Country__c	= :inComingInfo.countryCode) 
                          AND TeamMemberRole = 'Account Manager' 
                          Order By CreatedDate DESC Limit 1]){
                              atmMap.put(atm.AccountId, atm.UserId);
                              }
            
            for (Account a : [SELECT Id
                              FROM Account  
                              WHERE Id IN :atmMap.keySet()]){
                                      usAccounts.add(a);
                              }
            // insert the Account Manager into SEM_Digital_Consultant__c
            if (usAccounts != null){
                update usAccounts;
            }
        }


        //Locate any service provider records that match the JSON payload parameters
        List <Service_Provider__c> locatedRecords = [SELECT Account__c, Account__r.Billing_Account_Zuora__r.Zuora__Zuora_Id__c,
                                                     Account__r.Owner.Name, Account__r.Owner.Phone
                                                     FROM Service_Provider__c
                                                     WHERE Service_Provider_Id__c = :inComingInfo.serviceProviderId
                                                     AND Billing_Country__c = :inComingInfo.countryCode];
        
        //If no records were found, set the response body appropriately
        if (locatedRecords.isEmpty()){
            setErrorResponse(404, 'NO_ACCOUNT', 'No accounts found with provided information');
            return false;
                                   }
        
        //If only one record was found, add a new OutGoingErrorInfo object to the 
        //returnedAccountInfo list and return true from this method
        returnedAccountInfo.add(new OutgoingAccountInfo(locatedRecords[0].Account__c, 
                                                        locatedRecords[0].Account__r.Billing_Account_Zuora__r.Zuora__Zuora_Id__c,
                               							locatedRecords[0].Account__r.Owner.Name,
                                                        locatedRecords[0].Account__r.Owner.Phone));
        return true;
    }
    
    //
    //A BUNCH OF INNER WRAPPER CLASSES AND A STATIC METHOD USED TO CREATE THE ERROR RESPONSES
    //
    private class InComingAccountInfo{
        Decimal serviceProviderId;
        String countryCode;
    }
    public class OutgoingAccountInfo{
        @TestVisible 
        String salesForceAccountId;
        @TestVisible 
        String zuoraBillingAccountId;
        @TestVisible 
        String salesForceAccountOwnerName;
        @TestVisible 
        String salesForceAccountOwnerPhone;
        public OutgoingAccountInfo(String salesForceAccountId, String zuoraBillingAccountId, String salesForceAccountOwnerName,
                                  String salesForceAccountOwnerPhone){
            this.salesForceAccountId = salesForceAccountId;
            this.zuoraBillingAccountId = zuoraBillingAccountId;
            this.salesForceAccountOwnerName = salesForceAccountOwnerName;
            this.salesForceAccountOwnerPhone = salesForceAccountOwnerPhone;                   
        }
    }
    public class OutGoingErrorInfo{
        @TestVisible
        String errorCode;
        @TestVisible 
        String message;
        public OutGoingErrorInfo(String errorCode, string message){ 
            this.errorCode = errorCode;
            this.message = message;
        }
    }
    
    private static void setErrorResponse(Integer statusCode, String errorCode, String errorMessage){
        RestContext.response.statusCode = statusCode;
        List <OutGoingErrorInfo> specificErrorInfo = new List <OutGoingErrorInfo>();
        specificErrorInfo.add(new OutGoingErrorInfo(errorCode, errorMessage));
        RestContext.response.responseBody = Blob.valueOf(json.serialize(specificErrorInfo));
        RestContext.response.addHeader('Content-Type', 'application/json');
    }
}