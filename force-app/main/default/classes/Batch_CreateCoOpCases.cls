/**
 * @author Adam LaPlante
 * @module BR-1200
 * @created 11/17/2021
 * @modified 
 */
public class Batch_CreateCoOpCases implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

	public Database.QueryLocator start(Database.BatchableContext bc){
		string query = 'Select Id, Account__c, Active__c, Co_Op_Amount__c, Name, Co_Op_Program__c, ' +
                       'Co_Op_Program__r.Co_Op_OEM__c, Notes__c, Co_Op_Type__c, Contact__c, CreatedById, ' +
                       'Full_Service__c, Reimbursement_Display__c, Reimbursement_Listings__c, Start_Date__c ' +
                       'From Co_Op_Detail__c WHERE Active__c = true AND Self_Service__c = false';

		return Database.getQueryLocator(query);
	}


	public void execute(Database.BatchableContext bc, List<Co_Op_Detail__c> coOpDetails){
        List<Case> casesToCreate= new List<Case>();
        Id coOpCaseQueueId = Utilities.getCaseQueueMap().get('Co-Op Queue');
        ID coOpCaseRecordtypeID = Utilities.getrecordTypeId('Case', 'Co_Op');
        //Id coOpCaseRecordtypeID = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Co_Op');

		// loop through co-op details, add new cases to list
		for (Co_Op_Detail__c coOp : coOpDetails){
            Case c = new Case(
                OwnerId = coOpCaseQueueId,
                AccountId = coOp.Account__c,
                RecordTypeId = coOpCaseRecordtypeID,
                Subject = 'Co-Op Case',
                Co_Op_Status__c = 'Pre-Approval Prep',
                Co_Op_Type__c = coOp.Co_Op_Type__c, 
                Description = coOp.Notes__c,
                Priority = 'Medium',
                Co_Op_Claim_Month__c = Date.today(),
                Co_Op_OEM__c = coOp.Co_Op_Program__r.Co_Op_OEM__c,
                ContactId = coOp.Contact__c,
                Reason = 'Support: Co-Op',
                Origin = 'Internal'
            );
            casesToCreate.add(c);
		}

        // insert cases
		if (casesToCreate.size() > 0) {
			try {
                insert casesToCreate;
			} catch (DMLException e) {
				Utilities.sendSimpleErrorEmail('Batch_CreateCoOpCases', e.getMessage());
			}

		}

	}
	public void finish(Database.BatchableContext bc){
	}
	public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_CreateCoOpCases());
	}
}                                      