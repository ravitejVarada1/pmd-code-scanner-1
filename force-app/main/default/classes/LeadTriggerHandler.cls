/********************************************************************************************************
* author:         preddy
* modifiedBy:     dmcintyre
* created:        04/26/2021
* modified:       05/26/2021
* created jira:   BR-855
*********************************************************************************************************/
public class LeadTriggerHandler  extends TriggerHandler {
    private List<Lead> newLeadList;
    private Map<Id,Lead> newLeadMap;
    private List<Lead> oldLeadList;
    private Map<Id,Lead> oldLeadMap;

    public LeadTriggerHandler(){
        this.newLeadList = (List<Lead>) Trigger.new;
        this.newLeadMap = (Map<Id,Lead>) Trigger.newMap;
        this.oldLeadList = (List<Lead>) Trigger.old;
        this.oldLeadMap = (Map<Id,Lead>) Trigger.oldMap;
    }
    
    public override void beforeInsert() {
		CG_LeadOwnership.setDefaultLeadCountry(newLeadList); //BR-6610
        LeadTriggerFunctions.populateAcctContactSpRefFields(newLeadList);        
        CG_LeadOwnership.assignLeadtoAcquistions(newLeadList, null);
        CG_LeadOwnership.assignLeadOwnerWithRR(newLeadList, null); //BR-4043
    }

    public override void beforeUpdate() {
        CG_LeadOwnership.setDefaultLeadCountry(newLeadList); //BR-6610
        CG_LeadOwnership.assignLeadtoAcquistions(newLeadList, oldLeadMap);
    }

    public override void afterInsert() {
		LeadTriggerFunctions.upsertCampaigns(newLeadList);
    }    
}