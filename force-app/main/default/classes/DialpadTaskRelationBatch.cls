/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        01/07/2021
* modified:       01/07/2021
* created jira:   BR-363
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class DialpadTaskRelationBatch implements Database.Batchable<sObject>, Schedulable{
    
    private Set<ID> taskIds;
    public String numDaysBack = '7';
    
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new DialpadTaskRelationBatch());
    }
    
    public DialpadTaskRelationBatch(){
        
    }
    
    public DialpadTaskRelationBatch(Set<ID> taskIds){
        this.taskIds = taskIds;
    }
    
    public DialpadTaskRelationBatch(String numDaysBack){
        this.numDaysBack = numDaysBack;
    }
    
    //Find all dialpad tasks that have not been processed, and send them into the method
    //to find the related record
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Dialpad__IsDialpadCallLog__c, Dialpad_Caller_Phone__c, Dialpad__CallId__c, WhatId, WhoId, ' +
            'OwnerId, AccountId, Dialpad__PhoneNumber__c ' +
            'FROM Task ';
        
        if (taskIds == null){
            query += 'WHERE Dialpad_Matched__c = false ' +
                'AND Dialpad__IsDialpadCallLog__c = true ' +
                'AND CreatedDate = LAST_N_DAYS:' + numDaysBack;
        }else{
            query += 'WHERE Id IN :taskIds';
        }
        
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<Task> allTasks){
        TaskTriggerFunctions.populateRelatedDialpadRecord(new Map<ID,Task>(allTasks).keySet());
    }
    
    
    public void finish(Database.BatchableContext bc){
        //TA-DA!
    }
    
}