public class TaskTriggerFunctions {
    @testVisible
    private static Boolean skipDialpadMatch = false;
    
    
    public static void populateDialpadCallerPhone(List<Task> newTasks){
        Map<String,Task> callIdToTaskMap = new Map<String,Task>();
        
        for (Task t : newTasks){
            if (t.Dialpad__IsDialpadCallLog__c){
                callIdToTaskMap.put(t.Dialpad__CallId__c, t);
            }
        }
        
        if (callIdToTaskMap.isEmpty()){
            return;
        }
        
        for (Dialpad_Call_Event_Log__c log : [SELECT Id, External_Number__c, Call_Id__c
                                              FROM Dialpad_Call_Event_Log__c
                                              WHERE Call_Id__c in :callIdToTaskMap.keySet()
                                              AND External_Number__c	!= null])
        {
            callIdToTaskMap.get(log.Call_Id__c).Dialpad_Caller_Phone__c	= log.External_Number__c;
        }
    }
    
    
    public static void populateRelatedDialpadRecord(Set<ID> taskIds){
        
        //Skip the trigger function in certain test methods in order to test DialpadTaskRelationBatch
        if (skipDialpadMatch && Test.isRunningTest()){
            return;
        }
        
        List<Task> newTasks = [SELECT Dialpad__IsDialpadCallLog__c, WhatId, 
                                        WhoId, Dialpad__CallId__c, Dialpad_Matched__c, Account.PersonContactId, 
                                        Account.IsPersonAccount, OwnerId, AccountId, 
                                        Dialpad__PhoneNumber__c, Dialpad_Caller_Phone__c
                               FROM Task
                               WHERE Dialpad__IsDialpadCallLog__c = true AND CallType = 'Inbound'
                               AND (Dialpad_Matched__c = false 
                                OR ((WhatId= NULL OR (NOT(What.Type = 'Case'))) 
                                AND (Account.IsPersonAccount = true AND AccountId != NULL))) // SA-28: Added the OR condition to process Consumer Support dialpad tasks. 
                               AND (NOT(Subject LIKE '%Voicemail%')) 
                               AND Id IN :taskIds];
        
        if (newTasks.isEmpty()){
            return;
        }
        
        Set<ID> accountIds = new Set<ID>();
        Set<String> phoneNums = new Set<String>();
        Map<String,Task> processTaskMap = new Map<String,Task>();
        Set<ID> userOwnedLeads = new Set<ID>();
        Set<ID> userOwnedCases = new Set<ID>();

        Id ConsumerSupportCaseRecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Consumer_Support');
        
        //Loop through tasks to populate the three collections above
        for (Task t : newTasks) {

            String whatId = t.whatId;
            String whoId = t.WhoId;
            
            Boolean whoIdIsLead = whoId != null && whoId.startsWith('00Q');
            Boolean whatIdIsCase = whatId != null && whatId.startsWith('500');
            
            if (whoIdIsLead){
                userOwnedLeads.add(whoId);
            }
            
            if (whatIdIsCase){
                userOwnedCases.add(whatId);
            }
            
            processTaskMap.put(t.Dialpad__CallId__c, t);
            
            accountIds.add(t.AccountId);
            phoneNums.add(t.Dialpad_Caller_Phone__c);
        }
        
        accountIds.remove(null);
        phoneNums.remove(null);
        
        userOwnedLeads = new Map<ID,Lead>([SELECT Owner.Type
                                           FROM Lead
                                           WHERE Id IN :userOwnedLeads
                                           AND Owner.Type = 'User']).keySet();
        
        //initial case query
        userOwnedCases = new Map<ID,Case>([SELECT Owner.Type
                                           FROM Case
                                           WHERE Id IN :userOwnedCases
                                           AND Owner.Type = 'User'
                                          ]).keySet();
        
        
        //Create a map of dialpad Call Id to Master Call Id
        Map<String,String> callIdToMasterIdMap = new Map<String,String>();
        for (Dialpad_Call_Event_Log__c cl :  [SELECT Id, Call_Id__c, Master_Call_Id__c
                                              FROM Dialpad_Call_Event_Log__c
                                              WHERE Call_Id__c IN :processTaskMap.keySet()])
        {
            callIdToMasterIdMap.put(cl.Call_Id__c, cl.Master_Call_Id__c);
        }
        
        //Find all cases with a related Master Call Id

        //Dealer related maps
        Map<String,ID> masterCallIdCaseMap = new Map<String,ID>();
        Map<ID,ID> accountIdCaseMap = new Map<ID,ID>();
        Map<Id,Case> case2QueryMap = new Map<Id,Case>();

        //Consumer related maps
        Map<String,ID> masterCallIdCSCaseMap = new Map<String,ID>();
        Map<ID,ID> accountIdCSCaseMap = new Map<ID,ID>(); //Added under SA-669

        //2nd Case query
        for (Case c : [SELECT Id, Master_Call_Id__c, AccountId, OwnerId, Owner.Type
                        FROM Case
                        WHERE Master_Call_Id__c != null
                        AND (Master_Call_Id__c IN :callIdToMasterIdMap.values() 
                            OR (AccountId IN :accountIds AND isClosed = false))
                      ])
        {
            masterCallIdCaseMap.put(c.Master_Call_Id__c, c.Id);
            accountIdCaseMap.put(c.AccountId, c.Id);
            case2QueryMap.put(c.Id,c);
        }
        
        for (Case c : [SELECT Id, Master_Call_Id__c, AccountId
                        FROM Case
                        WHERE Master_Call_Id__c != null
                        AND (Master_Call_Id__c IN :callIdToMasterIdMap.values()
                            OR (AccountId IN :accountIds AND isClosed = false)
                        )
                        AND RecordTypeID = : ConsumerSupportCaseRecordTypeId
                        ORDER BY createdDate]) // Added under SA-669 to include the most recent case id as value in the map
        {
           masterCallIdCSCaseMap.put(c.Master_Call_Id__c, c.Id);
           accountIdCSCaseMap.put(c.AccountId, c.Id); //Added under SA-669 to include CS cases
        }

        //Find all leads with a related Master Call Id
        Map<String,ID> masterCallIdLeadMap = new Map<String,ID>();
        Map<String,ID> phoneLeadMap = new Map<String,ID>();
        Map<String,ID> phoneCaseMap = new Map<String,ID>();
        Set<Id> phoneCSCases = new Set<Id>();
        for (Lead l : [SELECT Id, Master_Call_Id__c, Phone
                       FROM Lead
                       WHERE Master_Call_Id__c != null
                       AND Master_Call_Id__c IN :callIdToMasterIdMap.values()])
        {
            masterCallIdLeadMap.put(l.Master_Call_Id__c, l.Id);
        }
        
        if (!phoneNums.isEmpty()){
            for (List<sObject> sObjectList : [FIND :String.join(new List<String>(phoneNums), ',')
                                              IN PHONE FIELDS
                                              RETURNING Lead (Id, Master_Call_Id__c, Phone 
                                                              WHERE Master_Call_Id__c != null)])
            {
                for (Lead l : (List<Lead>)sObjectList){
                    phoneLeadMap.put(l.Phone.removeStart('+'), l.Id);
                }
            }
            
            for (List<sObject> sObjectList : [FIND :String.join(new List<String>(phoneNums), ',')
                                              IN PHONE FIELDS
                                              RETURNING Case (Id, Master_Call_Id__c, Dialpad_Phone__c, RecordTypeID, OwnerId, Owner.Type //Added RecordTypeID under SA-669
                                                              WHERE Master_Call_Id__c != null AND isClosed = false ORDER BY createdDate desc//Added under SA-669 to only include most recent case
                                                              )])
            {
                for (Case c : (List<Case>)sObjectList){
                    String formattedDialpadPhone = c.Dialpad_Phone__c.removeStart('+');
                    if (!case2QueryMap.containsKey(c.Id)) {
                        case2QueryMap.put(c.Id, c);
                    }

                    if(c.RecordTypeID != ConsumerSupportCaseRecordTypeId){
                        phoneCaseMap.put(formattedDialpadPhone, c.Id);
                    } else if(!phoneCaseMap.keyset().contains(formattedDialpadPhone)){
                        phoneCaseMap.put(formattedDialpadPhone, c.Id);
                        phoneCSCases.add(c.id);
                    }
                }
            }
        }
        
        
        Map<ID,Case> casesToUpdate = new Map<ID,Case>();
        Map<ID,Lead> leadsToUpdate = new Map<ID,Lead> ();
        Map<ID,ID> caseToCorrectAccountId = new Map<ID,ID>();
        
        //Loop through tasks and populate the related whoId (with a lead) or whatId (with a case) as needed
        for (String callId : processTaskMap.keySet()) {
            Task t = processTaskMap.get(callId);
            t.Dialpad_Matched__c = true;
            
            String masterCallId = callIdToMasterIdMap.get(callId);
            
            ID accountId = t.AccountId;
            String phoneNum = t.Dialpad_Caller_Phone__c;
            
            String whatId = t.whatId;
            String whoId = t.WhoId;
            
            Boolean whoIdIsLead = whoId != null && whoId.startsWith('00Q');
            Boolean whatIdIsPopulated = whatId != null;
 
            Boolean updateTaskRelation = !whoIdIsLead && !whatIdIsPopulated;

            if (masterCallIdLeadMap.containsKey(masterCallId)){
                ID leadId = masterCallIdLeadMap.get(masterCallId);
                
                if (updateTaskRelation){
                    t.WhoId = leadId;
                }
                
                if (!userOwnedLeads.contains(leadId)){
                    leadsToUpdate.put(
                        leadId,
                        new Lead(
                            Id = leadId,
                            OwnerId = t.ownerId
                        )
                    );
                }
                
            }else if (masterCallIdCaseMap.containsKey(masterCallId)){
                ID caseId = masterCallIdCaseMap.get(masterCallId);
                if (updateTaskRelation){
                    t.WhatId = caseId;
                // SA-28: updateTaskRelation takes care of unknown caller whatId Assignment.
                // This condition checks if the associated case is a consumer support case 
                // and associated account is a person account.
                } else if (masterCallIdCSCaseMap.values().contains(caseId) && t?.Account?.IsPersonAccount){ 
                    t.WhoId = t?.Account?.PersonContactId;
                    t.WhatId = caseId;
                }
                
                if (!userOwnedCases.contains(caseId) && !masterCallIdCSCaseMap.containsKey(masterCallId) ){
                    if (case2QueryMap.containsKey(caseId) && case2QueryMap.get(caseId).Owner.Type != 'User') {
                        System.debug('Found Case via masterCallIdCaseMap');
                        casesToUpdate.put(
                            caseId,
                            new Case(
                                Id = caseId,
                                OwnerId = t.ownerId
                            )
                        );
                    }
                    
                }
                
                
            }else if (phoneLeadMap.containsKey(phoneNum)){
                ID leadId = phoneLeadMap.get(phoneNum);
                if (updateTaskRelation){
                    t.WhoId = leadId;
                }
                
                if (!userOwnedLeads.contains(leadId)){
                    leadsToUpdate.put(
                        leadId,
                        new Lead(
                            Id = leadId,
                            OwnerId = t.ownerId
                        )
                    );
                }
            }else if (accountIdCaseMap.containsKey(accountId)){
                ID caseId = accountIdCaseMap.get(accountId);
                if(t?.Account?.IsPersonAccount){ //SA-669: Update caseId to consumer suport case
                    caseId = accountIdCSCaseMap.get(accountId);
                }
                if (updateTaskRelation){
                    t.WhatId = caseId;
                }else if (accountIdCSCaseMap.values().contains(caseId) && t?.Account?.IsPersonAccount){  //Added under SA-669
                    t.WhoId = t?.Account?.PersonContactId;
                    t.WhatId = caseId;
                }
                
                if (!userOwnedCases.contains(caseId) && !accountIdCSCaseMap.values().contains(caseId)){
                    System.debug('Found Case via accountIdCaseMap');
                    if (case2QueryMap.containsKey(caseId) && case2QueryMap.get(caseId).Owner.Type != 'User') {
                        casesToUpdate.put(
                            caseId,
                            new Case(
                                Id = caseId,
                                OwnerId = t.ownerId
                            )
                        );
                    }
                }
            }else if (phoneCaseMap.containsKey(phoneNum)){
                ID caseId = phoneCaseMap.get(phoneNum);
                if (updateTaskRelation){
                    t.WhatId = caseId;

                }else if (phoneCSCases.contains(caseId)){  //Added under SA-669 // Updated under CSS-159
                    t.WhatId = caseId;
                }
                
                //added case2QueryMap check for DSS-408
                if (!userOwnedCases.contains(caseId) && !phoneCSCases.contains(caseId) && case2QueryMap.containsKey(caseId)){
                    if (case2QueryMap.get(caseId).Owner.Type != 'User') {
                        System.debug('Found Case via phone match');
                        casesToUpdate.put(
                            caseId,
                            new Case(
                                Id = caseId,
                                OwnerId = t.ownerId
                            )
                        );
                    }
                }
            }

            if (accountId != null && t.whatId != null && String.valueOf(t.whatId).startsWith('500')){
                caseToCorrectAccountId.put(t.whatId, accountId);
            }
        }
        
        for (Case c : [SELECT Id
                       FROM Case
                       WHERE Id IN :caseToCorrectAccountId.keySet()
                       AND IsClosed = false
                       AND AccountId = null 
                       AND RecordTypeID != : ConsumerSupportCaseRecordTypeId])
        {            
            if (casesToUpdate.containsKey(c.Id)){
                casesToUpdate.get(c.Id).accountId = caseToCorrectAccountId.get(c.Id);
            }else{
                c.accountId = caseToCorrectAccountId.get(c.Id);
                casesToUpdate.put(c.Id, c);
            }
        }

        update casesToUpdate.values();
        update leadsToUpdate.values();
        update processTaskMap.values(); 
    }

