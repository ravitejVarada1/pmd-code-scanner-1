public class OfferTriggerFunctions {
    
    public static void populateOfferActiveFlagOnInsert(List<Offer__c> newOffList){
        for(Offer__c o :newOffList){
            //If Offer Expiration Date > Today Set Active Offer Flag True
            if(o.Offer_Expiration_Date__c != null && o.Offer_Expiration_Date__c >= System.today()){
                o.Active_Offer__c =true;
            }
        }
    }
    
    public static void populateOfferActiveFlagOnUpdate(Map<id,Offer__c> newOffMap, Map<id,Offer__c> oldOffMap){
        for(Offer__c o :newOffMap.values()){
            
            if(O.Offer_Expiration_Date__c != oldOffMap.get(o.Id).Offer_Expiration_Date__c)
            {
                //If Offer Expiration Date >= Today then Set Active Offer Flag True
                if(o.Offer_Expiration_Date__c != null && o.Offer_Expiration_Date__c >= System.today()){
                    
                    o.Active_Offer__c =true;
                }
                //If Offer Expiration Date < Today then Set Active Offer Flag False
                else if(o.Offer_Expiration_Date__c != null && o.Offer_Expiration_Date__c < System.today())
                {
                    o.Active_Offer__c =false;  
                }
                //If Offer Expiration Date Blank then Set Active Offer Flag False
                else
                    o.Active_Offer__c =false;
            }
        }
    }
    
    public static void populateOfferSalesStatus(Map<id,Offer__c> newOffMap, Map<id,Offer__c> oldOffMap){
        List<String> excludedStageList = new List<String>{'ACCEPTED', 'TERMINATED', 'EXPIRED'}; 
        for(Offer__c off :newOffMap.values()){
            if(off.NewStage__c != oldOffMap.get(off.Id).NewStage__c){
                //offer status = "DOCS_SUBMITTED" 
                if(!excludedStageList.contains(off.NewStage__c) && !String.isBlank(off.NewStage__c)){ // SA-203: Added the OR condition
                    //Primary Sales Rep assigned and previous Assignment Status is ‘InProgress’ within 7 days from offer created
                    if(off.Primary_Sales_Rep__c != null && oldOffMap.get(off.Id).Assignment_Status__c == 'In Progress'
                        && off.CreatedDate.Date().daysBetween(Date.today()) <= 7){
                        off.Assignment_Status__c='Closed - Agent-Converted';
                    }
                    
                    else{
                        off.Assignment_Status__c='Closed - Auto-Converted';   
                    }
                    
                }
                	//offer status = "EXPIRED"
                else if(off.NewStage__c=='EXPIRED'){
                    off.Assignment_Status__c='Closed Lost';
                }
            }
            if(off.Secondary_Sales_Rep__c != oldOffMap.get(off.Id).Secondary_Sales_Rep__c )
            {
                if(off.Secondary_Sales_Rep__c==null)
                {
                off.Date_Secondary_Rep_Claimed__c = null;
                }
                else{
                    off.Date_Secondary_Rep_Claimed__c = DateTime.now();
                }
            }   
        }
    }

    public static void OnInsertOfferSalesStatus(List<Offer__c> newOffList){
        
        
        for(Offer__c off :newOffList){
                //offer status = "DOCS_SUBMITTED"
                if(off.NewStage__c=='DOCS_SUBMITTED'){
                    off.Assignment_Status__c='Closed - Auto-Converted';    
                }
                    //offer status = "EXPIRED"
                else if(off.NewStage__c=='EXPIRED'){
                    off.Assignment_Status__c='Closed Lost';
                }
            }
    }
}