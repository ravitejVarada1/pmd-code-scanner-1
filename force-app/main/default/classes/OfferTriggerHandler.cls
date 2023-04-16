public class OfferTriggerHandler extends TriggerHandler {
    
    private List<Offer__c> newOffList;
    private Map<ID,Offer__c> newOffMap;
    private List<Offer__c> oldOffList;
    private Map<ID,Offer__c> oldOffMap;
    
    public OfferTriggerHandler(){
        this.newOffList = (List<Offer__c>) Trigger.new;
        this.newOffMap  = (Map<Id,Offer__c>) Trigger.newMap;
        this.oldOffList = (List<Offer__c>) Trigger.old;
        this.oldOffMap  = (Map<Id,Offer__c>) Trigger.oldMap;
    }
    
     public override void beforeInsert(){
       OfferTriggerFunctions.populateOfferActiveFlagOnInsert(newOffList);//CA-60,CA-61
       OfferTriggerFunctions.OnInsertOfferSalesStatus(newOffList);//CA-353
    }
    
    public override void beforeUpdate() {
        OfferTriggerFunctions.populateOfferActiveFlagOnUpdate(newOffMap, oldOffMap);//CA-60,CA-61
        OfferTriggerFunctions.populateOfferSalesStatus(newOffMap, oldOffMap); //CA-59
        FieldChangeTrackHandler.TrackTransactions(oldOffMap,newOffList); //SA-27
    }
}