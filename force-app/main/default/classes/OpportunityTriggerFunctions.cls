/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         amitul
* modifiedBy:     amitul
* created:        02/26/2021
* modified:       02/26/2021
* created jira:   BR-501
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class OpportunityTriggerFunctions {

   /**
    * Used to check if in future processing and if not call method to push to future.
    *
    * @author  Adam LaPlante
    * @date    01/21/2021
    * @module  BR-5187
    */

    public static void getAccountsForOppStatUpdate(List<Opportunity> newOppsList, Map<ID, Opportunity> oldMap) {

        Set<Id> accountIds = new Set<Id>();

        for (Opportunity opp : newOppsList) {

            Opportunity oldOpp = oldMap == null || oldMap.size() == 0 ? null : oldMap?.get(opp.Id);

            // if is new, or was just closed
            if(oldOpp == null) {
              if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
              }
            } else if (
                (oldOpp.OwnerId != opp.OwnerId) ||
                (oldOpp.StageName != opp.StageName) ||
                (!oldOpp.IsClosed && opp.IsClosed) ||
                (oldOpp.IsClosed && !opp.IsClosed)
              ) {
                accountIds.add(opp.AccountId);
            }
        }

        if (!accountIds.isEmpty()) {
          processOppStatUpdate(accountIds);
        }

    }



    /**
    * Used to check if in future processing and if not call method to push to future.
    *
    * @author  Adam LaPlante
    * @date    01/21/2021
    * @module  BR-5187
    */

    public static void processOppStatUpdate (Set<Id> accountIds) {
      // don't run with tests
      if (!Test.isRunningTest()) {
        // check if currently in batch or future context, if not invoke future method
        if (!System.isBatch() && !System.isFuture()) {
            // call method to return in future context
            processOppStatUpdateFuture(accountIds);
            return;
        }

        // process saturation changes
        updateAccountOppStatistics(accountIds);
      }

      return;
      
    }

  /**
    * Used to push processing context to future context to avoid mixed dml operations errors. 
    *
    * @author  Adam LaPlante
    * @date    01/21/2021
    * @module  BR-5187
    */

    @future
    private static void processOppStatUpdateFuture(Set<Id> accountIds) {
       // call back to main process opp stat update method
       processOppStatUpdate(accountIds);
   }


    /**
     * When opps are opened/closed, perform an account opp stats update
     *
     * @author  Adam LaPlante
     * @date    01/07/2022
     * @module  BR-5187
     */

    public static void updateAccountOppStatistics(Set<Id> accountIds) {

        // declare maps to associate accounts to 
        Map<Id, Integer> accOppOwnedByAcqMap = new Map<Id, Integer>();
        Map<Id, Integer> accOppOwnedByDRMap = new Map<Id, Integer>();

        // object maps
        Map<Id, List<AccountTeamMember>> accountToTeamMemberMap = new Map<Id, List<AccountTeamMember>>();
        Map<Id, List<Opportunity>> accountToOpportunityMap = new Map<Id, List<Opportunity>>();
        Map<Id, String> userRoleMap = new Map<Id, String>();

        // comparison lists
        List<String> drRoleCompareList = new List<String>();
        List<String> acqRoleCompareList = new List<String>();

        // accounts
        List<Account> accountsToUpdate = new List<Account>();

        Id sysAdminRoleId = Utilities.getrecordTypeId('UserRole', 'System_Administrator');
        
        // SOQL query for open opps related to accounts
        List<Opportunity> openOpps = [
            SELECT Id, OwnerId, Owner.UserRole.DeveloperName, AccountId 
            FROM Opportunity 
            WHERE AccountId 
            IN :accountIds 
            AND isClosed = false
            AND Owner_Role_Id__c != :sysAdminRoleId
        ];


        system.debug('openOpps::' + openOpps);

        // SOQL query for users / team member related to accounts
        List<User> accountTeamMemberList = [
            SELECT Id, Name, UserRole.DeveloperName, (SELECT AccountId, UserId,TeamMemberRole from AccountTeams)
            FROM User 
            WHERE Id 
            IN (SELECT UserId FROM AccountTeamMember WHERE AccountId IN :accountIds)
        ];

        system.debug('accountTeamMemberList:: ' + accountTeamMemberList);

        // organize user role map
        for (User u : accountTeamMemberList) {
            userRoleMap.put(u.Id, u.UserRole.DeveloperName);
        }


        // get map of all user map metadata
        Map<String,UserRole_ATMRole_Map__mdt> atmUserRoleMap = UserRole_ATMRole_Map__mdt.getAll();

        for (Id accId : accountIds) {
            accOppOwnedByAcqMap.put(accId, 0);
            accOppOwnedByDRMap.put(accId, 0);
        }

        List<Opportunity> opps = new List<Opportunity>();



        // organize accountToOpportunityMap
        for (Opportunity opp : openOpps) {

          if (!userRoleMap.containsKey(opp.OwnerId)) {
            userRoleMap.put(opp.OwnerId, opp.Owner.UserRole.DeveloperName);
          }

          if (accountToOpportunityMap.containsKey(opp.AccountId)) {
            opps = accountToOpportunityMap.get(opp.AccountId);
          } else { 
            opps = new List<Opportunity>();
          }

          if (accountIds.contains(opp.AccountId)) {
              opps.add(opp);
              accountToOpportunityMap.put(opp.AccountId, opps);
          }
            
        }

        system.debug('accountToOpportunityMap::' + accountToOpportunityMap);



        // organize accountToTeamMemberMap
        for (User u : accountTeamMemberList) {
            List<AccountTeamMember> teamMembers = new List<AccountTeamMember>();
            // if accountteams is not empty
            if (!u.AccountTeams.isEmpty()) {
                // loop on teammembers
                for (AccountTeamMember teamMember : u.AccountTeams) {
                    if (accountIds.contains(teamMember.AccountId)) {
                        if (accountToTeamMemberMap.containsKey(teamMember.AccountId)){
                            teamMembers = accountToTeamMemberMap.get(teamMember.AccountId);
                        }
                        teamMembers.add(teamMember);
                        accountToTeamMemberMap.put(teamMember.AccountId, teamMembers);
                    }
                }
            }
            
        }

        // organize user role map lists
        for (UserRole_ATMRole_Map__mdt atmUserRole : atmUserRoleMap.values()) {
            if (atmUserRole.Account_Team_Member_Role__c == 'Dealer Relations') {
                drRoleCompareList.add(atmUserRole.User_Role_Developer_Name__c);
            } else if (atmUserRole.Account_Team_Member_Role__c == 'Acquisitions') {
                acqRoleCompareList.add(atmUserRole.User_Role_Developer_Name__c);
            }
        }

        system.debug('drRoleCompareList::'+drRoleCompareList);
        system.debug('acqRoleCompareList::'+acqRoleCompareList);
        system.debug('atmUserRoleMap::'+atmUserRoleMap);



        // loop on accountids
        for (Id accountId : accountIds) {

            Integer openAcqOpps = 0;
            Integer openDROpps = 0;
            if (accountToOpportunityMap.containsKey(accountId)) {
              //  loop on opps for account
              for (Opportunity opp : accountToOpportunityMap.get(accountId)) {

                  String oppId = opp.Id;
                  String oppOwnerId = opp.OwnerId;
                  String oppOwnerRole = opp.Owner.UserRole.DeveloperName;

                  if (acqRoleCompareList.contains(userRoleMap.get(oppOwnerId))) {
                      system.debug('openAcqOppFound');
                      openAcqOpps += 1;
                      continue;
                  } else if (drRoleCompareList.contains(userRoleMap.get(oppOwnerId))) {
                      system.debug('openDROppFound');
                      openDROpps += 1;
                      continue;
                  }

                  // try block to handle possible null pointer exceptions
                  try {

                    if (accountToTeamMemberMap == null) {
                      continue;
                    }

                    // loop on account team members
                    for (AccountTeamMember teamMember : accountToTeamMemberMap.get(accountId)) {

                        // if the opp owner matches team member in current iteration
                        if (teamMember.UserId == opp.OwnerId) {

                            if (teamMember.TeamMemberRole.toLowerCase().contains('acquisitions')) {
                                system.debug('openAcqOppFound');
                                openAcqOpps += 1;
                            } else if (teamMember.TeamMemberRole.toLowerCase().contains('dealer relations')) {
                                system.debug('openDROppFound');
                                openDROpps += 1;
                            }

                            // break out out of teamMember loop
                            break;
                        }

                    } // end teamMember loop

                  } catch (Exception e) {
                    system.debug(e.getMessage());
                  }
   

              } // end opp loop
            
              accOppOwnedByAcqMap.put(accountId, openAcqOpps);
              accOppOwnedByDRMap.put(accountId, openDROpps);

            }

        } // end account loop

        system.debug('accOppOwnedByAcqMap::' + accOppOwnedByAcqMap);
        system.debug('accOppOwnedByDRMap::' + accOppOwnedByDRMap);

        // loop through acq map, set accounts to update
        for (Id accId : accOppOwnedByAcqMap.keySet()){
          // if an account is in both maps
          if (accOppOwnedByDRMap.containsKey(accId)) {
              accountsToUpdate.add(
                new Account(
                    Id = accId, 
                    Open_Opps_Owned_By_Acq_SUM__c = accOppOwnedByAcqMap.get(accId),
                    Open_Opps_Owned_By_DR_SUM__c = accOppOwnedByDRMap.get(accId)
                )
            );
            accOppOwnedByDRMap.remove(accId);
          // else just update acquisitions values
          } else {
              accountsToUpdate.add(
                new Account(
                    Id = accId, 
                    Open_Opps_Owned_By_Acq_SUM__c = accOppOwnedByAcqMap.get(accId)
                )
            );
          }
        }

        // loop through DR map, set accounts to update
        for (Id accId : accOppOwnedByDRMap.keySet()){
            accountsToUpdate.add(
                new Account(
                    Id = accId, 
                    Open_Opps_Owned_By_DR_SUM__c = accOppOwnedByDRMap.get(accId)
                )
            );
        }

        // insert updated accounts
        upsert accountsToUpdate;

    }
    
  //To populate Auto Close Date when a non-migrated Opportunity gets created
  public static void populateAutoCloseDate(List<Opportunity> newOppList){
    
    Map<String, Opp_Auto_Close__mdt> mapAutoCloseDays = Opp_Auto_Close__mdt.getAll();
    for(Opportunity opp: newOppList){
        if(!mapAutoCloseDays.isEmpty() && mapAutoCloseDays.containsKey(opp.Account_Country_Code__c)
           && (String.isBlank(opp.Legacy_Opportunity_ID__c))
        )
            opp.Auto_Close_Date__c = System.today().addDays(Integer.valueOf(mapAutoCloseDays.get(opp.Account_Country_Code__c).Days__c));
    }
  }

  //- Jira: BR-878
  //- Purpose: Create Pending Activation Tracker records when an opportunity is created
  public static void createTrackerRecords(List<Opportunity> newOpps){
      
      Map<Id,Opportunity_Tracker__c> trackers = new Map<Id,Opportunity_Tracker__c>();
      
      for (Opportunity opp : newOpps){
          Opportunity_Tracker__c tracker = new Opportunity_Tracker__c(
              name = opp.Name
          );
          trackers.put(opp.Id, tracker); 
      }

      insert trackers.values();
      
      for (Opportunity opp : newOpps){
          opp.Opportunity_Tracker__c = trackers.get(opp.Id).Id;
          
      }
  }

  // if retention opp is closed won before the effective cancellation date, then:
  //   - expire the cancellation quote
  //   - blank out autorenewal disable date
  public static void stopCancellationProcessingIfRetentionOppWon(Map<Id,Opportunity> oldMap, Map<Id,Opportunity> newMap) {

    Id retentionRTId = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity', 'Retention');
    Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>();

    for(Opportunity o : newMap.values()) {
      Boolean isRetentionOpp = retentionRTId == o.RecordTypeId;
      Boolean hasBeenClosedWon = o.IsClosed && o.IsWon && o.StageName != oldMap.get(o.Id).StageName;
      Boolean isInflightCancellation = o.SBQQ__AmendedContract__c != null;
      
      if(isRetentionOpp && hasBeenClosedWon && isInflightCancellation) {
        oppsMap.put(o.Id, o);
      }
    }

    // if there are no retention opps that have just been closed won, abort
    if(oppsMap.isEmpty()) {
      return;
    }

    // query related cases as we need the cancellation effective date
    Map<Id,Case> casesMap = new Map<Id,Case>([
      SELECT Id, Cancellation_Effective_Date__c, Related_Opportunity__c, 
        Related_Contract__c, Related_Contract__r.Auto_Renewal_Disable_Date__c
      FROM Case
      WHERE RecordType.Name = 'Cancellations'
        AND Case_Resolution__c = 'Full Cancellation'
        AND Related_Opportunity__c IN :oppsMap.keySet()
    ]);

    List<Contract> contracts = new List<Contract>();
    Map<Id, Contract> contractIdMap = new Map<Id, Contract>(contracts);
    Set<Id> savedRetentionOppsIds = new Set<Id>();

    for(Opportunity opp : oppsMap.values()) {

      Case cancellationCase = casesMap.get(opp.Cancellation_Case__c);
      Boolean cancellationDateInTheFuture = cancellationCase != null && cancellationCase.Cancellation_Effective_Date__c > System.today();

      Contract contr = new Contract(
        Id = opp.SBQQ__AmendedContract__c,
        Cancellation_Effective_Date__c = null
      );

      if(cancellationDateInTheFuture) {
        contracts.add(contr);
        savedRetentionOppsIds.add(opp.Id);
      }
    }

    if(savedRetentionOppsIds.isEmpty() && contracts.isEmpty()) {
      return;
    }

    List<SBQQ__Quote__c> cancellationQuotesToExpire = [
      SELECT Id, SBQQ__Status__c, SBQQ__ExpirationDate__c
      FROM SBQQ__Quote__c
      WHERE SBQQ__Opportunity2__c IN :savedRetentionOppsIds
    ];
    for(SBQQ__Quote__c quote : cancellationQuotesToExpire) {
      // quote.SBQQ__Status__c = 'Expired';
      quote.SBQQ__ExpirationDate__c = System.today();
    }

    update contracts;
    update cancellationQuotesToExpire;

  }
  
  
  /**
  * BR-4143 Determine if negative line items needs to be added (delta is represented on the Amount field)
  * @author   Ramiro Alvarez
  * @date       10/18/2021
  * @param    List<Opportunity> - Trigger.new
  * @return   void
  */
  public static void setRenewalDeltaLineItems(List<Opportunity> updated_opps) {
    
    Map<Id, Id> opp_contract_map = new Map<Id, Id>();
    for(Opportunity ren_opp : [SELECT Id, SBQQ__RenewedContract__c
      FROM Opportunity
      WHERE Id IN :updated_opps
      AND SBQQ__Renewal__c = true
      AND SBQQ__RenewedContract__c != null
      AND Id NOT IN 
        (SELECT OpportunityId FROM OpportunityLineItem WHERE OpportunityId IN :updated_opps
        AND Quantity < 0)])
    {
      opp_contract_map.put(ren_opp.Id, ren_opp.SBQQ__RenewedContract__c);
    }

    if(opp_contract_map.isEmpty()) {
      return;
    }

    List<OpportunityLineItem> delta_oli_insert = new List<OpportunityLineItem>();
    Map<Id,List<SBQQ__Subscription__c>> renewed_cpq_subs = getRenewedContractSubs(new Set<Id>(opp_contract_map.values()));

    Set<Id> productIds = new Set<Id> ();
    Set<String> currencyCodes = new Set<String> ();
    for (Id contractId : renewed_cpq_subs.keySet()) {
      for(SBQQ__Subscription__c sub : renewed_cpq_subs.get(contractId)) {
        productIds.add(sub.SBQQ__Product__c);
        currencyCodes.add(sub.CurrencyIsoCode);
      }
    }

    // Query for PriceBook Entries
    List<PricebookEntry> pbeList = [
      SELECT Id, Product2Id,CurrencyIsoCode
      FROM PricebookEntry
      WHERE Product2Id IN :productIds
      AND CurrencyIsoCode IN :currencyCodes
      AND isActive = true];

    // Prepare a map with following key: Product2Id + CurrencyIsoCode and PBE Id as value
      Map<String,Id> pricebookEntryMap = new Map<String,Id>();
    for (PricebookEntry pbe : pbeList) {
      pricebookEntryMap.put(pbe.Product2Id + pbe.CurrencyIsoCode, pbe.Id);

    }

    for(Id opp_id : opp_contract_map.keySet()) {

      Id ren_contract_id = opp_contract_map.get(opp_id);
      List<SBQQ__Subscription__c> cpq_subs = renewed_cpq_subs.get(ren_contract_id);
      if(cpq_subs == null) { continue; }

      for(SBQQ__Subscription__c cpq_sub : cpq_subs) {
        Id priceBookEntryId = pricebookEntryMap.get(cpq_sub.SBQQ__Product__c + cpq_sub.CurrencyIsoCode);
        OpportunityLineItem delta_oli = createOppLineItemForSub(opp_id, cpq_sub, priceBookEntryId);
        delta_oli_insert.add(delta_oli);
      }

    }
    
    if(!delta_oli_insert.isEmpty()) {
      insert delta_oli_insert;
    }
  }

  //- Jira: BR-4143 - Return Map with contract Id as key and the related list of subs as values.
  private static Map<Id, List<SBQQ__Subscription__c>> getRenewedContractSubs(Set<Id> renewed_contract_ids) {
    
    Map<Id, List<SBQQ__Subscription__c>> renewed_cpq_subs = new Map<Id, List<SBQQ__Subscription__c>>();
		for(SBQQ__Subscription__c sub : [SELECT Id, SBQQ__Contract__c, SBQQ__ProductId__c, SBQQ__Quantity__c,
      SBQQ__SubscriptionType__c, SBQQ__NetPrice__c, CurrencyIsoCode,SBQQ__Product__c
      FROM SBQQ__Subscription__c
      WHERE SBQQ__NetPrice__c > 0
      AND SBQQ__TerminatedDate__c = null 
      AND SBQQ__Contract__c IN :renewed_contract_ids]) {
        
			  Id contractId = sub.SBQQ__Contract__c;
        if(!renewed_cpq_subs.containsKey(contractId)) {
          renewed_cpq_subs.put(contractId, new List<SBQQ__Subscription__c>());
        } 
        renewed_cpq_subs.get(contractId).add(sub);
    }

    return renewed_cpq_subs;
  }

  //- Jira: BR-4143 - Create negatives Opportunity Line items to calculate delta
  private static OpportunityLineItem createOppLineItemForSub(Id opportunityId, SBQQ__Subscription__c cpq_sub, Id pbeId) {
    return new OpportunityLineItem(
      OpportunityId = opportunityId,
      Product2Id = cpq_sub.SBQQ__ProductId__c,
      Quantity = (-cpq_sub.SBQQ__Quantity__c),
      UnitPrice = cpq_sub.SBQQ__NetPrice__c,
      SBQQ__SubscriptionType__c = cpq_sub.SBQQ__SubscriptionType__c,
      PricebookEntryId = pbeId
    );
  }

  // Jira BR-3711: stamp Opportunity owner's role on Opp Split upon opportunity closed
  public static void stampOpportunitySplit(List<Opportunity> newOppsList, Map<ID, Opportunity> triggerOldMap) {
        
    Set<Id> oppIdSet = new Set<Id>();
    List<OpportunitySplit> oppSplitsToUpdate = new List<OpportunitySplit>();
        
    for (Opportunity opp : newOppsList) {
        if(!triggerOldMap.get(opp.Id).IsClosed && opp.IsClosed) {
        oppIdSet.add(opp.Id);
      }
    }
    
    if (oppIdSet.isEmpty()) {
      return;
    }
    
    for(OpportunitySplit oppSplit : [
      SELECT Id, Split_Owner_s_Role__c, Split_Owner_Role_when_Closed__c,
      Split_Owner_Title_when_Closed__c,Split_Owner_s_Title__c
      FROM OpportunitySplit 
      WHERE OpportunityId IN :oppIdSet
    ]) {
      oppSplit.Split_Owner_Role_when_Closed__c = oppSplit.Split_Owner_s_Role__c;
      oppSplit.Split_Owner_Title_when_Closed__c = oppSplit.Split_Owner_s_Title__c;
      oppSplitsToUpdate.add(oppSplit);
    }
    
    if(!oppSplitsToUpdate.isEmpty()) {
      update oppSplitsToUpdate;
    }
  }

  public static Id commissionSplitTypeId;
  public static Id retentionSplitTypeId;

  public static Id getSplitTypeIds(String type) {
      if (commissionSplitTypeId == null) {
          List<OpportunitySplitType> splitTypes = [SELECT Id, MasterLabel FROM OpportunitySplitType WHERE MasterLabel = 'Comp' OR MasterLabel = 'Retention'];
          for (OpportunitySplitType ost : splitTypes) {
              if (ost.MasterLabel == 'Retention') {
                  retentionSplitTypeId = ost.Id;
              } else {
                  commissionSplitTypeId = ost.Id;
              }
          }
      }
      return type == 'Retention' ? retentionSplitTypeId : commissionSplitTypeId;
  }

  public static void createOppSplitsForCommissions(List<Opportunity> opps, Map<Id,Opportunity> oldOppMap) {
    
        Id retentionRTId = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Retention');
        List<Opportunity> retentionOpps = new List<Opportunity>();
        List<Opportunity> normalOpps = new List<Opportunity>();
        List<OpportunitySplit> oliInserts = new List<OpportunitySplit>();
        Set<String> wonStages = new Set<String>{'Closed Won','Closed Saved'};

        for (Opportunity o : opps) {
            if (wonStages.contains(o.StageName) && !wonStages.contains(oldOppMap.get(o.Id).StageName)) {
                if (o.RecordTypeId == retentionRTId) {
                    retentionOpps.add(o);
                } else {
                    normalOpps.add(o);
                }
            }
        }

        if (retentionOpps.size() > 0 || normalOpps.size() > 0) {

          Id retentionSplitTypeId = getSplitTypeIds('Retention');
          Id commissionsSplitTypeId = getSplitTypeIds('Commissions');
          
          // SA-801 : get map of existing opp splits, get Ids of commissions and retention split types
          Map<Id, Set<Id>> oppsWithExistingSplits = getOppsWithExistingSplits(
              oldOppMap.keySet(), 
              new Set<Id>{retentionSplitTypeId, commissionsSplitTypeId}
          );

          // SA-801 : loop through opps with existing splits, removing them from opps lists
          for (Id oppId : oppsWithExistingSplits.keySet()) {
              
            // temp list used as buffer to do list augmentation  
            List<Opportunity> tempList = new List<Opportunity>();

            // loop through retention opps removing opp w/ existing splits if found
            for (Opportunity opp : retentionOpps) {
              tempList = retentionOpps.clone();
              if (
                  opp.Id == oppId && 
                  oppsWithExistingSplits.get(oppId).contains(retentionSplitTypeId)
                ){
                tempList.remove(retentionOpps.indexOf(opp));
              }
            }
            
            // if the templist has been trimmed, copy to retentionOpps
            if (!tempList.equals(retentionOpps)) {
              retentionOpps.clear();
              retentionOpps.addAll(tempList);
            }

              tempList.clear();

            // loop through normal opps removing opp w/ existing splits if found
            for (Opportunity opp : normalOpps) {
              tempList = normalOpps.clone();
              if (              
                  opp.Id == oppId && 
                  oppsWithExistingSplits.get(oppId).contains(commissionSplitTypeId)
              ){
                tempList.remove(normalOpps.indexOf(opp));
              }
            }
              
            // if the templist has been trimmed, copy to normal opps
            if (!tempList.equals(normalOpps)){
              normalOpps.clear();
              normalOpps.addAll(tempList);
            }
              
              tempList.clear();
          }

          oliInserts.addAll(createRetentionCommissionSplits(retentionOpps));
          oliInserts.addAll(createNormalCommissionSplits(normalOpps));

          insert oliInserts;
        }

    }
    
    
  /**
   * SA-801 : Returns a list of Opportunity Ids w/ existing Opp Splits
   */

  public static Map<Id, Set<Id>> getOppsWithExistingSplits(Set<Id> oppIds, Set<Id> oppSplitTypeIds) {

    Map<Id, Set<Id>> oppsWithExistingSplits = new Map<Id, Set<Id>> ();

    List<OpportunitySplit> existingOppSplits = [
      SELECT Id, OpportunityId, SplitTypeId
      FROM OpportunitySplit 
      WHERE OpportunityId IN :oppIds
      AND SplitTypeId IN :oppSplitTypeIds
    ];

    for (OpportunitySplit split : existingOppSplits){
      if (oppsWithExistingSplits.containsKey(split.OpportunityId)){
          Set<Id> splitTypeIdSet = oppsWithExistingSplits.get(split.OpportunityId);
          splitTypeIdSet.add(split.SplitTypeId);
      } else {
        oppsWithExistingSplits.put(
            split.OpportunityId, 
            new Set<Id> {split.SplitTypeId}
        );
      }
    }

    return oppsWithExistingSplits;
  }

  public static List<OpportunitySplit> createRetentionCommissionSplits(List<Opportunity> opps) {

      Map<Id,Opportunity> oppMap = new Map<Id,Opportunity>(opps);
      List<OpportunitySplit> oppSplitReturn = new List<OpportunitySplit>();


      Opportunity[] oppList = [SELECT Id, Original_Contract_Spend__c,
              Amount, OwnerId, Owner.UserRole.Name, Account.OwnerId, 
              (SELECT Id FROM OpportunityLineItems WHERE Quantity < 0) FROM Opportunity WHERE Id IN: oppMap.keySet()];

      for (Opportunity o : oppList) {
          if (o.Original_Contract_Spend__c != null) {
              Double retSplit = 0;
              if (!o.OpportunityLineItems.isEmpty()) {
                  if (o.Amount > 0) {
                      retSplit = o.Original_Contract_Spend__c;  //ex original Spend = 1000, Amount = 500, retSplit = 1000
                  } else {
                      retSplit = o.Original_Contract_Spend__c + o.Amount; //ex: original Spend = 1000, Amount = -300, retSplit = 700
                  }
              } else {
                  if (o.Amount > o.Original_Contract_Spend__c) {
                      retSplit = o.Original_Contract_Spend__c;  //ex: origiinal spend = 1000, Amount = 1500, retSplit = 1000
                  } else {
                      retSplit = o.Amount; //ex original Spend = 1000, Amount = 700, retSplit = 700
                  }
              }

              OpportunitySplit retentionSplit = new OpportunitySplit(
                  OpportunityId = o.Id,
                  SplitPercentage = retSplit/o.Original_Contract_Spend__c*100,
                  SplitOwnerId = o.OwnerId,
                  SplitTypeId = getSplitTypeIds('Retention')//,
                  //Split_Owner_Role_when_Closed__c = o.Owner.UserRole.Name
              );
              oppSplitReturn.add(retentionSplit);

              if (!o.OpportunityLineItems.isEmpty()) {
                  if (o.Amount > 0) {
                      OpportunityTeamMember otm = new OpportunityTeamMember(
                          OpportunityId = o.Id,
                          UserId = o.Account.OwnerId,
                          TeamMemberRole = 'Account Manager',
                          OpportunityAccessLevel = 'Edit'
                      );
                      insert otm;

                      OpportunitySplit commissionSplit = new OpportunitySplit(
                          OpportunityId = o.Id,
                          SplitPercentage = 100,
                          SplitOwnerId = o.Account.OwnerId,
                          SplitTypeId = getSplitTypeIds('Commissions')//,
                          //Split_Owner_Role_when_Closed__c = o.Account.Owner.UserRole.Name
                      );
                      oppSplitReturn.add(commissionSplit);
                  }
              } else {
                  if (o.Amount > o.Original_Contract_Spend__c) {
                      OpportunityTeamMember otm = new OpportunityTeamMember(
                          OpportunityId = o.Id,
                          UserId = o.Account.OwnerId,
                          TeamMemberRole = 'Account Manager',
                          OpportunityAccessLevel = 'Edit'
                      );
                      insert otm;

                      OpportunitySplit commissionSplit = new OpportunitySplit(
                          OpportunityId = o.Id,
                          SplitPercentage = (o.Amount - o.Original_Contract_Spend__c)/o.Amount*100,
                          SplitOwnerId = o.Account.OwnerId,
                          SplitTypeId = getSplitTypeIds('Commissions')//,
                          //Split_Owner_Role_when_Closed__c = o.Account.Owner.UserRole.Name
                      );
                      oppSplitReturn.add(commissionSplit);
                  }
              }
          }
      }

      return oppSplitReturn;

  }

  public static List<OpportunitySplit> createNormalCommissionSplits(List<Opportunity> opps) {
      Map<Id,Opportunity> oppMap = new Map<Id,Opportunity>(opps);
      List<OpportunitySplit> oppSplitReturn = new List<OpportunitySplit>();


      Opportunity[] oppList = [SELECT Id, Amount, OwnerId, Owner.UserRole.Name FROM Opportunity WHERE Id IN: oppMap.keySet()];

      for (Opportunity o : oppList) {
          OpportunitySplit commissionSplit = new OpportunitySplit(
              OpportunityId = o.Id,
              SplitPercentage = 100,
              SplitOwnerId = o.OwnerId,
              SplitTypeId = getSplitTypeIds('Commissions')//,
              //Split_Owner_Role_when_Closed__c = o.Owner.UserRole.Name
          );
          oppSplitReturn.add(commissionSplit);
      }

      return oppSplitReturn;
  }

  //Jira BR-4622- Process to clear out renewal eligible flag and renwal Status on account.
  public static void setRenewalEligibleToFalse(List<Opportunity> newOpps){
      
    Set<Id> contractID = new Set<Id>();
    Map<Id,Account> accsToUpdate = new Map<Id,Account>();
      
    for (Opportunity opp : newOpps){
        if(opp.SBQQ__RenewedContract__c!=null && opp.isClosed == True 
           && opp.recordTypeId==SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Renewal')){
          contractID.add(opp.SBQQ__RenewedContract__c);
        } 
    }

    if (!contractId.isEmpty()) {
        for (SBQQ__Subscription__c subs : [SELECT Id, Fulfillment_Account__c, Fulfillment_Account__r.Renewal_Eligible__c, Fulfillment_Account__r.Renewal_Status__c 
            FROM SBQQ__Subscription__c WHERE  SBQQ__Contract__c IN:contractID AND Fulfillment_Account__r.Renewal_Eligible__c = True]){
            
            Account acc = new Account();
            acc.Id = subs.Fulfillment_Account__c;
            acc.Renewal_Eligible__c = false;
            acc.Renewal_Status__c='';
            accsToUpdate.put(subs.Fulfillment_Account__c,acc);
            acc.ApprovalStatus__c ='';
        }

        if(!accsToUpdate.isEmpty()){
          update accsToUpdate.values();
        }
    }
  }

  public static void createContactRole(Map<Id,Opportunity> oldMap, Map<Id,Opportunity> newMap, boolean isNew){

    List<OpportunityContactRole> roleNeedToCreate = new List<OpportunityContactRole>();
	  for(Opportunity opp: newMap.values()){
		
        if(isNew && opp.QuotePrimaryContact__c != null){ 
        
            OpportunityContactRole ocr = new OpportunityContactRole();
            ocr.opportunityId = opp.id;
            ocr.contactId = opp.QuotePrimaryContact__c;
            ocr.Role = 'Business User';
            roleNeedToCreate.add(ocr);
        }
        else
        {
            if(opp.QuotePrimaryContact__c != null && opp.QuotePrimaryContact__c != oldMap.get(opp.Id).QuotePrimaryContact__c)
        {
          OpportunityContactRole ocr = new OpportunityContactRole();
          ocr.opportunityId = opp.id;
          ocr.contactId = opp.QuotePrimaryContact__c;
          ocr.Role = 'Business User';
          roleNeedToCreate.add(ocr);
        }
    }
            
	}
		if(!roleNeedToCreate.isEmpty())
			insert roleNeedToCreate;
  }  
  
  
  // SA-682 Set Default Values on Amendment Opportunity
  public static void setDefaultValuesOnAmend(List<Opportunity> newOpps) {

    Map<Id,Id> opptyContractIdMap = new Map<Id,Id> ();
    for (Opportunity oppty : newOpps) {
      if (oppty.SBQQ__AmendedContract__c != null) {
        oppty.Type = 'Existing Business';        
      }
    }
  }
  
  // SA-289 Update Opportunity Close Date when Closed Lost
  public static void updateClosedDateOnLost(List<Opportunity> newOpps, Map<Id,Opportunity> oldMap) {

    Map<Id,Id> opptyContractIdMap = new Map<Id,Id> ();
    for (Opportunity oppty : newOpps) {
      if (oppty.StageName == 'Closed Lost' && oppty.StageName != oldMap.get(oppty.Id).StageName) {
        oppty.CloseDate = System.today();
      }      
    }
  }

  //SA-436
  public static void setManagerEmail(List<Opportunity> opps, Map<Id,Opportunity> oldOpps){
    for (Opportunity opp : opps){
      if (oldOpps == null || (oldOpps != null && (opp.OwnerId != oldOpps.get(opp.Id).OwnerId || opp.Opp_Owner_Manager_Auto_Close__c == null))){
        opp.Opp_Owner_Manager_Auto_Close__c = opp.Opp_Owner_Manager_Email__c;
      }
    }
  }
}