public class CaseTriggerHandler extends TriggerHandler {
    
    private List<Case> newCaseList; 
    private Map<ID,Case> newCaseMap;
    private List<Case> oldCaseList;
    private Map<ID,Case> oldCaseMap;
    
    public CaseTriggerHandler(){
         setContextVariables();
    }
    public override void beforeUpdate(){
        if(newCaseList.isEmpty()) { return; }
        CaseTriggerFunctions.validateCreateDateBusinessHours(newCaseList);
        CaseTriggerFunctions.populateCountryCode(oldCaseMap,newCaseList);
        CaseTriggerFunctions.setViewOnCGurl(newCaseList, oldCaseMap);
        CaseTriggerFunctions.setPriorityOnBillingCases(newCaseList, null); //BR-7291
        CaseTriggerFunctions.setReOpenedDateOnBillingCase(newCaseList, oldCaseMap); //BR-4567
        CaseTriggerFunctions.setCGDurationTimeOnBillingCase(newCaseList, oldCaseMap); //BR-4567
        CaseTriggerFunctions.preventAssignmentRulesOnUpdate(newCaseList); //DSS-367
        CaseTriggerFunctions.validateCaseClosure(newCaseList, oldCaseMap); //SA-987
    }
    
    public override void beforeInsert(){
        if(newCaseList.isEmpty()) { return; }
        CaseTriggerFunctions.validateCreateDateBusinessHours(newCaseList);
        CaseTriggerFunctions.populateCountryCode(null,newCaseList);   
        CaseTriggerFunctions.associateCargurusAccount(newCaseList);//BR-1249
        CaseTriggerFunctions.associateEntitlements(newCaseList);//BR-1224
        CaseTriggerFunctions.setPriorityOnBillingCases(newCaseList, null); //BR-7291
        CaseTriggerFunctions.assignDDCases(newCaseList);
    }
     
    public override void afterUpdate(){
        if(newCaseList.isEmpty()) { return; }
        CaseTriggerFunctions.activateRelatedOrderProduct(newCaseList,oldCaseMap);//BR-888
        CaseTriggerFunctions.updateAndInsertRelatedDataForCancellations(oldCaseMap, newCaseMap);
        CaseTriggerFunctions.sendNotification(newCaseList);//BR-951
        CaseTriggerFunctions.markMilestones(newCaseMap, oldCaseMap);//3715        
        CaseTriggerFunctions.updateAccount(newCaseList, oldCaseMap);
        CaseTriggerFunctions.updateRelatedDealerAccount(newCaseList);
    }
    
    public override void afterInsert(){
        if(newCaseList.isEmpty()) { return; }
        CaseTriggerFunctions.createTasks(newCaseList);
    }


    public void setContextVariables() {
         Id consumerSupportRTId = CaseTriggerFunctions.caseRTNameIdMap.get('Consumer Support');
        
        if (Trigger.isInsert || Trigger.isUpdate) {
            this.newCaseList = new List<Case>();

            for(Case c : (List<Case>)Trigger.new) {
                if(c.recordtypeid != consumerSupportRTId ) { 
                    this.newCaseList.add(c);
                }
            }
        }

        if ( (Trigger.isInsert && Trigger.isAfter) || Trigger.isUpdate ) {
            this.newCaseMap = new Map<Id, Case>(newCaseList);
            
        }
        
        if ( Trigger.isUpdate || Trigger.isDelete ) { 
            this.oldCaseList = new List<Case>();

            for(Case c : (List<Case>)Trigger.old) {
                this.oldCaseList.add(c);
            }

            this.oldCaseMap = new Map<Id, Case>(oldCaseList);
            
        }
    }
}