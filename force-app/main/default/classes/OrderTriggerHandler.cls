public class OrderTriggerHandler extends TriggerHandler {
    
    private List<Order> newList;
    private Map<ID,Order> newMap;
    private List<Order> oldList;
    private Map<ID,Order> oldMap;

    public OrderTriggerHandler(){
        this.newList = (List<Order>) Trigger.new;
        this.newMap = (Map<Id,Order>) Trigger.newMap;
        this.oldList = (List<Order>) Trigger.old;
        this.oldMap = (Map<Id,Order>) Trigger.oldMap;
    }

    public override void beforeInsert() {
    }

    public override void beforeUpdate() {
        OrderTriggerFunctions.checkContracted(newMap, oldMap);
    }

    public override void afterInsert() {
        OrderTriggerFunctions.updateQuoteToOrderGenerated(newMap.keySet());
        OrderTriggerFunctions.updateRetentionData(newList);
    }

    public override void afterUpdate() {
        OrderTriggerFunctions.checkActivationStatusesPending(newList, oldMap);  // BR-894
        OrderTriggerFunctions.updateContractData(newMap);
        OrderTriggerFunctions.sendZuoraAmendTermsMessage(newMap, oldMap);
        OrderItemTransactionTypes.recordTransactionType(newMap); //BR-4610
    }
}