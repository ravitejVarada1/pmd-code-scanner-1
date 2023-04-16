/**
 * @description       : 
 * @author            : alaplante
 * @group             : 
 * @last modified on  : 08/01/2022
 * @last modified by  : alaplante
**/
public class ProductProvisioningCaseProcessor {

    /**
     * Initialize Global Variables
     */

    // get product provisioning metadata, organize into activation and deactivation POBS
    private static List<String> activationPobs = Utilities.getManualActivationPobs();
    private static List<String> deactivationPobs = Utilities.getManualDeactivationPobs();

    // get a list of product which are manually provisioned
    private static Map<Id, Product2> manuallyProvisionedProductMap = getManuallyProvisionedProductMap();
        
    // get map of case queues from utilities
    private static Map<String, Id> caseQueueMap = Utilities.getCaseQueueMap();

    /**
    * Main logical function, creates and returns list of provisioning case records in the following steps:
    *
    * 1.) Using getter function, gets map of orders in scope who have a manually provisioned product included
    * 2.) Gets set of order product ids that are manually provisioned
    * 3.) Queries for product and order data related to manually provisioned order products
    * 4.) Loops through order product list, check if they are actually manually provisioned
    * 5.) If product is manually provisioned, create the manual activation or deactivation case based on context
    * 6.) Add created case to list
    * 7.) After processing all orders, return case list to calling function
    *
    */

    public static List<Case> createProvisioningCases(List<OrderItem> newOrderProductList) {

        // map of order with number of ManuallyProvisionRecord 
        Map<String,Integer> manuallyProvisionedRecordMap = getManuallyProvisionedRecordMap(newOrderProductList);

        // set to store order product  with manually provisioned product
        Set<Id> manuallyProvisionedorderProductIDSet = getManuallyProvisionedOrderProductIDSet(newOrderProductList);

        // intialize list of cases to be created
        List<Case> caseListToBeCreated = new List<Case>();

        // checking if manuallyProvisionedorderProductIDSet is empty or not, if empty then skip the create case logic
        if (!manuallyProvisionedorderProductIDSet.isEmpty()) {

            // querying order product to get relevant record data from order,product and account
            Map<Id, OrderItem> manuallyProvisionedOrderProdMap = 
                getManuallyProvisionedOrderProdMap(manuallyProvisionedorderProductIDSet);

            // loop through order items creating cases if eligible
            for (OrderItem ordProd : manuallyProvisionedOrderProdMap.values()) {

                // check if order is in manually provisioned map
                if(checkIfOrderIsManuallyProvisioned(ordProd, manuallyProvisionedRecordMap)) {

                    // Create case if order product is inserted.
                    if (checkForActivationEligibility(ordProd)) {
                        caseListToBeCreated.add(createCaseRecord(ordProd, true));

                    // Create case if Ordered Quantity is updated with negative quantity.
                    } else if (checkForDeactivationEligibility(ordProd)) {
                        caseListToBeCreated.add(createCaseRecord(ordProd, false));
                    }

                }
            }
        }
        return caseListToBeCreated;
    }

    /**
    * Creates and returns instance of a new Case record.
    */

    private static Case createCaseRecord(OrderItem ordProd, Boolean activation) {

        // Initialize all case string values
        String description = getCaseDescription(ordProd);
        String displayAdTag = ordProd.order.SBQQ__Quote__r.SBQQ__Opportunity2__r.Display_Ad_Tag_line__c;
        String excludeInventory = ordProd.order.SBQQ__Quote__r.SBQQ__Opportunity2__r.Excluded_Inventory__c;
        String excludeState = ordProd.order.SBQQ__Quote__r.SBQQ__Opportunity2__r.Excluded_State__c;
        String priceEst = ordProd.order.SBQQ__Quote__r.SBQQ__Opportunity2__r.Pricing_Estimate_Details__c;
        String reason = getCaseReason(activation);
        String shipEst = ordProd.order.SBQQ__Quote__r.SBQQ__Opportunity2__r.Shipping_Price_Estimate__c;
        String subject = getCaseSubject(ordProd, activation);

        // Intialize all case Id values
        Id accountId = ordProd.Fulfillment_Account__c;
        Id oppId = ordProd.order.SBQQ__Quote__r.SBQQ__Opportunity2__c;
        Id ordProdId = ordProd.Id;
        Id orderId = ordProd.orderId;
        Id recTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Product Provision').getRecordTypeId();
        Id queueId = getCaseQueueId(ordProd, activation);

        // return case with set values
        return new Case(
            Status = 'New',
            Origin = 'Internal',
            Reason = reason,
            Subject = subject,
            Excluded_State__c = excludeState,
            Excluded_Inventory__c = excludeInventory,
            Display_Ad_Tag_line__c = displayAdTag,
            Shipping_Price_Estimate__c = shipEst,
            Pricing_Estimate_Details__c = priceEst,
            Order_Product__c = ordProdId,
            Order__c = orderId,
            Related_Opportunity__c = oppId,
            recordTypeID = recTypeId,
            AccountId = accountId,
            Description =  description
        );
    }