    public static void checkForEmailType (List<Task> newTaskList){
          for (task tk: newTaskList){
            if (tk.Type == NULL && tk.subject != NULL && tk.subject.startsWithIgnoreCase('Email:')){
                tk.Type = 'Email';
            }
        }
    }

    public static void initializeActivityType (List<Task> newList, Map<ID,Task> oldMap) {


        for (Task t : newList){
            if (t.Type != NULL && (oldMap == NULL || oldMap.get(t.ID).Type != t.Type)){
                t.Activity_Type__c = t.Type; 

            }
        }
    }

    public static void updateRelatedRecords(Task[] taskList) {
		Map<ID,Task> tcIdMap = new Map<ID,Task>();
		List<task> listOfTask = [SELECT Id, WhatId, Subject, What.Type, Description, createdDate FROM Task WHERE Id IN :taskList];
		Map<ID,Date> drTouchAccountIdMap = new Map<ID,Date>();
		for (Task t : listOfTask) {
			Task oldT;
			if (Trigger.isUpdate) {
				oldT = (Task)Trigger.oldMap.get(t.Id);
			}

			if (t.whatId != null) {
				String objectAPIName = t.what.type;
				if (objectAPIName == 'Case') {
					if (t.Subject != null
						&& (t.Subject.startsWith('Mass Email')
						|| t.Subject.startsWith('Missed Call')
						|| t.Subject.startsWith('Group ring'))
						|| t.Description == 'Assigned to Case via call routing') {
				} else {
						tcIdMap.put(t.WhatId, t);
			    }
			    }
		    }

        }
		caseTriggerFunctions.updateFirstActivityDate(tcIdMap);
	}
    
