public class ContractTriggerHandler extends TriggerHandler {

    private List<Contract> newList;
    private Map<ID,Contract> newMap;
    private List<Contract> oldList;
    private Map<ID,Contract> oldMap;

    public ContractTriggerHandler(){
        this.newList= (List<Contract>) Trigger.new;
        this.newMap = (Map<Id,Contract>) Trigger.newMap;
        this.oldList = (List<Contract>) Trigger.old;
        this.oldMap = (Map<Id,Contract>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        ContractTriggerFunctions.initialSetup(newList);
    }

    public override void beforeUpdate() {

    }

    public override void afterInsert() {
        //ContractTriggerFunctions.updateAccountType(newList, null); //BR-7299
        ContractTriggerFunctions.getContractPDF(newList); //BR-4265
    }

    public override void afterUpdate() {
        ContractTriggerFunctions.updateAccountType(newList, oldMap);
        ContractTriggerFunctions.getAmendContractPDF(newList, oldMap); //BR-4265
    }

}