    /**
    * Checks an order product if it is eligible to create a product provisioning activation case 
    */

    private static boolean checkForActivationEligibility (OrderItem ordProd) {
        
        /**
        * If Conditions:
        *
        * If order item > 0 AND type = Quote
        *
        * If order item quantity > 0 AND type = amendment AND upgraded sub != null OR existing == false
        * 
        * If order item quantity > 0 AND type = renewal AND existing == false
        */

        if (
            ( ordProd.Quantity > 0 ) &&
            (
                ordProd.SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' ||
                ( ordProd.SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' && 
                    ( 
                        ordProd.SBQQ__QuoteLine__r.SBQQ__UpgradedSubscription__c != null ||
                        ordProd.SBQQ__QuoteLine__r.SBQQ__Existing__c != true 
                    )
                ) ||
                ( 
                    ordProd.SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Type__c == 'Renewal' &&
                    ordProd.SBQQ__QuoteLine__r.SBQQ__Existing__c != true 
                )
            )
        ) {
            return true;
        } else {
            return false;
        }
    }

    /**
    * Checks an order product if it is eligible to create a product provisioning deactivation case 
    */

    private static boolean checkForDeactivationEligibility (OrderItem ordProd) {

        /**
        * If Conditions:
        *
        * If order item < 0 AND type = amendment AND upgraded sub == null
        *
        * If order item < 0 AND type = amendment AND existing == true
        */

        if (
            ( ordProd.Quantity < 0) &&
            ( ordProd.SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment') &&
            (
                ordProd.SBQQ__QuoteLine__r.SBQQ__UpgradedSubscription__c == null ||
                ordProd.SBQQ__QuoteLine__r.SBQQ__Existing__c == true
            )
        ) {
            return true;
        } else {
            return false;
        }
    }

    /**
    * Checks an order product belongs to a manually provisioned order
    */

    private static Boolean checkIfOrderIsManuallyProvisioned( 
            OrderItem ordProd, 
            Map<String, Integer> manuallyProvisionedRecordMap
        ) {
            if(
                manuallyProvisionedRecordMap.containsKey(ordProd.orderId + '' + ordProd.Product2Id) && 
                manuallyProvisionedRecordMap.get(ordProd.orderId + '' + ordProd.Product2Id) <= 2 //SA-904
            ) {
                return true;
            } else {
                return false;
            }
    }

    /*
    * Gets and returns case queue
    */

    private static Id getCaseQueueId(OrderItem ordProd, Boolean activation) {

        // if a product id is present, 
        // and its an activation with activation queue id 
        // or deactivation with deactivtion queue id
        if (
            ordProd.Product2Id != null && 
            (
                activation == true && ordProd.Product2.Activation_Case_Queue__c != null ||
                activation == false && ordProd.Product2.Deactivation_Case_Queue__c != null
            )
        ) {
            return ( 
                ordProd.Fulfillment_Account__r.BillingCountryCode == 'GB' ? 
                (   
                    ordProd.Product2.Sub_Category__c == 'Area Boost' ? 
                    caseQueueMap.get('UK Area Boost Case Queue') : 
                    caseQueueMap.get('UK Ad Ops Case Queue')
                ) : 
                caseQueueMap.get(
                    activation == true ? 
                    ordProd.Product2.Activation_Case_Queue__c : 
                    ordProd.Product2.Deactivation_Case_Queue__c
                )
            );
        }

        return null;
    }

    /*
    * Gets and returns case subject
    */

    private static String getCaseSubject(OrderItem ordProd, Boolean activation) {
        // get strings for subject
        String fulfillmentAccountName = ordProd.Fulfillment_Account__r.Name;
        String productName = ordProd.Product2.Name;

        return (
            activation == true ? 
            'Product Activation for Fulfillment Account ' + fulfillmentAccountName +  '-'  + productName :
            'Product Deactivation for Fulfillment Account ' + fulfillmentAccountName +  '-'  + productName
        );
    }

    /*
    * Gets and returns case reason
    */

    private static String getCaseReason(Boolean activation) {
        return activation == true ? 'Product Activation' : 'Product Deactivation';
    }

    /*
    * Gets and returns case description
    */

    private static String getCaseDescription(OrderItem ordProd) {
        return 'Fulfillment for manually provision product for order#' + ordProd.Order.OrderNumber + 
                ' for order Product#' + ordProd.OrderItemNumber + 
                ' for Fulfillment Account ' + ordProd.Fulfillment_Account__r.Name;
    }

    /**
    * Gets and returns manually provisioned product map using POB metadata
    */

    private static Map<Id, Product2> getManuallyProvisionedProductMap() {
        return new Map<Id, Product2>([
            SELECT Id, Name, Family, Product_Provisioning_Behavior__c
            FROM Product2
            WHERE (Product_Provisioning_Behavior__c IN :activationPobs
            AND Activation_Case_Queue__c != null)
            OR (Product_Provisioning_Behavior__c IN :deactivationPobs
            AND Deactivation_Case_Queue__c != null)
        ]);
    }

    /**
    * Gets and returns manually provisioned record map
    */

    private static Map<String,Integer> getManuallyProvisionedRecordMap(List<OrderItem> newOrderProductList) {
        // map of order with number of ManuallyProvisionRecord 
        Map<String,Integer> manuallyProvisionedRecordMap  = new map<String,Integer>();

        // loop through order products in scope
        for(OrderItem oi : newOrderProductList){

            // if order product is manually provisioned and order id is present
            if (
                manuallyProvisionedProductMap.containskey(oi.Product2Id) && 
                oi.OrderId != null
            ) {
                // create unique string
                String orderIDWithProductId = oi.OrderId+''+oi.Product2Id;
        
                // if unique string is already in map
                if (manuallyProvisionedRecordMap.containsKey(orderIDWithProductId)) {
                    // get num, increment, put back in map
                    Integer num = manuallyProvisionedRecordMap.get(orderIDWithProductId);
                    num++;
                    manuallyProvisionedRecordMap.put(orderIDWithProductId, num);

                // if unique string is not in map
                } else {
                    // put unique string in map with num intialized at 1
                    manuallyProvisionedRecordMap.put(orderIDWithProductId, 1);
                } 
            }
        }
        // return map
        return manuallyProvisionedRecordMap;
    }

    /**
    * Gets and returns manually provisioned order product id set
    */

    private static Set<Id> getManuallyProvisionedOrderProductIDSet(List<OrderItem> newOrderProductList) {

        Set<Id> manuallyProvisionedOrderProductIDSet = new Set<Id>();

        // logic to store order product Id with manually provisioned product into manuallyProvisionedorderProductIDSet set
        for (OrderItem ordProd : newOrderProductList){
            // checking if product associated with order product is manually provisioned then store the order product Id
            if (
                manuallyProvisionedProductMap.containskey(ordProd.Product2Id) && 
                ordProd.OrderId != null
            ){
                manuallyProvisionedOrderProductIDSet.add(ordProd.Id);
            }
        }

        return manuallyProvisionedOrderProductIDSet;
    }

    /**
    * Gets and returns manually provisioned order product map
    */

    private static Map<Id, OrderItem> getManuallyProvisionedOrderProdMap(Set<Id> manuallyProvisionedorderProductIDSet) {
        // querying order product to get relevant record data from order,product and account
        return new Map<Id, OrderItem>([
            SELECT Id,SBQQ__QuoteLine__r.SBQQ__UpgradedSubscription__c, SBQQ__QuoteLine__r.SBQQ__Existing__c, 
                SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Type__c, orderId, Product2.Activation_Case_Queue__c,
                Product2.Deactivation_Case_Queue__c, Product2Id, 
                order.SBQQ__Quote__r.SBQQ__Opportunity2__r.Excluded_inventory__c, 
                order.SBQQ__Quote__r.SBQQ__Opportunity2__r.Display_Ad_Tag_line__c, 
                order.SBQQ__Quote__r.SBQQ__Opportunity2__r.Excluded_State__c, 
                order.SBQQ__Quote__r.SBQQ__Opportunity2__r.Shipping_Price_Estimate__c,
                order.SBQQ__Quote__r.SBQQ__Opportunity2__r.Pricing_Estimate_Details__c,
                order.SBQQ__Quote__r.SBQQ__Opportunity2__c, 
                Product2.Name, Fulfillment_Account__c, Order.OrderNumber, Quantity,
                Order.Account.Name, Order.AccountId, OrderItemNumber, 
                Fulfillment_Account__r.BillingCountryCode, Fulfillment_Account__r.Name,
                Product2.Sub_Category__c
            FROM OrderItem
            WHERE Id IN :manuallyProvisionedorderProductIDSet
        ]);
    }

}
