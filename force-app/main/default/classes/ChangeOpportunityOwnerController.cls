/**
* Controller class for ChangeOpportunityOwnerController LWC
* @author 	Ramiro Alvarez
* @date 	  12/23/2021
* @module   BR-3994 and BR-3992
*/

public without sharing class ChangeOpportunityOwnerController {

    /**
    * BR-3994/3972 Send opportunity to FAE/AE and update account ownership only if saturation is 0
    */

    @AuraEnabled
    public static void sendOppty(String recordId, String groupName) {
        
        // Sanity check
        if (recordId == null || groupName == null) {
            return;
        }

        //Query for Logged User Profile
        User userProfile = [
            SELECT Id, UserRole.Name, Profile.Name
            FROM User
            WHERE Id = :userinfo.getUserId()];

        // Only allow to send to Field AE if logged user is from Field SDR, Sys Admin or Sales Ops
        if (groupName == 'RR_Field_AE_GB' &&
            userProfile.UserRole.Name != ConstantsUtil.GB_ROLE_FIELD_SDR &&
            !(userProfile.Profile.Name == ConstantsUtil.SYSTEM_ADMIN || userProfile.Profile.Name == ConstantsUtil.SALES_OPS))
        {
            throw new AuraHandledException('Your User Role does not have permissions to send Opportunity to Field AE');
        }
        // Only allow to send to AE if logged user is from Outbound SDR, Sys Admin or Sales Ops
        if (groupName == 'RR_AE_GB' &&
            userProfile.UserRole.Name != ConstantsUtil.GB_ROLE_OUTBOUND_SDR &&
            !(userProfile.Profile.Name == ConstantsUtil.SYSTEM_ADMIN || userProfile.Profile.Name == ConstantsUtil.SALES_OPS))
        {
            throw new AuraHandledException('Your User Role does not have permissions to send Opportunity to Account Executive');
        }
        
        // Query for related Opportunity
        List<Opportunity> opps = [
            SELECT Id, OwnerId, AccountId, SBQQ__PrimaryQuote__c,
            Account.Account_Saturation_Percentage_Formula__c
            FROM Opportunity
            WHERE Id = :recordId];

        //Get Previous Owner Id to update Opportunty Team Member Role
        Id oldOwnerId = opps[0].OwnerId;
        Decimal accountSaturation = opps[0].Account.Account_Saturation_Percentage_Formula__c;
        
        // Validate if Total Used Inventory Car is not greater than 10
        Id quoteId = opps[0].SBQQ__PrimaryQuote__c;
        if (groupName == 'RR_AE_GB') {
            Boolean preventSendToAEflag = false;
            List<SBQQ__QuoteLine__c> quotesLines = new List<SBQQ__QuoteLine__c> ();
            if (quoteId != null) {
                quotesLines = [
                    SELECT Id, Used_Inventory_Cap__c
                    FROM SBQQ__QuoteLine__c
                    WHERE SBQQ__Quote__c = :quoteId
                    AND SBQQ__ProductCode__c = 'CG-BASE'];

                // If Used Inventory Cap is less or equal than 10, do not allow send Oppty to AE
                for (SBQQ__QuoteLine__c quoteLine : quotesLines) {
                    if (quoteLine.Used_Inventory_Cap__c <= 10) {
                        preventSendToAEflag = true;
                        break; // If at least one is less or equal than 10, break
                    }
                }
            }

            preventSendToAEflag = (quoteId == null || quotesLines.isEmpty()) ? true : preventSendToAEflag;
            if (preventSendToAEflag) {
                throw new AuraHandledException('Opportunity cannot be sent to AE: Used Car Inventory contracted is less or equal than 10');
            }
        }

        //Call Round Robin framework
        Set<String> groupNames = new Set<String> {groupName};
        Map<String, List<Round_Robin_User__c>> roundRobinUserMap = new Map<String, List<Round_Robin_User__c>>();
        List<Round_Robin_User__c> rrUsersToUpdate = new List<Round_Robin_User__c>();
        roundRobinUserMap = RoundRobinUserHelper.getSortedRoundRobinUserMap(groupNames);
        List<Round_Robin_User__c> rrUsers = roundRobinUserMap.get(groupName);
        RoundRobinUserAssignment rrua = new RoundRobinUserAssignment(opps, rrUsers);
        rrUsersToUpdate.addAll(rrua.roundRobinAssignUser());        
        
        update opps;
        upsert rrUsersToUpdate;

        //Change Owner on the related accounts
        if (accountSaturation == 0) {
            changeAccountOwner(opps[0].AccountId,opps[0].OwnerId);
        }

        //BR-6262 Change Primary Quote's owner to be same as new Oppty Owner
        if (quoteId != null) {
            SBQQ__Quote__c primaryQuote = new SBQQ__Quote__c(Id = quoteId, OwnerId = opps[0].OwnerId);
            update primaryQuote;
        }

        // Update Opportunity Team Member for Field SDR user
        List<OpportunityTeamMember> opptyTeamMembers = [
            SELECT Id, TeamMemberRole
            FROM OpportunityTeamMember
            WHERE UserId = :oldOwnerId
            AND OpportunityId = :recordId];

        for (OpportunityTeamMember otm : opptyTeamMembers) {
            otm.TeamMemberRole = groupName == 'RR_Field_AE_GB' ? ConstantsUtil.GB_ROLE_FIELD_SDR : ConstantsUtil.GB_ROLE_OUTBOUND_SDR;
        }
        if (!opptyTeamMembers.isEmpty()) {
            update opptyTeamMembers;
        }
        
    }    

    /**
     * Update ownership of the account hierarchy when required.
     */
    
    public static void changeAccountOwner(Id accountId, Id ownerId) {
        
        List<Account> allAccsToUpdate = new List<Account>();
        List<Account> account = [
            SELECT Id, Ultimate_Parent_Account__c
            FROM Account
            WHERE Id = :accountId];

        //Get Ultimate Parent Account Id
        Id ultimateParentAccId = account[0].Ultimate_Parent_Account__c == null ? account[0].Id : account[0].Ultimate_Parent_Account__c;

        List<Account> accountsToUpd = [SELECT Id, Ultimate_Parent_Account__c
            FROM Account
            WHERE Ultimate_Parent_Account__c = :ultimateParentAccId
            OR Id = :ultimateParentAccId];

        for (Account acc : accountsToUpd) {            
            acc.OwnerId = ownerId;            
        }
        
        if(!accountsToUpd.isEmpty()) {
            update accountsToUpd;
        }
    }

    /**
    * @description return true if logged user has permissions to access feature. Return false in otherwise.
    * @param null
    */
    
    @AuraEnabled(cacheable=true)
    public static Boolean checkUserRole() {

        Set<String> activeProfiles = new Set<String> ();
        
        //Query for Active Permissions Settings
        for (Permissions_Settings__mdt profile : [
            SELECT Label, Is_Active__c
            FROM Permissions_Settings__mdt
            WHERE Object__c = 'Opportunity'
                AND Permission_Type__c = 'AllowSendToAE'
                AND Is_Active__c = true
        ]) {
            activeProfiles.add(profile.Label);
        }

        //Query for Logged User Profile
        User user = [
            SELECT Id, UserRole.Name, Profile.Name
            FROM User
            WHERE Id = :userinfo.getUserId()];
		
		if (activeProfiles.contains(user.UserRole.Name) ||
          user.Profile.Name == ConstantsUtil.SYSTEM_ADMIN ||
          user.Profile.Name == ConstantsUtil.SALES_OPS) {
            return true;
        } else {
            return false;
        }
    }
}