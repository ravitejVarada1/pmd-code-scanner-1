/**
 * Perform Account Ownership changes when Opportunities are created
 * as per Book Of Business rules
 */
public class AccountOwnershipOppCreateEvent {

    public static List<String> oppGroupings = CG_AccountOwnership.oppGroupings;

    public static void opportunityCreateEvents(Map<Id, Opportunity> newOppMap) {
        Map<String, Map<Id, Opportunity>> createdOppMap = new Map<String, Map<Id, Opportunity>>();
        Set<Id> relatedAccountIds = new Set<Id>();
        Set<Id> oppOwnerIds = new Set<Id>();
        Map<Id, User> userMap = new Map<Id, User>();
        for(String oppGroups : oppGroupings) {
            createdOppMap.put(oppGroups, new Map<Id, Opportunity>());
        }

        // Create a map of Account Ids => Opp Ids on opps that moved to closed won 
        for(Opportunity newOpp: newOppMap.values()) {
            relatedAccountIds.add(newOpp.AccountId);
            oppOwnerIds.add(newOpp.OwnerId);
        }

        // Map of account fields
        Map<Id, Account> accountMap = CG_AccountOwnership.getAccounts(relatedAccountIds);

        for(Opportunity newOpp : newOppMap.values()) {

            System.debug(newOpp.OwnerId);

            Account acct = accountMap.get(newOpp.AccountId);
            String billingCountry = acct.BillingCountryCode;
            String fieldGroupType = acct.Field_Group_Type__c;

            if(billingCountry == 'GB') {
                if(acct.Field_Group_Type__c != null ) {
                    createdOppMap.get('GB_Field').put(newOpp.Id, newOpp);
                } else {
                    createdOppMap.get('GB_NonField').put(newOpp.Id, newOpp);
                }

            } else if(billingCountry == 'CA') {
                createdOppMap.get('CA_All').put(newOpp.Id, newOpp);
            
            } else if(billingCountry == 'US') { //BR-7047
                if(acct.BookNumber__c == null && acct.Field_Group_Type__c == null) {
                    createdOppMap.get('US_All').put(newOpp.Id, newOpp);
                }
            }
        }

        if(!createdOppMap.get('GB_Field').isEmpty()) {
            createdOppMap.get('GB_All').putAll(createdOppMap.get('GB_Field'));
            //oppCreated_GB(createdOppMap.get('GB_Field'), accountMap); 
        }

        if(!createdOppMap.get('GB_NonField').isEmpty()) {
            createdOppMap.get('GB_All').putAll(createdOppMap.get('GB_NonField'));
            //oppCreated_GB(createdOppMap.get('GB_Field'), accountMap);
        }

        if(!createdOppMap.get('GB_All').isEmpty()) {
            oppCreated_GB(createdOppMap.get('GB_All'), accountMap);
        }

        if(!createdOppMap.get('CA_All').isEmpty()) {
            List<Opportunity> newOppList = createdOppMap.get('CA_All').values();
            updateAccountOwnerToOpptyOwner(newOppList, accountMap);
        }

        if(!createdOppMap.get('US_All').isEmpty()) {
            oppCreated_US(createdOppMap.get('US_All'), accountMap);
        }
    }

    /**
     * Process account ownership when an Opp is created at a Field Group Type National account
     */
    public static void oppCreated_GB(Map<Id, Opportunity> newOppMap, Map<Id, Account> accountMap) {

        Map<Id, Id> accountToOwnerIdMap = new Map<Id, Id>();
        for(Opportunity newOpp : newOppMap.values()) {
            Account acct = accountMap.get(newOpp.AccountId);
            if(acct.Account_Saturation_Percentage_Formula__c == 0.0) {
                accountToOwnerIdMap.put(acct.Id, newOpp.OwnerId);
            } 
        }

        if(!accountToOwnerIdMap.isEmpty()) {
            CG_AccountOwnership.updateAccountOwner(accountToOwnerIdMap, 'Acquisitions', false);
        }
    }

    /**
     *  loop through Opportunities, check if the related account is not a customer
     *   or is owned by CGAPI, if so, then update the ownership of the
     *   Account and the hierarchy
     */
    public static void updateAccountOwnerToOpptyOwner(List<Opportunity> newOppList, Map<Id, Account> accountMap) { 
        
        Map<Id,Id> accountToOppOwnerMap = new Map<Id,Id>();
        List<Account> accountsToUpdate = new List<Account>();
        List<AccountTeamMember> accTeamMembers = new list<AccountTeamMember>();
        Map<Id, Id> accountIdOwnerIdMap = new Map<Id, Id>();

        
        for(Opportunity opp : newOppList) {
            Id accId = opp.AccountId;
            Account a = accountMap.get(accId);

            // ON NON-CUSTOMERS + CGAPI OWNED
            if(a.Account_Saturation_Percentage_Formula__c == 0.0 
                && a.OwnerId == CG_AccountOwnership.getCGAPIUser()) 
            {  
                Id oppOwnerId = opp.OwnerId;
                a.OwnerId = oppOwnerId;
                accountsToUpdate.add(a);
                accountIdOwnerIdMap.put(a.Id, a.OwnerId);

                // create account team members for Acquisition Rep
                accTeamMembers.add(CG_AccountOwnership.createAccountTeamMember(a.Id, 'Acquisitions', a.OwnerId, 'Edit', 'Edit', 'Edit', 'Edit'));
            }
        } 

        //update accounts and create team members if any
        if(!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
            CG_AccountOwnership.processResults(Database.insert(accTeamMembers, false));
            CG_AccountOwnership.updateAccountOwner(accountIdOwnerIdMap, 'Acquisitions', false);
        }
    }

    /**
     * BR-7047 US - Process account ownership when an Opp is created from Lead
     */
    public static void oppCreated_US(Map<Id, Opportunity> newOppMap, Map<Id, Account> accountMap) {

        Map<Id, Id> accountToOwnerIdMap = new Map<Id, Id>();
        for(Opportunity newOpp : newOppMap.values()) {
            Account acct = accountMap.get(newOpp.AccountId);
            if(acct.Account_Saturation_Percentage_Formula__c == 0.0 &&
               acct.OwnerId == CG_AccountOwnership.getCGAPIUser()) {
                accountToOwnerIdMap.put(acct.Id, newOpp.OwnerId);
            } 
        }

        if(!accountToOwnerIdMap.isEmpty()) {
            CG_AccountOwnership.updateAccountOwner(accountToOwnerIdMap, 'Account Executive', false);
        }
    }

}
