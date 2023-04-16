public without sharing class DialpadCallEventLogTriggerFunctions {
    @TestVisible
    private static final String CONNECTED = 'CONNECTED';
    
    public static void populateMissingDialpadCallerPhone(List<Dialpad_Call_Event_Log__c> newCallLogList) {
        Map<String,Dialpad_Call_Event_Log__c> callIdToLogMap = new Map<String,Dialpad_Call_Event_Log__c>();
        
        //Return if the log is not a CONNECTED state log and return if not.
        for(Dialpad_Call_Event_Log__c log: newCallLogList){
            if(log.State__c == CONNECTED && !String.isEmpty(log.External_Number__c) && !String.isEmpty(log.Call_Id__c)){
                callIdToLogMap.put(log.Call_Id__c, log);
            }
        }
        if(callIdToLogMap.isEmpty()){
            return;
        }

        //Adding created date cutoff to avoid unselective query error
        DateTime taskCutoffDate = System.Now().addHours(-24);

        //Check if there is any task with the same CallId that did not have their Caller Phone updated yet. Return if Task was updated.
        List<Task> updateTaskList = [SELECT Id, Dialpad_Caller_Phone__c, Dialpad__CallId__c 
                                    FROM Task 
                                    WHERE Dialpad__CallId__c IN: callIdToLogMap.keyset()
                                        AND Dialpad__CallId__c != NULL 
                                        AND Dialpad_Caller_Phone__c = NULL 
                                        AND Dialpad__IsDialpadCallLog__c = true 
                                        AND CallType = 'Inbound' 
                                        AND CreatedDate >: taskCutoffDate];
        if(updateTaskList.isEmpty()){
            return;
        }
        
        //Update the Caller Phone and flip the Dialpad_Matched__c to false to meet filter criteria in TaskTriggerFunctions.populateRelatedDialpadRecord
        for(Task t: updateTaskList){
            t.Dialpad_Caller_Phone__c = callIdToLogMap.get(t.Dialpad__CallId__c).External_Number__c;
            t.Dialpad_Matched__c = false;
            }
        
        UPDATE updateTaskList;
    }
}
