public without sharing class EventTriggerHandler extends TriggerHandler{
    private List<Event> newEventList;
    private Map<ID,Event> newEventMap;
    private List<Event> oldEventList;
    private Map<ID,Event> oldEventMap;
    
    public EventTriggerHandler(){
        this.newEventList = (List<Event>) Trigger.new;
        this.newEventMap  = (Map<Id,Event>) Trigger.newMap;
        this.oldEventList = (List<Event>) Trigger.old;
        this.oldEventMap  = (Map<Id,Event>) Trigger.oldMap;
    }
    
    public override void beforeInsert(){
    }

    public override void afterInsert() {
        ActivityTriggerFunctions.updateLastActivityOnAccount(newEventMap, null);
    }
}
