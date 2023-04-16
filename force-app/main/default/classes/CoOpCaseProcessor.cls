/**
 * @description       : 
 * @author            : alaplante
 * @group             : 
 * @last modified on  : 09/14/2022
 * @last modified by  : alaplante
**/

public class CoOpCaseProcessor {

   /**
   * Creates co-op cases
   */

  public static List<Case> createCoOpCases(Map<Id, OrderItem> newOrderItemsMap, Map<Id, OrderItem> oldOrderItemsMap) {

    Set<Id> fulfillmentAccsForCoop = new Set<Id>();
    List<OrderItem> activatedOrderItemsList = new List<OrderItem>();
    List<Case> createCaseList = new List<Case>();
      
    // consider only 
    for(OrderItem oi : newOrderItemsMap.values()) {
        if (
            oi.SBQQ__Status__c == 'Activated' && 
            oi.SBQQ__Status__c != oldOrderItemsMap.get(oi.id).SBQQ__Status__c &&
            oi.Potential_Co_Op_Eligible__c && 
            oi.SBQQ__ContractAction__c != 'Cancel'
        ) {
                fulfillmentAccsForCoop.add(oi.Fulfillment_Account__c);
        }
    }

    Id coopCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Co-Op').getRecordTypeId();
    Map<String, Id> caseQueueWithIds = Utilities.getCaseQueueMap();
    Map<Id,List<String>> accsToOEMMap = getOEMs(fulfillmentAccsForCoop);
    Map<String, String> oemToDivisionMap = getOEMtoDivisionMap();
    Map<Id, List<String>> accToDivisionMap = new Map<Id, List<String>>();
    
    // loop through accounts
    for(Account a : getAccountList(accsToOEMMap)) {

        // put account id in account to group map
        accToDivisionMap.put(a.Id, new List<String>());

        // loop through each oem for accounts
        for(String s : accsToOEMMap.get(a.Id)) {
            String oemDivision = oemToDivisionMap.get(s);
            List<String> accDivisionList = accToDivisionMap.get(a.Id);
            // if this account doesn't already have a case for this division
            if (
				(oemDivision != null &&
                !accDivisionList.contains(oemDivision)) ||
                oemDivision == null || oemDivision == ''
            ) {
                // create a new co-op case, add to case list to return
                createCaseList.add(
                    new Case(
                        AccountId = a.Id,
                        OwnerId = caseQueueWithIds.get('Co-Op Queue'),
                        Subject = 'Potential Co-Op for ' + a.Name,
                        RecordTypeId = coopCaseRecordTypeId,
                        Origin = 'Sales Rep',
                        Priority = 'Medium',
                        Reason = 'Co-Op Team Approval',
                        Co_Op_OEM__c = s,
                        Co_Op_Division__c = oemToDivisionMap.get(s)
                    )
                );

                if (oemToDivisionMap.get(s) != null && oemToDivisionMap.get(s) != '') {
                    // add OEM division to accounts mapped list
                    accToDivisionMap.get(a.Id).add(oemToDivisionMap.get(s));
                }
            }
        }
    }
     return createCaseList; //BR-7299
    //insert createCaseList;
  }

  /*
  * getter for accounts in accsToOEMMap
  */

  public static List<Account> getAccountList(Map<Id,List<String>> accsToOEMMap) {
    return
    [
        SELECT Id, Name 
        FROM Account
        WHERE Id 
        IN :accsToOEMMap.keySet()
    ];

  }

   /**
   * Gets OEMs for co-op
   */

  public static Map<Id,List<String>> getOEMs(Set<Id> ffAcctIds) {

    // setup map of account id to OEM name
    Map<Id,List<String>> accIdToOEM = new Map<Id,List<String>>();

    // setup map of coop program names
    Map<String, String> coopProgramNames = getCoOpProgramsMap();

    for (
        Service_Provider__c sp : [
            SELECT ID, Account__c, New_Makes_Sold__c 
            FROM Service_Provider__c
            WHERE Account__c 
            IN :ffAcctIds 
            AND New_Makes_Sold__c != null
        ]
    ) {

        List<String> newMakes = sp.New_Makes_Sold__c.split(', ');

        for(String s : newMakes) {

            String normalizedString = s.toLowerCase();

            if(coopProgramNames.keySet().contains(normalizedString)) {

                if(!accIdToOEM.keySet().contains(sp.Account__c)){
                    accIdToOEM.put(
                        sp.Account__c, new List<String>()
                    );
                }

                accIdToOEM.get(sp.Account__c).add(coopProgramNames.get(normalizedString));

            } 

        }
    }

    return accIdToOEM;
  }

  /*
  * getter for CoOpPrograms Map
  */

  public static Map<String, String> getCoOpProgramsMap() {

    // setup string of coop program names
    Map<String, String> coopProgramNames = new Map<String, String>();

    // get co op oems
    SObjectField picklistUsingGlobal = SObjectType.Co_op_Program__c.fields.Co_Op_OEM__c.getSObjectField();

    // get picklist entries
    List<PicklistEntry> entries = picklistUsingGlobal.getDescribe().getPicklistValues();

    // fill map of coop program names
    for(PicklistEntry pe : entries){
        coopProgramNames.put(pe.value.toLowerCase(),pe.value);
    }

    return coopProgramNames;

  }

  /*
  * getter for OEMtoDivisionMap
  */
  public static Map<String, String> getOEMtoDivisionMap() {

    Map<String,String> oemToDivisionMap = new Map<String,String>();

    List<Co_Op_Program__c> programs = [
        SELECT Id, Co_Op_OEM__c, Co_Op_OEM_Group__c
        FROM Co_Op_Program__c
        WHERE Co_Op_OEM_Group__c != null
    ];

    for (Co_Op_Program__c program : programs) {
        oemToDivisionMap.put(program.Co_Op_OEM__c, program.Co_Op_OEM_Group__c);
    }

    return oemToDivisionMap;

  }

}