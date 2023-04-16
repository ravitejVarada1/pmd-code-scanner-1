/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        03/11/2021
* modified:       03/11/2021
* created jira:   BR-367 & BR-368
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class ServiceProviderTriggerFunctions {
    
    public static final Set<String> SPID_ACCOUNT_CALC_FIELDS = new Set<String>{
        'Dealer_Type__c',
        'Force_Recalc_Account_Fields__c',
        'reviewStatus__c',
        'Account__c',
        'Used_Cars_Fair_Pct__c',
        'Used_Cars_Good_Pct__c',
        'Used_Cars_Great_Pct__c',
        'Total_Used_Inventory_Units__c'
    };
                
    @TestVisible
    private static final String DEALER_TYPE_NEW = 'New';
    @TestVisible
    private static final String DEALER_TYPE_USED = 'Used';
    
    //Updates the Ultimate Parent Account field on service providers on insert and
    //on update when the related account has changed | Jira: BR-367 & BR-368
    public static void updateUltimateParentRef(List<Service_Provider__c> newSpList, Map<ID,Service_Provider__c> oldSpMap){
        //Map of account Id to the related ultimate parent account Id
        Map<ID,ID> accountToUltParentAccount = new Map<ID,ID>();
        List<Service_Provider__c> spidsToUpdate = new List<Service_Provider__c>();
        
        //Add related account Id into the map to populate the keyset (used in query below)
        for (Service_Provider__c sp : newSpList){
            if (!Trigger.isUpdate || sp.Account__c != oldSpMap.get(sp.Id).Account__c){
                accountToUltParentAccount.put(sp.Account__c, null);
                spidsToUpdate.add(sp);
            }
        }
        
        if (accountToUltParentAccount.isEmpty()){
            return;
        }
        
        //Loop through the related accounts to populate the values in the map
        for (Account a : [SELECT Ultimate_Parent_Account__c, Is_Ultimate_Parent__c
                          FROM Account
                          WHERE Id IN :accountToUltParentAccount.keySet()])
        {
            ID ultParent = a.Is_Ultimate_Parent__c
                ? a.Id
                : a.Ultimate_Parent_Account__c;

            accountToUltParentAccount.put(a.Id, ultParent);
        }
        
        //Update the ultimate parent account on the spids that need an updaate
        for (Service_Provider__c spToUpdate : spidsToUpdate){
            spToUpdate.Ultimate_Parent_Account__c = accountToUltParentAccount.get(spToUpdate.Account__c);
        }
    }
    
    //On insert, delete, and undelete, send all the related accounts into the
    //updateAccountsFromSpids method | Jira: BR-367 & BR-368
    public static void checkAccountFieldsInsAndDel(List<Service_Provider__c> newSpList){
        Set<ID> accountIdsToCheck = new Set<ID>();
        
        for (Service_Provider__c sp : newSpList){
            accountIdsToCheck.add(sp.Account__c);
        }
        
        updateAccountsFromSpids(accountIdsToCheck);
    }
    
    //On update, collect all accounts that had a field in the SPID_ACCOUNT_CALC_FIELDS set change,
    //and send them into the updateAccountsFromSpids method | Jira: BR-367 & BR-368
    public static void checkAccountFieldsUpdate(List<Service_Provider__c> newSpList, Map<ID,Service_Provider__c> oldMap){
        Set<ID> accountIdsToCheck = new Set<ID>();
        
        for (Service_Provider__c sp : newSpList){
            ID spId = sp.Id;
            
            Service_Provider__c oldSp = oldMap.get(spId);
            
            //Loop through spid fields and check if any field changed
            for (String apiName : SPID_ACCOUNT_CALC_FIELDS){
                if(sp.get(apiName) != oldSp.get(apiName)){
                    accountIdsToCheck.add(sp.Account__c);
                }
            }
        }
        
        if (accountIdsToCheck.isEmpty()){
            return;
        }
        
        updateAccountsFromSpids(accountIdsToCheck);
    }

    @future 
    private static void updateAccountsFromSpidsFuture(Set<ID> accountIdsToCheck){
        updateAccountsFromSpids(accountIdsToCheck);
    }

    //Check spid fields against related account fields, and update if needed | Jira: BR-367 & BR-368
    @TestVisible
    private static void updateAccountsFromSpids(Set<ID> accountIdsToCheck){
        
        if (!System.isBatch() && !System.isFuture()){
            updateAccountsFromSpidsFuture(accountIdsToCheck);
            return;
        }

        //For each account, check if the Dealer Type needs to be updated (based on the related spids)
        List<Account> accountsToUpdate = new List<Account>();

        for (Account a : Database.query('SELECT Id, (SELECT ' + String.join(new List<String>(SPID_ACCOUNT_CALC_FIELDS), ',') + ' ' +
                                        		'FROM Service_Provider__r ' +
                                        		'WHERE reviewStatus__c != \'DENIED\') ' +
                                        'FROM Account ' +
                                        'WHERE Id IN :accountIdsToCheck '))
             {
                 Account beforeA = a.clone(true,true,true,true);
                 
                 checkAccountForUpdate(a);

            //If the above method changed the account, add the account to the list that gets updated
            if (beforeA != a){
                accountsToUpdate.add(a);
            }
        }
        update accountsToUpdate;
    }
    
    //Check various account fields against their feeding values | BR-367 & BR-368
    private static void checkAccountForUpdate(Account a){
        a.Dealer_Type__c = DEALER_TYPE_USED;
        
        Decimal totalInventoryFairOrAbove = 0;
        Integer totalSpids = a.Service_Provider__r.size();
        
        for (Service_Provider__c sp : a.Service_Provider__r){
            //If there is at least Service Provider with a "New" Dealer Type, then the 
            //account Dealer Type is "New"
            if (sp.Dealer_Type__c == DEALER_TYPE_NEW){
                a.Dealer_Type__c = DEALER_TYPE_NEW;
            }
            
            //For each spid, add the fair, good, great, and high inventory percentages together.
            if (sp.Total_Used_Inventory_Units__c != null){

                Decimal fairPct = sp.Used_Cars_Fair_Pct__c != null
                    ? sp.Used_Cars_Fair_Pct__c 
                    : 0;
                
                Decimal goodPct = sp.Used_Cars_Good_Pct__c != null
                    ? sp.Used_Cars_Good_Pct__c
                    : 0;
                
                Decimal greatPct = sp.Used_Cars_Great_Pct__c != null
                    ? sp.Used_Cars_Great_Pct__c
                    : 0;
                
                totalInventoryFairOrAbove += fairPct + goodPct + greatpct;
            }
            
        }
        
        //Divide the total fair, good, great, and high inventory percentage by the number of spids
        a.InventoryFairOrAbove__c = totalSpids == 0
            ? 0
            : totalInventoryFairOrAbove / totalSpids;
    }

    //- Jira: BR-482 & BR-520 | Method: ServiceProviderTriggerFunctions.CreateDealerAccount
    //- Purpose: Creating delear account after SP record is inserted
    //- Creating case record once dealer account is created
	public static void createDealerAccount(List<Service_Provider__c> newServiceProviderList){
    //getting account recordType  Delear accountID   
		Id dealerAccountRecordType= SObjectDescribeUtils.getRecordTypeIdByDevName('Account','Dealer_Account');
		Map<String,Account> accountMap = new Map<String,Account>();
		Map<String,Service_Provider__c> spMap = new Map<String,Service_Provider__c>();

		for(Service_Provider__c sp : newServiceProviderList)
		{
			if (sp.Account__c != null) {
			continue;
			}
        String spKey = sp.Billing_Country__c+sp.Service_Provider_Id__c;
        spMap.put(spKey, sp);
        Account acc = new Account();
        acc.Name = sp.Name ;
        acc.BillingCity = sp.Billing_City__c ;
        acc.BillingCountryCode = sp.Billing_Country__c;
        acc.billingStateCode = sp.Billing_State_Province__c ;
        acc.BillingPostalCode = sp.Billing_Zip_Postal_Code__c ;
        acc.billingStreet = sp.Billing_Street__c;
        acc.shippingCity = sp.Billing_City__c ;
        acc.shippingCountryCode = sp.Billing_Country__c;
        acc.shippingStateCode = sp.Billing_State_Province__c ;
        acc.shippingPostalCode = sp.Billing_Zip_Postal_Code__c ;
        acc.shippingStreet = sp.Billing_Street__c;
        acc.phone = sp.Phone__c;
        acc.website = sp.Website__c;
        acc.Account_Status__c = 'Pending';
    	acc.recordtypeId = dealerAccountRecordType;
        acc.OwnerId = CG_AccountOwnership.getCGAPIUser();
		accountMap.put(spKey, acc);
		}
        if (accountMap.isEmpty()) {
        	return;
        }
		insert accountMap.values();
        for (String spKey : spMap.keySet()) {
	        spMap.get(spKey).Account__c = accountMap.get(spKey).Id;
        }
	}

    //SA-255
    public static void checkSPDenyUndenyScenarios(List<Service_Provider__c> newSpList, Map<ID,Service_Provider__c> oldMap){
        
        String caseRecordTypeId = CaseTriggerFunctions.caseRTNameIdMap.get('Data Correction');
        List<Case> insertCs = new List<Case>();

        List<Service_Provider__c> confirmDeniedSPs = new List<Service_Provider__c>();
        Set<Id> confirmDeniedAccIds = new Set<Id>();

        for(Service_Provider__c newSP : newSpList){
            
            if(newSP.reviewStatus__c!=null){

                //Account Denied
                if(newSP.reviewStatus__c == 'DENIED'
                && oldMap.get(newSP.Id).reviewStatus__c!='DENIED'){
                    
                    confirmDeniedAccIds.add(newSP.Account__c);
                    confirmDeniedSPs.add(newSP);

                }else if(newSP.reviewStatus__c != 'DENIED'
                && oldMap.get(newSP.Id).reviewStatus__c =='DENIED'){
                    //Account undenied
                    insertCs.add(
                        setCaseFields(newSP,caseRecordTypeId,'Service Provider record Approved','Service Provider:'+newSP.Name+'('+newSP.Unique_Id__c+') has been approved, please check its related Account and update the record to match.')
                    );
                }
            }
        }

        //check if ALL SPS under the Account are denied
        if(!confirmDeniedAccIds.isEmpty()){

            for(Service_Provider__c notDeniedSPs : [
                SELECT Id,Account__c 
                FROM Service_Provider__c 
                WHERE reviewStatus__c != 'DENIED' 
                AND Account__c IN:confirmDeniedAccIds
            ]){
                confirmDeniedAccIds.remove(notDeniedSPs.Account__c);
            }

            if(!confirmDeniedAccIds.isEmpty()){
                for(Service_Provider__c deniedSPs : confirmDeniedSPs){
                    if(confirmDeniedAccIds.contains(deniedSPs.Account__c)){
                        insertCs.add(
                            setCaseFields(deniedSPs,caseRecordTypeId,'Service Provider record Denied','Service Provider:'+deniedSPs.Name+'('+deniedSPs.Unique_Id__c+') has been denied, please check its related Account and update the record to match.')
                        );
                    }
                }
            }
        }

        if(!insertCs.isEmpty()){
            List<String> errors = new List<String>();
            Database.SaveResult[] srList = Database.insert(insertCs, false);
            
            for(Database.SaveResult sr : srList){
                if (!sr.isSuccess()) {
                    // Operation failed, so get all errors                
                    for(Database.Error err : sr.getErrors()){
                        String errText = 'The following error has occurred:\n ' +
                        err.getStatusCode() + ': ' + err.getMessage() + '\n' +
                        'Fields that affected this error: ' + err.getFields();
                        errors.add(errText);
                    }
                }
            }

            if(!errors.isEmpty()){
                Utilities.sendSimpleErrorEmail('Service Provider Deny/Undeny process',JSON.serialize(errors));
            }
        }
    }

    static Case setCaseFields(Service_Provider__c spRecord,String caseRecordTypeId,String subject,String description){
        
        //Run Case assignment rule from apex
        Database.DMLOptions dmlOption = new Database.DMLOptions();
        dmlOption.assignmentRuleHeader.useDefaultRule = true;

        Case cs = new Case();
        cs.RecordTypeId = caseRecordTypeId;
        cs.Subject = subject;
        cs.Description = description;
        cs.AccountId = spRecord.Account__c;
        cs.Origin = 'Internal';
        cs.Reason = 'SP Merge/Deny';
        cs.setOptions(dmlOption);
        return cs;
    }
}