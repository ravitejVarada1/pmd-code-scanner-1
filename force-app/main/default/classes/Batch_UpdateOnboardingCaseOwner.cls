public class Batch_UpdateOnboardingCaseOwner implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

    public Database.QueryLocator start(Database.BatchableContext bc){
        //Id onboardingCaseRecordtypeID = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Onboarding');
        ID onboardingCaseRecordtypeID = Utilities.getrecordTypeId('Case', 'Onboarding');

        String query = 'SELECT Id, OwnerId, Account.OwnerId,(Select Id, OwnerId  From Tasks) FROM Case WHERE RecordTypeId =: onboardingCaseRecordtypeID '+
                        'AND Related_Quote__c != null AND Related_Quote__r.SBQQ__Opportunity2__c != null AND AccountId != null ' +
                        'AND Related_Quote__r.SBQQ__Type__c = \'Quote\' AND Related_Quote__r.SBQQ__Opportunity2__r.StageName = \'Closed Won\' ' +
                        'AND CaseOwnerIdCheck__c = true AND Status != \'Closed\' AND CountryCode__c != \'US\' AND Account.Owner.Name != \'CarGurus API\' ';
        return Database.getQueryLocator(query);
                    
    }
    
    public void execute(Database.BatchableContext bc,List<Case> Cases) {
        List<Case> casesToUpdate = new List<Case>();
        List<Task> tasksToUpdate = new List<Task>();
        for(Case c : cases){
            if(c.OwnerId != c.Account.OwnerId){
            casesToUpdate.add(new Case(Id = c.Id, OwnerId = c.Account.OwnerId)); 
            
            for(Task t : c.Tasks) {
                t.OwnerId = c.Account.OwnerId;
                tasksToUpdate.add(t); 
                } 
        	}
        }

        if(!casesToUpdate.isEmpty()) {
        update casesToUpdate;
    	}

        if(!tasksToUpdate.isEmpty()) {
        update tasksToUpdate;
        }
    }
    
    public void finish(Database.BatchableContext bc) {
	}

	public void execute(SchedulableContext sc) {
		Database.executeBatch(new Batch_UpdateOnboardingCaseOwner());
	}

}