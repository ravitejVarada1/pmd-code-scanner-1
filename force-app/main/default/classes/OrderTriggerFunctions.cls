/**
 * @description       : 
 * @author            : LZhao
 * @group             : 
 * @last modified on  : 11-08-2021
 * @last modified by  : LZhao
**/
public without sharing class OrderTriggerFunctions {

    static final String ACTIVATIONSTATUS_PENDING = ConstantsUtil.ACTIVATION_STATUS_PENDING;
    static final Set<String> PH_PRODUCT_CODES = ConstantsUtil.PH_PRODUCT_CODES;
    static final String ACTIVATIONSTATUS_COMPLETE = ConstantsUtil.ACTIVATION_STATUS_COMPLETE;
    static final String ACTIVATIONSTATUS_NA = ConstantsUtil.ACTIVATION_STATUS_NA;

    // BR-7312 - Once zuora sub activation completes, if a term update is needed send to Zuora
    public static void sendZuoraAmendTermsMessage(Map<Id, Order> orderMap, Map<Id,Order> oldOrderMap) {

        Map<Id,Id> ordersToSend = new Map<Id,Id>();

        for (Id orderId : orderMap.keySet()) {
            
            Order currOrder = orderMap.get(orderId);
            Order oldOrder = oldOrderMap.get(orderId);
            
            if (
                currOrder.Status == 'Activated' &&
                currOrder.Type == 'Amendment' &&
                currOrder.Initial_Term_End_Date__c != null &&
                currOrder.Activation_Zuora_Subscription__c == 'Complete' && 
                currOrder.Activation_Zuora_Subscription__c != oldOrder.Activation_Zuora_Subscription__c
            ) {
                ordersToSend.put(currOrder.ContractId, currOrder.Id);
            }
        }

        if (ordersToSend.size() > 0) ZuoraIntegration_SupplementOrderHelper.sendAmendTermsMessages(ordersToSend, false);
    }

    // for any integration statuses newly pending, send related orders for processing
    // currently this applies only to zuora order and zuora billing
    public static void checkActivationStatusesPending(List<Order> orderList, Map<Id,Order> oldOrderMap) {
        
        Map<String,Set<Id>> activationTypeOrderIdsMap = new Map<String,Set<Id>>{
            'Activation_Status_Renew_Prior__c' => new Set<Id>(),
            'Activation_Zuora_Subscription__c' => new Set<Id>(),
            'Activation_Zuora_Invoice__c' => new Set<Id>(),
            'Activation_PH_Admin_Centre__c' => new Set<Id>()
        };

        // BR-5591
        Set<Id> ordersToAmend = new Set<Id>();

        for (Order o : orderList) {
            Id orderId = o.Id;

            // BR-5591
            if (
                o.Status == 'Activated' &&
                o.Type == 'Amendment' &&
                o.Initial_Term_End_Date__c != null
            ) {
                ordersToAmend.add(orderId);
            }

            for (String statusField : activationTypeOrderIdsMap.keySet()) { 

                if (o.get(statusField) == ACTIVATIONSTATUS_PENDING 
                    && oldOrderMap?.get(orderId).get(statusField) != ACTIVATIONSTATUS_PENDING) 
                {
                    activationTypeOrderIdsMap.get(statusField).add(orderId);
                }
            }
        }
        ZuoraIntegration_SupplementOrderHelper.sendRenewalPriorToCancellation(
            activationTypeOrderIdsMap.get('Activation_Status_Renew_Prior__c'), false);

        ZuoraIntegration_OrderHelper.createAndSendZOrderMessages(
            activationTypeOrderIdsMap.get('Activation_Zuora_Subscription__c'), ordersToAmend, false);
        
        ZuoraIntegration_InvoiceHelper.createAndSendZBillingMessages(
            activationTypeOrderIdsMap.get('Activation_Zuora_Invoice__c'), false);

        PHIntegration_AccountHelper.createAndSendPHAccountMessages(
            activationTypeOrderIdsMap.get('Activation_PH_Admin_Centre__c'), false);
       
    }        

    //Updated on Jira BR-2732. This method contracts recently Activated orders by 
    //sending the related quoteId into a batch class with a batch size of 1 for amendment quotes and 
    //200 for new quotes. This is due to CPQ requiring that orders on quotes with an existing
    //master contract get contracted in a single transaction, but orders on quotes without an 
    //existing master contract get contracted in one transaction per order.
    private static Set<ID> quotesContractedInTransaction = new Set<ID>();
    public static void checkContracted(Map<Id,Order> orderMap, Map<Id,Order> oldOrderMap) {
        Map<ID,SBQQ__Quote__c> quotesToContract = new Map<ID,SBQQ__Quote__c>();
        for (Id orderId : orderMap.keySet()) {
            Order currOrder = orderMap.get(orderId);
            Order oldOrder = oldOrderMap.get(orderId);
            
            if (currOrder.Status == 'Activated' 
                && currOrder.Status != oldOrder.Status
                && !quotesContractedInTransaction.contains(currOrder.SBQQ__Quote__c)) 
            {
                quotesToContract.put(currOrder.SBQQ__Quote__c, null);
            }
        }
        
        quotesToContract = new Map<ID,SBQQ__Quote__c>([SELECT Id, SBQQ__MasterContract__c
                                                       FROM SBQQ__Quote__c
                                                       WHERE Id IN : quotesToContract.keySet()]);
        
        for (ID quoteId : quotesToContract.keySet()){
            System.enqueueJob(new QueueableContractOrders(quoteId));
        }
        
        quotesContractedInTransaction.addAll(quotesToContract.keySet());
    }

    public static void updateQuoteToOrderGenerated(Set<Id> newOrderIds){
        
        List<SBQQ__Quote__c> ogQuotes = [SELECT Id
                                         FROM SBQQ__Quote__c
                                         WHERE SBQQ__Status__c != :ConstantsUtil.QUOTE_STATUS_ORDER_GENERATED
                                         AND Id IN (SELECT SBQQ__Quote__c
                                                    FROM Order
                                                    WHERE Id IN : neworderIds)];
        
        for (SBQQ__Quote__c q : ogQuotes){
            q.SBQQ__Status__c = ConstantsUtil.QUOTE_STATUS_ORDER_GENERATED;
        }
        
        update ogQuotes; 
    }

    // Updates data on the related contract record of an activated order.
    public static void updateContractData(Map<Id,Order> orderMap) {
        Map<Id,Order> contractOrderMap = new Map<Id,Order>();
        Set<Id> updateContractEndDates = new Set<Id>();
        Set<Id> updateContractApplyGroupPricing = new Set<Id>();
        Set<Id> updateContractInvCapGroup = new Set<Id>();
        Set<Id> contractsToQuery = new Set<Id>();

        // Loop through orders to separate out different types of orders that require a contract update
        for(Order o : orderMap.values()) {            
            if(o.Status == 'Activated') {
                // Maintain a map of Contract to Order map. We only need one order since all orders will originate from one quote
                // The following scenarios below will all originate from one quote
                // This will need to be refactored if we ever have orders with different attributes
                if(!contractOrderMap.containsKey(o.ContractCustom__c)) {
                    contractOrderMap.put(o.ContractCustom__c, o);
                } else {
                    continue;
                }

                if(o.Type == 'Amendment' && o.Initial_Term_End_Date__c != null) {
                    updateContractEndDates.add(o.ContractCustom__c);
                }
                if(o.Apply_Group_Pricing__c) {
                    updateContractApplyGroupPricing.add(o.ContractCustom__c);
                }
                if(o.Used_Inventory_Cap_Group__c > 0) {
                    updateContractInvCapGroup.add(o.ContractCustom__c);
                }
            }
        }

        contractsToQuery.addAll(updateContractEndDates);
        contractsToQuery.addAll(updateContractApplyGroupPricing);
        contractsToQuery.addAll(updateContractInvCapGroup);

        Map<Id, Contract> contractsToUpdate = new Map<Id, Contract>(
            [SELECT Id, EndDate, Initial_Term_End_Date__c, SBQQ__Order__c, Apply_Group_Pricing__c, ContractTerm,
                Used_Inventory_Cap_Group__c FROM Contract WHERE Id IN :contractsToQuery]);

        for(Contract c : contractsToUpdate.values()) {

            if(updateContractEndDates.contains(c.Id)) {
                updateContractEndDate(c, contractOrderMap.get(c.Id));
            }

            if(updateContractApplyGroupPricing.contains(c.Id)) {
                c.Apply_Group_Pricing__c = contractOrderMap.get(c.Id).Apply_Group_Pricing__c;
            }

            if(updateContractInvCapGroup.contains(c.Id)) {
                c.Used_Inventory_Cap_Group__c = contractOrderMap.get(c.Id).Used_Inventory_Cap_Group__c;
            }               
        }
        update contractsToUpdate.values();
    }

    // Update the contract end dates and contract term
    public static void updateContractEndDate(Contract contract, Order order) {

        Date orderInitialTermEndDate = order.Initial_Term_End_Date__c;
        Integer commitmentTermMonths = Integer.valueOf(order.Contract_Commitment_Term_Months__c);
		
        Boolean endDateValidate = orderInitialTermEndDate > contract.Initial_Term_End_Date__c;
        Boolean contractDateValidate = orderInitialTermEndDate > contract.EndDate;
        Boolean commitmentTermMonthsValidate = contract.ContractTerm != commitmentTermMonths;

        if(endDateValidate && contractDateValidate) {
            contract.EndDate = orderInitialTermEndDate;
            contract.Initial_Term_End_Date__c = orderInitialTermEndDate;
        }

        if(commitmentTermMonthsValidate) {
            contract.ContractTerm = commitmentTermMonths;
        }
    }

    // BR-3845
    // method that clears out the opportunity lookup on Cancellation orders
    // this is to allow creation of new quotes under already ordered opportunities (key to Retention process)
    public static void updateRetentionData(List<Order> orders) {

      // extract opportunity IDs - only if it's an amendment (cancellation) order
      List<Id> oppIds = new List<Id>();
      for(Order o : orders) {
        if(o.Type == 'Amendment') {
          oppIds.add(o.OpportunityId);
        }
      }

      // query retention opportunities only where cancellation date is today
      Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>([
        SELECT Id, RecordType.Name, Cancellation_Case__c
        FROM Opportunity
        WHERE Id IN :oppIds
          AND RecordType.Name = 'Retention'
          AND Cancellation_Case__c != NULL
          //AND Cancellation_Case__r.Cancellation_Effective_Date__c <= TODAY
      ]);

      // loop through the newly inserted orders to:
      // (1) wipe out the opp ID from the order, and (2) update the cancellation case with the order
      Map<Id,Case> cancellationCases = new Map<Id,Case>();
      List<Order> ordersToUpdate = new List<Order>();
      for(Order o : orders) {
        if(oppsMap.containsKey(o.OpportunityId)) {
          ordersToUpdate.add(
            new Order(
              Id = o.Id,
              OpportunityId = null
            )
          );
          if(!cancellationCases.containsKey(oppsMap.get(o.OpportunityId).Cancellation_Case__c)) {
            cancellationCases.put(
              oppsMap.get(o.OpportunityId).Cancellation_Case__c,
              new Case(
                Id = oppsMap.get(o.OpportunityId).Cancellation_Case__c, 
                Order__c = o.Id
              )
            );
          }
        }
      }
      
      if(!cancellationCases.isEmpty()) {
        update ordersToUpdate;
        update cancellationCases.values();
      }
    }
}