/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ralvarez
* modifiedBy:     
* created:        10/27/2022
* modified:       
* created jira:   SA-374
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class AccountTeamMemberTriggerHandler extends TriggerHandler {

    private List<AccountTeamMember> newATMList;
    private Map<Id,AccountTeamMember> newATMmap;
    private List<AccountTeamMember> oldATMList;
    private Map<Id,AccountTeamMember> oldATMmap;
    
    public AccountTeamMemberTriggerHandler() {
        this.newATMList = (List<AccountTeamMember>) Trigger.new;
        this.newATMmap  = (Map<Id,AccountTeamMember>) Trigger.newMap;
        this.oldATMList = (List<AccountTeamMember>) Trigger.old;
        this.oldATMmap  = (Map<Id,AccountTeamMember>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        AccountTeamMemberTriggerFunctions.setDefaultAccTeamMemberValues(newATMList);
    }

    public override void beforeUpdate() {
        AccountTeamMemberTriggerFunctions.setDefaultAccTeamMemberValues(newATMList);
    }
    
    public override void afterInsert() {
        AccountTeamMemberTriggerFunctions.createATMHistory(newATMList, null);
    }

    public override void afterUpdate() {
        AccountTeamMemberTriggerFunctions.createATMHistory(newATMList, oldATMmap);
        
    }
    public override void afterDelete() {
        AccountTeamMemberTriggerFunctions.createATMHistory(null,oldATMmap);
    }

}
