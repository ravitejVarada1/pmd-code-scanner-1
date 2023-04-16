public without sharing class IntegrationMessageTriggerFunctions {

    static final String STATUS_PENDING = ConstantsUtil.ACTIVATION_STATUS_PENDING;
    static final String STATUS_COMPLETE = ConstantsUtil.ACTIVATION_STATUS_COMPLETE;
    static final String STATUS_ERROR = ConstantsUtil.ACTIVATION_STATUS_ERROR;
    static final String RENEW_SUB_ACTIONTYPE = ZuoraIntegration_SupplementOrderHelper.RENEW_SUB_ACTIONTYPE;

    // keep track of processed message ids so we can skip re-querying completed ones after updating
    static Set<Id> processedResponseIntMsgIds = new Set<Id>();

    // process message responses for updated integration messages
    public static void processMessageResponses(Set<Id> intMsgIds) {
        if (processedResponseIntMsgIds.containsAll(intMsgIds)) {
            return;
        }

        // if not in an async context, kick to future method
        if (!System.isBatch() && !System.isFuture() && !Test.isRunningTest()) {
            processMessageResponsesFuture(intMsgIds);
            return;
        }

        processedResponseIntMsgIds.addAll(intMsgIds);
        Map<String,List<Integration_Message__c>> intMsgProcessMap = new Map<String,List<Integration_Message__c>>();

        // query to find matching integration messages with unprocessed responses
        // populate messages to be processed into a map based on the process type
        for (Integration_Message__c intMsg : [SELECT Id, Process__c, Request_Status__c, Response_Status__c, 
            Response_Body__c, Account__c, CPQ_Order__c, CPQ_Order_Product__c, CPQ_Quote__c, Service_Provider__c,
            Order_Type__c
            FROM Integration_Message__c 
            WHERE Id IN :intMsgIds AND Response_Status__c IN :Integrations.RESPONSE_STATUSES_TO_PROCESS]) 
        {
            String process = intMsg.Process__c;

            String orderType = intMsg.Order_Type__c;
            Boolean isRenewOrderType = (orderType != null && orderType == RENEW_SUB_ACTIONTYPE);
            if(isRenewOrderType) {
                process = orderType;
            }

            if (!intMsgProcessMap.containsKey(process)) {
                intMsgProcessMap.put(process, new List<Integration_Message__c>());
            }
            intMsgProcessMap.get(process).add(intMsg);
        }

        // process integration messages in map based on process type
        for (String intProcess : intMsgProcessMap.keySet()) 
        {
            List<Integration_Message__c> intMsgList = intMsgProcessMap.get(intProcess);

            if (intProcess == RENEW_SUB_ACTIONTYPE) {
                processZOrderRenewSubscriptionResponses(intMsgList);
            } 
            else if (intProcess == Integrations.PROCESS_FEATUREFRAMEWORK) {
                processFeatureMessageResponses(intMsgList);
            }
            else if (intProcess == Integrations.PROCESS_ZACCOUNT) {
                processZAccountMessageResponses(intMsgList);
            }
            else if (intProcess == Integrations.PROCESS_ZBILLING) {
                processZBillingMessageResponses(intMsgList);
            }
            else if (intProcess == Integrations.PROCESS_ZORDER) {
                processZOrderMessageResponses(intMsgList);
            }
            else if (intProcess == Integrations.PROCESS_ZREVPROACTIVATION) {
                processZRevProActivationMessageResponses(intMsgList);
            }
            else if (intProcess == Integrations.PROCESS_ZORDER_TERMS) {
                processZOrderTermsMessageResponses(intMsgList);
            }
            else if (intProcess == Integrations.PROCESS_PHACCOUNT) {
                processPistonHeadsAccountMessageResponses(intMsgList);
            }
        }
    }

    @future // round trip back to main method, now in a future context
    static void processMessageResponsesFuture(Set<Id> intMsgIds) {
        processMessageResponses(intMsgIds);
    }

    // process feature framework message responses
    static void processFeatureMessageResponses(List<Integration_Message__c> intMsgList) {
        for (Integration_Message__c intMsg : intMsgList) {
            intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_PROCESSED;
        }
        update intMsgList;
    }

    // process zuora account message responses
    static void processZAccountMessageResponses(List<Integration_Message__c> intMsgList) {
        for (Integration_Message__c intMsg : intMsgList) {
            intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_PROCESSED;
        }
        update intMsgList;
    }

    // process zuora billing message responses
    static void processZBillingMessageResponses(List<Integration_Message__c> intMsgList) {
        Map<Id,Account> accountWithOrderItemMap = new Map<Id,Account>();

        // get related billing account ids into a map
        for (Integration_Message__c intMsg : intMsgList) {
            accountWithOrderItemMap.put(intMsg.Account__c, null);
        }

        // query related accounts with related cpq subscriptions where order product / order pending zuora billing
        accountWithOrderItemMap = new Map<Id,Account>(
            [SELECT Id, (SELECT Id, SBQQ__OrderProduct__r.OrderId FROM CPQ_Subscription_Billing__r 
                WHERE SBQQ__OrderProduct__r.Order.Activation_Zuora_Invoice__c = :STATUS_PENDING)
            FROM Account WHERE Id IN :accountWithOrderItemMap.keySet()]
        );

        Map<Id,Order> orderMap = new Map<Id,Order>();
        
        // loop through integration message list
        for (Integration_Message__c intMsg : intMsgList) {
            Id accountId = intMsg.Account__c;
            
            // if integration message has no related account, we cannot process
            if (accountId == null) {
                intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_ERROR;
                intMsg.Response_Processing_Error__c = 
                    'Account is null on Integration Message - cannot find CPQ Orders to update';
                continue;
            }

            Boolean isSuccess = (intMsg.Request_Status__c == Integrations.REQUEST_STATUS_SUCCESS);

            if (!isSuccess) {
                //relatedRecords.addCase(new Case());   --- add case linked to Integration Message with request error
            }

            // we will find multiple cpq subs per order, so keep track of which orders we have processed
            Set<Id> processedOrderIds = new Set<Id>();

            // loop through billing account's related cpq subscriptions
            for (SBQQ__Subscription__c cpqSub : accountWithOrderItemMap.get(accountId).CPQ_Subscription_Billing__r) {
                Id orderId = cpqSub.SBQQ__OrderProduct__r.OrderId;

                // if already processed, skip
                if (processedOrderIds.contains(orderId)) {
                    continue;
                }
                processedOrderIds.add(orderId);

                // add order to update list, setting activation status for zuora billing according to message success
                orderMap.put(orderId, 
                    new Order(
                        Id = orderId,
                        Activation_Zuora_Invoice__c = isSuccess ? STATUS_COMPLETE : STATUS_ERROR
                    )
                );
            }
    
            // update message response status to processed
            intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_PROCESSED;
        }

        if (!orderMap.isEmpty()) {
            update orderMap.values();
        }
        update intMsgList;
    }

    // process zuora order message responses
    static void processZOrderMessageResponses(List<Integration_Message__c> intMsgList) {
        Map<Id,Order> orderMap = new Map<Id,Order>();
        Map<Id,String> orderIdZSubNumberMap = new Map<Id,String>();

        // loop through integration message list
        for (Integration_Message__c intMsg : intMsgList) {
            Id orderId = intMsg.CPQ_Order__c;

            // if integration message has no related order, we cannot process it
            if (orderId == null) {
                intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_ERROR;
                intMsg.Response_Processing_Error__c = 'CPQ Order is null on Integration Message - cannot update';
                continue;
            }

            // add / retrieve order from map
            if (!orderMap.containsKey(orderId)) {
                orderMap.put(orderId, new Order(Id=orderId));
            }
            Order o = orderMap.get(orderId);

            // interpret order response from zuora / boomi
            ZuoraIntegration_OrderResponse zOrderResponse = (ZuoraIntegration_OrderResponse)JSON.deserialize(
                intMsg.Response_Body__c, ZuoraIntegration_OrderResponse.class);
            
            // if success, update order with order number, status for zuora order to complete, 
            // status for zuora billing to pending
            if (intMsg.Request_Status__c == Integrations.REQUEST_STATUS_SUCCESS) {
                o.Zuora_Order_Number__c = zOrderResponse.orderNumber;
                o.Activation_Zuora_Subscription__c = STATUS_COMPLETE;
                o.Activation_Zuora_Invoice__c = STATUS_PENDING;
                zOrderResponse.subscriptionNumbers.sort();
                String subscriptionNumber = 
                    zOrderResponse.subscriptionNumbers.size() > 1 ? 
                        zOrderResponse.subscriptionNumbers[1] : 
                        zOrderResponse.subscriptionNumbers[0];
                
                orderIdZSubNumberMap.put(orderId, subscriptionNumber);
            } else {
                o.Activation_Zuora_Subscription__c = STATUS_ERROR;
                //relatedRecords.addCase(new Case());   --- add case linked to Integration Message with request error
            }
    
            intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_PROCESSED;
        }

        // for all successful zuora orders, update cpq subscriptions related to order with zuora sub number
        if (!orderIdZSubNumberMap.isEmpty()) {
            List<SBQQ__Subscription__c> cpqSubs = [SELECT Id, SBQQ__OrderProduct__r.OrderId FROM SBQQ__Subscription__c 
                WHERE SBQQ__OrderProduct__r.OrderId IN :orderIdZSubNumberMap.keySet()];
            
            for (SBQQ__Subscription__c cpqSub : cpqSubs) {
                cpqSub.Zuora_Subscription_Number__c = orderIdZSubNumberMap.get(cpqSub.SBQQ__OrderProduct__r.OrderId);
            }
            update cpqSubs;
        }

        if (!orderMap.isEmpty()) {
            update orderMap.values();
        }
        update intMsgList;
    }

    static void processZRevProActivationMessageResponses(List<Integration_Message__c> intMsgList) {

      Map<Id,OrderItem> orderItemMap = new Map<Id,OrderItem>();
      Set<Id> orderIds = new Set<Id>();

      for (Integration_Message__c intMsg : intMsgList) {
        Id orderItemId = intMsg.CPQ_Order_Product__c;

        if (orderItemId == null) {
            intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_ERROR;
            intMsg.Response_Processing_Error__c = 'CPQ Order Product is null on Integration Message - cannot update';
            continue;
        }

        if (!orderItemMap.containsKey(orderItemId)) {
          orderItemMap.put(orderItemId, new OrderItem(Id=orderItemId, OrderId=intMsg.CPQ_Order__c));
          orderIds.add(intMsg.CPQ_Order__c);
        }
        OrderItem o = orderItemMap.get(orderItemId);

        ZuoraIntegration_RevproResponse revproResponse = (ZuoraIntegration_RevproResponse)JSON.deserialize(
                intMsg.Response_Body__c, ZuoraIntegration_RevproResponse.class);
            
        if (intMsg.Request_Status__c == Integrations.REQUEST_STATUS_SUCCESS) {
          o.Activation_Zuora_RevPro__c = STATUS_COMPLETE;
        } else {
          o.Activation_Zuora_RevPro__c = STATUS_ERROR;
        }

        intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_PROCESSED;
      }

      if (!orderItemMap.isEmpty()) {
        update (orderItemMap.values());
      }

      // requery the updated order products plus any other manual provisioning ones related to the same orders
      List<OrderItem> orderItems = [
        SELECT Id, OrderId, Activation_Zuora_RevPro__c, Order.Activation_Status_Manual_Activation__c
        FROM OrderItem
        WHERE OrderId IN :orderIds
          AND Product2.Manually_Provisioned__c = TRUE
          AND Activation_Zuora_RevPro__c != 'N/A'
          AND Order.Activation_Status_Manual_Activation__c != :STATUS_COMPLETE
      ];

      // build a map with unique order product revpro statuses by Order
      Map<Id, Set<String>> orderProductStatusesMap = new Map<Id, Set<String>>();

      for(OrderItem oi : orderItems) {
        if(!orderProductStatusesMap.containsKey(oi.OrderId)) {
          orderProductStatusesMap.put(oi.OrderId, new Set<String>());
        }
        orderProductStatusesMap.get(oi.OrderId).add(oi.Activation_Zuora_RevPro__c);
      }

      // if an order has only 'Complete' order products (revpro statuses), then the order needs to be set to Complete
      List<Order> orders = new List<Order>();

      for (Id orderId : orderProductStatusesMap.keySet()) {
        Set<String> statuses = orderProductStatusesMap.get(orderId);
        if(statuses.size() == 1 && statuses.contains(STATUS_COMPLETE)) {
          orders.add(new Order(Id=orderId, Activation_Status_Manual_Activation__c=STATUS_COMPLETE));
        }
      }

      if (!orders.isEmpty()) {
        update orders;
      }

      update intMsgList;

    }

    //modify to include better error handling
    static void processZOrderTermsMessageResponses(List<Integration_Message__c> intMsgList) {
        // loop through integration message list
        for (Integration_Message__c intMsg : intMsgList) {

            // interpret order response from zuora / boomi
            ZuoraIntegration_OrderResponse zOrderResponse = (ZuoraIntegration_OrderResponse)JSON.deserialize(
                intMsg.Response_Body__c, ZuoraIntegration_OrderResponse.class);

            if(intMsg.Request_Status__c == Integrations.REQUEST_STATUS_SUCCESS) {
                if (zOrderResponse.success != null && zOrderResponse.success == true) {
                    intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_PROCESSED;
                } else {
                    intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_ERROR;
                }
            }
        }

        update intMsgList;
    }

    static void processPistonHeadsAccountMessageResponses(List<Integration_Message__c> intMsgList) {

        List<Account> accounts = new List<Account>();
        List<Order> orders = new List<Order>();
        List<Integration_Message__c> processedMessages = new List<Integration_Message__c>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> orderIds = new Set<Id>();
        Set<Id> messageIds = new Set<Id>();


        // loop through integration message list
        for (Integration_Message__c intMsg : intMsgList) {
            
            // if an account is provided, do account operations
            if(intMsg.Account__c != null && intMsg.CPQ_Order__c != null) {

                // parse the response to extract the dealerId value
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(intMsg.Response_Body__c);
                String dealerId = String.valueOf((Integer)response.get('dealerId'));

                // update PH Admin Centre Id on Account
                if (!accountIds.contains(intMsg.Account__c)) {
                    accountIds.add(intMsg.Account__c);
                    accounts.add(new Account(Id=intMsg.Account__c, PH_Admin_Centre_Id__c=dealerId));
                }
                

                // set order ph admin activation status to complete
                if (!orderIds.contains(intMsg.CPQ_Order__c)) {
                    orderIds.add(intMsg.CPQ_Order__c);
                    orders.add(new Order(Id=intMsg.CPQ_Order__c, Activation_PH_Admin_Centre__c='Complete'));
                }

            }

            if (!messageIds.contains(intMsg.Id)) {
                intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_PROCESSED;
                messageIds.add(intMsg.Id);
                processedMessages.add(intMsg);
            }

        }

        if(!accounts.isEmpty()) {
            try {
                update accounts;
            } catch (DMLException e) {
                System.debug('Error updating accounts. See error: ' + e.getMessage());
            }
        }


        if(!orders.isEmpty()) {
            try { 
                update orders;
            } catch (DMLException e) {
                System.debug('Error updating orders. See error: ' + e.getMessage());
            }
        }


        if(!processedMessages.isEmpty()) {
            try {
                update processedMessages;
            } catch (DMLException e) {
                System.debug('Error updating messages. See error: ' + e.getMessage());
            }
        }

    }

    static void processZOrderRenewSubscriptionResponses(List<Integration_Message__c> intMsgList) {
        Map<Id,Order> orderMap = new Map<Id,Order>();
        Map<Id, Contract> orderIdToContractMap = new Map<Id, Contract>();
        Map<Id, Contract> contractUpdateMap = new Map<Id, Contract>();
        Map<Id,String> orderIdZSubNumberMap = new Map<Id,String>();

        orderIdToContractMap = getOrderContracts(intMsgList);

        // loop through integration message list
        for (Integration_Message__c intMsg : intMsgList) {
            Id orderId = intMsg.CPQ_Order__c;

            // if integration message has no related order, we cannot process it
            if (orderId == null) {
                intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_ERROR;
                intMsg.Response_Processing_Error__c = 'CPQ Order is null on Integration Message - cannot update';
                continue;
            }

            // add / retrieve order from map
            if (!orderMap.containsKey(orderId)) {
                orderMap.put(orderId, new Order(Id=orderId));
            }
            Order o = orderMap.get(orderId);
            
            Contract crt = orderIdToContractMap.get(o.Id);

            // interpret order response from zuora / boomi
            ZuoraIntegration_OrderResponse zOrderResponse = (ZuoraIntegration_OrderResponse)JSON.deserialize(
                intMsg.Response_Body__c, ZuoraIntegration_OrderResponse.class);
            
            // if success set Activation_Status_Renew_prior__c to Complete
            if (intMsg.Request_Status__c == Integrations.REQUEST_STATUS_SUCCESS) {
                o.Activation_Status_Renew_Prior__c = STATUS_COMPLETE;
                o.Activation_Zuora_Subscription__c = STATUS_PENDING;

                //update contract end date since we pushed the zuora
                //subscription out by a month    
                if(crt != null && !contractUpdateMap.containsKey(crt.Id)) {
                    Date firstDayOfMonth = crt.EndDate.addMonths(1).toStartOfMonth();
                    Date lastDayOfMonth = firstDayOfMonth.addDays(Date.daysInMonth(firstDayOfMonth.year(), firstDayOfMonth.month()) - 1);
                    crt.EndDate = lastDayOfMonth;
                    contractUpdateMap.put(crt.Id, crt);
                }
            } else {
                o.Activation_Status_Renew_Prior__c = STATUS_ERROR;
                //relatedRecords.addCase(new Case());   --- add case linked to Integration Message with request error
            }
    
            intMsg.Response_Status__c = Integrations.RESPONSE_STATUS_PROCESSED;
        }

        if (!contractUpdateMap.isEmpty()) {
            update contractUpdateMap.values();
        }

        if (!orderMap.isEmpty()) {
            update orderMap.values();
        }

        update intMsgList;
    }

    public static Map<Id, Contract> getOrderContracts(List<Integration_Message__c> intMsgList) {
        Map<Id, Contract> orderIdToContract = new Map<Id, COntract>();
        for(Integration_Message__c intMsg :intMsgList) {
            orderIdToContract.put(intMsg.CPQ_Order__c, null);
        }

        for(Order o : [SELECT Id, ContractCustom__c, ContractCustom__r.EndDate FROM Order WHERE Id IN :orderIdToContract.keySet()]) {
            Contract crt = new Contract(Id = o.ContractCustom__c, EndDate = o.ContractCustom__r.EndDate);
            orderIdToContract.put(o.Id, crt);
        }
        
        return orderIdToContract;
    }

}