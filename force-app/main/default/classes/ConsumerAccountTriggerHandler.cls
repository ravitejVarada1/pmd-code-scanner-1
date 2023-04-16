/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         prabhu
* modifiedBy:     prabhu
* created:        05/27/2027
* modified:       05/27/2027
* created jira:   CA-611
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class ConsumerAccountTriggerHandler extends TriggerHandler{
    
    private List<Account> newPAList; //new updated person accounts
    private Map<Id,Account> newPAMap; //new updated person accounts map
    private List<Account> oldPAList; //old version person accounts
    private Map<Id,Account> oldPAMap; //old version person accounts map
    
    public ConsumerAccountTriggerHandler(){
        setContextVariables();
    }
    
    public override void beforeUpdate(){
        ConsumerAccountTriggerFunctions.checkPhoneField(newPAList, oldPAMap);//SA-944
        
    }
    public override void beforeInsert(){
        ConsumerAccountTriggerFunctions.checkPhoneField(newPAList, null);//SA-944
    }
    
    public override void afterUpdate(){ 
        //added under CA-611      
        ConsumerAccountTriggerFunctions.updatePhoneNumberOnRelatedOffer(newPAMap,oldPAMap);
    }
    
    public override void afterInsert(){
        
    }

    public override void afterDelete() {
        //Added under SA-618
        //Using the Trigger.old which will trap dealer accounts too
        ConsumerAccountTriggerFunctions.preventAccountDelete(Trigger.old); 
    }
    
    public void setContextVariables() {
        
        if (Trigger.isInsert || Trigger.isUpdate) {
            this.newPAList = new List<Account>();
            
            for(Account a : (List<Account>)Trigger.new) {
                if(a.IsPersonAccount) { 
                    this.newPAList.add(a);
                } 
            }
        }
        
        if ( (Trigger.isInsert && Trigger.isAfter) || Trigger.isUpdate ) {
            this.newPAMap = new Map<Id, Account>(newPAList);   
        }
        
        
        if ( Trigger.isUpdate || Trigger.isDelete ) { 
            this.oldPAList = new List<Account>();
            
            for(Account a : (List<Account>)Trigger.old) {
                if(a.IsPersonAccount) {
                    this.oldPAList.add(a);
                }
            }
            
            this.oldPAMap = new Map<Id, Account>(oldPAList);          
            
        }
        
        if(Trigger.isUnDelete){
            this.newPAList = new List<Account>();
            
            for(Account a : (List<Account>)Trigger.new) {
                if(a.IsPersonAccount) { 
                    this.newPAList.add(a);
                }
            }
            
        }
    }
    
}