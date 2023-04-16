public class EmailMessageTriggerHandler extends TriggerHandler {
    
    private List<EmailMessage> newEmailMessageList;
    private Map<ID,EmailMessage> newEmailMessageMap;
    private List<EmailMessage> oldEmailMessageList;
    private Map<ID,EmailMessage> oldEmailMessageMap;
    
    public EmailMessageTriggerHandler(){
        this.newEmailMessageList = (List<EmailMessage>) Trigger.new;
        this.newEmailMessageMap  = (Map<Id,EmailMessage>) Trigger.newMap;
        this.oldEmailMessageList = (List<EmailMessage>) Trigger.old;
        this.oldEmailMessageMap  = (Map<Id,EmailMessage>) Trigger.oldMap;
    }
    
    public override void afterUpdate(){
        EmailMessageTriggerFunctions.updateCaseStatus(newEmailMessageList);
    }
    
    public override void afterInsert(){
         EmailMessageTriggerFunctions.updateCaseStatus(newEmailMessageList);
       
    }
   
}