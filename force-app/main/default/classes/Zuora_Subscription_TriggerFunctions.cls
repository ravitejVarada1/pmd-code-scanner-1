public without sharing class Zuora_Subscription_TriggerFunctions {
     // evaluates the need for and handles the creation / closing of delinquency tasks
    public static void delinquencyTaskEvaluation(List<Zuora__Subscription__c> subList, Map<Id,Zuora__Subscription__c> oldMap) {
        // set up lists
        Map<Id, Zuora__Subscription__c> zuoraSubMap = new Map<Id, Zuora__Subscription__c>();
        List<Zuora__Subscription__c> cpqSubLookupList = new List<Zuora__Subscription__c>();
        List<Task> taskList = new List<Task>();



        // loop through subs entering trigger
        for (Zuora__Subscription__c newSub : subList ) {
            // get old sub if available
            Zuora__Subscription__c oldSub = oldMap?.get(newSub.ID);

            // if a delinquency status update has occured (paying to delinquent, delinquent to paying)
            if (delinquencyUpdated(newSub, oldSub)) {
                // add zuora sub to cpq sub look up list
                cpqSubLookupList.add(newSub);
                zuoraSubMap.put(newSub.Id, newSub);
            }
        }

        // get map of Zuora Sub -> CPQ Sub using cpq sub lookup list
        Map<Id, SBQQ__Subscription__c> cpqSubMap = cpqSubLookup(cpqSubLookupList);
        List<Task> delinquencyTasks = taskLookup();


        // iterate through returned map, key = Zuora Sub, value = CPQ sub
        for (Id zuoraSubId : cpqSubMap.keySet()) {
            // setup vars for clarity
            SBQQ__Subscription__c cpqSub = cpqSubMap.get(zuoraSubId);
            Zuora__Subscription__c zuoraSub = zuoraSubMap.get(zuoraSubId);
            Boolean taskFound = false;

            for (Task task : delinquencyTasks) {
                // of the zuoraSub billing status == delinquent and there's already an open delinquency task, do nothing
                if (zuoraSub.BillingStatus__c == 'Delinquent' && task.Subject.contains(cpqSub.SBQQ__ContractNumber__c)) {
                    taskFound = true;
                    break;

                // if the status is not delinquent and there's an open delinquency task, mark task to close and put in update list
                } else if (zuoraSub.BillingStatus__c != 'Delinquent' && task.Subject.contains(cpqSub.SBQQ__ContractNumber__c)) {
                    taskFound = true;
                    task.status = 'Closed';
                    taskList.add(task);
                    break;
                }

            }

            // if no task was found and billingStatus is delinquency, create task add to task list
            if (!taskFound && zuoraSub.BillingStatus__c == 'Delinquent') {
                taskList.add(createDelinquencyTask(cpqSub));
            }
        }


        // if tasks where created / updtaed
        if (taskList.size() > 0) {
            // upsert all freshly created / updated tasks
            upsert taskList;
        }
    }

    // creates delinquency task
    private static Task createDelinquencyTask(SBQQ__Subscription__c sub) {
        // setup delinquency task
        Task delTask  = new Task();
        delTask.Subject = 'Delinquency Notification - Contract #' + sub.SBQQ__ContractNumber__c	 + '; ' + sub.Name;
        delTask.Status = 'Open';
        delTask.OwnerId = sub.Fulfillment_Account__r.ownerId;
        delTask.WhatId = sub.SBQQ__Account__c;
        delTask.CurrencyIsoCode = sub.CurrencyIsoCode;
        delTask.Priority = 'Normal';
        delTask.ActivityDate = date.today()+1;
        return delTask;
    }

    // Checks if a delinquency update has happened to the subscription
    private static boolean delinquencyUpdated(Zuora__Subscription__c newSub, Zuora__Subscription__c oldSub) {
        if (oldSub == null) {
            return newSub.BillingStatus__c == 'Delinquent' ? true : false;
        } else {
            return ((newSub.BillingStatus__c == 'Delinquent' && oldSub.BillingStatus__c == 'Paying') || 
                    (oldSub.BillingStatus__c == 'Delinquent' && newSub.BillingStatus__c == 'Paying') ? true : false);
        }
    }
    
    private static List<Task> taskLookup () {
        return (new List<Task>([SELECT Status, Subject FROM TASK WHERE Status = 'Open' AND Subject LIKE '%Delinquency Notification - Contract #%']));
    }

    private static Map<Id, SBQQ__Subscription__c> cpqSubLookup(List<Zuora__Subscription__c> cpqSubsToLookup) {
        List<String> subNums = new List<String>();

        for (Zuora__Subscription__c zuoraSub : cpqSubsToLookup) {
            subNums.add(zuoraSub.name);
        }

        Map<Id, SBQQ__Subscription__c> returnMap = new Map<Id, SBQQ__Subscription__c>();
        List<SBQQ__Subscription__c> subList = [SELECT Id, Name, CurrencyIsoCode, SBQQ__Account__c, SBQQ__ContractNumber__c, Zuora_Subscription_Number__c, Fulfillment_Account__r.OwnerId FROM SBQQ__Subscription__c WHERE Zuora_Subscription_Number__c in :subNums];

        for (SBQQ__Subscription__c cpqSub : subList) {
            for (Zuora__Subscription__c zuoraSub : cpqSubsToLookup) {
                if (cpqSub.Zuora_Subscription_Number__c == zuoraSub.name) {
                     returnMap.put(zuoraSub.Id, cpqSub);
                }
            }
        }

        return returnMap;
    }
}