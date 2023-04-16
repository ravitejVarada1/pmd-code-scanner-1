/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ngoldy
* created:        06/22/2021
* modified:       06/22/2021
* created jira:   BR-1844
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public without sharing class CGR_Functions {

  // set of CGR Rep eligibility fields (matrix)
  private static Set<String> getEligibilityFields() {
    return new Set<String> {
      'CGR_Eligible_Data__c',
      'CGR_Eligible_Digital_Retail__c',
      'CGR_Eligible_Display__c',
      'CGR_Eligible_Listings__c',
      'CGR_Eligible_PistonHeads__c',
      'CGR_Eligible_Website_Inventory__c'
    };
  }

  // map of start-of-quarter fields (CGR) and their account field counterpart 
  private static Map<String,String> getStartMappings() {
    return new Map<String,String> {
      'Starting_Amount_Data__c' => 'Data_CMRR__c',
      'Starting_Amount_Digital_Retail__c' => 'Digital_Retail_CMRR__c',
      'Starting_Amount_Display__c' => 'Display_CMRR__c',
      'Starting_Amount_Listings__c' => 'Listings_CMRR__c',
      'Starting_Amount_PistonHeads__c' => 'PistonHeads_CMRR__c',
      'Starting_Amount_Website_Inventory__c' => 'Website_Inventory_CMRR__c',
      'Account_Product_Activation_Status_Start__c' => 'Product_Activation_Status__c',
      'Starting_Customer_Type__c' => 'Type'
    };
  }

  // map of end-of-quarter fields (CGR) and their account field counterpart
  private static Map<String,String> getEndMappings() {
    return new Map<String,String> {
      'Ending_Amount_Data__c' => 'Data_CMRR__c',
      'Ending_Amount_Digital_Retail__c' => 'Digital_Retail_CMRR__c',
      'Ending_Amount_Display__c' => 'Display_CMRR__c',
      'Ending_Amount_Listings__c' => 'Listings_CMRR__c',
      'Ending_Amount_PistonHeads__c' => 'PistonHeads_CMRR__c',
      'Ending_Amount_Website_Inventory__c' => 'Website_Inventory_CMRR__c',
      'Account_Product_Activation_Status_End__c' => 'Product_Activation_Status__c',
      'Ending_Customer_Type__c' => 'Type'
    };
  }
    
  // create CGR records for supplied Accounts with quarter start values
  // also update previous CGR records with end values (current)
  public static void createAndUpdateCgrRecords(List<Account> accounts) {
    
    List<Account_CGR__c> cgrsToInsert = new List<Account_CGR__c>();
    List<Account_CGR__c> cgrsToUpdate = new List<Account_CGR__c>();
    
    for (Account acc : accounts) {

      Boolean isFormerCustomer = (acc.Product_Activation_Status__c == 'Restricted – Activated' && acc.Type == 'Former Customer');

      if((acc.Account_CGRs__r == null || (acc.Account_CGRs__r).isEmpty()) && !isFormerCustomer) {
        // if there's no previous CGR, create one and put 0 as start values
        // and end values with the current CMRR ones
        cgrsToInsert.add(createCgrForPreviousQuarter(acc));
      }
      else {
        // if there's a previous CGR, update the end values with the current CMRR ones
        cgrsToUpdate.add(updatePreviousCgrEndValues(acc.Account_CGRs__r[0], acc));
      }

      // create the new CGR for the new quarter, and populate start values
      if(!isFormerCustomer) {
        cgrsToInsert.add(createCgrForCurrentQuarter(acc));
      }
    }
    insert cgrsToInsert;
    update cgrsToUpdate;

  }

  // create and return an CGR record for the previous quarter. 
  // start values will be 0, end values will be the current account values
  private static Account_CGR__c createCgrForPreviousQuarter(Account acc) {
    Account_CGR__c newCgr = new Account_CGR__c(
      Name = getQuarterString(System.today().addMonths(-3)),
      Account__c = acc.Id,
      CGR_Start_Date__c = System.today().addMonths(-3),
      CurrencyIsoCode = acc.CurrencyIsoCode
    );

    // populate start values with 0
    Map<String,String> startFieldsMap = getStartMappings();
    for(String startField : startFieldsMap.keySet()) {
      if(startField != 'Account_Product_Activation_Status_Start__c' && startField != 'Starting_Customer_Type__c') {
        newCgr.put(startField, 0);
      }
    }

    // populate end values from the account values
    Map<String,String> endFieldsMap = getEndMappings();
    for(String endField : endFieldsMap.keySet()) {
      newCgr.put(endField, acc.get(endFieldsMap.get(endField)));
    }

    return newCgr;
  }

  // update (no DML) and return an existing CGR record (typically for the previous quarter). 
  // end values will be set to the current account values
  private static Account_CGR__c updatePreviousCgrEndValues(Account_CGR__c cgr, Account acc) {

    // populate end values from the account values
    Map<String,String> endFieldsMap = getEndMappings();
    for(String endField : endFieldsMap.keySet()) {
      cgr.put(endField, acc.get(endFieldsMap.get(endField)));
    }
    return cgr;

  }

  // create and return an CGR record for the current quarter. 
  // start values will be set to the current account values
  private static Account_CGR__c createCgrForCurrentQuarter(Account acc) {

    Account_CGR__c newCgr = new Account_CGR__c(
      Name = getQuarterString(System.today()),
      Account__c = acc.Id,
      CGR_Start_Date__c = System.today(),
      CurrencyIsoCode = acc.CurrencyIsoCode
    );

    // populate start values with current account values
    Map<String,String> startFieldsMap = getStartMappings();
    for(String startField : startFieldsMap.keySet()) {
      newCgr.put(startField, acc.get(startFieldsMap.get(startField)));
    }
    return newCgr;
  }

  // create one CGR Rep record per eligible account team member for each CGR
  public static void createCgrRepRecords(List<Account_CGR__c> cgrList) {

    List<Id> accountIds = new List<Id>();
    Map<Id,List<AccountTeamMember>> atmsMap = new Map<Id,List<AccountTeamMember>>();
    List<Account_CGR_Rep__c> cgrReps = new List<Account_CGR_Rep__c>();
    Map<String,CGR_Product_Eligibility_Matrix__mdt> matrixRolesMap = new Map<String,CGR_Product_Eligibility_Matrix__mdt>();

    // query metadata: eligibility matrix
    for(CGR_Product_Eligibility_Matrix__mdt m : [
      SELECT MasterLabel, CGR_Rep_Role__c, CGR_Eligible_Data__c, CGR_Eligible_Digital_Retail__c,
        CGR_Eligible_Display__c, CGR_Eligible_Listings__c, CGR_Eligible_Pistonheads__c, CGR_Eligible_Website_Inventory__c
      FROM CGR_Product_Eligibility_Matrix__mdt
    ]) {
      matrixRolesMap.put(m.CGR_Rep_Role__c, m);
    }

    for(Account_CGR__c cgr : cgrList) {
      accountIds.add(cgr.Account__c);
    }

    // query account team members that have eligible CGR roles
    for(AccountTeamMember atm : [
      SELECT Id, AccountId, UserId, TeamMemberRole, User.Name
      FROM AccountTeamMember
      WHERE AccountId IN :accountIds
        AND TeamMemberRole IN :matrixRolesMap.keySet()
    ]) {
      if(!atmsMap.containsKey(atm.AccountId)) {
        atmsMap.put(atm.AccountId, new List<AccountTeamMember>());
      }
      atmsMap.get(atm.AccountId).add(atm);
    }

    for(Account_CGR__c cgr : cgrList) {
      List<AccountTeamMember> atms = atmsMap.get(cgr.Account__c);
      if(atms == null) {
        // future enhancement: log error if an account doesn't have team members
        continue;
      }

      for(AccountTeamMember atm : atms) {
        // for each Account Team Member on each CGR, create an CGR Rep record
        cgrReps.add(
          createCgrRep(cgr, atm, matrixRolesMap.get(atm.TeamMemberRole))
        );
      }
    }

    insert cgrReps;

  }

  // construct quarter string for Account CGR name
	public static String getQuarterString(Date d) {
		return String.valueOf(d.year())+' - Q'+String.valueOf(Math.ceil(Double.valueOf(d.month())/3).longValue());
	}

  private static Account_CGR_Rep__c createCgrRep(Account_CGR__c cgr, AccountTeamMember atm, CGR_Product_Eligibility_Matrix__mdt mdt) {
    Account_CGR_Rep__c cgrRep = new Account_CGR_Rep__c(
      Account_CGR__c = cgr.Id,
      CGR_Rep__c = atm.UserId,
      Name = atm.TeamMemberRole + ' - ' + atm.User.Name,
      CGR_Role__c = atm.TeamMemberRole,
      CurrencyIsoCode = cgr.CurrencyIsoCode
    );

    for(String field : getEligibilityFields()) {
      cgrRep.put(field, mdt.get(field));
    }

    return cgrRep;

  }

}