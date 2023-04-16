/**
 * @description       : JIRA SA-950 - This batch will create onboarding cases based on a mapping in custom metadata
 * @author            : Lawrence Zhao
 * @last modified on  : 25-Oct-2022
 * @last modified by  : Lawrence Zhao
**/

public with sharing class Batch_CreateOnboardingCases implements Database.Batchable<SObject>, Database.Stateful, Schedulable {

    List<Id> caseSuccesses = new List<Id>();
    List<Id> caseFailures = new List<Id>();
    List<Id> taskSuccesses = new List<Id>();
    List<Id> taskFailures = new List<Id>();
    List<String> productsToQuery = new List<String>();
    Id RECORDTYPEIDRETENTION = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Retention').getRecordTypeId();

    OnboardingCaseProcessor occ = new OnboardingCaseProcessor();

    @testVisible
    private static String result = '';

    public Database.QueryLocator start(Database.BatchableContext context) {

        List<String> productsToQuery = occ.getSettingProducts();
        Date farthestLookbackDate = occ.getFarthestLookbackDate();

        String queryString = 'SELECT Id, Product2.ProductCode, ServiceDate, Fulfillment_Account__c, Fulfillment_Account__r.OwnerId, Fulfillment_Account__r.Name, Fulfillment_Account__r.BillingCountryCode, ' +
        'OrderId, Order.SBQQ__Quote__c, SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__c, SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__PrimaryContact__c, Transaction_Type__c, SBQQ__Status__c FROM OrderItem ' +
        'WHERE SBQQ__Status__c = \'Activated\' AND Product2.ProductCode IN :productsToQuery AND SBQQ__Subscription__r.Activation_Status__c = \'Activated\' AND SBQQ__Subscription__r.Cancellation_Effective_Date__c = null '+ 
        'AND SBQQ__OrderedQuantity__c > 0 AND SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.RecordTypeId != :RECORDTYPEIDRETENTION AND ServiceDate >= :farthestLookbackDate';

        System.debug('Furthest Lookback Date : '+farthestLookbackDate);
        System.debug('getProductLookbackDates : '+occ.getProductLookbackDates());
        System.debug('QueryString : ' +queryString);
        return Database.getQueryLocator(queryString);
    }

    public void execute(Database.BatchableContext context, List<OrderItem> scope) {

        List<Case> casesToCreate = occ.getOnboardingCases(scope).values();
        List<Database.SaveResult> caseResults = new List<Database.SaveResult>();
        caseResults = Database.insert(casesToCreate, false);

        for(Database.SaveResult sr : caseResults) {
            if(sr.isSuccess()) {
                // Only available *across* scope executions because of Database.stateful
                caseSuccesses.add(sr.getId());
            } else {
                // Only available *across* scope executions because of Database.stateful
                caseFailures.add(sr.id);
            }
        }

        List<Task> tasksToInsert = occ.getTasksByCaseIds(caseSuccesses);
        List<Database.SaveResult> taskResults = new List<Database.SaveResult>();
        taskResults = Database.insert(tasksToInsert, false);

        for(Database.SaveResult sr : taskResults) {
            if(sr.isSuccess()) {
                // Only available *across* scope executions because of Database.stateful
                taskSuccesses.add(sr.getId());
            } else {
                // Only available *across* scope executions because of Database.stateful
                taskFailures.add(sr.id);
            }
        }
    }

    public void finish(Database.BatchableContext context) {
    }

    public void execute(SchedulableContext sc) {
		Database.executeBatch(new Batch_CreateOnboardingCases(), 50);
	}
}
