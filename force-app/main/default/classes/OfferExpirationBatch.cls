global class OfferExpirationBatch implements Database.Batchable<sObject>, Schedulable{
    
    //Getting Offer Record where Offer Expiration Date < Today
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([select id,NewStage__c,Email__c,Phone__c,Person_Account__c, Active_Offer__c  from Offer__c where Offer_Expiration_Date__c < Today ]);
        
    }
    
        global void execute(Database.BatchableContext bc, List<Offer__c> offerList){
            List<Offer__c> OFList = new List<Offer__c>();
            //Update Active Offer Flag as False
            for(Offer__c O : offerList){
                O.Active_Offer__c=false;
                OFList.add(O);
                
            }
            
            if(OFList.size()>0)
                update OFList;
       
    }
    
        global void finish(Database.BatchableContext bc){
        
    }
    
      public void execute(SchedulableContext ctx) {
          //Execute the "OfferExpirationBatch" Batch Class
      Database.executeBatch(new OfferExpirationBatch(), 200);
  }
}