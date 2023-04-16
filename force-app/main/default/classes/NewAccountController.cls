/**
* Controller class for NewAccountLwc
* @author 	Ramiro Alvarez
* @date 	  11/11/2021
* @module   BR-4466
*/

public with sharing class NewAccountController {
    
    /**
    * @description return true if logged user has Sales User profile. Return false in otherwise.
    * @param null
    */
    
    @AuraEnabled(cacheable=true)
    public static Boolean checkUserProfile() {

        Set<String> activeProfiles = new Set<String> ();
        
        //Query for Active Permissions Settings
        for (Permissions_Settings__mdt profile : [
            SELECT Label, Is_Active__c
            FROM Permissions_Settings__mdt
            WHERE Object__c = 'Account'
                AND Permission_Type__c = 'NewAccount'
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