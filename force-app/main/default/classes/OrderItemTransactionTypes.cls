/**
 * Determines OrderItem Transaction Types
 * https://cargurus.atlassian.net/browse/BR-4610
 */

public without sharing class OrderItemTransactionTypes {

    //Contants - Transaction Types
    public static final String RATE_REDUCTION = 'Rate Reduction';
    public static final String EXISTING_BUSINESS = 'Existing Business';
    public static final String NEW_BUSINESS = 'New Business';
    public static final String ANNUAL_UPSELL = 'Annual Upsell';

    //Define actions, when Order Item quantity < 0 we use CANCEL_ACTION
    //when Order Item quantity > 0, we'll use ADD_ACTION
    public static final String ADD_ACTION = 'Add';
    public static final String CANCEL_ACTION = 'Cancel';

    //If core product, then we want to not append a sub category
    //constant defined here
    public static final String CORE_PRODUCT_CATEGORY = 'Core Products';

    //multiple updates will launch this multiple times
    //attempt to contain execution times to 1 time
    public static Set<Id> ordersProcessedByTrigger = new Set<Id>();

    /**
     * Called from the OrderTrigger Handler, accepts a new orders map
     */
    public static void recordTransactionType(Map<Id, Order> newOrdersMap) {
        if(ordersProcessedByTrigger.containsAll(newOrdersMap.keySet())) {
            return;
        }
        
        Set<Id> oItemCPQSubIds = new Set<Id>();
        Set<Id> fullAccIds = new Set<Id>();

        Map<Id, Map<String, List<OrderItem>>> orderItemsMap = 
            getOrderItems(newOrdersMap.keySet(), oItemCPQSubIds, fullAccIds);
        
        if(orderItemsMap.isEmpty()) {
            return;
        }

        Map<Id, Set<String>> fulAccExistProductCategories = getExistingProductCategories(fullAccIds, oItemCPQSubIds);   

        List<OrderItem> orderItemsToUpdate = calcTransactionType(newOrdersMap, orderItemsMap, fulAccExistProductCategories);

        //BR-7299/BR-4610 - convert to future method, keeps transaction lighter
        //during ordering large quotes
        if(!orderItemsToUpdate.isEmpty()) {
            if(!System.isBatch() && !System.isFuture() && !Test.isRunningTest()) {
                Map<Id, String> oItemIdToTransactionTypeMap = new Map<Id, String>();
                for(OrderItem oItem : orderItemsToUpdate) {
                    oItemIdToTransactionTypeMap.put(oItem.Id, oItem.Transaction_Type__c);
                }
                updateOrderItemTransactionTypes(oItemIdToTransactionTypeMap);
            }  else {
                update orderItemsToUpdate;
            } 
            ordersProcessedByTrigger.addAll(newOrdersMap.keySet());
        }
    }

    @future
    public static void updateOrderItemTransactionTypes( Map<Id, String> oItemIdToTransactionTypeMap ){
        List<OrderItem> oItemsToUpdate = new List<OrderItem>();
        for(Id oItemId : oItemIdToTransactionTypeMap.keySet()) {
            String transactionType = oItemIdToTransactionTypeMap.get(oItemId);
            oItemsToUpdate.add(
                new OrderItem(
                    Id = oItemId,
                    Transaction_Type__c = transactionType
                )
            );
        }
        update oItemsToUpdate;
    }

    /**
     * Find all the existing product categories from the CPQ Subscriptions, excludes those products
     * that have been added new in the Order. This covers situations of has this business 'ever owned'
     * a certain product in the past.
     */
    public static Map<Id, Set<String>> getExistingProductCategories(Set<Id> fulAccIds, Set<Id> oItemCPQSubIds) {
        Map<Id, Set<String>> retMap = new Map<Id, Set<String>>();

        List<SBQQ__Subscription__c> cpqSubs = [SELECT Id, Fulfillment_Account__c,  
            Product_Code__c, SBQQ__Product__r.Product_Category__c, SBQQ__Product__r.Sub_Category__c 
            FROM SBQQ__Subscription__c
            WHERE Fulfillment_Account__c IN :fulAccIds 
            AND Id NOT IN: oItemCPQSubIds];

        for(SBQQ__Subscription__c cpqSub : cpqSubs) {
            Id fulAccId = cpqSub.Fulfillment_Account__c;
            String productCategory = cpqSub.SBQQ__Product__r.Product_Category__c;
            String productSubCategory = cpqSub.SBQQ__Product__r.Sub_Category__c;

            System.debug(cpqSub.Product_Code__c);
            System.debug(productCategory);

            Boolean isCoreProduct = productCategory == CORE_PRODUCT_CATEGORY;

            String uniqueCategory = !isCoreProduct ? productCategory+'_'+productSubCategory : productCategory;
            System.debug(uniqueCategory);
            if(!retMap.containsKey(fulAccId)) {
                retMap.put(fulAccId, new Set<String>{uniqueCategory});
            } else {
                retMap.get(fulAccId).add(uniqueCategory);
            }
        }

        return retMap;
    }

    /**
     * Get all order items that require the transaction type
     */
    public static Map<Id, Map<String, List<OrderItem>>> getOrderItems(Set<Id> orderIds, 
        Set<Id> oItemCPQSubIds, Set<Id> fullAccIds) 
    {

        //Order Id mapped to a map of actions (cancel/add) to a list of order items
        Map<Id, Map<String, List<OrderItem>>> orderToOrderItemMap = new Map<Id, Map<String, List<OrderItem>>>();

        List<OrderItem> orderItems = [SELECT Id, Quantity, OrderId, Fulfillment_Account__c,
            Product2Id, Product2.ProductCode, Product2.Product_Category__c, Product2.Sub_Category__c, SBQQ__Subscription__c,
            SBQQ__ContractAction__c, SBQQ__Status__c, TotalPrice 
            FROM OrderItem WHERE OrderId IN :orderIds 
            AND Transaction_Type__c = null
            ORDER BY Quantity ASC];

        for(OrderItem oi : orderItems) {
            Id orderId = oi.OrderId;
            String action = oi.Quantity > 0 ? ADD_ACTION : CANCEL_ACTION;

            if(!orderToOrderItemMap.containsKey(orderId)) {
                Map<String, List<OrderItem>> actionOItemMap = new Map<String, List<OrderItem>>();
                actionOItemMap.put(action, new List<OrderItem>{oi});
                orderToOrderItemMap.put(orderId, actionOItemMap);

            } else {
                Map<String, List<OrderItem>> actionOItemMap = orderToOrderItemMap.get(orderId);
                if(!actionOItemMap.containsKey(action)){
                    actionOItemMap.put(action, new List<OrderItem>{oi});
                } else {
                    orderToOrderItemMap.get(orderId).get(action).add(oi);
                }

            }
            
            //collect fulfillment account ids
            fullAccIds.add(oi.Fulfillment_Account__c);
            
            //collect cpq sub ids of the added products so they can be excluded from
            //the existing product finder
            if(action == ADD_ACTION) {
                oItemCPQSubIds.add(oi.SBQQ__Subscription__c);
            }
        }
        return orderToOrderItemMap;
    }

    /**
     * Determines Order Type and makes certain obvious decisions. If there are only cancellations in the Order then that
     * is a rate reduction. If there are only additions in the order then that is new business.
     * 
     * If non-obvious routes those Order Items to a different method.
     * 
     * Accepts the orders map, order items categorized by action and existing (past) product categories
     */
    public static List<OrderItem> calcTransactionType(Map<Id, Order> newOrdersMap, 
        Map<Id, Map<String, List<OrderItem>>> orderItemsMap, Map<Id, Set<String>> existProductCategories) {

        List<OrderItem> orderItemsToUpdate = new List<OrderItem>();
        for(Id orderId : newOrdersMap.keySet()) {
            
            Order ord = newOrdersMap.get(orderId);
            Map<String, List<OrderItem>> oItemActionMap = orderItemsMap.get(orderId);

            if(oItemActionMap == null || oItemActionMap.isEmpty()) {
                continue;
            }
            
            if(ord.Type == 'Amendment') {
                //check rate reductions first, there will be cancels but no additions
                if(oItemActionMap.containsKey(CANCEL_ACTION) && !oItemActionMap.containsKey(ADD_ACTION)) {
                    orderItemsToUpdate.addAll(setTransactionType(oItemActionMap.get(CANCEL_ACTION), RATE_REDUCTION));

                } else if(!oItemActionMap.containsKey(CANCEL_ACTION) && oItemActionMap.containsKey(ADD_ACTION)) {
                    orderItemsToUpdate.addAll(setTransactionType(oItemActionMap.get(ADD_ACTION), NEW_BUSINESS));

                } else {
                    //look for upsells (existing business)
                    orderItemsToUpdate.addAll(findAmendmentTransactionType(oItemActionMap, existProductCategories));
                }
            } else if(ord.Type == 'Renewal') {
                //look for upsells (existing business)
                orderItemsToUpdate.addAll(findAmendmentTransactionType(oItemActionMap, existProductCategories));
                continue;
            } else if(ord.Type == 'New') {
                List<OrderItem> oItems = oItemActionMap.get(ADD_ACTION);
                orderItemsToUpdate.addAll(setTransactionType(oItems, NEW_BUSINESS));
            }
        }

        return orderItemsToUpdate;
    }

    /**
     * When the transaction type is not determined by calcTransactionType those Order Items are examined 
     * here. Uses sum totals of removed vs additions to determine upsells.
     * 
     * Looks for Renew contract action to signify an upsell and looks at whether the product was ever
     * subscribed to in the past (existing business) 
     * 
     * Determines using the sum, if this is indeed a rate reduction vs existing business
     */
    public static List<OrderItem> findAmendmentTransactionType(Map<String, List<OrderItem>> oItemActionMap, 
        Map<Id, Set<String>> existProductCategories) 
    {
        List<OrderItem> toUpdateOrderItems = new List<OrderItem>();

        Decimal removedSum = 0;
        Decimal addedSum = 0;

        getActionTotalPrice(oItemActionMap, removedSum, addedSum);

        Map<Id, OrderItem> existingBusiness = new Map<Id, OrderItem>();
        Map<Id, OrderItem> rateReduction = new Map<Id, OrderItem>();
        Map<Id, OrderItem> newBusiness = new Map<Id, OrderItem>();
        Map<id, OrderItem> annualUpsell = new Map<Id, OrderItem>();

        for(String action : oItemActionMap.keySet()) {
            List<OrderItem> tmpOiLst = oItemActionMap.get(action);
            for(OrderItem oi : tmpOiLst) {
                String productCategory = oi.Product2.Product_Category__c;
                String productSubCategory = oi.Product2.Sub_Category__c;
                Boolean isCoreProduct = productCategory == CORE_PRODUCT_CATEGORY;
                String uniqueCategory = !isCoreProduct ? productCategory+'_'+productSubCategory : productCategory;

                Set<String> existingCategories = existProductCategories.get(oi.Fulfillment_Account__c);
                System.debug(existingCategories);

                System.debug('Contract Action::'+oi.SBQQ__ContractAction__c);

                if(oi.SBQQ__ContractAction__c == 'Renew') {
                    annualUpsell.put(oi.Id, oi);

                } else if(existingCategories != null && !existingCategories.contains(uniqueCategory) ) {
                    newBusiness.put(oi.Id, oi);
                
                } else if(removedSum > addedSum) {
                    rateReduction.put(oi.Id, oi);    

                } else {
                    existingBusiness.put(oi.Id, oi);
                }
            }
        }

        if(!existingBusiness.isEmpty()) {

            toUpdateOrderItems.addAll(setTransactionType(existingBusiness.values(), EXISTING_BUSINESS));
        }

        if(!rateReduction.isEmpty()) {

            toUpdateOrderItems.addAll(setTransactionType(rateReduction.values(), RATE_REDUCTION));
        }

        if(!newBusiness.isEmpty()) {

            toUpdateOrderItems.addAll(setTransactionType(newBusiness.values(), NEW_BUSINESS));
        }

        if(!annualUpsell.isEmpty()) {

            toUpdateOrderItems.addAll(setTransactionType(annualUpsell.values(), ANNUAL_UPSELL));
        }

        return toUpdateOrderItems;
    }

    /**
     * From the Order Items, determines the sum totals of the removed items and added items
     */
    public static void getActionTotalPrice(Map<String, List<OrderItem>> oItemActionMap, Decimal removed, Decimal added) {
        for(String action : oItemActionMap.keySet()) {
            List<OrderItem> tmpOiLst = oItemActionMap.get(action);
            
            for(OrderItem oi : tmpOiLst) {
                if(action == CANCEL_ACTION) {
                    removed += (oi.TotalPrice)*(-1);
                } else if(action == ADD_ACTION) {
                    added += oi.TotalPrice;
                }
            }
        }
    }

    /**
     * Utility to pass in a list of order items and the transaction type to apply
     */
    public static List<OrderItem> setTransactionType(List<OrderItem> orderItems, String transactionType) {
        
        List<OrderItem> oiUpdates = new List<OrderItem>();
        if(orderItems == null) {
            return oiUpdates;
        }

        for(OrderItem oi : orderItems) {
            oiUpdates.add(
                new OrderItem(Id = oi.Id, Transaction_Type__c = transactionType)
            );
        }
        return oiUpdates;
    }

}