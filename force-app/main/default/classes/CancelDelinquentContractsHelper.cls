
/**
 * BR-9607
 * Refactor the process to systematically cancel subscriptions that
 * are delinquent for 57 days past the original delinquency date. 
 * 
 * Instead of canceling the contract we will perform an amendment to 
 * only cancel the delinquent stores. 
 * If corporate account paying for all then they will all be delinquent, 
 * if multi store where stores are paying for themselves, then we do not 
 * cancel the contract but selectively amend to remove those stores.
 */

public without sharing class CancelDelinquentContractsHelper {
    
    public static final String SUB_DELINQUENT_STATUS = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_DELINQUENT;
    public static final String SUB_ACTIVATED_STATUS = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE;
    public static final String SUB_PENDING_STATUS = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_PENDING;

    public static final Set<String> queryCPQSubStatuses = new Set<String>{
        SUB_DELINQUENT_STATUS,
        SUB_ACTIVATED_STATUS,
        SUB_PENDING_STATUS
    };

    //Start here. Accept a list of contracts to examine for 
    //delinquent subscriptions
    public static void cancelDelinquentSubscriptions(Contract ct) {

        //Map of the contractId to a map of the provisioning status to list of subscriptions
        Map<String, List<SBQQ__Subscription__c>> statusToSubs = getAllCPQSubscriptions(ct);

        //figure out whether the contract needs to be cancelled or 
        //only delinquent subs need to be amended to cancel
        Id quoteId = amendContract(ct);
        
        Boolean isFullCancellation = determineCancellationScope(ct, statusToSubs);

        makeAmendmentUpdatesToQuote(ct, statusToSubs, quoteId, isFullCancellation);
    }

    //Query all the subscriptions, figure out if all subscriptions 
    //are delinquent (Example: when corporate pays for all the stores in the contract)
    public static Map<String, List<SBQQ__Subscription__c>> getAllCPQSubscriptions(Contract ct) {
        Map<String, List<SBQQ__Subscription__c>> statusToSubs = new Map<String, List<SBQQ__Subscription__c>>();

        List<SBQQ__Subscription__c> cpqSubs = [SELECT Id, Fulfillment_Account__c, Billing_Account__c, Billing_Status__c, 
            SBQQ__Contract__c, Provisioning_Status__c FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c = :ct.Id
            AND Provisioning_Status__c IN :queryCPQSubStatuses
            AND SBQQ__Quantity__c > 0];
        
        for(SBQQ__Subscription__c cpqsub : cpqSubs) {
            String provisioningStatus =  cpqSub.Provisioning_Status__c;
            System.debug(provisioningStatus);
            //We'll use this to determine if the contract has any active subscriptions so we can
            //determine if this is to be a full cancellation or a partial cancellation
            if(!statusToSubs.containsKey(provisioningStatus)) {
                statusToSubs.put(provisioningStatus, new List<SBQQ__Subscription__c>{cpqsub});

            } else {
                statusToSubs.get(provisioningStatus).add(cpqsub);
            }
        }

        return statusToSubs;
    }

    //Create an amendment quote for the contract that is passed in
    public static Id amendContract(Contract ct) {
        ContractAmender contractAmender = new ContractAmender();

        // returns quote model of amendment quote
        QuoteModel cancellationQuote = contractAmender.amend(ct.Id);

        return cancellationQuote.record.Id;
    }

    //determine scope full vs partial so we know that if it is a full cancellation, then we 
    //must mark the Cancellation Effective Date on the Contract
    public static Boolean determineCancellationScope(Contract ct, Map<String, List<SBQQ__subscription__c>> cpqsubs) {
        Boolean isFullCancellation = false;
        
        if( cpqsubs.containsKey(SUB_DELINQUENT_STATUS) && (!cpqsubs.containsKey(SUB_ACTIVATED_STATUS)
            && !cpqsubs.containsKey(SUB_PENDING_STATUS)) ) {

                isFullCancellation = true;
                System.debug(ct.Id + ': MARKED FOR FULL CANCELLATION');
        } else {
                isFullCancellation = false;
                System.debug(ct.Id + ': MARKED FOR PARTIAL CANCELLATION');
        }
        return isFullCancellation;
    }

    //Mark the quote lines to cancel depending on which associated subscriptions are delinquent.
    public static void makeAmendmentUpdatesToQuote(Contract ct, Map<String, List<SBQQ__Subscription__c>> statusToSubs, 
        Id cpqQuoteId, Boolean isFullCancellation) 
    {
        List<SBQQ__Subscription__c> delinquentCpqSubs = statusToSubs.get(SUB_DELINQUENT_STATUS);
        System.debug(delinquentCpqSubs.size());

        List<SBQQ__QuoteLine__c> cpqQuoteLines = [SELECT Id, SBQQ__Quantity__c FROM SBQQ__QuoteLine__c WHERE 
            SBQQ__UpgradedSubscription__c IN :delinquentCpqSubs AND SBQQ__Quote__c = :cpqQuoteId];

        System.debug(cpqQuoteLines);
        
        for(SBQQ__QuoteLine__c cpqQuoteLine : cpqQuoteLines) {
            cpqQuoteLine.SBQQ__Quantity__c = 0;
        }

        //set details on the quote to update
        SBQQ__Quote__c cpqQuote = new SBQQ__Quote__c(
            Id = cpqQuoteId,
            Cancellation_Quote__c = true,
            Quote_Comments__c = 'Quote automatically created on ' + Date.today() + ' for delinquency cancellation.',
            SBQQ__StartDate__c = Date.today(),
            SBQQ__ExpirationDate__c = null,
            SBQQ__Type__c = 'Cancellation'
        );

        //Disable cpq triggers and update the quote and quote lines
        SBQQ.TriggerControl.disable();

        update cpqQuote;
        update cpqQuoteLines;

        //Enable cpq triggers
        SBQQ.TriggerControl.enable();

        //if full cancellation mark date on the contract
        if(isFullCancellation) {
            ct.Cancellation_Effective_Date__c = Date.today();
            update ct;
        }
    }
}
