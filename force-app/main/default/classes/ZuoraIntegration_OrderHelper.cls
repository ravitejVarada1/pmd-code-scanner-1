// https://cargurus.atlassian.net/browse/BR-894
public without sharing class ZuoraIntegration_OrderHelper {

    // boolean to shut off integration automation when setting up test data
    @TestVisible static Boolean disableZuoraActions = false;

    public static final String ZCHARGEMODEL_PERUNIT = 'Per Unit';
    public static final String ZCHARGEMODEL_DISCOUNT = 'Discount';
    public static final Map<Id,Product2> PRODUCTMAP = getProductMap();

    static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;

    // if we are sending on-demand, delay send after datetime to avoid concurrent scheduled process picking same record
    static final Datetime SENDAFTERONDEMAND = Datetime.now().addMinutes(10);
    static final Datetime SENDINQUEUE = Datetime.now().addMinutes(-10);
    static final String PROCESS_ZORDER = Integrations.PROCESS_ZORDER;
    static final String REQUEST_STATUS_NEW = Integrations.REQUEST_STATUS_NEW;
    static final String ACTIVATIONSTATUS_PENDING = ConstantsUtil.ACTIVATION_STATUS_PENDING;
    
    public static void createAndSendZOrderMessages(Set<Id> orderIds, Set<Id> amendmentOrderIds, Boolean sendImmediately) {
        if (!INTEGRATION_CONTROLS.Enable_Zuora_Integration__c || orderIds.isEmpty() || disableZuoraActions) {
            return;
        }

        // if not in async context, kick to future method
        if (!System.isBatch() && !System.isFuture() && !Test.isRunningTest()) {
            createAndSendZOrderMessagesFuture(orderIds, amendmentOrderIds, sendImmediately);
            return;
        }

        // gather related records and construct integration messages for supplied order ids
        List<Integration_Message__c> zOrderMessages = getZOrderMessages(orderIds, amendmentOrderIds, sendImmediately);
        insert zOrderMessages;

        //commenting this to prevent Zuora lock competition errors
        //this will allow Boomi to poll and pick up the messages from the
        //integration queue. Messages inserted above.
        /*if (sendImmediately) {
            Integrations.sendMessageIdsToBoomi(zOrderMessages);
        }*/
    }

    @future // round trip back to main method in a future context
    static void createAndSendZOrderMessagesFuture(Set<Id> orderIds, Set<Id> amendmentOrderIds, Boolean sendImmediately) {
        createAndSendZOrderMessages(orderIds, amendmentOrderIds, sendImmediately);
    }

    // gather related records and construct integration messages for supplied order ids
    static List<Integration_Message__c> getZOrderMessages(Set<Id> orderIds, Set<Id> amendmentOrderIds, Boolean sendImmediately) {

        List<Integration_Message__c> returnMessages = new List<Integration_Message__c>();

        // get all non-base bundle pending cpq subscriptions for supplied order ids
        Map<Id,List<SBQQ__Subscription__c>> pendingCPQSubMap = getPendingCPQSubscriptionMap(orderIds);
        Map<Id,List<SBQQ__Subscription__c>> baseBundlesByOrderIdMap = new Map<Id,List<SBQQ__Subscription__c>>();
        Set<Id> removedBaseSubIds = new Set<Id>();
        Map<Id, Integer> amendmentCPQSubMap = new Map<Id, Integer>();

        // BR-5591
        // get map of orders w/ term amendments
        Map<Id, Order> amendmentOrderMap = new Map<Id, Order>([
            SELECT Id, Type, EffectiveDate, Initial_Term_End_Date__c FROM Order WHERE Id IN: amendmentOrderIds
        ]);


        // loop through all modified / created / cancelled base bundles
        for (SBQQ__Subscription__c baseCPQSub : getBaseBundleSubscriptions(pendingCPQSubMap.keySet(), orderIds)) {
            Id baseCPQSubId = baseCPQSub.Id;
            Id orderId;
            Integer commitmentPeriod;

            // if cancellation, add revised base bundle sub id to removed set and capture related order id
            // this is necessary because the removed related subs remain tied to the old base bundle (requiredby)
            if (baseCPQSub.SBQQ__Quantity__c < 1) {
                removedBaseSubIds.add(baseCPQSub.SBQQ__RevisedSubscription__c);
                orderId = baseCPQSub.SBQQ__OrderProduct__r.OrderId;
            } else {    // if this is not a cancellation, get the order id from the first related pending sub
                orderId = pendingCPQSubMap.get(baseCPQSubId)[0].SBQQ__OrderProduct__r.OrderId;
            }


            // BR-5591
            if (amendmentOrderIds.contains(orderId)){
                Order o = amendmentOrderMap.get(orderId);



                if (o.Type == 'Amendment' && baseCPQSub.Zuora_Subscription__r.Zuora__TermStartDate__c != null){


                    // calculate commitment period using start date from zuora sub and order term end date
                    commitmentPeriod = calculateCommitmentPeriod(
                        baseCPQSub.Zuora_Subscription__r.Zuora__TermStartDate__c, 
                        baseCPQSub.SBQQ__Contract__r.EndDate
                    );



                } else if (o.Type != 'Amendment') {
                    // calculate commitment period using cpq sub start and end dates
                    commitmentPeriod = calculateCommitmentPeriod(
                        baseCPQSub.SBQQ__SubscriptionStartDate__c, 
                        baseCPQSub.SBQQ__EndDate__c
                    );
                }

                amendmentCPQSubMap.put(baseCPQSubId, commitmentPeriod);
            }


            // if this base bundle is in the removed set, remove the related subs from the pending map and move on
            if (removedBaseSubIds.contains(baseCPQSubId)) {
                pendingCPQSubMap.remove(baseCPQSubId);
                continue;
            }

            // add base bundle to map entry for the current order id
            // mostly there will only be one, but there may be two if the order has a remove / replace
            if (!baseBundlesByOrderIdMap.containsKey(orderId)) {
                baseBundlesByOrderIdMap.put(orderId, new List<SBQQ__Subscription__c>());
            }
            baseBundlesByOrderIdMap.get(orderId).add(baseCPQSub);
        }

        // create an integration message for each order
        for (Id orderId : baseBundlesByOrderIdMap.keySet()) {
            returnMessages.add(
                createIntegrationMessage(
                    orderId, 
                    baseBundlesByOrderIdMap.get(orderId), 
                    pendingCPQSubMap, 
                    amendmentCPQSubMap,
                    sendImmediately
                )
            );
        }

        return returnMessages;
    }

    // create an integration message for the supplied base bundles / related pending cpq subs
    public static Integration_Message__c createIntegrationMessage(
        Id orderId, 
        List<SBQQ__Subscription__c> baseCPQSubList, 
        Map<Id,List<SBQQ__Subscription__c>> pendingCPQSubMap, 
        Map<Id, Integer> amendmentCPQSubMap,
        Boolean sendImmediately
    ) {
        String jsonString = ZuoraIntegration_Order.serializeJSON(baseCPQSubList, pendingCPQSubMap, amendmentCPQSubMap);
        
        return new Integration_Message__c(
            Account__c = baseCPQSubList[0].Fulfillment_Account__c,
            CPQ_Order__c = orderId,
            Request_Body__c = jsonString,
            Request_Status__c = REQUEST_STATUS_NEW,
            Process__c = PROCESS_ZORDER,
            Send_After__c = (sendImmediately ? SENDAFTERONDEMAND : SENDINQUEUE)
        );
    }

    // get zuora ids for products into a product map
    static Map<Id,Product2> getProductMap() {
        return new Map<Id,Product2>(
            [SELECT Id, Zuora_Product_Rate_Plan_ID__c, Zuora_Product_Rate_Plan_Charge_ID__c, 
                Zuora_Product_Rate_Plan_Charge_Disc_ID__c, Zuora_Charge_Model__c 
                FROM Product2 WHERE Zuora_Product_Rate_Plan_ID__c != null]
        );
    }

    // all fields needed from the cpq subs (base bundle and pending changes) to process orders
    public static final List<String> CPQSUB_QUERY_FIELDS = new List<String>{
        'Id',
        'Name',
        'Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c',
        'Billing_Account__r.Field_Group_Type__c',
        'SBQQ__Contract__r.EndDate',
        'Fulfillment_Account__c',
        'Fulfillment_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c',
        'Intro_Discount_Period__c',
        'Intro_Discount_Percentage__c',
        'SBQQ__BillingType__c',
        'SBQQ__Contract__c',
        'SBQQ__EndDate__c',
        'SBQQ__ListPrice__c',
        'SBQQ__NetPrice__c',
        'SBQQ__OrderProduct__r.OrderId',
        'SBQQ__OrderProduct__r.Order.OrderNumber',
        'SBQQ__Product__c',
        'SBQQ__Quantity__c',
        'SBQQ__RequiredById__c',
        'SBQQ__StartDate__c',
        'SBQQ__RevisedSubscription__c',
        'SBQQ__RevisedSubscription__r.Zuora_Rate_Plan_Id__c',
        'SBQQ__RevisedSubscription__r.Zuora_Subscription_Number__c',
        'Zuora_Rate_Plan_Id__c',
        'Zuora_Subscription_Number__c',
        'Zuora_Subscription__r.Zuora__TermStartDate__c'
    };

    // get all pending non-base bundle cpq subs for the supplied order ids
    static Map<Id,List<SBQQ__Subscription__c>> getPendingCPQSubscriptionMap(Set<Id> orderIds) {
        Map<Id,List<SBQQ__Subscription__c>> returnMap = new Map<Id,List<SBQQ__Subscription__c>>();

        String query = 'SELECT '+String.join(CPQSUB_QUERY_FIELDS, ', ')+' FROM SBQQ__Subscription__c '+
            'WHERE SBQQ__OrderProduct__r.Order.Activation_Zuora_Subscription__c = :ACTIVATIONSTATUS_PENDING '+
            'AND SBQQ__RequiredById__c != null'+
            (orderIds != null ? ' AND SBQQ__OrderProduct__r.OrderId IN :orderIds' : '');
        
        for (SBQQ__Subscription__c cpqSub : (List<SBQQ__Subscription__c>)Database.query(query)) {
            Id baseCPQSubId = cpqSub.SBQQ__RequiredById__c;

            if (!returnMap.containsKey(baseCPQSubId)) {
                returnMap.put(baseCPQSubId, new List<SBQQ__Subscription__c>());
            }
            returnMap.get(baseCPQSubId).add(cpqSub);
        }

        return returnMap;
    }

    static Map<Id,List<SBQQ__Subscription__c>> getPendingCPQSubscriptionMap() {
        return getPendingCPQSubscriptionMap(null);
    }

    // get all base bundle cpq subs for a) the supplied order ids (for removals) or b) pending cpq subs
    static List<SBQQ__Subscription__c> getBaseBundleSubscriptions(Set<Id> baseCPQSubIds, Set<Id> orderIds) {
        String query = 'SELECT '+String.join(CPQSUB_QUERY_FIELDS, ', ')+
            ' FROM SBQQ__Subscription__c WHERE Id IN :baseCPQSubIds '+
            'OR (SBQQ__RequiredById__c = null AND SBQQ__OrderProduct__r.OrderId IN :orderIds) '+
            'ORDER BY SBQQ__Quantity__c';
        return (List<SBQQ__Subscription__c>)Database.query(query);
    }


    // calculates commitment period for commitment period updates
    public static Integer calculateCommitmentPeriod(Date startDate, Date endDate) {
       /* Integer  diff = */ return (startDate.daysBetween(endDate) + 1);
      /*  if (diff > 100) {
  			return startDate.monthsBetween(endDate);
        } else {
            return diff;
        } */
    }
    
}
