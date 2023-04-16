/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ksuh
* modifiedBy:     ksuh
* created:        12/22/2022
* modified:       12/22/2022
* created jira:   SA-988
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class DialpadCallEventLogTriggerHandler extends TriggerHandler {
    private List<Dialpad_Call_Event_Log__c> newCallLogList;
    // private Map<ID,Dialpad_Call_Event_Log__c> newCallLogMap;
    // private List<Dialpad_Call_Event_Log__c> oldCallLogList;
    // private Map<ID,Dialpad_Call_Event_Log__c> oldCallLogMap;

    public DialpadCallEventLogTriggerHandler() {
        this.newCallLogList = (List<Dialpad_Call_Event_Log__c>) Trigger.new;
        // this.newCallLogMap  = (Map<Id,Dialpad_Call_Event_Log__c>) Trigger.newMap;
        // this.oldCallLogList = (List<Dialpad_Call_Event_Log__c>) Trigger.old;
        // this.oldCallLogMap  = (Map<Id,Dialpad_Call_Event_Log__c>) Trigger.oldMap;

    }

    public override void afterInsert(){
        DialpadCallEventLogTriggerFunctions.populateMissingDialpadCallerPhone(newCallLogList);

    }
}
