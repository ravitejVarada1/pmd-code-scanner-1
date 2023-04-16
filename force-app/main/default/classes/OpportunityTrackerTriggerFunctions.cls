/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        05/10/2021
* modified:       05/10/2021
* created jira:   BR-878
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class OpportunityTrackerTriggerFunctions {
    //- Jira: BR-878
    //- Purpose: Checks for newly completed Opportunity_Tracker__c records
    public static void checkNewlyCompletedTracker(List<Opportunity_Tracker__c> newOptList, Map<ID,Opportunity_Tracker__c> oldOptMap){
        Set<ID> trackerIdsToActivateOpps = new Set<ID>();

        for (Opportunity_Tracker__c opt : newOptList){
            Opportunity_Tracker__c oldOpt = oldOptMap.get(opt.Id);

            if (opt.Complete__c && !oldOpt.Complete__c){       
                trackerIdsToActivateOpps.add(opt.Id);
            }
        }
        
        if (trackerIdsToActivateOpps.isEmpty()){
            return;
        }
        
        activateOppsFromTrackerIds(trackerIdsToActivateOpps);
    }
    
    public static void checkNewlyCompletedTrackersBefore(List<Opportunity_Tracker__c> newOptList, Map<ID,Opportunity_Tracker__c> oldOptMap){
        
        for (Opportunity_Tracker__c opt : newOptList){
            Opportunity_Tracker__c oldOpt = oldOptMap.get(opt.Id);
            
            if (opt.Complete__c && !oldOpt.Complete__c){       
                opt.QuoteOrderingErrors__c = null;
            }
        } 
    }
    
     //- Jira: BR-878
    //- Queries for quotes with a set of Opportunity_Tracker__c Ids, then creates an order from the quotes
    public static void activateOppsFromTrackerIds(Set<ID> trackerIds){
        Savepoint sp = Database.setSavepoint();
        
        ID trackerId = new List<ID>(trackerIds)[0];
        
        try{
            Date tdy = Date.today();
            
           Map<ID,Opportunity> oppsToClose = new Map<ID,Opportunity>();
            
            List<SBQQ__Quote__c> quotesToActivate = [SELECT Id, SBQQ__StartDate__c, SBQQ__Opportunity2__c
                                                     FROM SBQQ__Quote__c
                                                     WHERE SBQQ__Ordered__c = false
                                                     AND Id IN (SELECT SBQQ__PrimaryQuote__c
                                                                FROM Opportunity
                                                                WHERE Opportunity_Tracker__c IN :trackerIds)];

            //BR-7299 - made changes below to consider an aysnc process
            //for ordering quote where fulfillment accounts exceed 10. 
            //Also changed the pat handler to set variable largeQuote = true.
            Map<Id, SBQQ__Quote__c> quoteMap = new Map<Id, SBQQ__Quote__c>(quotesToActivate);
            Map<Id, Set<Id>> quoteFulfillmentAccs = new Map<Id, Set<Id>>();
            for(SBQQ__QuoteLine__c ql : [SELECT Id, SBQQ__Quote__c, Fulfillment_Account__c 
                FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN :quoteMap.keySet()]) 
            {
                Id qtId = ql.SBQQ__Quote__c;
                Id fullAccId = ql.Fulfillment_Account__c;

                if(quoteFulfillmentAccs.containsKey(qtId)) {
                    quoteFulfillmentAccs.get(qtId).add(fullAccId);
                } else {
                    quoteFulfillmentAccs.put(qtId, new Set<Id>{qtId});
                }
            }
            Set<Id> quoteIdsToAsyncOrder = new Set<Id>();
            List<SBQQ__Quote__c> quotesToActivate2 = new List<SBQQ__Quote__c>();
            Boolean doAsyncOrder = false;
            
            for (SBQQ__Quote__c q : quotesToActivate){
                Set<Id> fulAccIds = quoteFulfillmentAccs.get(q.Id); 
                if(fulAccIds.size() > 10) { 
                    quoteIdsToAsyncOrder.add(q.Id); 
                    continue;
                }
                
                q.SBQQ__Ordered__c = true;
                quotesToActivate2.add(q);
                    
                oppsToClose.put(q.SBQQ__Opportunity2__c, null);
            }

            // if > 10 fulfillment accounts, process asynchronously
            if(!quoteIdsToAsyncOrder.isEmpty()) {
                System.enqueueJob(new QueueableQuoteOrders(new List<Id>(quoteIdsToAsyncOrder)));
            }

            //if fulfillment accounts in quote < 10 then process synchronously
            if(!quotesToActivate2.isEmpty()) {
                update quotesToActivate2; 
            
                Id RECORDTYPEIDSTANDARD = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Standard_Opportunity');
                Id RECORDTYPEIDRETENTION = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Retention');
                Id RECORDTYPEIDRENEWAL = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Renewal');
                
                oppsToClose = new Map<ID,Opportunity>([SELECT Id, CloseDate, recordTypeID
                                                        FROM Opportunity
                                                        WHERE Id IN :oppsToClose.keySet()]);
                
                for (Opportunity opp : oppstoClose.values()) {
                    
                    opp.CloseDate = tdy; //DSS-705 Stamp Today Date when closing won

                    if(opp.recordTypeID == RECORDTYPEIDSTANDARD || opp.recordTypeID == RECORDTYPEIDRENEWAL) {
                        opp.StageName = ConstantsUtil.OPP_STATUS_CLOSED_WON;
                    }
                    
                    if(opp.recordTypeID == RECORDTYPEIDRETENTION ){
                        opp.StageName = ConstantsUtil.OPP_STATUS_CLOSED_SAVED;
                    }
                }
                
                update oppsToClose.values();
            }
        }catch (exception e){
            Database.rollback(sp);
            
            Opportunity_Tracker__c oppTrackerToUpdate = new Opportunity_Tracker__c(
            	Id = trackerId,
                QuoteOrderingErrors__c = e.getMessage() + '<orderBrokenSpacer>' +  e.getStackTraceString()
            );
            
            update oppTrackerToUpdate;
        }
    }
}