public with sharing class  ZuoraAccountTriggerFunctions {
    //- Jira: BR-876 | Method: ZuoraAccountTriggerFunctions.UpdateAccount
    //- Purpose: Update Active billing account lookup field on account when billing account is created in SF via API
    //- Update account with Active billing Account
    public static void updateDealerAccount(List<Zuora__CustomerAccount__c> newZuoraCustomerList){
        
        Map<ID,Account> updateAccountMap = new Map<ID,Account>();
        Map<String,Id> zIdMap = new Map<String,Id>();
        for (Zuora__CustomerAccount__c zca : newZuoraCustomerList) 
        {
            if(zca.Zuora__Status__c == 'Active') {
                if (zca.Zuora__Account__c != null && !zca.Linked_to_Account__c) {
                    updateAccountMap.put(zca.Zuora__Account__c, 
                        new Account(Id=zca.Zuora__Account__c,Billing_Account_Zuora__c=zca.Id));
                }
            }
        }

        if(updateAccountMap.isEmpty()) {
            return;
        }
        update updateAccountMap.values();
    }
    
    public static void updateActiveBillingAcc(List<Zuora__CustomerAccount__c> newZuoraCustomerList, Map<Id, Zuora__CustomerAccount__c> zuoraOldMap){
        List<Id> previousActiveBillingAccountList = new List<Id>();
        for(Zuora__CustomerAccount__c zac: newZuoraCustomerList) {
            if(zuoraOldMap.get(zac.id).Zuora__Status__c == 'Active' && zac.Zuora__Status__c != 'Active') {
                previousActiveBillingAccountList.add(zac.Id);
            }
        }

        List<Account> accList = [SELECT Id, Billing_Account_Zuora__c FROM Account WHERE Billing_Account_Zuora__c IN :previousActiveBillingAccountList];

        if(!accList.isEmpty()) {
            for(Account acc: accList) {
                acc.Billing_Account_Zuora__c = null;
            }
            update accList;   
        }
    }

    public static void sendIntegrationMessageForChildren(List<Zuora__CustomerAccount__c> newZac, Map<ID,Zuora__CustomerAccount__c> oldZacMap) {
        List<Id> accountsToLookup = new List<Id>();
        List<Account> accountsToSend = new List<Account>();
        // loop through accounts in passed trigger scope
        for(Zuora__CustomerAccount__c zac : newZac) {
            // if oldAccount grab, otherwise set to null
            Zuora__CustomerAccount__c oldZac = oldZacMap == null || oldZacMap.size() == 0 ? null : oldZacMap?.get(zac.ID);
            // if no existing zuora billing account, don't proceed
            if (zac.Parent_Zuora_Id__c != null) {
                // check for field changes or if new account
                if (
                    (oldZac == null) ||
                    (zac.Parent_Zuora_Id__c != oldZac.Parent_Zuora_Id__c)
                ) {
                    accountsToLookup.add(zac.Zuora__Account__c);
                }
            }
        }

        if (accountsToLookup.size() > 0) {
            accountsToSend = [SELECT Id, Product_Activation_Status__c,Account_Status__c FROM Account WHERE Id IN: accountsToLookup AND Billing_Account_Zuora__c != ''];
            if (accountsToSend.size() > 0) {
                ZuoraIntegration_AccountHelper.createAndSendZAccountMessages(accountsToSend);
            } 
        }
    }

}