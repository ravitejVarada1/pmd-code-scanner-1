/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     alaplante
* created:        03/11/2021
* modified:       12/09/2021
* created jira:   BR-367 & BR-368 & BR-2564 & BR-1492
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public without sharing class AccountTriggerFunctions {
  
    // global vars
    public static final string REVIEW_IN_PROGRESS = 'Renewal Review In-progress';
    public static final string PRICE_CHANGE_APPROVED = 'Renewal Price Change Approved';
    public static final string PRICE_CHANGE_REJECTED = 'Renewal Price Change Rejected';

    // holds all group fields who's update should trigger a group stats recalc
    public static final List<String> GROUP_FIELDS = new List<String>{
        'Type', 
        'Used_Inventory_Avg__c', 
        'Total_New_Inventory__c', 
        'Total_Used_Inventory__c', 
        'ParentId',
        'Open_Opps_Owned_By_Acq_SUM__c',
        'Open_Opps_Owned_By_DR_SUM__c',
        'Total_CMRR__c'
    };

    // holds all fields whos update should trigger a zuora sync
    public static final List<String> INTEGRATION_FIELDS = new List<String>{
      'Account_Category_Formula__c','BillingCountryCode', 'BillingStateCode', 'VAT_Id__c', 
      'Preferred_Language__c', 'ParentId', 'Billing_Account_Zuora__c', 'Dealer_ID__c', 'Field_Group_Type__c',
      'OwnerId','Enrollment_Date__c','External_Dealer_ID__c','Division__c','iMR_funds__c','Co_Op_Program_Opt_In__c'
    };

    /**
     * If an Account is changed to UltimateAccount from NOT UltimateAccount
     *
     * @author  Navdeep Singh
     * @date    04/04/2022
     * @module  BR-7581
     */
    public static void updateChildAccRecordsUltAccount(List<Account> accounts, Map<ID,Account> oldAccountMap) {
        
        Set<Id> ultParentAcctIds = new Set<Id>();
        Set<Id> ultimateParentAccounts = new Set<Id>();

        Map<Id,Id> notUltAccIdToNewUltAccId = new Map<Id,Id>();

        List<Account> relatedChildAccts = new List<Account>();
        Map<Id,Set<Account>> parentAccIdToChildAcc = new Map<Id,Set<Account>>();
        Map<Id,List<Account>> accIdToChildAccList = new Map<Id,List<Account>>();

        for(Account acc : accounts){
            
            if(acc.Is_Ultimate_Parent__c && !oldAccountMap.get(acc.Id).Is_Ultimate_Parent__c){
                //Account is changed to UltimateAccount from NOT UltimateAccount
                ultParentAcctIds.add(acc.Id);

                if(oldAccountMap.get(acc.Id).Ultimate_Parent_Account__c!=null){
                    ultimateParentAccounts.add(oldAccountMap.get(acc.Id).Ultimate_Parent_Account__c);
                }
                
            }else if(!acc.Is_Ultimate_Parent__c 
            && oldAccountMap.get(acc.Id).Is_Ultimate_Parent__c){
                //Account is changed to NOT UltimateAccount from UltimateAccount
                notUltAccIdToNewUltAccId.put(acc.Id,acc.Ultimate_Parent_Account__c);
            }
        }

        //Secnario: Account is changed to NOT UltimateAccount from UltimateAccount
        if(!notUltAccIdToNewUltAccId.isEmpty()){
            for(Account chldAccs : [
                SELECT Id,Ultimate_Parent_Account__c,ParentId,Parent.Ultimate_Parent_Account__c
                FROM Account
                WHERE Ultimate_Parent_Account__c IN:notUltAccIdToNewUltAccId.keyset()
            ]){
                //where parent has become a NON Utlimate Parent Account
                chldAccs.Ultimate_Parent_Account__c = notUltAccIdToNewUltAccId.get(chldAccs.Ultimate_Parent_Account__c);
                relatedChildAccts.add(chldAccs);
            }
        }

        //Scenario: Account is changed to UltimateAccount from NOT UltimateAccount
        if(!ultParentAcctIds.isEmpty() && !ultimateParentAccounts.isEmpty()){

            for(Account chldAccs : [
                SELECT Id,Name,Ultimate_Parent_Account__c,ParentId,Parent.Ultimate_Parent_Account__c,
                (SELECT Id,Name,Ultimate_Parent_Account__c,ParentId FROM ChildAccounts)
                FROM Account
                WHERE (ParentId IN:ultParentAcctIds 
                OR Ultimate_Parent_Account__c IN:ultimateParentAccounts)
            ]){
                accIdToChildAccList.put(chldAccs.Id,chldAccs.ChildAccounts);

                if(ultParentAcctIds.contains(chldAccs.ParentId)){

                    if(parentAccIdToChildAcc.containskey(chldAccs.ParentId)){
                        Set<Account> parentAccIdToChildAccList = parentAccIdToChildAcc.get(chldAccs.ParentId);
                        parentAccIdToChildAccList.add(chldAccs);
                        parentAccIdToChildAcc.put(chldAccs.ParentId,parentAccIdToChildAccList);
                    }else{
                        parentAccIdToChildAcc.put(chldAccs.ParentId,new Set<Account>{chldAccs});
                    }
                }
            }

            //second iteration to update ultimateParent Account for indirect child accounts
            relatedChildAccts = checkIndirectChildAccsToUpdate(relatedChildAccts,parentAccIdToChildAcc,accIdToChildAccList);
        }

        System.debug('final list: ' + JSON.serializePretty(relatedChildAccts));

        if(!relatedChildAccts.isEmpty()){
            update relatedChildAccts;
        }
        
    }

    private static List<Account> checkIndirectChildAccsToUpdate(List<Account> relatedChildAccts,Map<Id,Set<Account>> parentAccIdToChildAcc,Map<Id,List<Account>> accIdToChildAccList){

        Integer counter = 0;
        Integer childListSize = accIdToChildAccList.size();

        for(Id parentId : parentAccIdToChildAcc.keyset()){

            Set<Account> tempChildAccs = parentAccIdToChildAcc.get(parentId);

            while(counter < childListSize){

                for(Account chldAcc : tempChildAccs){
                
                    if(accIdToChildAccList.containsKey(chldAcc.Id) && accIdToChildAccList.get(chldAcc.Id)!=null){
                        tempChildAccs.addAll(accIdToChildAccList.get(chldAcc.Id));
                    }
                }
                parentAccIdToChildAcc.put(parentId,tempChildAccs);
                counter++;
            }
        }

        for(Id parentId : parentAccIdToChildAcc.keyset()){

            for(Account childAcc : parentAccIdToChildAcc.get(parentId)){
                Account acc = new Account(
                    Id = childAcc.Id,
                    Name = childAcc.Name,
                    Ultimate_Parent_Account__c = parentId
                );
                relatedChildAccts.add(acc);
            }
        }

        System.debug('final list: ' + JSON.serializePretty(relatedChildAccts));

        return relatedChildAccts;
    }

    /**
     * When hierarchy is updated, perform a group statistics update.
     *
     * @author  Adam LaPlante
     * @date    10/05/2021
     * @module  BR-4251 
     */

    public static void updateGroupStatistics(List<Account> accounts, Map<ID,Account> oldAccountMap) {
        List<Id> accountsToLookup = new List<Id>();
        Set<Id> accountsToLookupForOpp = new Set<Id>(); // couldn't fit opp stats within group stats framework
        

        // loop through accounts in passed trigger scope
        for(Account acc : accounts) {
            // if oldAccount grab, otherwise set to null
            Account oldAccount = oldAccountMap == null || oldAccountMap.size() == 0 ? null : oldAccountMap?.get(acc.ID);
            // if no existing zuora billing account, don't proceed
            if (
                oldAccount == null || Utilities.simpleCompareFields(acc, oldAccount, GROUP_FIELDS)
            ) {
                    accountsToLookup.add(acc.Ultimate_Parent_Account__c != null ? acc.Ultimate_Parent_Account__c : acc.Id);
            }
        }
        
        if (accountsToLookup.size() > 0) {
            AccountGroupStatisticsCalculator.calculateAndUpdateGroupStatistics(
                 [
                  SELECT Id, Name, Type, Used_Inventory_Avg__c, Total_Used_Inventory__c, Total_New_Inventory__c,
                  Open_Opps_Owned_By_Acq_SUM__c, Open_Opps_Owned_By_DR_SUM__c,Total_CMRR__c,
                  (SELECT Id, Name, Type, Used_Inventory_Avg__c, Total_Used_Inventory__c, Total_New_Inventory__c,
                  Open_Opps_Owned_By_Acq_SUM__c, Open_Opps_Owned_By_DR_SUM__c,Total_CMRR__c
                  FROM Accounts_Descendents__r),
                  (SELECT Id, Account__c, reviewStatus__c FROM All_Hierarchy_Service_Providers__r) 
                  FROM Account WHERE Id in :accountsToLookup
                 ]
            );
        } 

    }

  
    /**
    * When a new account is created, gets ultimate parent account and sets it.
    *
    * @author  Adam LaPlante
    * @date    07/01/2021
    * @module  BR-1510 : Logic to auto-populate the ultimate parent account on Salesforce accounts 
    */
    public static void setUltimateParent(List<Account> newAccounts,Map<Id,Account> oldAccountMap) {
        Set<Id> parentIds = new Set<Id>();
        for(Account a : newAccounts) {
            if((a.ParentId != null && oldAccountMap == null) 
            || 
            (a.ParentId != null && oldAccountMap!=null && oldAccountMap.get(a.Id).ParentId!=a.ParentId)
            ) {
                parentIds.add(a.ParentId);
            }
        }

        if (parentIds.size() > 0) {
            // grab parent accounts
            Map<Id, Account> parentAccounts = new Map<Id, Account>([SELECT Id, Ultimate_Parent_Account__c 
                FROM Account WHERE Id in :parentIds]);
            // loop trhough accounts setting ultimate parent
            for (Account acc : newAccounts) {
                        
                if(acc.ParentId == null) {
                    continue;
                } 
                
                Account parentAccount = parentAccounts.get(acc.ParentId);
                Id parentsUltimateParent = parentAccount.Ultimate_Parent_Account__c;
                
                if(parentsUltimateParent != null) {
                    acc.Ultimate_Parent_Account__c = parentsUltimateParent;
                } else {
                    acc.Ultimate_Parent_Account__c = parentAccount.Id;
                }
            }
        }
    }

    /**
    * Determines if an integration message should be sent to Zuora. 
    * 
    * @author   Adam LaPlante
    * @date     06/09/21
    * @module   BR-1492 : Update Zuora Accounts - Boomi
    */

    public static void createZuoraIntegrationMessage(List<Account> newAccount, Map<ID,Account> oldAccountMap) {
        List<Account> accountsToSend = new List<Account>();
        List<Id> zacIds = new List<Id>();
        // loop through accounts in passed trigger scope
        for(Account acc : newAccount) {
            // if oldAccount grab, otherwise set to null
            Account oldAccount = oldAccountMap == null || oldAccountMap.size() == 0 ? null : oldAccountMap?.get(acc.ID);
                // make sure there's a zuora billing account associated, check for field changes or if new account
                if (
                    acc.Billing_Account_Zuora__c != null && 
                    (oldAccount == null || Utilities.simpleCompareFields(acc, oldAccount, INTEGRATION_FIELDS))
                ) {
                    accountsToSend.add(acc);
                    // if a parent update occurred, also update the parent on the zuora billing account
                    if (acc.ParentId != oldAccount.ParentId) {
                        zacIds.add(acc.Billing_Account_Zuora__c);
                    }
                }
        }
        try {
            // if theres account integration messages to send, create and send
            if (accountsToSend.size() > 0) {
                ZuoraIntegration_AccountHelper.createAndSendZAccountMessages(accountsToSend);
            }

            // if theres zuora customer accounts to update with new parent ids
            if (zacIds.size() > 0){
                updateZACparent(zacIds);
            }
        } catch (Exception e) {
            Utilities.sendSimpleErrorEmail('AccountTriggerFunctions - Create Zuora Integration Message', e.getMessage());
        }

    }


    // used to keep the parent field on the zuora billing account up to date
    public static void updateZACparent(List<Id> zacIds) {

        List<Zuora__CustomerAccount__c> zacsToUpdate = new List<Zuora__CustomerAccount__c>();

        for(Zuora__CustomerAccount__c zac : [
                    SELECT Id, Zuora__Zuora_Id__c,Zuora__Parent__c,
                    (SELECT Id, Parent.Billing_Account_Zuora__c 
                    FROM Accounts__r WHERE ParentId != null) 
                    FROM Zuora__CustomerAccount__c WHERE Id IN :zacIds
                ]
            ){
            for (Account acc : zac.Accounts__r) {
                zac.Zuora__Parent__c = acc.Parent.Billing_Account_Zuora__c;
            }
            if (zac.Zuora__Parent__c != null) {
                zacsToUpdate.add(zac);
            }
        }

        if (zacsToUpdate.size() > 0){
             update zacsToUpdate;
        }

    }


    /**
    * When a new account is created, if Dealer City is Quebec default preferred language to French.
    * 
    * @author   Adam LaPlante
    * @date     06/08/21
    * @module   BR-2564 : Account Data Element - Preferred Language
    */

    public static void evaluateLanguageDefaulting(List<Account> newAccount) {

        // loop through accounts in passed trigger scope
        for(Account acc : newAccount) {

            // check for null references before evaluation
            String newBillCity = acc.BillingCity == null ? '' : acc.BillingCity;
            String newBillState = acc.BillingStateCode == null ? '' : acc.BillingStateCode;

            // evaluate if update is needed
            if (newBillCity.toLowerCase() == 'quebec' || newBillState.toLowerCase() == 'qc') {
                acc.Preferred_Language__c = 'French';
            } 
        }   
    }

    /**
    * Evaluates if an account saturation update is necessary.
    * 
    * @author   Adam LaPlante
    * @date     03/04/21
    * @module   BR-371 : Account Saturation
    */

    public static void evaluateAccountSaturationChange(List<Account> newAccount, Map<ID,Account> oldAccountMap) {
        Set<ID> ultimateParentIDs = new Set<ID>();
        
        // loop through accounts in passed trigger scope
        for(Account acc : newAccount) {
            // get account object before update
            Account oldAccount = oldAccountMap?.get(acc.ID);
            // check if product activation status has changed
            if (oldAccount == null || 
                    (acc.Product_Activation_Status__c != oldAccount.Product_Activation_Status__c) 
                        || (acc.Account_Status__c != oldAccount.Account_Status__c)
                    ) {
                // if product activation status, check for a parent id, otherwise use own id
                ultimateParentIDs.add(acc.ParentID == null ? acc.ID : acc.Ultimate_Parent_Account__c);
            }
        }
        // pass to main thread
        ultimateParentIDs.remove(null);
        processSaturationChanges(ultimateParentIDs);
    }


    /**
    * Checks if in future context before executing. If not in future context, 
    * pushes to future and returns back to continue processing.
    *
    * @author   Adam LaPlante
    * @date     03/04/21
    * @module   BR-371 : Account Saturation
    */

    public static void processSaturationChanges(Set<Id> accountIds) {
        // check if currently in batch or future context, if not invoke future method
        if (!System.isBatch() && !System.isFuture()) {
            // call method to return in future context
            processSaturationChangesFuture(accountIds);
            return;
        }

        // process saturation changes
        updateAccountSaturation(accountIds);

    }

    /**
     * Used to push processing context to future context. 
     *
     * @author  Adam LaPlante
     * @date    03/04/21
     * @module  BR-371 : Account Saturation
     */

    @future
    private static void processSaturationChangesFuture(Set<Id> accountIds) {
       // call back to main process saturation changes method
       processSaturationChanges(accountIds);
   }

   /**
    * Takes in provided ultparent ID, creates list of child accounts, and sets the saturation text on all accounts.
    * 
    * @author  Adam LaPlante
    * @date    03/04/21
    * @module  BR-371 : Account Saturation
    */

    private static void updateAccountSaturation(Set<Id> ultAccountIds) {
       
        //set of ult parent account ids to update if saturation is zero
        Set<Id> zeroSaturationAccIds = new Set<Id>();

        // create new list of ultimate accounts to update
        List<Account> ultAccountsToUpdate = new List<Account>();
        
        // get dealer record type id
        ID dealerRecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', ConstantsUtil.RT_ACCOUNT_DEALER);

        Map<Id, List<Account>> ultToDealerMap = new Map<Id, List<Account>>();
        Map<Id, Account> ultParentsMap = new Map<Id, Account>();

        for(Account acc : [SELECT Id, ParentId, Ultimate_Parent_Account__c, Account_Saturation_Percentage__c, 
            RecordTypeId, Product_Activation_Status__c, Account_Status__c FROM Account 
            WHERE Ultimate_Parent_Account__c IN :ultAccountIds OR Id IN :ultAccountIds]) {

            Id accId = acc.Id;
            Id ultParentId = acc.ParentId == null ? acc.Id : acc.Ultimate_Parent_Account__c;

            if(acc.RecordTypeId == dealerRecordTypeId) {
                if(ultToDealerMap.containsKey(ultParentId)) {
                    ultToDealerMap.get(ultParentId).add(acc);
                } else {
                    List<Account> accLst = new List<Account>{acc};
                    ultToDealerMap.put(ultParentId, accLst);
                }
            }

            if(ultAccountIds.contains(accId)) {
                ultParentsMap.put(accId, acc);
            }
        }

        for(Id ultParId : ultToDealerMap.keySet()) {
            List<Account> dealers = ultToDealerMap.get(ultParId);
            Account ultA = ultParentsMap.get(ultParId);         

            // get the saturation percentage for all accounts in calculation list
            Integer saturationPercentage = getSaturationPercentage(dealers);
            
            if(saturationPercentage == 0) {
                zeroSaturationAccIds.add(ultA.Id);
            }
            
            // if the saturation percentage needs update, update
            if (saturationPercentage != ultA.Account_Saturation_Percentage__c){
                ultA.Account_Saturation_Percentage__c = saturationPercentage;
                ultAccountsToUpdate.add(ultA);
            }
        }

        // send update to salesforce
        if (ultAccountsToUpdate.size() > 0) {
            update ultAccountsToUpdate;
        }

        if(!zeroSaturationAccIds.isEmpty()) {
            CG_AccountOwnership.updateAccountOwner(zeroSaturationAccIds);
        }
        
    }

   /**
    * Takes in provided account list and evaluates the saturation value of the list. Returns value as string.
    * 
    * @author  Adam LaPlante
    * @date    03/04/21
    * @module  BR-371 : Account Saturation
    */

    private static Integer getSaturationPercentage(List<Account> accounts) {
       // if accounts is empty, return 0 value
       if (accounts.isEmpty()) { 
           return 0;
       }

       // initialize counters
       Integer payingAccounts = 0;


       // evaluate array for scoring, increment appropriate counters
       for (Account acc : accounts) {
           // paying account status = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE, all other statuses non-paying
           if (acc.Product_Activation_Status__c == ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE 
                   && acc.Account_Status__c == ConstantsUtil.ACCOUNT_STATUS_ACTIVE) {
               payingAccounts++;
           }
       }

       // get score based on derived account data
       return (Integer)((payingAccounts * 100 ) / accounts.size());
   }

   /**
     * creates case to review the newly created Dealer Account in the Pending status.
     * @author 	aganji
     * @module 	BR-520
     */

    public static void createCaseRecord(List<Account> newAccountCreated) {
       // getting case recordType data correctionID
        Id rtIdDataCorrection = 
            SObjectDescribeUtils.getRecordTypeIdByDevName('Case', ConstantsUtil.RT_CASE_DATACORRECTION);
        Id rtIdDealer = 
            SObjectDescribeUtils.getRecordTypeIdByDevName('Account', ConstantsUtil.RT_ACCOUNT_DEALER);
    
        Group adminQueue = [SELECT ID FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Cargurus_Admin'];

        List<Case> caseList = new List<Case>();
        
        for(Account acc : newAccountCreated) {
            if (acc.recordTypeID == rtIdDealer && acc.Account_Status__c == ConstantsUtil.ACCOUNT_STATUS_PENDING) {
                Case caseSobject = new Case();
                caseSobject.Reason = 'New Dealer Account created';
                caseSobject.Origin = 'Internal';
                caseSobject.Status = 'New';
                caseSobject.RecordTypeId = rtIdDataCorrection;
                caseSobject.Subject = 'Create New Account/SP for '+acc.Name;    
                caseSobject.AccountId = acc.Id;
                caseSobject.Description = acc.Name+' created on '+Datetime.now().format()+' with Country Code '+
                    acc.BillingCountryCode;
                caseSobject.ownerId = adminQueue.Id;
                caseList.add(caseSobject);
            }
        }

        if(!caseList.isEmpty()) {
            insert caseList;
        }
    }

   //When a new account is inserted or undeleted, run various data cleanup methods on the ultimate parent
   //Jira: BR-367 & BR-368 | 
    public static void newAccountUltParentCleanup(List<Account> newAList){
       Set<ID> ultParentAccountsToCheck = new Set<ID>();
       
       for (Account a : newAList){
           ultParentAccountsToCheck.add(
               !a.Is_Ultimate_Parent__c
               ? a.Ultimate_Parent_Account__c
               : a.Id
           );
       }
       
       AccountCategoryCalculator.execute(ultParentAccountsToCheck);
   }
   
   //When a new account is deleted, run various data cleanup methods on the ultimate parent
   //Jira: BR-367 & BR-368 | 
   public static void deletedAccountUltParentCleanup(List<Account> oldAList){
       Set<ID> ultParentAccountsToCheck = new Set<ID>();
       
       for (Account a : oldAList){
           if (a.Is_Ultimate_Parent__c){
               continue;
           }
           ultParentAccountsToCheck.add(a.Ultimate_Parent_Account__c);
       }
       
       AccountCategoryCalculator.execute(ultParentAccountsToCheck);
   }
   
   //When the ultimate parent account rerference is updated, run various data cleanup 
   //methods on the ultimate parent and the old ultimate parent | Jira: BR-367 & BR-368
    public static void ultParentChangedDataCleanup(List<Account> newAList, Map<Id,Account> oldAMap){
       
       Set<ID> ultParentAccountsToCheck = new Set<ID>();
       
       for (Account newA : newAList){
           ID newAId = newA.Id;
           Account oldA = oldAMap.get(newAId);
           
           Id newUltParent = newA.Ultimate_Parent_Account__c;
           Id oldUltParent = oldA.Ultimate_Parent_Account__c;

           if(newUltParent == oldUltParent){
               continue;  
           }
           
           if (newA.Is_Ultimate_Parent__c){
              ultParentAccountsToCheck.add(newAId);
           }else{
               ultParentAccountsToCheck.add(newUltParent);
           }
           
           if (!oldA.Is_Ultimate_Parent__c){
               ultParentAccountsToCheck.add(oldUltParent);
           }
       }

       if (ultParentAccountsToCheck.isEmpty()){
           return;
       }
       
       
       AccountCategoryCalculator.execute(ultParentAccountsToCheck);
   }

   //Check for accounts that had their Dealer Type updated, and send them into the 
   //accountCategoryUpdate method | Jira: BR-367 & BR-368
    public static void accountCategoryCheckUpdate(List<Account> newAList, Map<Id,Account> oldAMap){
       Set<ID> ultParentAccountsToCheck = new Set<ID>();
       
       for (Account a : newAList){
           Account oldA = oldAMap.get(a.Id);

           if(a.Dealer_Type__c != oldA.Dealer_Type__c){
               ultParentAccountsToCheck.add(
                   !a.Is_Ultimate_Parent__c
                   ? a.Ultimate_Parent_Account__c 
                   : a.Id
               );
           }
       }
       
       if (ultParentAccountsToCheck.isEmpty()){
           return;
       }
       
       AccountCategoryCalculator.execute(ultParentAccountsToCheck);
   }

   // Check if the account is going to any Product Activation Status other than cancelling, 
   // and in that case make sure Cancellation Date is blanked out | Jira: BR-2019
    public static void checkCancellingProductActivationStatus(List<Account> newAList, Map<Id,Account> oldAMap) {
       for(Account acc : newAList) {
           Account oldAccount = oldAMap.get(acc.Id);
           Boolean productActivationStatusChanged = acc.Product_Activation_Status__c != oldAccount.Product_Activation_Status__c;
           Boolean productActivationStatusCancelling = acc.Product_Activation_Status__c == ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_CANCELING57DAYS;
           if(productActivationStatusChanged && !productActivationStatusCancelling) {
               acc.Cancellation_Effective_Date__c = null;
           }
       }
   }

   /**
     * Checks the BillingCountryCode field to determine what currency to use on insert/update of an account.
     * @author 	Lawrence Zhao
     * @module 	BR-1732
     */

    public static void checkCurrencyField(List<Account> accList, Map<Id,Account> oldAccountMap) {
       for (Account a : accList) {
           if(oldAccountMap != null) {
               Account oldA = oldAccountMap.get(a.id);
               if(a.BillingCountryCode != oldA.BillingCountryCode) {
                   Utilities.setCurrencyField(a,a.BillingCountryCode);
               }
           } else {
               Utilities.setCurrencyField(a,a.BillingCountryCode);
           }
       }
   }
   
   // BR-1144 - if the billing contact info is newly populated, see if the account has an approved quote
   // if there is an approved quote, trigger process to send new account to zuora
    public static void checkBillingContactPopulated(List<Account> accountList, Map<Id,Account> oldAccountMap) {
       
       Set<Id> updatedAccountIds = new Set<Id>();

       for (Account a : accountList) {
           if (a.Billing_Account_Zuora__c != null || String.isBlank(a.System_BillingContactEmail__c)) {
               continue;
           }

           Id accountId = a.Id;
           Account oldA = oldAccountMap.get(accountId);

           if (String.isBlank(oldA.System_BillingContactEmail__c)) {
               updatedAccountIds.add(accountId);
           }
       }

       if (updatedAccountIds.isEmpty()) {
           return;
       }

       ZuoraIntegration_AccountHelper.checkAccountsForApprovedQuotes(updatedAccountIds);
   }


   /**
     * Prevents Account merges with active subscriptions
     * @author 	aganji
     * @module 	BR-1044
     */

    public static void preventAccountMerge(List<Account> newAList){
       List<account> accList = [SELECT ID, MasterRecordID, (SELECT ID FROM CPQ_Subscriptions_Fulfillment__r) FROM Account WHERE ID IN :newAList];
        For(Account acc: accList){
           if(!acc.CPQ_Subscriptions_Fulfillment__r.isEmpty())
           Trigger.oldMap.get(acc.Id).addError('Account cannot be merged with active subscriptions ');
        }
    }
     
    /**
     * Renewal Approval Process
     * @author 	Alexander Mitul
     * @module 	BR-3770
     */
    public static void createRenewalRecord(List<Account> newAccList,Map<Id,Account> oldAccountMap) {
        ID dealerRecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', ConstantsUtil.RT_ACCOUNT_DEALER);
        List<Renewal__c> createRenewalRec =  new List<Renewal__c>();
        for(Account acc : newAccList){
            if(( acc.Renewal_Eligible__c != oldAccountMap.get(acc.id).Renewal_Eligible__c || acc.Renewal_Period__c != oldAccountMap.get(acc.id).Renewal_Period__c )
                && acc.recordTypeId == dealerRecordTypeId && acc.Renewal_Eligible__c == true && acc.Renewal_Period__c !=null && acc.type == 'Customer') {

                Renewal__c renew =new  Renewal__c();
                renew.Account__c = acc.id;
                renew.Name = acc.name;    
                renew.Renewal_Period__c = acc.Renewal_Period__c;
                renew.Renewal_Status__c = REVIEW_IN_PROGRESS;
                renew.CurrencyIsoCode = acc.CurrencyIsoCode;     
                createRenewalRec.add(renew);
                AccountExtController extController = new AccountExtController(new ApexPages.StandardController(acc));
                extController.onSubmit();
            }
        }

       if(!createRenewalRec.isEmpty()){
           insert createRenewalRec;     
       }
    }

    /* public static void submitForApproval(Account acc){         
       Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();          
       req.setComments('Submitting approval request using Trigger');        
       req.setObjectId(acc.id);       
       Approval.ProcessResult result = Approval.process(req);        
       System.debug('Account submitted for approval successfully: '+result.isSuccess());    
     
    } */

    public static void setRenewalRecordStatus(List<Account> newAccList,Map<Id,Account> oldAccountMap) { 
        ID dealerRecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', ConstantsUtil.RT_ACCOUNT_DEALER);
        Set<Id> accountId = new Set<Id>();
        Set<Id> approvedAccountId = new Set<Id>();
        List<Renewal__c> updateRenewalRec =  new List<Renewal__c>();
        for(Account acc : newAccList){
            if( (acc.Renewal_Period__c != oldAccountMap.get(acc.id).Renewal_Period__c) 
                && acc.recordTypeId == dealerRecordTypeId && acc.Renewal_Period__c ==null && acc.type == 'Customer' 
                && (acc.Renewal_Status__c == PRICE_CHANGE_APPROVED || acc.Renewal_Status__c == PRICE_CHANGE_REJECTED)) {
                    
                    accountId.add(acc.Id);
                    if(acc.Renewal_Status__c == PRICE_CHANGE_APPROVED){

                        approvedAccountId.add(acc.Id);
                    }    
            }
        }   
        
        if(!accountId.isEmpty()){
            for(Renewal__c renewal : [SELECT Id, Renewal_Status__c, account__r.Renewal_Status__c 
                                      FROM Renewal__c WHERE account__c IN :  accountId order by createdDate desc limit 1 ]) {
                
                renewal.Renewal_Status__c = renewal.account__r.Renewal_Status__c; 
                updateRenewalRec.add(renewal);
            }  
        }

        if(!updateRenewalRec.isEmpty()){
            update updateRenewalRec;   
        } 
    }

    /* Update Contract End Date when Renewal Price Change is Approved
     * @author 	Ramiro Alvarez
     * @module 	DSS-33
     */

    public static void updateContractEndDateOnRenewalsAutoPay(List<Account> newAccList,Map<Id,Account> oldAccountMap) {
        
        Set<Id> accountBillingAccMap = new Set<Id> ();
        for(Account acc : newAccList) {
            if (acc.Renewal_Status__c == PRICE_CHANGE_APPROVED &&
                  oldAccountMap.get(acc.Id).Renewal_Status__c == REVIEW_IN_PROGRESS &&
                  acc.Renewal_Eligible__c == true) {
                    
                accountBillingAccMap.add(acc.Id);
            }
        }

        if (accountBillingAccMap.isEmpty()) {
            return;
        }
      
        // Query related Subs and check for Contracts ending last day of current month
        Date lastDateOfCurrentMonth = System.today().addMonths(1).toStartofMonth().addDays(-1);
        Map<Id,SBQQ__Subscription__c> subsMap = new Map<Id,SBQQ__Subscription__c> ([
            SELECT Id, Billing_Account__c, SBQQ__Contract__c, SBQQ__Contract__r.EndDate
            FROM SBQQ__Subscription__c
            WHERE SBQQ__Product__r.ProductCode = 'CG-BASE'
            AND Billing_Account__c IN :accountBillingAccMap
            AND SBQQ__Contract__r.EndDate = :lastDateOfCurrentMonth
            AND SBQQ__Contract__r.Status = 'Activated']);

        // If subMap contains records it means we need to update Contract End Date to match the same date as the Renewal Period        
        Map<Id,Contract> contractsToUpd = new Map<Id,Contract> ();
        Date firstDayOfNextMonth = System.today().addMonths(1).toStartOfMonth();        
        Date lastDayOfNextMonth = firstDayOfNextMonth.addDays(Date.daysInMonth(firstDayOfNextMonth.year(), firstDayOfNextMonth.month())-1);
        for (SBQQ__Subscription__c sub : subsMap.values()) {
            if (!contractsToUpd.containsKey(sub.SBQQ__Contract__c)) {
                contractsToUpd.put(sub.SBQQ__Contract__c, new Contract(Id = sub.SBQQ__Contract__c, EndDate = lastDayOfNextMonth));
            }
        }
        
        if (!contractsToUpd.isEmpty()) {
            update contractsToUpd.values();
        }
    }

    /**
    * https://cargurus.atlassian.net/browse/BR-3942
    * Reset the Last Activity By Account Owner datetime field when the owner changes
    */
    public static void ownerChangeResetLastActivityDate(Map<Id, Account> newAccountMap, Map<Id, Account> oldAccountMap) {
        for(Account acc : newAccountMap.values()) {
            Account oldAccount = oldAccountMap.get(acc.Id);
            Id newAccOwnerId = acc.OwnerId;
            Id oldAccOwnerId = oldAccount.OwnerId;
            
            if(newAccOwnerId != oldAccOwnerId) {
                acc.Last_Activity_Account_Owner__c = null;
            }
        }
    }

    /**
    * https://cargurus.atlassian.net/browse/SA-705
    * Reset the Account Status to active when the owner changes the account status reason to none.
    */
    public static void updateAccountStatus(List<Account> newAccList,Map<Id,Account> oldAccountMap){
        for (Account acc : newAccList){
            if (acc.Account_Status_Reason__c == null 
                && oldAccountMap.get(acc.id).Account_Status_Reason__c != null 
                && acc.Account_Status__c != 'Pending'){
                 acc.Account_Status__c = 'Active';
            }   
        }
    }
    
    /**
    * SA-791
    * Validate CoOpProgram field selection on Account
    */
    public static void evaluateCoOpProgramSelection(List<Account> newAccList,Map<Id,Account> oldAccountMap){

        List<Account> validateAccounts = new List<Account>();

        for(Account acc : newAccList){

            if(acc.Co_Op_Program_Opt_In__c!=null 
            && oldAccountMap != null && oldAccountMap.containsKey(acc.Id) 
            && oldAccountMap.get(acc.Id).Co_Op_Program_Opt_In__c != acc.Co_Op_Program_Opt_In__c
            ){
                validateAccounts.add(acc);
            }
        }

        if(!validateAccounts.isEmpty()){

            Map<Id,String> accIdToNewMakesSolds = CoOpProgramUtils.getSyncedNewMakesSold(validateAccounts);

            if(!accIdToNewMakesSolds.isEmpty()){

                Map<String,List<Set<String>>> programToMakes = CoOpProgramUtils.getOEMSponsorConfiguration();

                for(Account acc : validateAccounts){

                    String coOpProgram = acc.Co_Op_Program_Opt_In__c;

                    if(accIdToNewMakesSolds.containsKey(acc.Id) 
                    && programToMakes.containsKey(coOpProgram)){

                        Set<String> newMakesList = new Set<String>(accIdToNewMakesSolds.get(acc.Id).split(','));

                        Boolean validateMakes = false;

                        for(Set<String> allowedMakesSet : programToMakes.get(coOpProgram)){
                            if(allowedMakesSet.containsAll(newMakesList)){
                                validateMakes = true;
                                break;
                            }
                        }

                        if(!validateMakes){
                            //throw validation to error out invalid OEM makes against an Account
                            acc.addError('Please check "New Makes Sold" field on the related service providers with this account as it does not satisfy the '+coOpProgram+' requirements. A separate account needs to be created with the allowed OEM makes.');
                        }
                    }
                }
            }
        }
    }

    /**
     * Create Cancellation Case for Turnkey
     * @author 	Ramiro Alvarez
     * @module 	SA-957
     */

    public static void createCancellationCaseTurnkey(List<Account> newAccList,Map<Id,Account> oldAccountMap) {

        Map<Id,Account> accountMap = new Map<Id,Account> ();
        Id rtCancellation =  SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Cancellations');

        List<Case> casesToIns = new List<Case> ();
        for (Account acc : newAccList) {
            if (acc.Withdrawal_Date__c != null && oldAccountMap.get(acc.Id).Withdrawal_Date__c == null) {
                accountMap.put(acc.Id, acc);
            }
        }

        if (accountMap.isEmpty()) {
            return;
        }

        //Validate if there is a valid Turnkey contract for these accounts
        List<Contract> turnkeyContracts = [
            SELECT Id, AccountId, Co_Op_Program_Opt_in__c, Status, Account.Name
            FROM Contract
            WHERE AccountId IN :accountMap.KeySet()
            AND Co_Op_Program_Opt_in__c != NULL
            AND Status = 'Activated'
        ];

        Map<Id,Contract> accountContractIdMap = new Map<Id,Contract> ();
        for (Contract contract : turnkeyContracts) {
            accountContractIdMap.put(contract.AccountId, contract);
        }

        for (Id accId : accountMap.keySet()) {
            if (accountContractIdMap.containsKey(accId)) {
                
                Date firstDayOfMonth = System.today().toStartOfMonth();
                Date lastDayOfMonth = firstDayOfMonth.addDays(Date.daysInMonth(firstDayOfMonth.year(), firstDayOfMonth.month()) - 1);

                casesToIns.add(new Case(
                    Origin = 'Cancellation',
                    RecordTypeId = rtCancellation,
                    Subject = 'Turnkey Cancellation for '+ accountContractIdMap.get(accId).Account.Name,
                    Related_Contract__c = accountContractIdMap.get(accId).Id,
                    AccountId = accId,
                    Cancel_Override__c = lastDayOfMonth, //Set last Day of the current month
                    Reason = accountContractIdMap.get(accId).Co_Op_Program_Opt_in__c));
            }
        }

        if(!casesToIns.isEmpty()) {
            insert casesToIns;
            
            List<Id> caseIds = new List<Id> ();
            for (Case c : casesToIns) {
                caseIds.add(c.Id);
            }

            if(!System.isBatch() && !Test.isRunningTest()) {
               Database.executeBatch(new CancellationCasesProcessor(caseIds));
              }
        }
    }
    public static void requestedAccountRenewalFunctions(Map<Id, Account> oldAccounts, Map<Id, Account> updatedAccounts){
        for(Account acc : updatedAccounts.values()){
            if(acc.ApprovalStatus__c == 'Pending'){
                acc.Renewal_Status__c = REVIEW_IN_PROGRESS;
            }
        }
    }
    public static void approvedAccountRenewalFunctions(Map<Id, Account> oldAccounts, Map<Id, Account> updatedAccounts){
        //takes in old accounts and updated accounts
        for(Account acc : updatedAccounts.values()){
            Id accId = acc.Id;
            //if the account is approved make the changes
            if (acc.ApprovalStatus__c == 'Approved'){
                acc.Renewal_Status__c = PRICE_CHANGE_APPROVED;
                acc.Renewal_Period__c = null;
                //acc.Renewal_Eligible__c = False;
                //Don't untick the box when approved
            }
        }
    }

    public static void rejectedAccountRenewalFunctions(Map<Id, Account> oldAccounts, Map<Id, Account> updatedAccounts){
        for(Account acc : updatedAccounts.values()){
            if(acc.ApprovalStatus__c == 'Rejected'){
                acc.Renewal_Status__c = PRICE_CHANGE_REJECTED;
                acc.Renewal_Period__c = null;
                acc.Renewal_Eligible__c = False;
            }
        }
    }

}