/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* https://cargurus.atlassian.net/browse/SF-1899
* https://cargurus.atlassian.net/browse/CRM-2227
* Added to allow Sales Admin to edit Opportunity Split in Sales Pending
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Accenture
* @modifiedBy     Justin Chang
* @created        4/5/2019
* @modified       6/21/2021
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public with sharing class OpportunitySplitHandler {
    
    public static boolean skipControls = false;
    public static void setSkipControls(boolean setTo) {
        skipControls = setTo;
    }

    public static void handleTrigger(List<OpportunitySplit> oppSplits){
        if (!skipControls) {
            Map<Id, Opportunity> relatedOpportunities = getRelatedOpportunities(oppSplits);
            checkIsUpdatePermitted((List<OpportunitySplit>)Trigger.new, relatedOpportunities);
        }
    }
    
    public static void checkIsUpdatePermitted(List<OpportunitySplit> newSplits, Map<Id, Opportunity> relatedOpportunities) {
        
        Map<String,OpportunitySplit_Controls__mdt> allControls = OpportunitySplit_Controls__mdt.getAll();
        OpportunitySplit_Controls__mdt oppSplitControls = allControls.get('OpportunitySplit');

        if (isUserPermitted(oppSplitControls)){
            
            for(OpportunitySplit os : newSplits) {
                 
                //CRM-3358 Update code to allow Sales Admins to edit splits on Standard Opps that are not in Closed and Won status
                Opportunity relatedOpp = relatedOpportunities.get(os.OpportunityId);
                
                if(relatedOpp.isWon) {
                    if (oppSplitControls.Restricted_Ids_When_Won__c != null && oppSplitControls.Restricted_Ids_When_Won__c.contains(UserInfo.getProfileId())) {
                        os.addError(System.Label.Restrict_To_Edit_Opportunity_Splits);
                    } else { //should only hit this on initial insertion to new org
                        Set<Id> restrictedIds = new Map<Id,Profile>([SELECT Id FROM Profile WHERE Name = 'Sales Admin']).keySet();
                        if (restrictedIds.contains(UserInfo.getProfileId())) {
                            os.addError(System.Label.Restrict_To_Edit_Opportunity_Splits);
                        }
                    }
                    
                }
            }               
        } 
        else {
            for(OpportunitySplit os : newSplits) 
                os.addError(System.Label.OpportunitySplit_Direct_Edit_Error);
        }
    } 
    
    /*
    * Need to examine the stage name of the Opportunity. Only SalesOps and SysAdmins can 
    * edit OpportunitySplits related to closed won opportunities
    */
    public static Map<Id, Opportunity> getRelatedOpportunities(List<OpportunitySplit> splits) {
        Set<Id> opportunityIds = new Set<Id>();
        //opportunityIds.addall(splits);
        for(OpportunitySplit os : splits) {
            opportunityIds.add(os.OpportunityId);
        }
        //SF-1899 Accenture Added Record Type field in query 
        return new Map<Id, Opportunity>([SELECT Id, StageName,RecordType.Id, isWon FROM Opportunity WHERE Id IN :opportunityIds]);
    }
    /**
    * Examines running user's profile to check is permitted to edit Opportunity
    * Splits directly. 
    */
    public static boolean isUserPermitted(OpportunitySplit_Controls__mdt oppSplitControls) {
        Set<String> profiles = new Set<String>(oppSplitControls.Profile_Ids__c.split(','));
        return profiles.contains(UserInfo.getProfileId());
    }
}