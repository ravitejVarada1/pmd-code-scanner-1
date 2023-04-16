public class ConsumerCaseTriggerHandler extends TriggerHandler{
    
    private List<Case> newCSCaseList; //new updated Customer Support Case
    private Map<ID,Case> newCSCaseMap; //new updated Customer Support Case Map
    private List<Case> oldCSCaseList; //old version Customer Support Case
    private Map<ID,Case> oldCSCaseMap; //old version Customer Support Case Map
    
    public ConsumerCaseTriggerHandler(){
        setContextVariables();
    }
    
    public override void beforeUpdate(){
        // CaseTriggerFunctions.caseAssignmentOnUpdate(newCSCaseMap, oldCSCaseMap); //CA-61
        ConsumerCaseTriggerFunctions.populateContactOnCase(newCSCaseMap, oldCSCaseMap); //CA-472
    }
    public override void beforeInsert(){
        
    }
    
    public override void afterUpdate(){ 
        //added under BR-8364      
        ConsumerCaseTriggerFunctions.checkCaseAssignmentExecution(newCSCaseList,(Map<Id,Case>)Trigger.oldMap);
        ConsumerCaseTriggerFunctions.createDataIntegrityCase(newCSCaseList, oldCSCaseMap);//SA-18
    }
    
    public override void afterInsert(){
        ConsumerCaseTriggerFunctions.caseAssignment(newCSCaseList, false);//CA-60, CA-61 // CA-655 - Passing false to filter profile
    }
    
    public void setContextVariables() {
        Id consumerSupportRTId = CaseTriggerFunctions.caseRTNameIdMap.get('Consumer Support');
        
        if (Trigger.isInsert || Trigger.isUpdate) {
            this.newCSCaseList = new List<Case>();
            
            for(Case c : (List<Case>)Trigger.new) {
                if(c.recordtypeid == consumerSupportRTId ) { 
                    this.newCSCaseList.add(c);
                } 
            }
        }
        
        if ( (Trigger.isInsert && Trigger.isAfter) || Trigger.isUpdate ) {
            this.newCSCaseMap = new Map<Id, Case>(newCSCaseList);
            
        }
        
        if ( Trigger.isUpdate || Trigger.isDelete ) { 
            this.oldCSCaseList = new List<Case>();
            
            for(Case c : (List<Case>)Trigger.old) {
                this.oldCSCaseList.add(c);
            }
            
            this.oldCSCaseMap = new Map<Id, Case>(oldCSCaseList);
            
        }
    }
    
}