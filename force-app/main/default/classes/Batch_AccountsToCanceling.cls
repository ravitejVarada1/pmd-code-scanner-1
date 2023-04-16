/**
 * BR-8618
 * 
 * Batch that looks for contracts with cancellation effective date that
 * is within the past 57 days and sets the Account Product Activation
 * Status to Canceling – 57 days
 * 
 * Unit tests in Batch_AccoutnsToStatusTest.cls
 * 
 */

public without sharing class Batch_AccountsToCanceling  implements Database.Batchable<sObject>, Schedulable {

    public static final String CPQSUB_PROVISIONING_STATUS_ACTIVE = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE;
    public static final String CPQSUB_PROVISIONING_STATUS_DELINQUENT = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_DELINQUENT;
    public static final String CONTRACT_CANCELLED = ConstantsUtil.CONTRACT_STATUS_CANCELLED;
    public static final String PRODUCT_ACTIVATION_STATUS_CANCELING = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_CANCELING57DAYS;
    public static final String PRODUCT_ACTIVATION_STATUS_BLOCKED = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_BLOCKED;
    public static final String PRODUCT_ACTIVATION_STATUS_TRIAL = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_TRIAL;
    public static final String ACCOUNT_STATUS_INACTIVE = ConstantsUtil.ACCOUNT_STATUS_INACTIVE;

    Set<String> productActivationStatusExclude = new Set<String>{
        PRODUCT_ACTIVATION_STATUS_CANCELING,
        PRODUCT_ACTIVATION_STATUS_BLOCKED,
        PRODUCT_ACTIVATION_STATUS_TRIAL
    };

    //SA-270 excludes accounts with delinquent subscriptions when those subscriptions are current
    Set<String> subsProvisioningStatusExclude = new Set<String>{
        CPQSUB_PROVISIONING_STATUS_ACTIVE,
        CPQSUB_PROVISIONING_STATUS_DELINQUENT
    };
    
    //default constructor
    public Batch_AccountsToCanceling() {}

    //Execute for the scheduleable
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_AccountsToCanceling(), 200);
    }

    //modified to now verify that the Account does not have any Activated subscriptions
    //before we set them to former customer and canceling 57 days
    public Database.QueryLocator start(Database.BatchableContext BC) { 
        String accountQuery = 'SELECT Id, Type, Product_Activation_Status__c '+
            'FROM Account WHERE Id IN '+
                '(SELECT Fulfillment_Account__c FROM SBQQ__Subscription__c WHERE SBQQ__Contract__r.Status = :CONTRACT_CANCELLED '+ 
                    'AND SBQQ__Contract__r.Cancellation_Effective_Date__c = LAST_N_DAYS:57) '+
                'AND Id NOT IN '+
                '(SELECT Fulfillment_Account__c FROM SBQQ__Subscription__c WHERE Provisioning_Status__c IN :subsProvisioningStatusExclude '+
                    'AND SBQQ__EndDate__c > TODAY AND (SBQQ__TerminatedDate__c = null OR SBQQ__TerminatedDate__c > TODAY)) '+
            'AND Product_Activation_Status__c NOT IN :productActivationStatusExclude '+
            'AND Account_Status__c != :ACCOUNT_STATUS_INACTIVE';
        System.debug('accountQuery === '+accountQuery);
        return Database.getQueryLocator(accountQuery);
    }
    
    //set the type to former customer and set the product activation status to
    //Canceling - 57
    public void execute(Database.BatchableContext BC, List<Account> accounts) {
        
        Map<Id, Date> accToCancellationDateMap = new Map<Id, Date>();
        
        for(SBQQ__Subscription__c sub : [SELECT Id, SBQQ__Contract__c, SBQQ__Contract__r.Cancellation_Effective_Date__c, Fulfillment_Account__c FROM SBQQ__Subscription__c 
            WHERE Fulfillment_Account__c IN :accounts AND SBQQ__Contract__r.Status = :CONTRACT_CANCELLED AND Product_Code__c = 'CG-BASE'
            ORDER BY SBQQ__Contract__c, SBQQ__Contract__r.Cancellation_Effective_Date__c DESC]) {

            Id ffAccountId = sub.Fulfillment_Account__c;
            Date contractCancelEffDate = sub.SBQQ__Contract__r.Cancellation_Effective_Date__c;

            if(!accToCancellationDateMap.containsKey(ffAccountId)) {
                accToCancellationDateMap.put(ffAccountId, contractCancelEffDate);
            } else {
                Date cancellationDate = accToCancellationDateMap.get(ffAccountId);
                if(cancellationDate < contractCancelEffDate) {
                    accToCancellationDateMap.put(ffAccountId, contractCancelEffDate);
                }
            }
        }


        for(Account acc : accounts) {
            acc.Type = 'Former Customer';
            acc.Product_Activation_Status__c = PRODUCT_ACTIVATION_STATUS_CANCELING;
            acc.Last_Cancellation_Effective_Date__c = accToCancellationDateMap.get(acc.Id);
        }
        update accounts;
    }
    
    public void finish(Database.BatchableContext BC) {
        
    }

}