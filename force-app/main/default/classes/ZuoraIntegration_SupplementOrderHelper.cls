/**
 * BR-1273, Zuora Order API implementation that can be used for terms and conditions amendments
 * The Supplement Order Helper sets up the Order contained in the SupplementOrder class
 * and generates a message
 */

public without sharing class ZuoraIntegration_SupplementOrderHelper {

    @TestVisible static Boolean disableZuoraActions = false;
    public static final String RENEW_SUB_ACTIONTYPE = 'RenewSubscription';
    static final String SUBSCRIPTION_PROVISIONINGSTATUS_INACTIVE = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_INACTIVE;
    static final String PROCESS_ZORDER_TERMS = Integrations.PROCESS_ZORDER_TERMS;
    static final String REQUEST_STATUS_NEW = Integrations.REQUEST_STATUS_NEW;
    static final Datetime SENDAFTERONDEMAND = Datetime.now().addMinutes(10);
    static final Datetime SENDINQUEUE = Datetime.now().addMinutes(-10);
    static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;
    static final String CGBASE_PRODUCTCODE = ConstantsUtil.PRODUCT_PRODUCTCODE_CGBASE;

    //Takes in the contract ids, the autoRenew value to set and a boolean to send immediately
    public static void sendAmendTermsMessages(Set<Id> contractIds, Boolean autoRenew, Boolean sendImmediately) {

        // continue if integration enabled
        if (!INTEGRATION_CONTROLS.Enable_Zuora_Integration__c || contractIds.isEmpty() || disableZuoraActions) {
            return;
        }

        if (!System.isBatch() && !System.isFuture() && !Test.isRunningTest()) {
            sendAmendTermsMessagesFuture(contractIds, autoRenew, sendImmediately);
            return;
        }

        List<Integration_Message__c> zTermsAmendMessages = getZTermsAmendMessages(contractIds, autoRenew, sendImmediately);
        insert zTermsAmendMessages;

        if (sendImmediately) {
            Integrations.sendMessageIdsToBoomi(zTermsAmendMessages);
        }
    }

    //@future implementation
    @future
    public static void sendAmendTermsMessagesFuture(Set<Id> contractIds, Boolean autoRenew, Boolean sendImmediately) {
        sendAmendTermsMessages(contractIds, autoRenew, sendImmediately);
    }

    // override for commtiment term extensions
    public static void sendAmendTermsMessages(Map<Id, Id> contractIdToOrderMap, Boolean sendImmediately) {

        // continue if integration enabled
        if (!INTEGRATION_CONTROLS.Enable_Zuora_Integration__c || contractIdToOrderMap.keySet().isEmpty() || disableZuoraActions) {
            return;
        }

        
        if (!System.isBatch() && !System.isFuture() && !Test.isRunningTest()) {
            sendAmendTermsMessagesFuture(contractIdToOrderMap, sendImmediately);
            return;
        }

        List<Integration_Message__c> zTermsAmendMessages = 
            getZTermsCommitmentAmendMessages(contractIdToOrderMap, sendImmediately);

        insert zTermsAmendMessages;

        if (sendImmediately) {
            Integrations.sendMessageIdsToBoomi(zTermsAmendMessages);
        }
    }


    //@future implementation, override
    @future
    public static void sendAmendTermsMessagesFuture(Map<Id, Id> contractIdToOrderMap, Boolean sendImmediately) {
        sendAmendTermsMessages(contractIdToOrderMap, sendImmediately);
    }


    // BR-3733 Send Amend Transfer Owner Messages
    public static void sendAmendTransferOwnerMessages(Set<Id> subIds, Boolean sendImmediately) {
        
        if (!INTEGRATION_CONTROLS.Enable_Zuora_Integration__c || subIds.isEmpty() || disableZuoraActions) {
            return;
        }

        /*
        if (!System.isBatch() && !System.isFuture() && !Test.isRunningTest()) {
            sendAmendTransferOwnerMessagesFuture
            return;
        }*/

        List<Integration_Message__c> zTermsAmendMessages = getZTransferOwnerAmendMessages(subIds, sendImmediately);
        insert zTermsAmendMessages;

        if (sendImmediately) {
            Integrations.sendMessageIdsToBoomi(zTermsAmendMessages);
        }
    }

    // BR-3733 Send Amend Transfer Owner Messages - Future implementation
    @future
    public static void sendAmendTransferOwnerMessagesFuture(Set<Id> subIds, Boolean sendImmediately) {
        sendAmendTransferOwnerMessages(subIds, sendImmediately);
    }

    //BR-7742
    public static void sendRenewalPriorToCancellation(Set<Id> orderIds, Boolean sendImmediately) {
        if (!INTEGRATION_CONTROLS.Enable_Zuora_Integration__c || orderIds.isEmpty() || disableZuoraActions) {
            return;
        }

        if (!System.isBatch() && !System.isFuture() && !System.isQueueable() && !Test.isRunningTest()) {
            sendRenewalMessagesFuture(orderIds, sendImmediately);
            return;
        }

        List<Integration_Message__c> renewalMessages = getRenewalMessages(orderIds, sendImmediately);
        if(renewalMessages.isEmpty()) {
            return;
        }
        insert renewalMessages;

        if (sendImmediately) {
            Integrations.sendMessageIdsToBoomi(renewalMessages);
        }
    }

    public static List<Integration_Message__c> getRenewalMessages(Set<Id> orderIds, Boolean sendImmediately) {
        List<Integration_Message__c> renewMessages = new List<Integration_Message__c>();
        List<SBQQ__Subscription__c> cpqBaseSubs = getCancelingBaseBundleSubsFromOrders(orderIds);
        if(cpqBaseSubs.isEmpty()) {
            return new List<Integration_Message__c>();
        }
        Set<String> zSubNumProcessed = new Set<String>();
        for(SBQQ__Subscription__c cpqBaseSub :cpqBaseSubs) {
            if(zSubNumProcessed.contains(cpqBaseSub.SBQQ__RevisedSubscription__r.Zuora_Subscription_Number__c)) {
                continue;
            }
            zSubNumProcessed.add(cpqBaseSub.SBQQ__RevisedSubscription__r.Zuora_Subscription_Number__c);
            renewMessages.add(createIntegrationMessage(cpqBaseSub, RENEW_SUB_ACTIONTYPE, sendImmediately));
        }
        return renewMessages;
    }

    @future
    public static void sendRenewalMessagesFuture(Set<Id> orderIds, Boolean sendImmediately) {
        sendRenewalPriorToCancellation(orderIds, sendImmediately);
    }

    //creates and returns an Integration message for each CPQ Base Sub
    public static Integration_Message__c createIntegrationMessage(SBQQ__Subscription__c cpqBaseSub, 
        String actionType, Boolean sendImmediately) 
    {
        // serialize json
        String jsonString = ZuoraIntegration_SupplementOrder.getSerializedRenewalOrder(cpqBaseSub, actionType);

        // return message
        return new Integration_Message__c(
            Account__c = cpqBaseSub.Fulfillment_Account__c,
            CPQ_Order__c = cpqBaseSub.SBQQ__OrderProduct__r.OrderId,
            Request_Body__c = jsonString,
            Request_Status__c = REQUEST_STATUS_NEW,
            Process__c = PROCESS_ZORDER_TERMS,
            Order_Type__c = actionType,
            Send_After__c = (sendImmediately ? SENDAFTERONDEMAND : SENDINQUEUE)
        );
    }

    //for each CG Base Bundle CPQ Sub, sets up the amend terms message
    public static List<Integration_Message__c> getZTermsAmendMessages(
        Set<Id> contractIds, 
        Boolean autoRenew, 
        Boolean sendImmediately
    ) {
        List<Integration_Message__c> amendMessages = new List<Integration_Message__c>();
        List<SBQQ__Subscription__c> cpqBaseSubs = getBaseBundleSubscriptions(contractIds);
        Set<String> zSubNumProcessed = new Set<String>();
        for(SBQQ__Subscription__c cpqBaseSub :cpqBaseSubs) {
            if(zSubNumProcessed.contains(cpqBaseSub.Zuora_Subscription_Number__c)) {
                continue;
            }
            zSubNumProcessed.add(cpqBaseSub.Zuora_Subscription_Number__c);
            amendMessages.add(createIntegrationMessage(cpqBaseSub, autoRenew, sendImmediately));
        }
        return amendMessages;
    }

    //for each CG Base Bundle CPQ Sub, sets up the amend terms message
    public static List<Integration_Message__c> getZTermsCommitmentAmendMessages(
        Map<Id,Id> contractIdToOrderMap,
        Boolean sendImmediately
    ) {

        Set<Id> contractIds = contractIdToOrderMap.keySet();
        List<Id> orderIds = contractIdToOrderMap.values();

        String commitmentTerm;
        Integer commitmentPeriod;

        Map<Id, Order> orderMap = new Map<Id, Order>([
            SELECT Id, Type, EffectiveDate, Initial_Term_End_Date__c 
            FROM Order 
            WHERE Id 
            IN: orderIds
        ]);

        List<Integration_Message__c> amendMessages = new List<Integration_Message__c>();
        List<SBQQ__Subscription__c> cpqBaseSubs = getBaseBundleSubscriptions(contractIds);

        Set<String> zSubNumProcessed = new Set<String>();

        for(SBQQ__Subscription__c cpqBaseSub : cpqBaseSubs) {

            Id contractId = cpqBaseSub.SBQQ__Contract__c;
            Id orderId = contractIdToOrderMap.get(contractId);

            Order order = orderMap.get(orderId);

            if(zSubNumProcessed.contains(cpqBaseSub.Zuora_Subscription_Number__c)) {
                continue;
            }

            // calculate commitment periods & term
            commitmentTerm = 'Day';

            if (order.Type == 'Amendment'){
                commitmentPeriod = calculateCommitmentPeriod(order.EffectiveDate, order.Initial_Term_End_Date__c);
            } else {
                commitmentPeriod = calculateCommitmentPeriod(cpqBaseSub.SBQQ__SubscriptionStartDate__c, cpqBaseSub.SBQQ__EndDate__c);
            }
            

            zSubNumProcessed.add(cpqBaseSub.Zuora_Subscription_Number__c);

            // create amendment integration messages
            amendMessages.add(
                createCommitmentIntegrationMessage(
                    cpqBaseSub, orderId, true, commitmentTerm, commitmentPeriod, sendImmediately
                )
            );
        }
        return amendMessages;
    }

    // BR-3733 for each CG Base Bundle CPQ Sub, sets up the transfer owner message
    public static List<Integration_Message__c> getZTransferOwnerAmendMessages(Set<Id> subIds, Boolean sendImmediately) {

        String newAccountNum;        
        List<Integration_Message__c> amendMessages = new List<Integration_Message__c>();
        List<SBQQ__Subscription__c> cpqBaseSubs = getBaseBundleSubscriptionsFromSubIds(subIds);
        Set<String> zSubNumProcessed = new Set<String>();
        for(SBQQ__Subscription__c cpqBaseSub :cpqBaseSubs) {
            
            newAccountNum = cpqBaseSub.Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c;            
            if(zSubNumProcessed.contains(cpqBaseSub.Zuora_Subscription_Number__c) || newAccountNum == null) {
                continue;
            }
            
            zSubNumProcessed.add(cpqBaseSub.Zuora_Subscription_Number__c);
            amendMessages.add(createIntegrationMessageTransferOwner(cpqBaseSub, newAccountNum, sendImmediately));
        }
        return amendMessages;
    }

    //creates and returns an Integration message for each CPQ Base Sub
    public static Integration_Message__c createIntegrationMessage(
        SBQQ__Subscription__c cpqBaseSub,
        Boolean autoRenew, 
        Boolean sendImmediately
    ) {
        // serialize json
        String jsonString = ZuoraIntegration_SupplementOrder.getSerializedTermsOrder(cpqBaseSub, autoRenew);
        // return message
        return new Integration_Message__c(
            Account__c = cpqBaseSub.Fulfillment_Account__c,
            //CPQ_Order__c = orderId,
            Request_Body__c = jsonString,
            Request_Status__c = REQUEST_STATUS_NEW,
            Process__c = PROCESS_ZORDER_TERMS,
            Send_After__c = (sendImmediately ? SENDAFTERONDEMAND : SENDINQUEUE)
        );
    }

    //creates and returns an Integration message for each CPQ Base Sub
    public static Integration_Message__c createCommitmentIntegrationMessage(
        SBQQ__Subscription__c cpqBaseSub,
        Id orderId,
        Boolean autoRenew, 
        String commitmentTerm, 
        Integer commitmentPeriod, 
        Boolean sendImmediately
    ) {
        // serialize json
        String jsonString = ZuoraIntegration_SupplementOrder.getSerializedCommitmentTermsOrder(
            cpqBaseSub, true, commitmentPeriod, commitmentTerm, 'TERMED');
        // return message
        return new Integration_Message__c(
            Account__c = cpqBaseSub.Fulfillment_Account__c,
            CPQ_Order__c = orderId,
            Request_Body__c = jsonString,
            Request_Status__c = REQUEST_STATUS_NEW,
            Process__c = PROCESS_ZORDER_TERMS,
            Send_After__c = (sendImmediately ? SENDAFTERONDEMAND : SENDINQUEUE)
        );
    }

    //creates and returns an Integration message for each CPQ Base Sub - Transfer Owner
    public static Integration_Message__c createIntegrationMessageTransferOwner(
        SBQQ__Subscription__c cpqBaseSub,
        String accountNumNew,
         Boolean sendImmediately
    ) {
        // serialize json
        String jsonString = ZuoraIntegration_SupplementOrder.getSerializedTransferOwner(cpqBaseSub, accountNumNew);
        //return message
        return new Integration_Message__c(
            Account__c = cpqBaseSub.Fulfillment_Account__c,
            //CPQ_Order__c = orderId,
            Request_Body__c = jsonString,
            Request_Status__c = REQUEST_STATUS_NEW,
            Process__c = PROCESS_ZORDER_TERMS,
            Send_After__c = (sendImmediately ? SENDAFTERONDEMAND : SENDINQUEUE)
        );
    }

    //query to fetch base bundle subscriptions parented by the contract ids that are passed in
    //from the batch
    public static List<SBQQ__Subscription__c> getBaseBundleSubscriptions(Set<Id> contractIds) {
        return [SELECT Id, Zuora_Subscription__r.Zuora__Zuora_Id__c, Zuora_Subscription_Number__c, 
                Zuora_Subscription__r.Zuora__AutoRenew__c, Fulfillment_Account__c,
                Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c,
                SBQQ__Contract__c, SBQQ__EndDate__c, SBQQ__SubscriptionStartDate__c 	
                FROM  SBQQ__Subscription__c
                WHERE SBQQ__ProductName__c = 'CG Base Bundle' 
                AND Provisioning_Status__c != :SUBSCRIPTION_PROVISIONINGSTATUS_INACTIVE
                AND Zuora_Subscription__c != null 
                AND SBQQ__Contract__c IN :contractIds];
    }

    public static List<SBQQ__Subscription__c> getBaseBundleSubscriptionsFromSubIds(Set<Id> subIds) {
        return [SELECT Id, Zuora_Subscription__r.Zuora__Zuora_Id__c, Zuora_Subscription_Number__c, 
                Zuora_Subscription__r.Zuora__AutoRenew__c, Fulfillment_Account__c,
                Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c,
                SBQQ__EndDate__c, SBQQ__SubscriptionStartDate__c,
                Zuora_Subscription__r.Zuora__CustomerAccount__r.Zuora__AccountNumber__c,
                Zuora_Subscription__r.Zuora__InvoiceOwner__r.Zuora__AccountNumber__c
                FROM  SBQQ__Subscription__c
                WHERE SBQQ__Product__r.ProductCode = :ConstantsUtil.PRODUCT_PRODUCTCODE_CGBASE
                AND Provisioning_Status__c != :SUBSCRIPTION_PROVISIONINGSTATUS_INACTIVE
                AND Zuora_Subscription__c != null 
                // AND Zuora_Subscription__r.Zuora__AutoRenew__c = true
                AND Id IN :subIds];
    }

    // calculates commitment period for commitment period updates
    public static Integer calculateCommitmentPeriod(Date startDate, Date endDate) {
       return (startDate.daysBetween(endDate) + 1);
    } 

    public static List<SBQQ__Subscription__c> getCancelingBaseBundleSubsFromOrders(Set<Id> orderIds) {
        //base bundles to return, these are base bundles whose related zuora subscriptions 
        //will have to renewed before the cancellation
        List<SBQQ__Subscription__c> retBaseBundles = new List<SBQQ__Subscription__c>();
        List<Order> ordersUpdates = new List<Order>();

        Map<Id, Order> orders = new Map<Id, Order>([SELECT Id, EffectiveDate, Activation_Status_Renew_Prior__c,
            Activation_Zuora_Subscription__c FROM Order WHERE Id IN :orderIds]);

        List<SBQQ__Subscription__c> cpqCancelingBaseBundles = [SELECT Id, SBQQ__RevisedSubscription__r.Zuora_Subscription_Number__c, 
            Fulfillment_Account__c, Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c, SBQQ__OrderProduct__c,
            SBQQ__OrderProduct__r.OrderId, SBQQ__RevisedSubscription__r.Zuora_Subscription__r.Zuora__TermEndDate__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__OrderProduct__c IN 
            (SELECT Id FROM OrderItem WHERE Product2.ProductCode = :CGBASE_PRODUCTCODE AND Quantity < 0 AND OrderId IN :orderIds)];

        for(SBQQ__Subscription__c cpqBaseSub : cpqCancelingBaseBundles) {
            Id orderProductId = cpqBaseSub.SBQQ__OrderProduct__c;
            if(orderProductId == null) {
                continue;
            }

            Id orderId = cpqBaseSub.SBQQ__OrderProduct__r.OrderId;
            Order ord = orders.get(orderId);
            Date zTermEndDate = cpqBaseSub.SBQQ__RevisedSubscription__r.Zuora_Subscription__r.Zuora__TermEndDate__c;
            Date effectiveDate = ord.EffectiveDate;
            Integer daysBetween = zTermEndDate.daysBetween(effectiveDate);

            if(daysBetween > 1) {
                retBaseBundles.add(cpqBaseSub);
            } else {
                ord.Activation_Status_Renew_Prior__c = ConstantsUtil.ACTIVATION_STATUS_NA;
                ord.Activation_Zuora_Subscription__c = ConstantsUtil.ACTIVATION_STATUS_PENDING;
                ordersUpdates.add(ord);
            }
        }

        if(!ordersUpdates.isEmpty()) {
            update ordersUpdates;
        }

        return retBaseBundles;
    }
}