    // SA-301
    // SA-210 - 08/09/2022 - Updated to associate survey links to digital deal tasks
    public static void populateTaskFields(List<Task> taskList, Map<ID,Task> oldTaskMap) {

        Set<Id> caseIdsToQuery = new Set<Id>();
        
        for (Task t : taskList) {

            Task oldT;

            if (t.whatId != null) {

                Boolean whatidIsCase = String.valueOf(t.whatId).startsWith('500');

                if (whatidIsCase && oldTaskMap != null && oldTaskMap.keySet().contains(t.id)) {
                    oldT = oldTaskMap.get(t.id);
                    if(oldT.whatId != t.whatId) {
                        caseIdsToQuery.add(t.whatId);
                    }
                } else {
                    caseIdsToQuery.add(t.whatId);
                }
            }
        }

        if(caseIdsToQuery.isEmpty()) {
            return;
        }
        
        Map<Id, Case> queriedCases = new Map<Id, Case>([SELECT Id, AccountId, Subject FROM Case WHERE AccountId != null AND Id IN :caseIdsToQuery]);

        // SA-210 : map of account id to task, holds digital deal tasks that need to be associated to surveys
        Map<Id, Task> digitalDealTasks = new Map<Id, Task>();

        for (Task t : taskList) {
            if (queriedCases.keySet().contains(t.whatId)) {
                t.Related_Account__c = queriedCases.get(t.whatId).AccountId;
                // SA-210 : if the task is related to a digital deal case, add to digital deal tasks map
                if (t.Related_Survey_Results__c == null && queriedCases.get(t.whatId).Subject != null && queriedCases.get(t.whatId).Subject.contains('Digital Deal')) {
                    digitalDealTasks.put(t.Related_Account__c, t);
                }
            }
        }

        // SA-210 : if digital deal tasks needing survey link are identified
        if (digitalDealTasks.size() > 0) {
            // SA-210 : grab map of digital deal survey results created for identified accounts
            List <Survey_Results__c> digitalDealsSurveyResultsList = new List <Survey_Results__c>([
                SELECT Id, Account__c
                FROM Survey_Results__c 
                WHERE RecordTypeID = :Utilities.getrecordTypeId('Survey_Results__c', 'Digital_Deal') 
                AND Account__c IN :digitalDealTasks.keySet()
                ORDER BY createdDate DESC NULLS LAST
            ]);
            // SA-210 : loop through tasks associating to survey results
            for (Task t : digitalDealTasks.values()) {
                for (Survey_Results__c result : digitalDealsSurveyResultsList) {
                    if (result.Account__c == t.Related_Account__c) {
                        t.Related_Survey_Results__c = result.Id;
                    }
                }
            }
        }
    }

    public static void updateIntegrityCaseRecord(Task[] taskList, Map<ID,Task> oldTaskMap) {
        List<Case> updateCaseStatus = new List<case>();
        Set<Id> caseIds = new Set<Id>();
        for(Task t: taskList){
            if(t.Subject == 'Pending Investigation Alert' 
                && oldTaskMap.get(t.Id).Status != t.Status 
                && t.Status=='Completed' && String.valueof(t.WhatId).left(3)=='500') 
            caseIds.add(t.WhatId);
        }
        
        for(Case c : [Select Id,Status from Case where Id =:caseIds ]){
            c.status='Investigation - Email Sent';
            updateCaseStatus.add(c);
        }
        
        if(!updateCaseStatus.isEmpty()){
        update updateCaseStatus;
        }
    }

}