public class ContactTriggerHandler extends TriggerHandler {
    private List<Contact> newContactList;
    private Map<ID,Contact> newContactMap;
    private List<Contact> oldContactList;
    private Map<ID,Contact> oldContactMap;
    
    private List<Contact> newPAContactList;
    private Map<ID,Contact> newPAContactMap;
    private List<Contact> oldPAContactList;
    private Map<ID,Contact> oldPAContactMap;
    
    public ContactTriggerHandler(){
 		setContextVariables();
    }
    public override void beforeUpdate(){
        ContactTriggerFunctions.setCurrencyCode(oldContactMap,newContactList);
        
    }
    
    public override void beforeInsert(){
        ContactTriggerFunctions.setCurrencyCode(null,newContactList);//BR-1842
    }
    
    public override void afterInsert(){
        ContactTriggerFunctions.updateAccountsForConductViolation(oldContactMap,newContactMap);
    }
    
    public override void afterUpdate(){
        ContactTriggerFunctions.updateAccountsForConductViolation(newContactMap,oldContactMap);
    }

    public override void beforeDelete(){
        //Added under SA-618
        ContactTriggerFunctions.preventContactDelete(oldContactList); 
    }
    
    public void setContextVariables() {
        
        if (Trigger.isInsert || Trigger.isUpdate) {
            this.newContactList = new List<Contact>();
            this.newPAContactList = new List<Contact>();
            
            for(Contact c : (List<Contact>)Trigger.new) {
                if(!c.IsPersonAccount) { 
                    this.newContactList.add(c);
                } else {
                    this.newPAContactList.add(c);
                }
            }
        }
        
        if ( (Trigger.isInsert && Trigger.isAfter) || Trigger.isUpdate ) {
            this.newContactMap = new Map<Id, Contact>(newContactList);
            this.newPAContactMap = new Map<Id, Contact>(newPAContactList);
            
        }
        
        if ( Trigger.isUpdate || Trigger.isDelete ) { 
            this.oldContactList = new List<Contact>();
            this.oldPAContactList = new List<Contact>();
            
            for(Contact c : (List<Contact>)Trigger.old) {
                if(!c.IsPersonAccount) {
                    this.oldContactList.add(c);
                } else {
                    this.oldPAContactList.add(c);
                }
            }
            
            this.oldContactMap = new Map<Id, Contact>(oldContactList);
            this.oldPAContactMap = new Map<Id, Contact>(oldPAContactList);
            
            
        }
        
        if(Trigger.isUnDelete){
            this.newContactList = new List<Contact>();
            this.newPAContactList = new List<Contact>();
            
            for(Contact c : (List<Contact>)Trigger.new) {
                if(!c.IsPersonAccount) { 
                    this.newContactList.add(c);
                } else {
                    this.newPAContactList.add(c);
                }
            }
            
        }
        
    }
    
}