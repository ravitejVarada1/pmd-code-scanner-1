/**
 * This class handles Opportunity Closed - Won/Lost events and sets up 
 * account ownership changes when certain criteria are met
 * BR-4002, BR-4004
 */
public class AccountOwnershipOppClosedEvent {
    
    //Some GB tty and account team member role constants
    public static final String GB_FAM_TTY_ROLE = 'FAM';
    public static final String GB_FAM_ATM_ROLE = 'Field Account Manager';
    public static final String GB_DR_TTY_ROLE = 'DRAM';
    public static final String GB_DR_ATM_ROLE = 'Dealer Relations';
    public static final String GB_CS_TTY_ROLE = 'Customer Success';

    //Some CA tty and account team member role constants
    public static final String CA_DR_TTY_ROLE = 'DRAM';
    public static final String CA_DR_ATM_ROLE = 'Dealer Relations';
    public static final String CA_AQ_ATM_ROLE = 'Acquisitions';


    //Map the territory role to the account team member role
    public static Map<String, String> ttyToAtmRoleMap = new Map<String, String>{
        GB_FAM_TTY_ROLE => GB_FAM_ATM_ROLE,
        GB_DR_TTY_ROLE => GB_DR_ATM_ROLE
    };
    
    //Field SDR and Field AE closing Opportunities > 1500
    public static final String CAT_FRANCHISE_LARGE = 'Franchise - Large';
    public static final String CAT_FRANCHISE_SMALL = 'Franchise - Small';
    public static final Set<String> GB_FLD_FRANCHISE_CATS = new Set<String>{CAT_FRANCHISE_SMALL, CAT_FRANCHISE_LARGE};

    public static List<String> oppGroupings = CG_AccountOwnership.oppGroupings;

    /**
     * Categorize into closed won or closed lost
     */
    public static void handleOpportunityUpdates(Map<Id,Opportunity> newOppMap, Map<Id,Opportunity> oldOppMap) {
        Map<Id, Opportunity> newClosedWonOpps = new Map<Id, Opportunity>();
        Map<Id, Opportunity> newClosedLostOpps = new Map<Id, Opportunity>();

        for(Opportunity newOpp : newOppMap.values()) {
            Id oppId = newOpp.Id;
            Opportunity oldOpp = oldOppMap.get(oppId);
            Boolean newIsClosed = newOpp.IsClosed;
            Boolean oldIsClosed = oldOpp.IsClosed;
            String stageName = newOpp.StageName;

            if(newIsClosed && !oldIsClosed && stageName == 'Closed Won') {
                newClosedWonOpps.put(newOpp.Id, newOpp);
            } else if(newIsClosed && !oldIsClosed && stageName == 'Closed Lost' ) {
                newClosedLostOpps.put(newOpp.Id, newOpp);
            }
        }

        if(!newClosedLostOpps.isEmpty()) {
            processClosedLostOpps(newClosedLostOpps);
        }

        if(!newClosedWonOpps.isEmpty()) {
            processClosedWonOpps(newClosedWonOpps);
        }
    }

    /**
     * Process closed won opps into different geographies
     */
    public static void processClosedWonOpps(Map<Id, Opportunity> newOppMap) {

        //get related accounts as a id => account map
        Set<Id> relatedAccounts = new Set<Id>();
        for(Opportunity newOpp: newOppMap.values()) {
            relatedAccounts.add(newOpp.AccountId);
        }
        Map<Id, Account> accountMap = CG_AccountOwnership.getAccounts(relatedAccounts); 

        Map<String, Map<Id, Opportunity>> closedWonOppMap = sortClosedWonOppsByCountry(newOppMap, accountMap);
        Map<Id, Opportunity> gbOpps = new Map<Id, Opportunity>();

        if(!closedWonOppMap.get('GB_Field').isEmpty()) {
            gbOpps.putAll(closedWonOppMap.get('GB_Field'));
        }

        if(!closedWonOppMap.get('GB_NonField').isEmpty()) {
            gbOpps.putAll(closedWonOppMap.get('GB_NonField'));
        }

        if(!gbOpps.isEmpty()) {
            processGBClosedWon(gbOpps, accountMap);
        }

        if(!closedWonOppMap.get('CA_All').isEmpty()) {
            updateAccountOwnerToDRAM(closedWonOppMap.get('CA_All'), accountMap);
        }
    }

