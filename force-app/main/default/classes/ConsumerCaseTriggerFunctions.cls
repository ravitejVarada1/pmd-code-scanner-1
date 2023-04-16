public class ConsumerCaseTriggerFunctions extends TriggerHandler {
    
    //added under BR-8364
    public static void checkCaseAssignmentExecution(List<Case> newCaseList,Map<Id,Case> oldCaseMap){

        List<Case> runCaseAssignmentList = new List<Case>();
        Id consumerSupportRTId = CaseTriggerFunctions.caseRTNameIdMap.get('Consumer Support');

        for(Case cs : newCaseList){
            
            //Force_Run_Assignment_Rules__c flag added via CaseQueueTransferLWC assures this assignment runs once,
            //if a Consumer Support Queue is selected
            if(cs.RecordTypeId!=null && cs.RecordTypeId == consumerSupportRTId 
            && oldCaseMap!=null && oldCaseMap.containskey(cs.Id)
            && oldCaseMap.get(cs.Id).RecordTypeId!=cs.RecordTypeId
            && cs.Force_Run_Assignment_Rules__c){
                
                runCaseAssignmentList.add(cs);
            }
        }

        if(!runCaseAssignmentList.isEmpty()){
            caseAssignment(runCaseAssignmentList, true); // CA-655 Passing true to avoid profile filtering for after udpate
        }
    }

     public static void caseAssignment(List<Case> newCaseList, Boolean isConvertedCase){
        Map<String,String> caseTeamMetaMap = new Map<String,String>();
        Map<String,String> queueMap = new Map<string,string>();
        List<Case> cList = new List<Case>();
        Set<String> assignmentProfiles = new Set<String>();
        List<Id> consumerSupportUserIdList = new List<Id>();
        List<Case> runAssignmentCaseList = new List<Case>();
        Map<String, CaseQueueTeam__mdt > mapCQT = CaseQueueTeam__mdt.getAll();

        Id consumerSupportRTId = CaseTriggerFunctions.caseRTNameIdMap.get('Consumer Support');

        // Check profile & filter case list only for after insert.
        if (isConvertedCase == false ) {
            // Get profile name(s) from Custom Metadata text area field Profiles__c
            for(CaseQueueTeam__mdt CQT : mapCQT.values()){
                caseTeamMetaMap.put(CQT.Queue__c,CQT.CaseTeam__c);
                for(String profile: CQT.Profiles__c.split(',')) {
                    assignmentProfiles.add(profile.trim());
                }
            }
            // Get cases where the profile of the createdby user matches the profiles from custom metadata
            for (User u: [SELECT id, profile.name FROM User WHERE profile.name IN: assignmentProfiles]) {
                consumerSupportUserIdList.add(u.id);
            }
            for (Case c: newCaseList) { 
                if (consumerSupportUserIdList.contains(c.CreatedById) && c.RecordTypeId == consumerSupportRTId) {
                    runAssignmentCaseList.add(c);
                }
            }
            // Replace existing case list with new case list.
            newCaseList = runAssignmentCaseList;
        } else {
            //Getting Queue Names from Custom Metadata
            for(CaseQueueTeam__mdt CQT : mapCQT.values()){
                caseTeamMetaMap.put(CQT.Queue__c,CQT.CaseTeam__c);
            }
        }

        //With Queue name Map KeySet getting Queue ID
        for (Group G : [select Id,name from Group where name in : caseTeamMetaMap.keyset() ])
        {
            queueMap.put(G.name, G.id);
        }
        
        for (case c : newCaseList){
            //When the case insterting from car offer service email exclude the run assignment
            if(c.OwnerId != null && !c.OfferSupport_Email__c) 
            {
                Case CE = new Case();
                CE.id = c.id;
                if(c.Origin == 'Phone' && isConvertedCase == false) //CSS-91
                {
                    //If Case Origin Phone, then assign to Consumer Support Phone Queue - After insert
                    CE.OwnerId = queueMap.get(mapCQT.get('Consumer_Support_Phone').Queue__c);
                    cList.add(CE);
                
                }
                else if(c.Origin == 'Email')//css-91
                {
                    CE.OwnerId = queueMap.get(mapCQT.get('Consumer_Support_Email').Queue__c);
                    cList.add(CE);
                    
                      
                 }           
                //if any of the above condition is not met, then it will be assigned default tier 1 queue
                else{
                    CE.OwnerId = queueMap.get(mapCQT.get('Consumer_Support_Tier_1').Queue__c);
                    cList.add(CE);
                 }
                
            }
            if(cList.size()>0){
                
                Database.DMLOptions dml = new Database.DMLOptions();
                dml.assignmentRuleHeader.useDefaultRule = false;
                Database.update(cList, dml);
                
            }
           
        }
    }
   

    public static void populateContactOnCase(Map<Id,Case> newCSCaseMap, Map<Id,Case> oldCSCaseMap){
        Set<Id> accountId = new Set<Id>();
        Set<Id> caseId = new Set<Id>();
        Map<String,String> accountContactMap = new Map<String,String>();
        
        for (Case c : newCSCaseMap.values()) {
            if(oldCSCaseMap!=null && oldCSCaseMap.containsKey(c.id) && c.accountId != oldCSCaseMap.get(c.id).accountId){
                if (c.accountId != null)
                {
                    accountId.add(c.accountId);
                    caseId.add(c.id);
                }
                else if(c.accountId == null)
                    c.ContactId=null;
            }
            
        }
        
        if(accountId.size()>0){
            
            for(Contact Con :[select id,accountid from contact
                              where accountid in :accountId order by CreatedDate asc]){
                    if(!accountContactMap.containsKey(Con.accountid))
                        accountContactMap.put(Con.accountid,Con.id);
                                  
                }
            
            for (Case c : newCSCaseMap.values()) {
                if (caseId.contains(c.id))
                    c.ContactId = accountContactMap.get(c.accountId);
                
            }
            
        }
        
    }

    /**
    * https://cargurus.atlassian.net/browse/SA-18
    * automation to create a case for DI team when a Consumer Support rep changes the Consumer Support 
    * case's Status = "Closed" with Case Resolution = "Reported to Integrity
    */
    public static void createDataIntegrityCase(List<Case> newCases, Map<Id,Case> oldCaseMap) {
  
        Id integrityQueueId = Utilities.getCasequeueMap().get('Integrity Case Queue');
        Id consumerSupportRT = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Consumer Support').getRecordTypeId();
        Id integrityRT = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Integrity').getRecordTypeId();
        
        List<Case> newCaseList = new List<Case>();
        for (Case c : newCases) {
            if (oldCaseMap!=null && oldCaseMap.containsKey(c.id) && c.RecordTypeId == consumerSupportRT && 
                oldCaseMap.get(c.Id).Status != c.Status && c.Status == 'Closed' && 
                c.Case_Resolution__c == 'Reported to Integrity' &&
                c.Related_Dealer_Account__c != null) {
                  
                Case dataIntegrityCase = new Case();
                dataIntegrityCase.AccountId = c.Related_Dealer_Account__c;
                dataIntegrityCase.OwnerId = integrityQueueId;
                dataIntegrityCase.ContactId = c.ContactId;
                dataIntegrityCase.Subject = 'Integrity issue:' + c.Subject;
                dataIntegrityCase.RecordTypeId = integrityRT;
                dataIntegrityCase.Origin = 'Internal';
                dataIntegrityCase.Priority = 'Medium';
                dataIntegrityCase.ParentId = c.Id;
                dataIntegrityCase.Description = 'Please refer to the parent case ticket for details';
                newCaseList.add(dataIntegrityCase);
                }
            }
    
        if(!newCaseList.isEmpty()){
            insert newCaseList;
            CaseTaskCreationProcessor.createIntegrityCaseTask(newCaseList);
        }
    }
}