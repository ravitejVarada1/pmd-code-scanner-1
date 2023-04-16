/**
 * https://cargurus.atlassian.net/browse/BR-3942
 * When an activity is logged/copmpleted against an account, stamp the datetime of this 
 * event on the account in the Last_Activity_Account_Owner__c field
 */

public without sharing class ActivityTriggerFunctions {

    public static final String CHECK_TASK_TYPE = 'Call';

    public static void updateLastActivityOnAccount(Map<Id, SObject> newActivityMap, Map<Id, SObject> oldActivityMap) {

        Map<Id, Id> atyAccountIdMap = new Map<Id, Id>();
        Map<Id, Id> atyOwnerIdMap = new Map<Id, Id>();

        Map<Id, Account> accountsToUpdate = new Map<Id, Account>();

        //collect activity owner and change to the IsClosed state (if task)
        for(SObject aty : newActivityMap.values()) {

            Id atyId = aty.Id;
            Id atyOwnerId = (Id)aty.get('OwnerId');
            Id atyWhatId = (Id)aty.get('WhatId');

            Boolean isTaskSObj = isTaskSObject(String.valueOf(atyId));
            Boolean notATask = !isTaskSobj;

            Task oldTsk;
            Boolean isNewTskClosed = false;
            Boolean isOldTskClosed = false;

            //BR-5317 allow LastActivityByOwner field update if Type = Call
            Boolean allowLastActivityByOwnerUpdate = false;

            if(isTaskSObj) {
                oldTsk = (Task)oldActivityMap?.get(atyId);
                isNewTskClosed = (Boolean)aty.get('IsClosed');
                isOldTskClosed = oldTsk == null?false:oldTsk.IsClosed;

                //BR-5317 allow LastActivityByOwner field update if Type = Call
                String taskType = String.isNotBlank(String.valueOf(aty.get('Type'))) ? String.valueOf(aty.get('Type')) : '';
                allowLastActivityByOwnerUpdate = taskType.equalsIgnoreCase(CHECK_TASK_TYPE) ? true : false;
            } 

            //if the activity is owned by a user then collect the owner id and the Account id in a map
            if(isAtyOwnedByUser(atyOwnerId) && isAtyRelatedToAccount(atyWhatId)) {
                //BR-5317 commenting out notATask condition to only update the field under a Call related task
                //if( (isTaskSObj && isNewTskClosed && !isOldTskClosed) || (notATask) ) {
                if(isTaskSObj && isNewTskClosed && !isOldTskClosed && allowLastActivityByOwnerUpdate) {
                    atyOwnerIdMap.put(atyId, atyOwnerId);
                    atyAccountIdMap.put(atyId, atyWhatId);
                }
            }
        }

        if(atyAccountIdMap.isEmpty()) { return; }

        //query the accounts related to the activity
        Map<Id, Account> accountMap = new Map<Id, Account>([SELECT Id, OwnerId, Last_Activity_Account_Owner__c,
            (SELECT Id, TeamMemberRole, UserId FROM AccountTeamMembers) //EA-131
            FROM Account WHERE Id IN :atyAccountIdMap.values()]);        

        //if the task/event owner matches the account owner, update the last_activity_account_owner__c
        //field with a timestamp of now
        for(Id atyId : atyAccountIdMap.keySet()) {

            Boolean isAMorFAMaTeamMember = false;

            Boolean isTaskSObj = isTaskSObject(atyId);

            Id atyOwnerId = atyOwnerIdMap.get(atyId);
            Id atyRelatedAccId = atyAccountIdMap.get(atyId);

            Account acc = accountMap.get(atyRelatedAccId);
            Id accOwnerId = accountMap.get(atyRelatedAccId).OwnerId;
            
            Datetime lastActivityOnRecord;
            Datetime now = Datetime.now();

            //if the activity owner is also the account owner
            //log this in the last activity date time
            if(accOwnerId == atyOwnerId) {
                acc.Last_Activity_Account_Owner__c = now;
                accountsToUpdate.put(atyRelatedAccId, acc);
            }
            
            List<AccountTeamMember> accTeamMembers = acc.AccountTeamMembers;
            for (AccountTeamMember act : accTeamMembers) {
                if (act.UserId == atyOwnerId &&
                    (act.TeamMemberRole == 'Account Manager' || act.TeamMemberRole == 'Field Account Manager')) {
                        isAMorFAMaTeamMember = true;
                        break;
                }
            }

            // EA-131 If the activity owner is also AM or FAM, log this in the last activity by manager date time
            if(isAMorFAMaTeamMember) {
                acc.Last_Activity_By_Account_Manager__c = now;
                accountsToUpdate.put(atyRelatedAccId, acc);
            }

        }
        
        if(!accountsToUpdate.isEmpty()) {
            update accountsToUpdate.values();
        }
    }

    //returns true if the task owner is a user id
    public static Boolean isAtyOwnedByUser(String tskOwnerId) {
        return tskOwnerId != null && tskOwnerId.startsWith('005');
    }

    //returns true if the what id is an account id
    public static Boolean isAtyRelatedToAccount(String tskWhatId) {
        return tskWhatId != null && tskWhatId.startsWith('001');
    }

    //returns true if the Activity Id belongs to a Task
    public static Boolean isTaskSObject(String atyId) {
        return atyId.startsWith('00T');
    }
}