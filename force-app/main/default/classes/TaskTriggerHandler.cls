/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        01/07/2021
* modified:       01/07/2021
* created jira:   BR-363d
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class TaskTriggerHandler extends TriggerHandler{
    private List<Task> newTaskList;
    private Map<ID,Task> newTaskMap;
    private List<Task> oldTaskList;
    private Map<ID,Task> oldTaskMap;
    
    public TaskTriggerHandler(){
        this.newTaskList = (List<Task>) Trigger.new;
        this.newTaskMap  = (Map<Id,Task>) Trigger.newMap;
        this.oldTaskList = (List<Task>) Trigger.old;
        this.oldTaskMap  = (Map<Id,Task>) Trigger.oldMap;
    }
    
    public override void beforeInsert(){
        TaskTriggerFunctions.populateDialpadCallerPhone(newTaskList);
        TaskTriggerFunctions.checkForEmailType(newTaskList);
        TaskTriggerFunctions.initializeActivityType(newTaskList,NULL);
        TaskTriggerFunctions.populateTaskFields(newTaskList, null);
    }
    
    public override void beforeUpdate(){
        TaskTriggerFunctions.initializeActivityType(newTaskList,oldTaskMap);
        TaskTriggerFunctions.populateTaskFields(newTaskList, oldTaskMap);
    }

    public override void afterInsert() {
        TaskTriggerFunctions.populateRelatedDialpadRecord(newTaskMap.keySet());
        ActivityTriggerFunctions.updateLastActivityOnAccount(newTaskMap, null);
        TaskTriggerFunctions.updateRelatedRecords(newTaskList);
    }

    public override void afterUpdate() {
        TaskTriggerFunctions.populateRelatedDialpadRecord(newTaskMap.keySet());
        ActivityTriggerFunctions.updateLastActivityOnAccount(newTaskMap, oldTaskMap);
        TaskTriggerFunctions.updateIntegrityCaseRecord(newTaskList,oldTaskMap);
    }

}