    /**
     * BR-3970 - Return Opportunty InventoryCapThreshold Map
     * If all CG-BASE lines has Used_Inventory_Cap__c <= 10 then set true
     */
    public static Map<Id,Boolean> getInvCapThreshold(Set<Id> opptyIds) {

        Map<Id,Boolean> opptyInvCapThresholdMap = new Map<Id,Boolean> ();
        Map<Id,List<SBQQ__QuoteLine__c>> opptyQuoteLineMap = new Map<Id,List<SBQQ__QuoteLine__c>> ();

        // Query for related CG-BASE Quote Lines
        List<SBQQ__QuoteLine__c> quoteLines = [
            SELECT Id, Used_Inventory_Cap__c,
            SBQQ__Quote__r.SBQQ__Opportunity2__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__r.SBQQ__Opportunity2__c IN :opptyIds
            AND SBQQ__ProductCode__c = 'CG-BASE'
            ORDER BY SBQQ__Quote__r.SBQQ__Opportunity2__c];

        // Build OpportunityId -> QuoteLines Map
        for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
            if (!opptyQuoteLineMap.containsKey(quoteLine.SBQQ__Quote__r.SBQQ__Opportunity2__c)) {
                opptyQuoteLineMap.put(quoteLine.SBQQ__Quote__r.SBQQ__Opportunity2__c, new List<SBQQ__QuoteLine__c> ());
            }
            opptyQuoteLineMap.get(quoteLine.SBQQ__Quote__r.SBQQ__Opportunity2__c).add(quoteLine);
        }

        // Loop through OpportunityId -> QuoteLines Map 
        for (Id opportunityId : opptyQuoteLineMap.keySet()) {

            for (SBQQ__QuoteLine__c quoteLine : opptyQuoteLineMap.get(opportunityId)) {

                if (!opptyInvCapThresholdMap.containsKey(quoteLine.SBQQ__Quote__r.SBQQ__Opportunity2__c)) {
                    opptyInvCapThresholdMap.put(quoteLine.SBQQ__Quote__r.SBQQ__Opportunity2__c, true);
                }
                // If at least one CG-BASE quote line has Used Inv Cap > 10, then set false
                if (quoteLine.Used_Inventory_Cap__c > 10) {
                    opptyInvCapThresholdMap.put(quoteLine.SBQQ__Quote__r.SBQQ__Opportunity2__c, false);
                    break;
                }
            }
        }
        
