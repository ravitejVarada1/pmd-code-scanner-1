
public class OrderItemUpdateEventTriggerHandler extends TriggerHandler {
    private List<Order_Item_Update_Event__e> newEventList;
    private Map<ID,Order_Item_Update_Event__e> newEventMap;
    private List<Order_Item_Update_Event__e> oldEventList;
    private Map<ID,Order_Item_Update_Event__e> oldEventMap;

    public OrderItemUpdateEventTriggerHandler(){
        this.newEventList = (List<Order_Item_Update_Event__e>) Trigger.new;
        this.newEventMap  = (Map<Id,Order_Item_Update_Event__e>) Trigger.newMap;
        this.oldEventList = (List<Order_Item_Update_Event__e>) Trigger.old;
        this.oldEventMap  = (Map<Id,Order_Item_Update_Event__e>) Trigger.oldMap;
    }

    public override void afterInsert() {
        OrderItemUpdateEventTriggerFunctions.setOrderItemPending(newEventList);
    }
    
}