/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         amitul
* modifiedBy:     amitul
* created:        04/05/2021
* modified:       04/05/2021
* created jira:   BR-864
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class UserTriggerFunctions {
    
    static Map<Id, User> activeUsers = new Map<Id, User>([SELECT Id, Is_Final_Approver__c, 
		Final_Approver_Id_Text__c, ManagerId FROM User WHERE IsActive = true AND Profile.UserLicense.Name = 'Salesforce']);

    //clear the termination date if user become active from inactive  
    public static void clearTerminationDate( Map<ID,User> oldUserMap, List<User> newUserList ) {
        //setting the termination date to null if isactive is set to true.
        for(User u : newUserList){
            if(u.IsActive == true && oldUserMap.get(u.ID).IsActive != u.IsActive ){
                u.Termination_Date__c = null; 
            }
        } 
        
    }

      // unfreeze the user if user become active from inactive
    public static void unfreezeUser(Map<ID,User> oldUserMap, List<User> newUserList){
        // create a list to store the updated user login record.
        List<UserLogin> loginListToUpdate =  new List<UserLogin>();
        Set<Id> userID = new Set<Id>();        
         for(User u : newUserList){
            if(u.IsActive == true && oldUserMap.get(u.ID).IsActive != u.IsActive ){
                userID.add(u.Id);
            }
        }
        
        for(UserLogin uLogin : [SELECT Id, IsFrozen 
                                From UserLogin 
                                Where UserId IN : userID ]){
            uLogin.IsFrozen = false;
            loginListToUpdate.add(uLogin);
        }

        if(!loginListToUpdate.isEmpty()){
            update loginListToUpdate; 
        }
    }
      
	//jira: BR-1220
	//StampFinalApproverID
    public static void setFinalApproverText(List<User> newUserList, Map<ID,User> oldUserMap) {
        List<user> userListUpdate = new List<user>();
        for(User u : newUserList) {
            User finalApprover = BatchUpdateFinalApprover.findFinalApprover(u, activeUsers);
            u.Final_Approver_Id_Text__c = (finalApprover == null) ? null : finalApprover.Id;
        }
    }
}