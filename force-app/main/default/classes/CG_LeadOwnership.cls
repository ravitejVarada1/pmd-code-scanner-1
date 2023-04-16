public with sharing class CG_LeadOwnership {

    private static String ALLOWED_PERMISSION_TYPE = 'Allowed Lead SDR Role';

    //Map from Lead Country to the corresponding Queue
    public static Map<String, String> leadCountryQueueMap = new Map<String, String> {
        'CA' => 'International_CA',
        'US' => 'International_US',
        'GB' => 'International_GB'
    };
   
    //  Lead Triggered Events

    public static void assignLeadtoAcquistions(List<Lead> newLeadList, Map<Id,Lead> oldLeadMap){
        //  grabbing accountIds in set to query for Open Opportunities
        Map<Id,List<Lead>> acctLeadMap = new Map<Id,List<Lead>>();
        
        for (Lead l : newLeadList){
            if (oldLeadMap == null) {
                if (l.Lead_Account__c != null) {
                    if (!acctLeadMap.containsKey(l.Lead_Account__c)) {
                        acctLeadMap.put(l.Lead_Account__c,new List<Lead>());
                    }
                    acctLeadMap.get(l.Lead_Account__c).add(l);
                }
            } else {
                if (l.Lead_Account__c != null && oldLeadMap.get(l.Id).Lead_Account__c != l.Lead_Account__c) {
                    if (!acctLeadMap.containsKey(l.Lead_Account__c)) {
                        acctLeadMap.put(l.Lead_Account__c,new List<Lead>());
                    }
                    acctLeadMap.get(l.Lead_Account__c).add(l);
                }
            }
        }

        if (acctLeadMap.isEmpty()) { return; }

        Map<Id,Account> acctMap = new Map<Id,Account>([SELECT Id, OwnerId, Account_Status__c FROM Account WHERE Id IN: acctLeadMap.keySet()]);

        if (!acctMap.isEmpty()) {
            for (Id acctId : acctLeadMap.keySet()) {
                List<Lead> leads = acctLeadMap.get(acctId);
                Account a = acctMap.get(acctId);
                if (a.Account_Status__c == 'Active' && a.OwnerId != CG_AccountOwnership.getCGAPIUser()) {
                    for (Lead l : leads) {
                        if (l.OwnerId != a.OwnerId) {
                            l.OwnerId = a.OwnerId;
                        }
                    }
                }
            }
        }
    } // End assignLeadtoAcquistions Method
    
    /**
    * BR-4043 Static method to assign Owner on US/UK Leads using Round-Robin logic.
    * 020922 Update: we need to only trigger this function if running user is an external system
    * @author   Ramiro Alvarez    
    */
    public static void assignLeadOwnerWithRR(List<Lead> newLeadList, Map<Id,Lead> oldLeadMap) { 

        Map<String, List<String>> permissionsSettingsMap = new Map<String, List<String>> ();
        List<Permissions_Settings__mdt> permissionsSettings = [
            SELECT Label, Is_Active__c,Permission_Type__c
            FROM Permissions_Settings__mdt
            WHERE Object__c = 'Lead'
            AND (Permission_Type__c = 'AllowRoundRobinProfile' OR Permission_Type__c = 'AllowRoundRobin')
            AND Is_Active__c = true
        ];

        for (Permissions_Settings__mdt ps : permissionsSettings) {
            if (!permissionsSettingsMap.containsKey(ps.Permission_Type__c)) {
                permissionsSettingsMap.put(ps.Permission_Type__c, new List<String>());
            }
            permissionsSettingsMap.get(ps.Permission_Type__c).add(ps.Label);
        }

        //Query for Running User Profile
        User user = [
            SELECT Id, UserRole.Name, Profile.Name
            FROM User
            WHERE Id = :userinfo.getUserId()];
		
		// Get Allowed Profiles to perform Round Robing on created Leads
        List<String> allowedProfiles = permissionsSettingsMap.get('AllowRoundRobinProfile');
        if (allowedProfiles.contains(user.Profile.Name)) {            
        
            //Get Allowed Country Codes on Permissions Settings to apply RR
            List<String> activeCountryCodesRR = permissionsSettingsMap.get('AllowRoundRobin');

            Map<Id,Id> leadAccIdMap = new Map<Id,Id> ();
            List<Lead> leadsToUpd = new List<Lead> ();

            for (Lead lead : newLeadList) {
                if (activeCountryCodesRR.contains(lead.CountryCode)) {
                    leadAccIdMap.put(lead.Id,lead.Lead_Account__c);
                }
            }

            // If there are no Leads to apply RoundRobin, return.
            if (leadAccIdMap.isEmpty()) {
                return;
            }
            
            Map<Id,Account> acctMap = new Map<Id,Account>([
                SELECT Id, OwnerId, Account_Status__c
                FROM Account
                WHERE Id IN :leadAccIdMap.values()
            ]);

            for (Lead lead : newLeadList) {
                if (lead.LeadSource != 'Inbound: Phone' &&
                    activeCountryCodesRR.contains(lead.CountryCode) &&
                        (lead.Lead_Account__c == null ||
                        (acctMap.containsKey(lead.Lead_Account__c) &&
                        acctMap.get(lead.Lead_Account__c).OwnerId == CG_AccountOwnership.getCGAPIUser())))
                    {   
                        /* If lead is not associated to any dealer account or
                        * associated to dealer account owned by CGAPI, add to the list for RR
                        */
                        leadsToUpd.add(lead);
                    }
            }

            // Call RoundRobin Lead Helper
            if (!leadsToUpd.isEmpty()) {
                RoundRobinLeadHelper.roundRobinLeads(leadsToUpd, null);
            }
        }
    }
    
    //  LWC Methods
    @AuraEnabled
    public static void sendToRep(Id LeadId) {

        Lead leadToUpdate = [
            SELECT Id, OwnerId, Lead_Account__c,
             Lead_Account__r.OwnerId, Lead_Account__r.Dealer_Classification__c,
             Lead_Category__c, CountryCode, Lead_Account__r.Total_Used_Inventory__c
            FROM Lead 
            WHERE Id = :LeadId];
        
        String currentUserId = UserInfo.getUserId();
        User usr = [SELECT Id,UserRole.Name FROM User WHERE Id=:currentUserId];
        String currentUserRole = currentUserId.startsWith('005') ? usr.UserRole.Name : '';

        Set<String> allowedSDRRoles = String.isNotBlank(currentUserRole) ? allowedSDRRoles() : new Set<String>();

        Id leadAccount = leadToUpdate.Lead_Account__c;
        List<Round_Robin_User__c> rrUsersToUpdate = new List<Round_Robin_User__c>();

        //BR-3984
        Set<Id> SDRgbMemberIds = new Set<Id> ();
        Set<Id> ISTusMemberIds = new Set<Id> ();
        List<GroupMember> SDRgbGroupMembers = [
            SELECT Id, Group.DeveloperName, UserOrGroupId
            FROM GroupMember
            WHERE Group.DeveloperName IN ('RR_SDR_GB','RR_IST_US')
        ];

        for (GroupMember gm : SDRgbGroupMembers) {
            if (gm.Group.DeveloperName == 'RR_SDR_GB') {
                SDRgbMemberIds.add(gm.UserOrGroupId);
            }
            if (gm.Group.DeveloperName == 'RR_IST_US') {
                ISTusMemberIds.add(gm.UserOrGroupId);
            }
        }

            
        if (leadAccount == null) {
            throw new AuraHandledException('The Lead must have an Account in order to send to rep');
        }

        if (leadToUpdate.Lead_Category__c == '' || leadToUpdate.Lead_Category__c == null) {
            throw new AuraHandledException('In order to send to Rep, please select appropriate Lead Source indicating Inbound vs Outbound');
        }

        //BR-3984 - Capability to assign the Inbound lead to AE
        if (leadToUpdate.CountryCode == 'GB' &&
            leadToUpdate.Lead_Category__c == 'Inbound' &&
            SDRgbMemberIds.contains(leadToUpdate.OwnerId)) {

            RoundRobinLeadHelper.roundRobinLeads(new List<Lead>{leadToUpdate},'RR_AE_GB');

         //BR-4077 - US - Capability to assign the Inbound & Outbound lead to appropriate Sales team member
         } else if (leadToUpdate.CountryCode == 'US') {

            if (leadToUpdate.Lead_Account__r.OwnerId == CG_AccountOwnership.getCGAPIUser() &&
                leadToUpdate.Lead_Account__r.Total_Used_Inventory__c > 10 &&
                ISTusMemberIds.contains(leadToUpdate.OwnerId)) {

                    rrUsersToUpdate = getRoundRobinUsersByTty(leadToUpdate,leadAccount,'USIndependent');
                    
            } else if (leadToUpdate.Lead_Account__r.OwnerId == CG_AccountOwnership.getCGAPIUser()) {
                throw new AuraHandledException('The related total used inventory is less than 10, or the Lead Owner does not belongs to the Inbound Sales Team. ' +
                'Please communicate with Inbound Sales team in order to convert to an opportunity.');
            } else {
                throw new AuraHandledException('The related US Lead Account is not owned by CarGurus API.');
            }
        } else if( leadToUpdate.Lead_Account__r.OwnerId == CG_AccountOwnership.getCGAPIUser()) {

                rrUsersToUpdate = getRoundRobinUsersByTty(leadToUpdate,leadAccount,'Acquisitions');

        } else {
            leadToUpdate.OwnerId = leadToUpdate.Lead_Account__r.OwnerId;
        }

        if(!allowedSDRRoles.isEmpty() && allowedSDRRoles.contains(currentUserRole)){
            leadToUpdate.SDR__c = currentUserId;
        }

        try{
            update leadToUpdate;
            upsert rrUsersToUpdate;
        }
        catch(Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public static Set<String> allowedSDRRoles(){

        Set<String> allowedSDRRoles = new Set<String>();

        for(Permissions_Settings__mdt permissionSetting : [
            SELECT Id, Label 
            FROM Permissions_Settings__mdt 
            WHERE Permission_Type__c =:ALLOWED_PERMISSION_TYPE 
            AND Is_Active__c = true 
            AND Object__c = 'Lead'
        ]){
            allowedSDRRoles.add(permissionSetting.Label);
        }
        return allowedSDRRoles;
    }

    /*
    * Static method to return List of Round Robin Users for some specific Lead, Account Id and Role Name.
    */

    public static List<Round_Robin_User__c> getRoundRobinUsersByTty(Lead leadToUpdate, Id leadAccount, String roleName) {

        List<Round_Robin_User__c> rrUsersToUpdate = new List<Round_Robin_User__c>();
        
        ObjectTerritory2Association ota = [ SELECT Id, ObjectId, Territory2Id, Territory2.Name 
            FROM ObjectTerritory2Association 
            WHERE ObjectId =: leadAccount
            AND Territory2.Is_Granular__c = true
            AND Territory2.Territory2Model.State != 'Archived'];
        
        //Get Territory NAme
        String territoryName = ota.Territory2.Name;
        Map<String,Map<String,Round_Robin_User__c[]>> roundRobinUserMap = 
        RoundRobinTerritoryHelper.getSortedRoundRobinUserMap(new Set<String>{territoryName}, new Set<String>{roleName});

        Map<String,Round_Robin_User__c[]> usIndepUserMap = roundRobinUserMap.get(territoryName);
        if (usIndepUserMap != null) {

            Round_Robin_user__c[] rrUsers = usIndepUserMap.get(roleName);
            RoundRobinUserAssignment rrua = new RoundRobinUserAssignment(new List<Lead>{leadToUpdate}, rrUsers);
            rrUsersToUpdate.addAll(rrua.roundRobinAssignUser());
            return rrUsersToUpdate;
        } else {
            throw new AuraHandledException('No users assigned on the related Lead Account territory');
        }
    }

    @AuraEnabled
    public static void sendToQueue(Id LeadId) {

        Map<String,Id> leadQueueMap = Utilities.getLeadQueueMap();

        try{
            Lead LeadtoUpdate = [SELECT Id, OwnerId, CountryCode
                                 FROM Lead 
                                WHERE Id = :LeadId];

            if (leadCountryQueueMap.containsKey(LeadtoUpdate.CountryCode)) {
                LeadtoUpdate.OwnerId = leadQueueMap.get(leadCountryQueueMap.get(LeadtoUpdate.CountryCode));
                update LeadtoUpdate;
            } else {
                throw new AuraHandledException('The lead has no country address information therefore cannot be assigned to the proper Queue');
            }
        }
        catch(Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
    * BR-6610 Static method to set Country based on Account Billing Country
    * @author   Ramiro Alvarez
    */
    public static void setDefaultLeadCountry(List<Lead> newLeadList) {

        // Map to store Leads and related Account Id
        Map<Lead,Id> leadAccountIdMap = new Map<Lead,Id> ();
        for (Lead lead : newLeadList) {
            if (lead.Lead_Account__c != null) {
                leadAccountIdMap.put(lead,lead.Lead_Account__c);
            }
        }

        // If map is empty, just return
        if (leadAccountIdMap.isEmpty()) {
            return;
        }

        // Query Lead Accounts to get Billing Country
        Map<Id,Account> accountMap = new Map<Id,Account>( [
            SELECT Id, BillingCountry
            FROM Account
            WHERE Id IN :leadAccountIdMap.values()
        ]);

        // Stamp Lead Country based on Account Billing Country
        for (Lead lead : leadAccountIdMap.keySet()) {
            lead.Country = accountMap.get(leadAccountIdMap.get(lead)).BillingCountry;
        }

    }

    
    
}