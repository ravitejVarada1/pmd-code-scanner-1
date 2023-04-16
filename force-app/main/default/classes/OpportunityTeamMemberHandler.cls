public without sharing class OpportunityTeamMemberHandler {
    
    public static void restrictProfiles(List<OpportunityTeamMember> newList,List<OpportunityTeamMember> oldList,Boolean isDelete)
    {
        List<OpportunityTeamMember> OppTeamList = new List<OpportunityTeamMember>();
        Set<id> OppIdSet= new Set<id>();
        Map<ID,Opportunity> oppIdMap = new Map<ID,Opportunity>();    
        Id userProfileId = UserInfo.getProfileId();
        Map<String,OpportunitySplit_Controls__mdt> oppControls = OpportunitySplit_Controls__mdt.getAll();
        OpportunitySplit_Controls__mdt oppTeamControl = oppControls.get('OpportunityTeam');
        List<String> profileExceptions = oppTeamControl.Profile_Ids__c.split(',');

        if(isDelete) {
            OppTeamList.addAll(oldList);
        } else {
            OppTeamList.addAll(newList);
        }

        for(OpportunityTeamMember oppTeam: OppTeamList) {
            OppIdSet.add(oppTeam.OpportunityId);
        }
        system.debug('oppidset '+OppIdSet);
        
        for(Opportunity opp:[SELECT id,RecordType.Id,isClosed 
                             FROM Opportunity 
                             WHERE Id in:oppIdSet AND 
                             IsClosed = true]) {   
            oppIdMap.put(opp.id,opp);
        }

        for(OpportunityTeamMember oppTeamMember: OppTeamList) {
            if(!(profileExceptions.contains(userProfileId)) 
               && oppIdMap.keySet().contains(oppTeamMember.OpportunityId)){
                oppTeamMember.addError(System.Label.Restrict_Operations_On_Opportunity_Team_Member);
            }
        }
    }
}