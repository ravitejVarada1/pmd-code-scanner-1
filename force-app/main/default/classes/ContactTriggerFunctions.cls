public class ContactTriggerFunctions{
	//BR-1842
	public static void setCurrencyCode(Map<ID, Contact> oldContactMap, List<Contact> newContactList){
		Set<Id> accountId = new Set<Id>();
		for (Contact c : newContactList){
			if ((oldContactMap == null || (oldContactMap != null 
			       && oldContactMap.get(c.id).accountId != c.accountId)) && c.accountId != null){
				accountId.add(c.accountId);
			}
		}

		if (!accountId.isEmpty()){

			Map<Id, Account> accountMap = new Map<Id, Account>([SELECT Id, BillingCountry, CurrencyIsoCode, BillingCountryCode
			                                                    FROM Account
			                                                    WHERE ID IN :accountId]);
			for (Contact con : newContactList){
				if (accountMap.containsKey(con.accountId)){
					Account acc = accountMap.get(con.accountId);
					if (acc.BillingCountryCode != null){
						con.CurrencyIsoCode = acc.CurrencyIsoCode;
					}
				}
			}
		}
	}

	public static void updateAccountsForConductViolation(Map<ID, Contact> newContactMap, Map<ID,Contact> oldContactMap){ 
		//EA-144
		Set<Id> conductViolationSet = new Set<Id>();
		Map<ID,Account> accountViolationsMap = new Map<ID,Account>();
		Set<Id> clearConductViolationSet = new Set<Id>();
		Map<ID,Account> clearAccountViolationsMap = new Map<ID,Account>();
		List<Account> updateAccounts = new List<Account>();
		List<AccountContactRelation> externalContactViolations = new List<AccountContactRelation>();

		Set<Id> accountsWithViolatingContacts = new Set<Id>();
		
		for (Contact c : newContactMap.values()){ 
		
			if (c.Code_of_Conduct_Violation__c != NULL && (oldContactMap == NULL || c.Code_of_Conduct_Violation__c != oldContactMap.get(c.id).Code_of_Conduct_Violation__c)){ 
				conductViolationSet.add(c.ID); 

			}
			else if (c.Code_of_Conduct_Violation__c == NULL && oldContactMap != NULL && c.Code_of_Conduct_Violation__c != oldContactMap.get(c.id).Code_of_Conduct_Violation__c){
				clearConductViolationSet.add(c.ID); 
			}
		}

		if(!conductViolationSet.isEmpty()) {
			
			accountViolationsMap = new Map<Id, Account> ([SELECT ID, Code_of_Conduct_Chkbox__c FROM Account WHERE ID IN (SELECT accountID FROM AccountContactRelation WHERE ContactID IN:conductViolationSet)]); 
			
			for (account a : accountViolationsMap.values()){
				a.Code_of_Conduct_Chkbox__c = true;
				updateAccounts.add(a);  
			}
		}

		if(!clearConductViolationSet.isEmpty()) {
			clearAccountViolationsMap = new Map<Id, Account> ([SELECT ID, Code_of_Conduct_Chkbox__c FROM Account WHERE ID IN (SELECT accountID FROM AccountContactRelation WHERE ContactID IN:clearConductViolationSet)]);

			externalContactViolations = [SELECT ID, AccountID FROM AccountContactRelation WHERE AccountID IN:clearAccountViolationsMap.keySet() AND Contact.Code_of_Conduct_Violation__c != NULL];

			for(AccountContactRelation ac : externalContactViolations){
				accountsWithViolatingContacts.add(ac.AccountID);
			}

			for (account ac: clearAccountViolationsMap.values()){
			
				if (!accountsWithViolatingContacts.contains(ac.Id)){ 
					ac.Code_of_Conduct_Chkbox__c = false;
					updateAccounts.add(ac);
				}
			}	
		}

		if(!updateAccounts.isEmpty()) {
			TriggerHandler.bypass('AccountTriggerHandler');
			update updateAccounts;
			TriggerHandler.clearBypass('AccountTriggerHandler');
		}

	}

	//Added under SA-618
    public static void preventContactDelete(List<Contact> oldContactList){

        String currentUserId = UserInfo.getUserId();

        //Check if current user has the AccountMerge permission set assigned.
        List<PermissionSetAssignment> accountMergeUser = [SELECT Id, AssigneeId FROM PermissionSetAssignment WHERE PermissionSet.Name =: ConsumerConstantsUtil.PS_ACCOUNT_MERGE AND AssigneeId =: currentUserId];
        Boolean mergeUser = accountMergeUser.size() > 0;

        if(!mergeUser){
            return;
        }

        String errorMessage = 'You do not have permissions to delete contacts. Contact your administrator for help.';
        
        for(Contact c: oldContactList){
            Trigger.oldMap.get(c.Id).addError(errorMessage);
        }
        
    }
}
