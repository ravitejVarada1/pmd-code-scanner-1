/**
* Controller class for SyncSPlwc
* @author 	Ramiro Alvarez
* @date 	  04/11/2022
* @module   BR-4589
*/

public without sharing class SyncSPController {
    
    
    /**
    * Perform On-Demand Service Provider Sync
    */

    @AuraEnabled
    public static void syncSP(String recordId) {

        // Sanity check
        if (recordId == null) {
            return;
        }

        Service_Provider__c sp = [
            SELECT Id, Service_Provider_Id__c,Account__r.BillingCountryCode
            FROM Service_Provider__c
            WHERE Id = :recordId];
            
        String boomiNamedCred = Utilities.IS_SANDBOX ? 'Boomi_Sandbox_API' : 'Boomi_API';

        String spobj = '{"spid":' + sp.Service_Provider_Id__c + ',"billing_country":"'+ sp.Account__r.BillingCountryCode+'"}';

        //System.debug('test spObj: ' + spobj);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:'+boomiNamedCred+'/ws/simple/getServiceProvider');
        req.setMethod('POST');
        req.setBody(spobj);
        req.setTimeOut(60000);
        Http http = new Http();
        HTTPResponse res = http.send(req);

        if(res.getStatusCode() == 200) {
            System.debug('syncSP: Success - 200');
        } else {
            String errorMsg = 'Error: ' + res.getStatusCode() + '-' + res.getStatus();
            System.debug('Error: ' + errorMsg);
            throw new AuraHandledException(errorMsg);
        }
        
    }
    
}
