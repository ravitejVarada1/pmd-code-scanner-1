public without sharing class ZuoraSubChargeTriggerFunctions {
    
    // BR-1144 - when zuora sub charges are inserted or updated, try to relate them to cpq subscriptions
    public static void relateToCpqRecords(Set<Id> zSubChargeIds) {
        if (!System.isBatch() && !System.isFuture()) {
            relateToCpqRecordsFuture(zSubChargeIds);
            return;
        }

        Set<String> zSubNumbers = new Set<String>();

        for (Zuora__Subscription__c zSub : [SELECT Id, Name FROM Zuora__Subscription__c WHERE Id IN 
            (SELECT Zuora__Subscription__c FROM Zuora__SubscriptionProductCharge__c WHERE Id IN :zSubChargeIds)]) 
        {
            zSubNumbers.add(zSub.Name);
        }

        ZuoraIntegration_RelateCpqRecords.matchCPQSubZuoraFields(zSubNumbers);
    }

    @future
    public static void relateToCpqRecordsFuture(Set<Id> zSubChargeIds) {
        relateToCpqRecords(zSubChargeIds);
    }

}
