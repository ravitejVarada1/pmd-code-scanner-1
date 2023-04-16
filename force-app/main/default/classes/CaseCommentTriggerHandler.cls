/********************************************************************************************************
* author:         alaplante
* modifiedBy:     
* created:        11/11/2021
* modified:       
* created jira:   BR-4432
*********************************************************************************************************/

public class CaseCommentTriggerHandler  extends TriggerHandler {
    private List<CaseComment> newCommentList;
    private Map<Id,CaseComment> newCommentMap;
    private List<CaseComment> oldCommentList;
    private Map<Id,CaseComment> oldCommentMap;

    public CaseCommentTriggerHandler(){
        this.newCommentList = (List<CaseComment>) Trigger.new;
        this.newCommentMap = (Map<Id,CaseComment>) Trigger.newMap;
        this.oldCommentList = (List<CaseComment>) Trigger.old;
        this.oldCommentMap = (Map<Id,CaseComment>) Trigger.oldMap;
    }
    
    public override void beforeInsert() {
    }

    public override void beforeUpdate() {
        CaseCommentTriggerFunctions.checkEditPermissions(newCommentMap);
    }

    public override void beforeDelete(){
        CaseCommentTriggerFunctions.checkDeletePermissions(oldCommentMap);
    }

    public override void afterInsert() {
    }    

    public override void afterUpdate() {
    }

    public override void afterDelete() {
    }
}