/**
 * @description       : 
 * @author            : LZhao
 * @group             : 
 * @last modified on  : 11-18-2021
 * @last modified by  : LZhao
**/
public class OrderProductTriggerHandler extends TriggerHandler{
	private List<OrderItem> newOrderProductList;
	private Map<ID, OrderItem> newOrderProductMap;
	private List<OrderItem> oldOrderProductList;
	private Map<ID, OrderItem> oldOrderProductMap;

	public OrderProductTriggerHandler(){
		this.newOrderProductList = (List<OrderItem>)Trigger.new;
		this.newOrderProductMap = (Map<Id, OrderItem>)Trigger.newMap;
		this.oldOrderProductList = (List<OrderItem>)Trigger.old;
		this.oldOrderProductMap = (Map<Id, OrderItem>)Trigger.oldMap;
	}

  	public override void beforeUpdate() {
	}

	public override void afterInsert() {
		OrderProductTriggerFunctions.createProvisioningCases(newOrderProductList);
		OrderProductTriggerFunctions.setOrderStatusToActivated(newOrderProductList);//BR-888
		OrderProductTriggerFunctions.checkOrderContractId(newOrderProductList, null);
		OrderProductTriggerFunctions.publishOrderItemUpdateEvent(newOrderProductMap);
		OrderProductTriggerFunctions.commitCaseInsert(); //BR-7299 - Always place this at the end
	}

	public override void afterUpdate() {
		OrderProductTriggerFunctions.createOnboardingCases(newOrderProductMap, oldOrderProductMap);
		OrderProductTriggerFunctions.createCoopCases(newOrderProductMap, oldOrderProductMap);
		OrderProductTriggerFunctions.checkOrderContractId(newOrderProductList, oldOrderProductMap);
		OrderProductTriggerFunctions.commitCaseInsert(); //BR-7299 - Always place this at the end
  	}
}