/**
 * BR-8618 
 * 
 * Batch looks for Accounts that are past 57 days in the canceling status and
 * sets the Product Activation Status to Restricted - Activated
 * 
 * Unit tests in Batch_AccoutnsToStatusTest.cls
 */

public without sharing class Batch_AccountsToRestrictedActivated implements Database.Batchable<sObject>, Schedulable {

    public static final String CPQSUB_PROVISIONING_STATUS_ACTIVE = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE;
    public static final String CPQSUB_PROVISIONING_STATUS_DELINQUENT = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_DELINQUENT;
    public static final String CONTRACT_CANCELLED = ConstantsUtil.CONTRACT_STATUS_CANCELLED;
    public static final String PRODUCT_ACTIVATION_STATUS_CANCELING = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_CANCELING57DAYS;
    public static final String PRODUCT_ACTIVATION_STATUS_RESTRICTED = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_RESTRICTEDACTIVATED;
    public static final String PRODUCT_ACTIVATION_STATUS_TRIAL = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_TRIAL;
    public static final String PRODUCT_ACTIVATION_STATUS_BLOCKED = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_BLOCKED;
    public static final String ACCOUNT_STATUS_INACTIVE = ConstantsUtil.ACCOUNT_STATUS_INACTIVE;

    

    Set<String> productActivationStatusExclude = new Set<String>{
        PRODUCT_ACTIVATION_STATUS_RESTRICTED,
        PRODUCT_ACTIVATION_STATUS_BLOCKED,
        PRODUCT_ACTIVATION_STATUS_TRIAL
    };

    //SA-270 excludes accounts with delinquent subscriptions when those subscriptions are current
    Set<String> subsProvisioningStatusExclude = new Set<String>{
        CPQSUB_PROVISIONING_STATUS_ACTIVE,
        CPQSUB_PROVISIONING_STATUS_DELINQUENT
    };

    //default constructor
    public Batch_AccountsToRestrictedActivated() {}

    //Execute for the scheduleable
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_AccountsToRestrictedActivated(), 200);
    }

    //modified to now verify that the Account does not have any Activated subscriptions
    //before we set them to former customer and canceling 57 days
    public Database.QueryLocator start(Database.BatchableContext BC) { 
        String accountQuery = 'SELECT Id, Type, Product_Activation_Status__c '+
            'FROM Account WHERE Id IN '+
                '(SELECT Fulfillment_Account__c FROM SBQQ__Subscription__c WHERE SBQQ__Contract__r.Status = :CONTRACT_CANCELLED '+ 
                    'AND SBQQ__Contract__r.Cancellation_Effective_Date__c < LAST_N_DAYS:57) '+
                'AND Id NOT IN '+
                '(SELECT Fulfillment_Account__c FROM SBQQ__Subscription__c WHERE Provisioning_Status__c IN :subsProvisioningStatusExclude  '+
                'OR SBQQ__Contract__r.Cancellation_Effective_Date__c = LAST_N_DAYS:57) '+
            'AND Product_Activation_Status__c NOT IN :productActivationStatusExclude '+
            'AND Account_Status__c != :ACCOUNT_STATUS_INACTIVE';

        return Database.getQueryLocator(accountQuery);
    }
    
    //Keep the type as Former Customer and update the product activation status
    //to Restricted - Activated
    public void execute(Database.BatchableContext BC, List<Account> accounts) {
        for(Account acc : accounts) {
            acc.Type = 'Former Customer';
            acc.Product_Activation_Status__c = PRODUCT_ACTIVATION_STATUS_RESTRICTED;
        }
        update accounts;
    }
    
    public void finish(Database.BatchableContext BC) {
        
    }
}
