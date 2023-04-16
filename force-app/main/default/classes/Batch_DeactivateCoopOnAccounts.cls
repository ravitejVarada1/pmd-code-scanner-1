/**
 * @description       : JIRA BR-4456 / SA-414 - This batch will remove dealers from co-op by finding accounts
 *                      which are not customers anymore
 * @author            : Lawrence Zhao
 * @last modified on  : 08-26-2022
 * @last modified by  : RA
**/

public with sharing class Batch_DeactivateCoopOnAccounts implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    private List<Id> successes = new List<Id>();
    private List<Id> failures = new List<Id>();

    private final String queryString = 'SELECT Id, Active__c FROM Co_Op_Detail__c ' +
        'WHERE Active__c = TRUE AND Account__r.Type != \'Customer\' ' ;

    @testVisible
    private static String result = '';

    public Database.QueryLocator start(Database.BatchableContext context) {
        System.debug('QueryString : ' +queryString);
        return Database.getQueryLocator(queryString);
    }

    public void execute(Database.BatchableContext context, List<Co_Op_Detail__c> scope) {
        
        for (Co_Op_Detail__c cod : scope) {
            cod.Active__c = false;
        }

        List<Database.SaveResult> saveResults = new List<Database.SaveResult>();
        saveResults = Database.update(scope, false);
        for (Database.SaveResult sr : saveResults) {
            if (sr.isSuccess()) {
                // Only available *across* scope executions because of
                // Database.stateful
                successes.add(sr.id);
            } else {
                // Only available *across* scope executions because of
                // Database.stateful
                failures.add(sr.id);
            }
        }
    }

    public void finish(Database.BatchableContext context) {
        Batch_DeactivateCoopOnAccounts.result =
            'Successes: ' +
            successes.size() +
            'Failures: ' +
            failures.size();
    }

    public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_DeactivateCoopOnAccounts());
	}
}