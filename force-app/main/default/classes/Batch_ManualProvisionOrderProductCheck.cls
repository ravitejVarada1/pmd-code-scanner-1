/**
 * @description       : JIRA DSS-31
 * @author            : Lawrence Zhao
 * @last modified on  : 01-30-2023
 * @last modified by  : Lawrence Zhao
**/

public with sharing class Batch_ManualProvisionOrderProductCheck implements Database.Batchable<SObject>, Schedulable {

    private final String queryString = 'SELECT Id, Product2Id FROM OrderItem ' +
        'WHERE Id IN (SELECT Order_Product__c FROM Case WHERE Reason = \'Product Activation\' AND IsClosed = false) AND SBQQ__Status__c = \'Activated\' ';

    public Database.QueryLocator start(Database.BatchableContext context) {
        System.debug('QueryString : ' +queryString);
        return Database.getQueryLocator(queryString);
    }

    public void execute(Database.BatchableContext context, List<OrderItem> scope) {
        
        Map<Id, OrderItem> orderItemMap = new Map<Id, OrderItem>(scope);
        OrderProductTriggerFunctions.publishOrderItemUpdateEvent(orderItemMap);
    }

    public void finish(Database.BatchableContext context) {
    }

    public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_ManualProvisionOrderProductCheck());
	}
}