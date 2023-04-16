/**
* Controller class for OneOffCancellationLWC
* @author 	Ramiro Alvarez
* @date 	  03/02/2022
* @module   BR-5515
*/

public without sharing class OneOffCancellationController {
    
    /**
    * Perform one-off cancellation call for one particular Account Id
    */

    @AuraEnabled
    public static void callCancellationBatch(String recordId) {

        // Sanity check
        if (recordId == null) {
            return;
        }
        Database.executeBatch(new CancellationQuotesProcessor(recordId), 1);
    }

    /**
    * @description return true if logged user has permissions to access feature. Return false in otherwise.
    * @param null
    */
    
    @AuraEnabled(cacheable=true)
    public static Boolean checkUserProfile() {

        //Query for Logged User Profile
        User user = [
            SELECT Id, UserRole.Name, Profile.Name
            FROM User
            WHERE Id = :userinfo.getUserId()];
		
		if (user.Profile.Name == ConstantsUtil.SYSTEM_ADMIN || user.Profile.Name == ConstantsUtil.SALES_OPS || user.Profile.Name == ConstantsUtil.ACCOUNTING) {
            return true;
        } else {
            return false;
        }
    }
}
