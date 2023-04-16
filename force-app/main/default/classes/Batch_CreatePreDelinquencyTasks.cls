public class Batch_CreatePreDelinquencyTasks implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {
	public Database.QueryLocator start(Database.BatchableContext bc){
        // predelinqunecy date = 14 days before going delinquent
        DateTime dT = System.now() - 16;
		Date preDelinquencyDate = date.newinstance(dT.year(), dT.month(), dT.day());

        // run select to get affected invoices
		string query = 'SELECT Id, Name, CurrencyIsoCode, Zuora__DueDate__c, Zuora__Balance2__c,' +
        'Zuora__Account__c, Zuora__BillingAccount__c,' +
        'Zuora__Account__r.Name, Zuora__Account__r.ownerId, Zuora__Account__r.Grace_Date_Formula__c ' +
        'FROM Zuora__ZInvoice__c WHERE Zuora__Status__c = \'Posted\' ' + 
        'AND Zuora__Balance2__c > 0.00 AND ' +
       	'(Zuora__Account__r.Grace_Date_Formula__c = null OR Zuora__Account__r.Grace_Date_Formula__c < TODAY) ' +
        'AND Zuora__DueDate__c = :preDelinquencyDate';


		return Database.getQueryLocator(query);
	}


    
	public void execute(Database.BatchableContext bc, List<Zuora__ZInvoice__c> Invoices){

        try {

            Set<Id> accountIds = new Set<Id>();

            // loop through invs filling accountId set
            for (Zuora__ZInvoice__c inv : Invoices){
                accountIds.add(inv.Zuora__Account__r.Id);
            }

            // get accountsWithTeamMembersMap for later use
            Map<Id, Account> accountsWithTeamMembersMap = new Map<Id, Account>([
                SELECT Id, OwnerId, 
                    (
                        SELECT Id, UserId, TeamMemberRole 
                        FROM AccountTeamMembers
                    ) 
                FROM Account 
                WHERE Id IN :accountIds
            ]);

            List<Task> tasksToCreate= new List<Task>();

            // loop through invs creating tasks
            for (Zuora__ZInvoice__c inv : Invoices){
                tasksToCreate.add(createDelinquencyTask(inv, accountsWithTeamMembersMap));
            }

            // insert newly made tasks
            insert tasksToCreate;

        } catch (Exception e) {
            System.debug('Error creating tasks : ' + e.getMessage());
        }
	}

    // creates delinquency task
    private static Task createDelinquencyTask(Zuora__ZInvoice__c inv, Map<Id, Account> accountsWithTeamMembersMap) {
        // setup delinquency task
        return new Task(
            Subject = 'Account Approaching Delinquency - Invoice #' + inv.Name + '; ' + inv.Zuora__Account__r.Name,
            Status = 'Open',
            OwnerId = determineTaskOwnerId(inv.Zuora__Account__r.Id, accountsWithTeamMembersMap),
            WhatId = inv.Zuora__Account__r.Id,
            CurrencyIsoCode = inv.CurrencyIsoCode,
            Priority = 'Normal',
            ActivityDate = date.today()+5
        );
    }


    /**
     * Determines task owner with these priorities 
     * 1. Account Manager
     * 2. Field Manager
     * 2. Account Executive
     *
     * @jira: EA-786
     * @author: Adam LaPlante
     * @created: 07/27/2022
     */

    private static Id determineTaskOwnerId(Id accountId, Map<Id, Account> accountsWithTeamMembersMap) {

        Account acc = accountsWithTeamMembersMap.get(accountId);
        Id accountManagerId;
        Id fieldManagerId;

        // loop through team members grabbing user ids for each respective role
        for (AccountTeamMember teamMember : acc.AccountTeamMembers) {
            // if account manager
            if (teamMember.TeamMemberRole == 'Account Manager' ) {
                accountManagerId = teamMember.UserId;
            // if field manager
            } else if (teamMember.TeamMemberRole == 'Field Account Manager') {
                fieldManagerId = teamMember.UserId;
            }
        }

        // priority #1 : account manager
        if (accountManagerId != null) {
            return accountManagerId;
        // priority #2 : field manager 
        } else if (fieldManagerId != null) {
            return fieldManagerId;
        // priority #3 : account executive
        } else {
            return acc.OwnerId;
        }
    }


	public void finish(Database.BatchableContext bc){
	}
	public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_CreatePreDelinquencyTasks());
	}
}