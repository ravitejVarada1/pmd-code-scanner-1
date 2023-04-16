public class OrderItemUpdateEventTriggerFunctions {

    public static void setOrderItemPending(List<Order_Item_Update_Event__e> events) {

        Set<Id> productIDs = new Set<Id>();

        for (Order_Item_Update_Event__e event : events) {
            productIds.add(event.ProductId__c);
        }

        // SA-559 - use activation performance obligations to determine need for manual provisioning
        List<String> activationPOBs = Utilities.getManualActivationPobs();
        List<OrderItem> orderItems = new List<OrderItem>();
        
        // SA-559 - get map of manually provisioned products
        Map<Id, Product2> manuallyProvisionedProductMap = new Map<Id, Product2>([
            SELECT Id
            FROM Product2
            WHERE Id IN :productIds
            AND Product_Provisioning_Behavior__c IN :activationPOBs
        ]);
        
        for(Order_Item_Update_Event__e updateEvent : events) {
            if (manuallyProvisionedProductMap.containsKey(updateEvent.ProductId__c)) {
                orderItems.add(
                    new OrderItem(
                        Id = updateEvent.TransactionId__c, 
                        SBQQ__Status__c = 'Pending Activation', 
                        Activation_Zuora_RevPro__c = null
                    )
                );
            }
        }

        if(orderItems.size() > 0) {
            update orderItems;
        }
    }
}
