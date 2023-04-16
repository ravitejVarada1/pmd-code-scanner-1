public class Batch_MassAmendOpportunity implements Database.Batchable<Id>,Database.AllowsCallouts,Database.stateful{

	public List<Id> contractIdList;

	public Batch_MassAmendOpportunity(List<Id> contractIdList ){
		this.contractIdList = contractIdList;
	}

	public Iterable<Id> start(Database.BatchableContext BC){
		return contractIdList;
	}

	public void execute(Database.BatchableContext BC, List<Id> reqIds){
		for(Id s : reqIds){
			ContractAmender c = new ContractAmender();    
			c.amend(string.valueOf(s));

		}
	}

	public void finish(Database.BatchableContext BC){

	}
}