        return opptyInvCapThresholdMap;
    }

    /**
     * Process closed lost opps, check if the accounts require to be returned to CGAPI 
     * as the owner
     */
    public static void processClosedLostOpps(Map<Id, Opportunity> newOppMap) {
        CG_AccountOwnership.returnAccountOwnerToCGAPIUser(newOppMap.values());
    }

    public static Map<String, Map<Id, Opportunity>> sortClosedWonOppsByCountry(Map<Id, Opportunity> newOppMap, 
        Map<Id, Account> accountMap) 
    {
        Map<String, Map<Id, Opportunity>> closedOppMap = new Map<String, Map<Id, Opportunity>>();

        for(String oppGroups : oppGroupings) {
            closedOppMap.put(oppGroups, new Map<Id, Opportunity>());
        }

        for(Opportunity newOpp : newOppMap.values()) {
            Account acct = accountMap.get(newOpp.AccountId);
            String billingCountry = newOpp.Account_Country_Code__c;
            Id oppId = newOpp.id;

            if(billingCountry == null) { 
                System.debug('Opp has no account country code: '+newOpp.id);
                continue; 
            }
            
            if(billingCountry == 'US') {
                if(acct.Field_Group_Type__c != null) {
                    closedOppMap.get('US_Field').put(newOpp.id, newOpp);
                } else {
                    closedOppMap.get('US_NonField').put(newOpp.id, newOpp);
                }
            }
            if(billingCountry == 'GB') {
                if(acct.Field_Group_Type__c != null) {
                    closedOppMap.get('GB_Field').put(newOpp.id, newOpp);
                } else {
                    closedOppMap.get('GB_NonField').put(newOpp.id, newOpp);
                }
            }
            if(billingCountry == 'CA') {
                closedOppMap.get('CA_All').put(newOpp.id, newOpp);
            }

        }

        return closedOppMap;
    }

    // Update account owner to FAM if all accounts are owned by Field
    public static void processGBClosedWon(Map<Id, Opportunity> newOppMap, Map<Id, Account> accountMap) {
        System.debug('processGBClosedWon::');

        Id cgUserId = CG_AccountOwnership.getCGAPIUser();

        Set<Id> accountIds = new Set<Id>();
        for(Opportunity o : newOppMap.values()) {
            accountIds.add(o.AccountId);
        }

        String transferToRole = GB_DR_TTY_ROLE;

        Map<Id, Account> accsToTransfer = new Map<Id, Account>();
        for(Id aId : accountIds) {
            Account a = accountMap.get(aId);
            if(a.Account_Saturation_Percentage_Formula__c == 0.00) {
                accsToTransfer.put(a.id, a);
            }
        }

        if(accsToTransfer.isEmpty()) {
            return;
        }

        Map<Id, String> accountTerritoryNameMap = new Map<Id, String>();

        List<ObjectTerritory2Association> lota;
        if(Test.isRunningTest()) {
            lota = [SELECT Id, ObjectId, Territory2.Name 
                FROM ObjectTerritory2Association 
                WHERE ObjectId IN :accsToTransfer.keySet()
                AND Territory2.Is_Granular__c = true];
        } else {
            lota = [SELECT Id, ObjectId, Territory2.Name 
                FROM ObjectTerritory2Association 
                WHERE ObjectId IN :accsToTransfer.keySet()
                AND Territory2.Is_Granular__c = true
                AND Territory2.Territory2Model.State = 'Active'];
        }

        for (ObjectTerritory2Association ota : lota)
        {
            accountTerritoryNameMap.put(ota.ObjectId, ota.Territory2.Name);
        }

        Map<String, Map<String, List<Account>>> accountsByRoleTerr = new Map<String, Map<String, List<Account>>>();
        Map<Id, String> accountToATMRoleMap = new Map<Id, String>();

        //BR-3970 Get Opportunity Inventory Cap Threshold Map
        Map<Id,Boolean> opptyUsedInventoryCapMap = getInvCapThreshold(newOppMap.keySet());

        for (Opportunity opp : newOppMap.values()){
            Id accountId = opp.AccountId;

            //Is transfer eligible?
            if(!accsToTransfer.containsKey(accountId)) {
                continue;
            }

            //Has territory assigned? Else will cause a null pointer
            if(!accountTerritoryNameMap.containsKey(accountId)) {
                continue;
            }

            //Account properties
            Account acc = accountMap.get(accountId);
            String fieldGroupType = acc.Field_Group_Type__c;
            String accountCategory = acc.Account_Category_Formula__c;
            String territoryName = accountTerritoryNameMap.get(accountId);

            System.debug('territoryName::'+territoryName);

            //Check if Opp amount exceeds threshold. If it does and the category is Franchise Large/Small
            //then transfer to FAM
            Decimal oppAmount = opp.Amount;
            Boolean isFldEligible = 
            ( (GB_FLD_FRANCHISE_CATS.contains(accountCategory) && oppAmount > 1500.0) || fieldGroupType != null );
            
            if(isFldEligible) {
                transferToRole = GB_FAM_TTY_ROLE;
            } else if (!opptyUsedInventoryCapMap.isEmpty() && fieldGroupType == null && opptyUsedInventoryCapMap.get(opp.Id)) {
                transferToRole = GB_CS_TTY_ROLE;
            } else {
                transferToRole = GB_DR_TTY_ROLE;
            }
            System.debug(transferToRole);

            //get the Account team member role 
            accountToATMRoleMap.put(accountId, ttyToAtmRoleMap.get(transferToRole));

            if (!accountsByRoleTerr.containsKey(territoryName)) {
                Map<String, List<Account>> accountsByRole = new Map<String, List<Account>>();
                List<Account> tmpAccounts = new List<Account>();
                tmpAccounts.add(acc);
                accountsByRole.put(transferToRole, tmpAccounts);
                accountsByRoleTerr.put(territoryName, accountsByRole);
            } else {
                Map<String, List<Account>> accountsByRole = accountsByRoleTerr.get(territoryName);
                if(!accountsByRole.containsKey(transferToRole)) {
                    List<Account> tmpAccounts = new List<Account>();
                    tmpAccounts.add(acc);
                    accountsByRole.put(transferToRole, tmpAccounts);
                } else {
                    accountsByRole.get(transferToRole).add(acc);
                }
                accountsByRoleTerr.put(territoryName, accountsByRole);
            }
        }

        //collect all the roles so we pass that to the class 
        //that finds the round robin users
        Set<String> allTransferRoles = new Set<String>();
        for(String ttyName : accountsByRoleTerr.keySet()) {
            Map<String, List<Account>> accountsByRole = accountsByRoleTerr.get(ttyName);
            allTransferRoles.addAll(accountsByRole.keySet());
        }

        // Start Round Robin
        Map<String, Map<String, List<Round_Robin_User__c>>> roundRobinUserMap = 
            RoundRobinTerritoryHelper.getSortedRoundRobinUserMap(accountsByRoleTerr.keySet(), allTransferRoles);
        RoundRobinUserAssignment rrua = new RoundRobinUserAssignment(accountsByRoleTerr, roundRobinUserMap);
        rrua.runRoundRobinAssignUser();
        List<Account> accountsUpdated = postRoundRobinUpdateAccounts(accountsByRoleTerr); 
        // End Round Robin

        CG_AccountOwnership.changeAccountOwner(accountsUpdated, accountToATMRoleMap, accountMap);
    } 

    public static List<Account> postRoundRobinUpdateAccounts(Map<String, Map<String, List<Account>>> accountsByRoleTerr) {
        
        List<Account> updatedAccounts = new List<Account>();
        for(String ttyName : accountsByRoleTerr.keySet()) {
            Map<String, List<Account>> accsByRole = accountsByRoleTerr.get(ttyName);

            for(String role : accsByRole.keySet()) {
                List<Account> accs = accsByRole.get(role);

                for(Account acc : accs) {
                    updatedAccounts.add(acc);
                }
            }
        }
        return updatedAccounts;
    }

    // Initially created to handle Canadian BoB and how Ownership passes hands. 
    public static void updateAccountOwnerToDRAM(Map<Id, Opportunity> newOppMap, Map<Id, Account> accountMap){
        String transferToRole = CA_DR_TTY_ROLE;

        List<Account> accountsToUpdate = new List<Account>();
        List<AccountTeamMember> accTeamMembers = new List<AccountTeamMember>();

        Map<Id,Id> accountIdOwnerIdMap = new Map<Id, Id>();
        Map<Id,Id> acctAcqUserMap = new Map<Id,Id>();
        Map<Id,Id> acctDRUserMap = new Map<Id,Id>();   
        
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity o : newOppMap.values()) {
            accountIds.add(o.AccountId);
        }

        //Only transfer if saturation is currently 0, else already owned by DR
        Map<Id, Account> accsToTransfer = new Map<Id, Account>();
        for(Id aId : accountIds) {
            Account a = accountMap.get(aId);
            if(a.Account_Saturation_Percentage_Formula__c == 0.00) {
                accsToTransfer.put(a.Id, a);
            }
        }

        if(accsToTransfer.isEmpty()) {
            return;
        }

        Map<String, Map<String, List<Account>>> accountsByRoleTerr = new Map<String, Map<String, List<Account>>>();

        //Test specific query
        List<ObjectTerritory2Association> lota;
        
        if(Test.isRunningTest()) {
            lota = [SELECT Id, ObjectId, Territory2Id, Territory2.Name 
                FROM ObjectTerritory2Association WHERE ObjectId IN: accsToTransfer.keySet()
                AND Territory2.Is_Granular__c = true];
        } else {
            lota = [SELECT Id, ObjectId, Territory2Id, Territory2.Name 
                FROM ObjectTerritory2Association WHERE ObjectId IN: accsToTransfer.keySet()
                AND Territory2.Is_Granular__c = true
                AND Territory2.Territory2Model.State = 'Active'];
        }

        // grab territory ids from the ObjectTerritory2Association.ObjectId values that
        // Opportunity.AccountId is associated to.  This query may need refinement when 
        // additional territories come onboard and language preference
        for (ObjectTerritory2Association ota : lota)
        {
            System.debug('In OTA loop');
            Account a = accountMap.get(ota.ObjectId);
            if(a.Field_Group_Type__c != null) {
                continue;
            }
            
            //add to territory map to process DR rep
            if(accountsByRoleTerr.containsKey(ota.Territory2.Name)) {
                Map<String, List<Account>> accountsByRole = accountsByRoleTerr.get(ota.Territory2.Name);
                accountsByRole.get(transferToRole).add(a);
            } else {
                Map<String, List<Account>> accountsByRole = new Map<String, List<Account>>();
                List<Account> aList = new List<Account>();
                aList.add(a);
                accountsByRole.put(transferToRole, aList);
                accountsByRoleTerr.put(ota.Territory2.Name, accountsByRole);
            }
        }

        //Start Round Robin//
        Map<String,Map<String,Round_Robin_User__c[]>> roundRobinUserMap = 
            RoundRobinTerritoryHelper.getSortedRoundRobinUserMap(accountsByRoleTerr.keySet(), new Set<String>{CA_DR_TTY_ROLE});
        RoundRobinUserAssignment rrua = new RoundRobinUserAssignment(accountsByRoleTerr, roundRobinUserMap);
        rrua.runRoundRobinAssignUser();
        List<Account> accountsUpdated = postRoundRobinUpdateAccounts(accountsByRoleTerr); 
        SYstem.debug(accountsUpdated.size());
        //End Round Robin//
        

        //Post Round Robin updates
        for(Account a: accountsUpdated) {
            accountIdOwnerIdMap.put(a.id, a.OwnerId);
            accTeamMembers.add(CG_AccountOwnership.createAccountTeamMember(a.Id, CA_DR_ATM_ROLE, a.OwnerId, 'Edit', 'Edit', 'Edit', 'Edit'));
        }
        
        Database.SaveResult[] memberResults = Database.insert(accTeamMembers, false);
        CG_AccountOwnership.processResults(memberResults);

        CG_AccountOwnership.updateAccountOwner(accountIdOwnerIdMap, CA_DR_ATM_ROLE, false);
        
        if(!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    } 

    //populates account team members into the collections passed
    //in the arguments
    public static void getAccountTeamMembers(Map<Id, Account> accountMap, Map<Id,Id> acctAcqUserMap, 
        Map<Id, Id> acctDRUserMap) 
    {
        for (Account a : accountMap.values()) {
            for (AccountTeamMember atm : a.AccountTeamMembers) {
                if (atm.TeamMemberRole == CA_AQ_ATM_ROLE) {
                    acctAcqUserMap.put(a.Id,atm.UserId);
                } else if (atm.TeamMemberRole == CA_DR_ATM_ROLE) {
                    acctDRUserMap.put(a.Id,atm.UserId);
                }
            }
        }
    }
}