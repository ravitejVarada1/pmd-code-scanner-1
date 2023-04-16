// https://cargurus.atlassian.net/browse/BR-1613
public without sharing class ZuoraIntegration_RevproBatch implements Database.Batchable<sObject>, Schedulable, 
Database.AllowsCallouts {

  public Database.QueryLocator start(Database.BatchableContext bc) {
    String query = '' +
      'SELECT Id, OrderId, Billing_Account__c, Product2Id, Activation_Zuora_RevPro__c, '+
        'ServiceDate, SBQQ__Status__c, SBQQ__Subscription__c, Manual_Activation_Date__c, ' +
        'SBQQ__Subscription__r.Zuora_Subscription_Rate_Plan__c, ' +
        'SBQQ__Subscription__r.Zuora_Subscription_Rate_Plan__r.Zuora__OriginalSubscriptionRatePlanId__c ' +
      'FROM OrderItem ' +
      'WHERE Activation_Zuora_RevPro__c IN (\'Pending\') '+
        'AND Product2.Manually_Provisioned__c = TRUE ' + 
        'AND SBQQ__Activated__c = TRUE ' +
        'AND SBQQ__Subscription__r.Zuora_Subscription_Rate_Plan__r.Zuora__OriginalSubscriptionRatePlanId__c != NULL ';
    
    return Database.getQueryLocator(query);
  }
  
  // schedulable execute method uses defaults
  public void execute(SchedulableContext ctx) {
    Database.executeBatch(new ZuoraIntegration_RevproBatch());
  }

  public void execute(Database.BatchableContext bc, List<OrderItem> orderProductsList) {
    try {
      ZuoraIntegration_RevproHelper.createAndSendRevproActivationMessages(orderProductsList);
    } catch (Exception e) {
      System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
      throw e;
    }
  }

  public void finish(Database.BatchableContext bc) {}

}