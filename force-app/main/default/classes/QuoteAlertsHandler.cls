/**
* Methods in this class are used in quoteAlerts LWC
* @author 	Lawrence Zhao
* @date 	06-07-2022
* @module   BR-8379
*/

public without sharing class QuoteAlertsHandler {

    /**
    * @description return true if userId passed into the method has Conga Contracts license. Return false if otherwise.
    * @param null
    */
    
    @AuraEnabled(cacheable=true)
    public static Boolean hasCongaLicense(String userId) {
        List<UserPackageLicense> pkgLicenses = [SELECT Id, PackageLicense.NamespacePrefix, UserId
                                                FROM UserPackageLicense 
                                                WHERE UserId = :userId AND PackageLicense.NamespacePrefix = 'APXT_Redlining'];
        return pkgLicenses.size() > 0 ? TRUE : FALSE;
    } 
}