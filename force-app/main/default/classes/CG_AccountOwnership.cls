/********************************************************************************************************
* author:         dmcintyre
* modifiedBy:     dmcintyre
* created:        05/26/2021
* modified:       05/26/2021
* created jira:   BR-855
*********************************************************************************************************/
public without sharing class CG_AccountOwnership {

    //define list of fields to help group Opportunities by a broad account field group type
    public static List<String> oppGroupings = new List<String>{
        'US_Field',
        'US_NonField',
        'US_All',
        'GB_Field',
        'GB_NonField',
        'GB_All',
        'CA_All'
    };

    public static Id cgAPIUserId;

    //User detail captures user's role name etc..
    public static Map<Id, User> userDetailMap;

    //Map User Role Developer names to the Account Team Member Role Names
    public static Map<String, Map<String, String>> userRoleToAtmRoleMap = new Map<String, Map<String, String>>();

    static {
        List<UserRole_ATMRole_Map__mdt> userToAtmRolesMdt = [SELECT Account_Billing_Country__c,
            Account_Team_Member_Role__c, User_Role_Developer_Name__c FROM UserRole_ATMRole_Map__mdt];
    
        for(UserRole_ATMRole_Map__mdt role : userToAtmRolesMdt) {
            String billingCountry = role.Account_Billing_Country__c;
            String atmRole = role.Account_Team_Member_Role__c;
            String usrRole = role.User_Role_Developer_Name__c;

            if(!userRoleToAtmRoleMap.containsKey(role.Account_Billing_Country__c)) {
                userRoleToAtmRoleMap.put(billingCountry, new Map<String, String>{usrRole => atmRole});
            } else {
                userRoleToAtmRoleMap.get(billingCountry).put(usrRole, atmRole);
            }
        }
    }

    public static Map<String, Map<String, String>> getUserToAtmRoleMap(String billingCountryCode, String userRoleDevName) {
        return userRoleToAtmRoleMap;
    }

    public static Id getCGAPIUser() {
        if (cgAPIUserId == null) {
            cgAPIUserId = [SELECT Id FROM User WHERE Name LIKE '%Cargurus API%' AND isActive = True Limit 1].Id;
        }
        return cgAPIUserId;
    }

    /**
     * Update ownership of the account hierarchy when required.
     */
    public static void updateAccountOwner(Map<Id, Id> accountIdOwnerIdMap, String tmr, Boolean toCgApiUser) {
        System.debug(accountIdOwnerIdMap);
        List<AccountTeamMember> atmsToCreate = new List<AccountTeamMember>();
        List<Account> accountToBeUpdated = new List<Account>();

        //get the users involved so we know their roles
        Set<Id> userIds = new Set<Id>();
        userIds.addAll(accountIdOwnerIdMap.values());
        Map<Id, User> userMap = getUsers(userIds);

        Map<Id, Id> ultimateParentToProposedOwners = getUltParentToNewOwnerMap(accountIdOwnerIdMap);
        System.debug(ultimateParentToProposedOwners);
        for (Account acc : [SELECT Id, BillingCountryCode, OwnerId, Ultimate_Parent_Account__c
            FROM Account
            WHERE Ultimate_Parent_Account__c IN :ultimateParentToProposedOwners.keySet() 
            OR Id IN :ultimateParentToProposedOwners.keySet()]) 
        {
            String billingCountry = acc.BillingCountryCode;
            Id ultimateParentId = acc.Ultimate_Parent_Account__c;
            if (ultimateParentId == null){
                ultimateParentId = acc.Id;
            }

            Id proposedOwnerId = toCgApiUser ? CGAPIUserId : ultimateParentToProposedOwners.get(ultimateParentId);

            Account pAcc = new Account(Id = acc.Id, OwnerId = proposedOwnerId);
            accountToBeUpdated.add(pAcc);

            if( !toCgApiUser ){
                User usr = userMap.get(proposedOwnerId);
                String usrRole = usr.UserRole.DeveloperName;
                Map<String, String> usrToAtmRoleMap = userRoleToAtmRoleMap.get(billingCountry);
                String teamRole = tmr;
                
                if(usrToAtmRoleMap != null && usrToAtmRoleMap.containsKey(usrRole)) {
                    teamRole = usrToAtmRoleMap.get(usrRole);
                }
                
                atmsToCreate.add(createAccountTeamMember(pAcc.Id, teamRole, pAcc.OwnerId, 'Edit', 'Edit', 'Edit', 'Edit'));
            }
        }

        update accountToBeUpdated;
        
        if(!atmsToCreate.isEmpty()) {
            insert atmsToCreate;
        }
    }

    /**
     * Update ownership of the account hierarchy when required.
     */
    public static void changeAccountOwner(List<Account> accounts, Map<Id, String> accAtmRoleMap, 
        Map<Id, Account> accountMap) 
    {
        System.debug('::changeAccountOwner::');
        
        List<AccountTeamMember> atmsToCreate = new List<AccountTeamMember>();
        List<Account> allAccsToUpdate = new List<Account>();

        Map<Id, Id> ultimateParentToProposedOwners = getUltParentToNewOwnerMap(accounts);
        Map<Id, String> ultParentToTeamRole = reMapRolesToUltParentId(accAtmRoleMap, accountMap);

        for (Account acc : [SELECT Id, BillingCountryCode, OwnerId, Ultimate_Parent_Account__c
            FROM Account
            WHERE Ultimate_Parent_Account__c IN :ultimateParentToProposedOwners.keySet() 
            OR Id IN :ultimateParentToProposedOwners.keySet()]) 
        {
            //String billingCountry = acc.BillingCountryCode;
            Id ultimateParentId = acc.Ultimate_Parent_Account__c;
            if (ultimateParentId == null){
                ultimateParentId = acc.Id;
            }

            Id proposedOwnerId = ultimateParentToProposedOwners.get(ultimateParentId);

            Account tmpAcc = new Account(Id = acc.Id, OwnerId = proposedOwnerId);
            allAccsToUpdate.add(tmpAcc);

            String teamRole = ultParentToTeamRole.get(ultimateParentId);
            System.debug('teamRole::'+teamRole);
            
            atmsToCreate.add(
                createAccountTeamMember(tmpAcc.Id, teamRole, tmpAcc.OwnerId, 'Edit', 'Edit', 'Edit', 'Edit')
            );
        }
        
        if(!allAccsToUpdate.isEmpty()) {
            update allAccsToUpdate;
        }
        
        if(!atmsToCreate.isEmpty()) {
            insert atmsToCreate;
        }
    }

    /**
     * Utility method to query all the ultimate parents so a hierarchy can be transferred
     * to new owner. This one takes a list of accounts.
     */
    public static Map<Id, Id> getUltParentToNewOwnerMap(List<Account> accounts) {
        Map<Id, Id> ultParentToNewOwners = new Map<Id, Id>();
        for (Account acc : accounts)
        {
            Id newOwnerId = acc.OwnerId;
            if (acc.Ultimate_Parent_Account__c == null){
                ultParentToNewOwners.put(acc.Id, newOwnerId);
            } else{
                ultParentToNewOwners.put(acc.Ultimate_Parent_Account__c, newOwnerId);
            }
        }

        return ultParentToNewOwners;
    }

    /**
     * Utility that maps ultimate parent id to team member role. Used when updating the hierarchy
     * with a new owner.
     */
    public static Map<Id, String> reMapRolesToUltParentId(Map<Id, String> accAtmRoleMap, Map<Id, Account> accountMap) {
        Map<Id, String> ultParentToTeamRole = new Map<Id, String>();
        for(Id accId : accAtmRoleMap.keySet()) {
            Id ultimateParentId = accountMap.get(accId).Ultimate_Parent_Account__c;
            if(ultimateParentId == null) {
                ultimateParentId = accId;
            }
            String atmRole = accAtmRoleMap.get(accId);
            ultParentToTeamRole.put(ultimateParentId, atmRole);
        }
        return ultParentToTeamRole;
    }

    /**
     * Utility method to query all the ultimate parents so a hierarchy can be transferred
     * to new owner
     */
    public static Map<Id, Id> getUltParentToNewOwnerMap(Map<Id, Id> accountIdOwnerIdMap) {
        Map<Id, Id> ultimateParentToProposedOwners = new Map<Id, Id>();
        for (Account acc : [SELECT Id, ParentId, Ultimate_Parent_Account__c
            FROM Account
            WHERE Id IN :accountIdOwnerIdMap.keySet()])
        {
            if (acc.Ultimate_Parent_Account__c == null){
                ultimateParentToProposedOwners.put(acc.Id, accountIdOwnerIdMap.get(acc.Id));
            } else{
                ultimateParentToProposedOwners.put(acc.Ultimate_Parent_Account__c, accountIdOwnerIdMap.get(acc.Id));
            }
        }

        return ultimateParentToProposedOwners;
    }
    
    public static void updateAccountOwner(Set<Id> returnAccsToCGApi){

        List<Account> accountToBeUpdated = new List<Account>();

        for(Account acc : [SELECT Id, OwnerId, Ultimate_Parent_Account__c,BookNumber__c,Field_Group_Type__c,
                            BillingCountryCode,
                            (SELECT Id FROM Opportunities WHERE IsClosed = false)
                            FROM Account
                            WHERE Ultimate_Parent_Account__c IN :returnAccsToCGApi 
                            OR Id IN :returnAccsToCGApi]){

            if(acc.Opportunities.isEmpty()) {
                //BR-8283 - Only return to CG API if it is not a named account
                if (acc.BillingCountryCode == 'US' && acc.BookNumber__c == null && acc.Field_Group_Type__c == null){
                    Account pAcc = new Account(Id = acc.Id, OwnerId = getCGAPIUser());
                    accountToBeUpdated.add(pAcc);
                }
                if (acc.BillingCountryCode == 'GB' && acc.Field_Group_Type__c == null) {
                    Account pAcc = new Account(Id = acc.Id, OwnerId = getCGAPIUser());
                    accountToBeUpdated.add(pAcc);
                }
                if (acc.BillingCountryCode == 'CA') {
                    Account pAcc = new Account(Id = acc.Id, OwnerId = getCGAPIUser());
                    accountToBeUpdated.add(pAcc);
                }
            }
        }

        if (!accountToBeUpdated.isEmpty()) {
            update accountToBeUpdated;
        }
    }

    //call to check and see if we need to return the account owner to CG API after 
    //a closed lost opp on prospect accounts
    public static void returnAccountOwnerToCGAPIUser(List<Opportunity> oppList) {

        List<Account> accountsToUpdate = new List<Account>();
        Set<Id> acctIds = new Set<Id>();
        Set<Id> quoteIds = new Set<Id>();
        Map<Id, Id> oppOwners = new Map<Id, Id>();

        for(Opportunity o : oppList) {
            acctIds.add(o.AccountId);
            if(o.SBQQ__PrimaryQuote__c != null) {
                quoteIds.add(o.SBQQ__PrimaryQuote__c);
            }
            oppOwners.put(o.Id, o.OwnerId);
        }

        //add related fulfillment accounts in the primary quote to also return to CG API
        for (SBQQ__QuoteLine__c ql : [SELECT Id, Fulfillment_Account__c 
                                        FROM SBQQ__QuoteLine__c
                                        WHERE SBQQ__Quote__c IN: quoteIds]) {
            acctIds.add(ql.Fulfillment_Account__c);
        }
        
        for (Account a : [SELECT Id, OwnerId, Owner.UserRole.Name, Type, Account_Saturation_Percentage_Formula__c,
            BillingCountryCode, BookNumber__c, Field_Group_Type__c,
            (SELECT Id, UserId, TeamMemberRole 
                FROM AccountTeamMembers 
                    WHERE TeamMemberRole = 'Field Account Manager' OR TeamMemberRole = 'Dealer Relations'),
            (SELECT Id, OwnerId, StageName
                FROM Opportunities
                    WHERE IsClosed = false 
                    AND Id NOT IN: oppOwners.keySet()) 
            FROM Account 
            WHERE Id IN: acctIds]) 
        {
            if((a.Type == 'Prospect' || a.Type == 'Former Customer') 
                && a.Account_Saturation_Percentage_Formula__c == 0.00 && a.Opportunities.isEmpty()
                && (a.BillingCountryCode != 'US' || a.BillingCountryCode == 'US' && a.BookNumber__c == null && a.Field_Group_Type__c == null))
                
            {
                accountsToUpdate.add(a);
            }
        }

        if(accountsToUpdate.isEmpty()) { return; }

        returnAccountOwnerToCGAPIUser(accountsToUpdate,'opp');
    }

    //call to check and see if we need to return the Account to CG API after the Account goes back to Former Customer
    public static void returnAccountOwnerToCGAPIUser(List<Account> acctList, Map<Id,Account> oldAcctMap) {
        List<Account> accountsToUpdate = new List<Account>();

        for (Account a : acctList) {
            Account oldAccount = oldAcctMap.get(a.Id);
            if (a.Type == 'Former Customer' && oldAccount.Type != 'Former Customer' && a.Account_Saturation_Percentage_Formula__c == 0) {
                accountsToUpdate.add(a);
            }
        }

        if (accountsToUpdate.isEmpty()) { 
            return; 
        }

        Account[] accts = [SELECT Id, OwnerId, Owner.UserRole.Name, Type,
                                (SELECT Id, UserId, TeamMemberRole 
                                    FROM AccountTeamMembers 
                                    WHERE TeamMemberRole IN ('Dealer Relations','Field Account Manager') limit 1
                                )
                                FROM Account WHERE Id IN: accountsToUpdate];

        returnAccountOwnerToCGAPIUser(accts,'account');
    }

    public static void returnAccountOwnerToCGAPIUser(List<Account> acctList,String context) {
        
        List<Account> accountsToUpdate = new List<Account>();
        List<AccountTeamMember> teamMembers = new List<AccountTeamMember>();

        if (acctList.isEmpty()) { return; }

        for(Account a : acctList){
            a.OwnerId = getCGAPIUser();
            accountsToUpdate.add(a);
            if (a.AccountTeamMembers != null && !a.AccountTeamMembers.isEmpty()) {
                AccountTeamMember atm = a.AccountTeamMembers[0];
                teamMembers.add(createAccountTeamMember(a.Id, atm.TeamMemberRole, atm.UserId, 'Edit', 'Edit', 'Edit', 'Edit'));
            }
        } // end Account for Loop
        
        if (context == 'opp') {
            // Update Accounts
            Database.SaveResult[] accountResults = Database.update(accountsToUpdate, false);

            // Provide readout of results if needed
            Map<Id,Id> accIDOwnerId = new Map<Id,Id>();
            for (Database.SaveResult sr : accountResults) {
                if (sr.isSuccess()) {
                    System.debug('Successfully updated: ' + sr.getId());
                    accIDOwnerId.put(sr.getId(),getCGAPIUser());
                }
                else {
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('The following error has occurred.');                    
                        System.debug(err.getStatusCode() + ': ' + err.getMessage());
                        System.debug('Account fields that affected this error: ' + err.getFields());
                    }
                }
            } 
            updateAccountOwner(accIDOwnerId,null,true);
            // end Save Results
        }

        // Insert Account Team Members
        processResults(Database.insert(teamMembers, false));

    } //end Account Team Members Save Results


    private static Map<Id, Account> allRelatedAccountInfo;

    public static Map<Id, Account> getAccounts(Set<Id> accountIds) {
        if(allRelatedAccountInfo == null) {
            allRelatedAccountInfo = new Map<Id, Account>([SELECT Id, Account_Saturation_Percentage_Formula__c, 
            BillingCountryCode, Field_Group_Type__c, Group_Total_Used_Inventory_Formula__c, 
            OwnerId, Owner.UserRole.Name, ParentId, Type, Ultimate_Parent_Account__c, 
            Ultimate_Parent_Account__r.Owner.UserRole.Name, Account_Category_Formula__c,
            BookNumber__c,
            (SELECT Id, TeamMemberRole, UserId 
                FROM AccountTeamMembers 
                ORDER BY TeamMemberRole ASC)
            FROM Account WHERE Id IN :accountIds]);
        }
        return allRelatedAccountInfo;
    }

    public static void processResults(List<Database.SaveResult> results) {
        for(Database.SaveResult sr : results) {
            if(sr.isSuccess()) {
                System.debug('Successfully inserted: ' + sr.getId());
            } else {
                for(Database.Error err : sr.getErrors()) {
                    System.debug('The following error has occurred.');                    
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                    System.debug('Account fields that affected this error: ' + err.getFields());
                }
            }
        }
    }

    public static AccountTeamMember createAccountTeamMember(Id acc, String teamMemberRole, Id userId, 
        String AccountAccessLevel, String CaseAccessLevel, String ContactAccessLevel, String OppAccessLevel) {
            AccountTeamMember atm = new AccountTeamMember();
            atm.AccountId = acc;
            atm.TeamMemberRole = AccountAccessLevel;
            atm.UserId= userId;
            atm.AccountAccessLevel = AccountAccessLevel;
            atm.CaseAccessLevel = CaseAccessLevel;
            atm.ContactAccessLevel = ContactAccessLevel;
            atm.OpportunityAccessLevel = OppAccessLevel;
            return atm;
    }

    public static Map<Id, User> getUsers(Set<Id> oppOwnerIds) {
        if(userDetailMap == null) {
            userDetailMap = new Map<Id, User>([SELECT Id, UserRole.DeveloperName FROM User WHERE Id IN :oppOwnerIds]);
        }
        return userDetailMap;
    }
}
