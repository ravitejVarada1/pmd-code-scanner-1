/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     alaplante
* created:        03/11/2021
* modified:       06/09/2021
* created jira:   BR-367 & BR-368
* updated jira:   BR-371 & BR-2564
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class AccountTriggerHandler extends TriggerHandler {

    private List<Account> newAList; //new/updated business accounts
    private Map<Id,Account> newAMap; //new/updated business accounts map
    private List<Account> oldAList; //old version business accounts
  	private Map<Id,Account> oldAMap; //old version business accounts map

    public AccountTriggerHandler(){

        setContextVariables();
    }

    public override void afterInsert() {
        AccountTriggerFunctions.createCaseRecord(newAList);
        AccountTriggerFunctions.newAccountUltParentCleanup(newAList);
        AccountTriggerFunctions.evaluateAccountSaturationChange(newAList, null);
        CG_AccountHelper.processAccountFeatureUpdates(newAList, oldAMap); // BR-884   
    }

    public override void afterUpdate() {
        AccountTriggerFunctions.createZuoraIntegrationMessage(newAList, oldAMap); // BR-1492
        AccountTriggerFunctions.accountCategoryCheckUpdate(newAList, oldAMap);
        AccountTriggerFunctions.ultParentChangedDataCleanup(newAList, oldAMap);
        AccountTriggerFunctions.evaluateAccountSaturationChange(newAList, oldAMap);
        CG_AccountHelper.processAccountFeatureUpdates(newAList, oldAMap);   // BR-884
        AccountTriggerFunctions.checkBillingContactPopulated(newAList, oldAMap);
        CG_AccountOwnership.returnAccountOwnerToCGAPIUser(newAList, oldAMap);
        AccountTriggerFunctions.updateGroupStatistics(newAList, oldAMap);
        AccountTriggerFunctions.createRenewalRecord(newAList, oldAMap);
        AccountTriggerFunctions.setRenewalRecordstatus(newAList, oldAMap);
        AccountTriggerFunctions.updateContractEndDateOnRenewalsAutoPay(newAList, oldAMap); //DSS-33

        //BR-7581 If an Account is changed to UltimateAccount from NOT UltimateAccount
        //updates its child accounts UltimateAccount Field
        AccountTriggerFunctions.updateChildAccRecordsUltAccount(newAList, oldAMap);

        AccountTriggerFunctions.createCancellationCaseTurnkey(newAList, oldAMap);


    }
    
    public override void afterUndelete() {
        AccountTriggerFunctions.newAccountUltParentCleanup(newAList);
        AccountTriggerFunctions.evaluateAccountSaturationChange(newAList, null);
    }

    public override void afterDelete() {
        AccountTriggerFunctions.deletedAccountUltParentCleanup(oldAList);
        AccountTriggerFunctions.evaluateAccountSaturationChange(oldAList, null);
    }
    
    public override void beforeInsert() {
        AccountTriggerFunctions.setUltimateParent(newAList,null); // BR-1510
        AccountTriggerFunctions.checkCurrencyField(newAList, null);
        AccountTriggerFunctions.evaluateLanguageDefaulting(newAList); // BR-2564
        AccountTriggerFunctions.evaluateCoOpProgramSelection(newAList,null);//SA-791
    }

    public override void beforeUpdate() {
        AccountTriggerFunctions.setUltimateParent(newAList,oldAMap); // BR-1510
        AccountTriggerFunctions.checkCurrencyField(newAList, oldAMap);
        AccountLimitHandler.verifyOwnerChange(newAList, oldAMap);
        AccountTriggerFunctions.checkCancellingProductActivationStatus(newAList, oldAMap);
        AccountTriggerFunctions.ownerChangeResetLastActivityDate(newAMap, oldAMap); //BR-3942
        AccountTriggerFunctions.updateAccountStatus(newAList, oldAMap);//SA-705
        AccountTriggerFunctions.evaluateCoOpProgramSelection(newAList,oldAMap);//SA-791
        AccountTriggerFunctions.requestedAccountRenewalFunctions(oldAMap, newAMap);
        AccountTriggerFunctions.approvedAccountRenewalFunctions(oldAMap, newAMap);
        AccountTriggerFunctions.rejectedAccountRenewalFunctions(oldAMap, newAMap);
    }

    public override void beforeDelete() {
        AccountTriggerFunctions.preventAccountMerge(oldAList); //BR-1044
    }

    public void setContextVariables() {

        if (Trigger.isInsert || Trigger.isUpdate) {
            this.newAList = new List<Account>();

            for(Account a : (List<Account>)Trigger.new) {
                if(!a.IsPersonAccount) { 
                    this.newAList.add(a);
                }
            }
        }

        if ( (Trigger.isInsert && Trigger.isAfter) || Trigger.isUpdate ) {
            this.newAMap = new Map<Id, Account>(newAList);
            
        }
        
        
        if ( Trigger.isUpdate || Trigger.isDelete ) { 
            this.oldAList = new List<Account>();

            for(Account a : (List<Account>)Trigger.old) {
                if(!a.IsPersonAccount) {
                    this.oldAList.add(a);
                }
            }

            this.oldAMap = new Map<Id, Account>(oldAList);

        }
        
        if(Trigger.isUnDelete){
            this.newAList = new List<Account>();
            
            for(Account a : (List<Account>)Trigger.new) {
                if(!a.IsPersonAccount) { 
                    this.newAList.add(a);
                }
            }
            
        }
    }

}