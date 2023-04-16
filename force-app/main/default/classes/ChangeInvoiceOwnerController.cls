/**
* Controller class for ChangeInvoiceOwnerLWC
* @author 	Ramiro Alvarez
* @date 	  11/03/2021
* @module   BR-3733
*/

public without sharing class ChangeInvoiceOwnerController {

    
    /**
    * Get Related Subscriptions for the passed Contract Id
    * @author   Ramiro A.
    * @date     11/03/21
    * @module   BR-3733 : Change Invoice Owner in Salesforce
    */
    @AuraEnabled(cacheable=true)
    public static List<SBQQ__Subscription__c> getRelatedSubs(String recordId) {

        List<SBQQ__Subscription__c> subs = [SELECT Id, Name, SBQQ__QuoteLine__r.SBQQ__Quote__r.Payment_Method__c,
        Invoice_Change_Status__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__Contract__c = :recordId
            AND SBQQ__Product__r.ProductCode = :ConstantsUtil.PRODUCT_PRODUCTCODE_CGBASE
            AND Zuora_Subscription__c != NULL];

        return subs;

    }

    /**
    * Populate Billing Account on the related CG-BASE subscriptions
    * @author   Ramiro A.
    * @date     11/03/21
    * @module   BR-3733 : Change Invoice Owner in Salesforce
    */
    @AuraEnabled
    public static void setBillingAccsOnSubs(String contractId, String billingAccountId) {        

        if (contractId == null || billingAccountId == null) {
            return;
        }

        List<SBQQ__Subscription__c> subList = [SELECT Id, Name,
            SBQQ__QuoteLine__r.SBQQ__Quote__r.Payment_Method__c,
            SBQQ__Contract__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__Contract__c = :contractId
            AND SBQQ__Product__r.ProductCode = :ConstantsUtil.PRODUCT_PRODUCTCODE_CGBASE
            AND Zuora_Subscription__c != NULL];
        
        List<SBQQ__Subscription__c> subListToUpd = new List<SBQQ__Subscription__c>();
        for (SBQQ__Subscription__c sub : subList) {
            subListToUpd.add( new SBQQ__Subscription__c(Id = sub.Id, Billing_Account__c = billingAccountId));
        }

        update subListToUpd;

    }

    /**
    * @description return true if logged user has permissions to access feature. Return false in otherwise.
    * @param null
    */
    
    @AuraEnabled(cacheable=true)
    public static Boolean checkUserProfile() {

        Set<String> activeProfiles = new Set<String> ();
        
        //Query for Active Permissions Settings
        for (Permissions_Settings__mdt profile : [
            SELECT Label, Is_Active__c
            FROM Permissions_Settings__mdt
            WHERE Object__c = 'Subscription'
                AND Permission_Type__c = 'ChangeInvoiceOwner'
                AND Is_Active__c = true
        ]) {
            activeProfiles.add(profile.Label);
        }       

        //Query for Logged User Profile
        List<Profile> userProfile = [SELECT Id, Name
            FROM Profile
            WHERE Id = :userinfo.getProfileId()];
		
		if (!userProfile.isEmpty() && activeProfiles.contains(userProfile[0].Name)) {
            return true;
        } else {
            return false;
        }
    }

}