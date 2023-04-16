/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     
* created:        10/27/2022
* modified:       
* created jira:   SA-374
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public without sharing class AccountTeamMemberTriggerFunctions {
    
    public static final List<String> ATM_FIELDS = new List<String> {
        'TeamMemberRole'
    };


    /**  
    * SA-374 Set Default AccountTeamMember Values
    * @author   Ramiro Alvarez
    * @date       10/28/2022
    */

    public static void setDefaultAccTeamMemberValues(List<AccountTeamMember> newATMList) {
        
        Set<Id> userIds = new Set<Id> ();
        for (AccountTeamMember atm : newATMList) {
            userIds.add(atm.UserId);
        }

        Map<Id,User> atmUserMap = new Map<Id,User> ([ 
            SELECT Id, UserRole.Name, Email
            FROM User
            WHERE Id = :userIds
        ]);

        for (AccountTeamMember atm : newATMList) {
            atm.Account_Team_Email__c = atmUserMap.get(atm.UserId).Email;
            atm.User_Role_Hierarchy__c =atmUserMap.get(atm.UserId).UserRole.Name;
        }
    }

    /**  
    * SA-374 Create AccountTeamMember History transaction
    * @author   Ramiro Alvarez
    * @date       10/28/2022
    */
    
    public static void createATMHistory(List<AccountTeamMember> newATMList, Map<Id,AccountTeamMember> oldATMmap) {
        
        List<Account_Team_Member_History__c> atmHistoryList = new List<Account_Team_Member_History__c> ();
        List<AccountTeamMember> atmList = newATMList != null ? newATMList : oldATMmap.values();
        
        // Set action variable (Insert, Update or Delete)
        String action = Trigger.isInsert ? 'Insert' : (Trigger.isUpdate ? 'Update' : 'Delete');
        
        // Loop through AccountTeamMember List and create ATM History transaction record
        for (AccountTeamMember atm : atmList) {
            if (action == 'Insert' || action == 'Delete') {
                atmHistoryList.add(createAccountTeamMemberHistory(atm, action));
            } else if (action == 'Update' && Utilities.simpleCompareFields(atm, oldATMmap.get(atm.Id), ATM_FIELDS)) {
                atmHistoryList.add(createAccountTeamMemberHistory(atm, action));
            }
        }
        
        if (!atmHistoryList.isEmpty()) {
            insert atmHistoryList;
        }
    }
    
    // Create Account Team Member History record.
    public static Account_Team_Member_History__c createAccountTeamMemberHistory(AccountTeamMember atm, String action) {
        return new Account_Team_Member_History__c(
            Account__c = atm.AccountId,
            Action__c = action,
            User__c = atm.UserId,
            TeamMemberRole__c = atm.TeamMemberRole,
            User_Role_Hierarchy__c = atm.User_Role_Hierarchy__c
        );
    }
}
