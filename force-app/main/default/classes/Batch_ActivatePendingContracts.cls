/**
 * BR-1452 - Update contract status from Pending Activation to Activated
 * when the contract dates are current. Also update the Account Product Activation
 * Status to Active (API Name) if not in an Active status
 * BR-2719, BR-2729
 */
public with sharing class Batch_ActivatePendingContracts implements Database.Batchable<sObject> {
    
    public static final String CONTRACT_STATUS_PENDING = ConstantsUtil.CONTRACT_STATUS_PENDING;
    public static final String CONTRACT_STATUS_ACTIVE = ConstantsUtil.CONTRACT_STATUS_ACTIVE;
    public static final String ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE;
    public static final String SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE;
    public static final String SUBSCRIPTION_PROVISIONINGSTATUS_PENDING = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_PENDING;
    public static Set<String> cpqSubQueryStatuses = new Set<String>{
        SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE, SUBSCRIPTION_PROVISIONINGSTATUS_PENDING
    };

    public Batch_ActivatePendingContracts() {}

    public Database.QueryLocator start(Database.BatchableContext BC){
        //commenting out to accomodate activating accounts in amended contracts - smoke test
        /*String query = 'SELECT Id, StartDate, EndDate, Status, '+
            '(SELECT Id, Fulfillment_Account__c, Fulfillment_Account__r.Product_Activation_Status__c '+
            'FROM SBQQ__Subscriptions__r WHERE Provisioning_Status__c IN :cpqSubQueryStatuses)  '+
            'FROM Contract WHERE Status = :CONTRACT_STATUS_PENDING'+
            'AND StartDate <= TODAY AND EndDate > TODAY';*/

        String query = 'SELECT Id, SBQQ__Contract__c, SBQQ__Contract__r.Status, Provisioning_Status_Formula__c, '+
        'Fulfillment_Account__c, Fulfillment_Account__r.Product_Activation_Status__c '+
        'FROM SBQQ__Subscription__c WHERE '+
        '(Provisioning_Status__c IN :cpqSubQueryStatuses AND SBQQ__Contract__r.Status = :CONTRACT_STATUS_PENDING AND SBQQ__Contract__r.StartDate <= Today AND SBQQ__Contract__r.EndDate >=Today) '+
        'OR (SBQQ__Contract__r.Status = :CONTRACT_STATUS_ACTIVE '+
                'AND Fulfillment_Account__r.Product_Activation_Status__c != :ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE)';
        
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SBQQ__Subscription__c> cpqSubs) {

        if(cpqSubs.isEmpty()) {
            return;
        }

        Set<Id> contractsToUpdateIds = new Set<Id>();
        Set<Id> accountsToUpdateIds = new Set<Id>();

        List<Contract> contractsToUpdate = new List<Contract>();
        List<Account> accountsToUpdate = new List<Account>();

        for(SBQQ__Subscription__c cpqSub : cpqSubs) {

            String contractStatus = cpqSub.SBQQ__Contract__r.Status;
            Id contractId = cpqSub.SBQQ__Contract__c;
            
            if( !contractsToUpdateIds.contains(contractId) && 
                    contractStatus == ConstantsUtil.CONTRACT_STATUS_PENDING) 
            {
                contractsToUpdateIds.add(contractId);
                Contract tmpCt = new Contract(
                    Id = contractId,
                    Status = CONTRACT_STATUS_ACTIVE
                );
                contractsToUpdate.add(tmpCt);
            }

            String fulAccountStatus = cpqSub.Fulfillment_Account__r.Product_Activation_Status__c;
            Id fulAccountId = cpqSub.Fulfillment_Account__c;

            if( !accountsToUpdateIds.contains(fulAccountId) &&
                fulAccountStatus != ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE &&
                cpqSub.Provisioning_Status_Formula__c == SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE)
            {
                accountsToUpdateIds.add(fulAccountId);
                Account tmpAcc = new Account(
                    Id = fulAccountId,
                    Type = 'Customer',
                    Product_Activation_Status__c = ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE
                );
                accountsToUpdate.add(tmpAcc);
            }
            
        }

        if(!contractsToUpdate.isEmpty()) {
            update contractsToUpdate;
        }
        
        if(!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    public void finish(Database.BatchableContext BC) {
        
    }
}
