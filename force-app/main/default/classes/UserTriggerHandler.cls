/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         amitul
* modifiedBy:     amitul
* created:        04/05/2021
* modified:       04/05/2021
* created jira:   BR-864
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class UserTriggerHandler extends TriggerHandler {
    private List<User> newUserList;
    private Map<ID,User> newUserMap;
    private List<User> oldUserList;
    private Map<ID,User> oldUserMap;
    
    public UserTriggerHandler(){
        this.newUserList = (List<User>) Trigger.new;
        this.newUserMap  = (Map<Id,User>) Trigger.newMap;
        this.oldUserList = (List<User>) Trigger.old;
        this.oldUserMap  = (Map<Id,User>) Trigger.oldMap;
    }
    
    public override void beforeUpdate(){
        UserTriggerFunctions.clearTerminationDate(oldUserMap,newUserList);
        UserTriggerFunctions.setFinalApproverText(newUserList, oldUserMap);
    }
    
     public override void afterUpdate(){
        UserTriggerFunctions.unfreezeUser(oldUserMap,newUserList);
    }
     public override void beforeInsert(){
        UserTriggerFunctions.setFinalApproverText(newUserList, null);
    }
    
}