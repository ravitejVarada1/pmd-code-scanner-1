/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     jchang
* created:        01/07/2021
* modified:       03/23/2022
* created jira:   BR-360
* Change History
	Date			Name 					Jira 				Description
03/28/2023		Ravitej Varada  	   	   CSS-110  	 Disable URL pop up for Consumer Support cases
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class DialpadCallEventHandler {
    
    private static final String INBOUND = 'INBOUND';
    private static final String HANGUP = 'HANGUP';
    private static final String CONNECTED = 'Connected';
    private static final String USER = 'User';
    private static final String dialPadScreenpopEndpoint = '/api/v2/users/<dialpadUserId>/screenpop';
    
    @TestVisible
    private static Integer testStatusCode = 200;
    
    public static void createSalesforceRecords(RestDialpadCallEvent.rawPayloadWrap payload){
        
        String callDirection = payload.direction?.toUpperCase();
        String callState = payload.state?.toUpperCase();
        
        if (callDirection != INBOUND){
            return;
        }
        
        Set<String> dialpadUserIds = new Set<String>();
        for (User u : [SELECT Id, Dialpad_Id__c FROM User WHERE IsActive = true AND Dialpad_Id__c != null]) {
            dialpadUserIds.add(u.Dialpad_Id__c);
        }
        
        String externalNumber = payload.external_number?.remove('+');
        String internalNumber = payload.internal_number?.remove('+');
        
        Dialpad_Call_Event_Log__c log = new Dialpad_Call_Event_Log__c(
            Name = callDirection + ' ' + callState + ' - ' + externalNumber,
            Call_Id__c = payload.call_id,
            Date_Time_Connected__c = payload.date_connected != null ? DateTime.newInstance(payload.date_connected) : null,
            Date_Time_Ended__c = payload.date_ended != null ? DateTime.newInstance(payload.date_ended) : null,
            Date_Time_Started__c = payload.date_started != null ? DateTime.newInstance(payload.date_started) : null,
            Direction__c = callDirection,
            Duration__c = payload.duration,
            Entry_Point_Call_Id__c = payload.entry_point_call_id,
            External_Number__c = externalNumber,
            Internal_Number__c = internalNumber,
            Is_Transferred__c = payload.is_transferred != null ? payload.is_transferred : false,
            Master_Call_Id__c = payload.master_call_id,
            State__c = callState,
            Target_Id__c = payload.target?.id,
            Target_Type__c = payload.target?.type_Z,
            Target_Name__c = payload.target?.name,
            Target_Email__c = payload.target?.email
        );
        
        if (callState == CONNECTED && dialpadUserIds.contains(log.Target_Id__c)){
            System.debug('entering url pop');
            runURLPop(log);
        }
        
        insert log;
    }
    
    
    public class urlPopReturn{
        public String screen_pop_uri;
        
        public urlPopReturn(String screen_pop_uri){
            this.screen_pop_uri = screen_pop_uri;
        }
    }
    
    private static void runURLPop(Dialpad_Call_Event_Log__c log){
        Dialpad_Router_Log__c relatedLog;
        String phoneCompare = '%'+log.External_Number__c;
        
        for (Dialpad_Router_Log__c singleLog : [SELECT Id, foundCaseIdsLong__c, createdCaseId__c
                                                FROM Dialpad_Router_Log__c
                                                WHERE externalNumber__c LIKE :phoneCompare
                                                ORDER BY CreatedDate Desc
                                                LIMIT 1])
        {
            System.debug(singleLog.Id);
            relatedLog = singleLog;
        }
        
        if (relatedLog == null){
            return;
        }
        
        List<String> caseIds = new List<String>();
        
        if (relatedLog.createdCaseId__c != null){
            caseIds.add(relatedLog.createdCaseId__c.trim());
        }else if (relatedLog.foundCaseIdsLong__c != null){
            for (String existingCaseId : relatedLog.foundCaseIdsLong__c.split(',')){
                caseIds.add(existingCaseId.trim());
            }
        }
        
        String baseURL = System.Url.getOrgDomainUrl().toExternalForm();
        
        log.URL_Pop_Ids__c = String.join(caseIds, ',');
        log.URL_Pop_Success_Responses__c = '';
        log.URL_Pop_Failure_Responses__c = '';
        
        //Map to store case id with case records from the related logs
        Map<Id,Case> idWithCaseMap = new Map<Id,Case>([SELECT id,recordtype.Name FROM Case WHERE ID IN:caseIds]);
        
         
        for (String caseId : caseIds){
            //Skip the Iteration if the Case is Consumer Support case. - CSS-110
            if (!idWithCaseMap.isEmpty() && idWithCaseMap.containsKey(caseId) && idWithCaseMap.get(caseId).RecordTypeId != Null && idWithCaseMap.get(caseId).RecordType.Name == 'Consumer Support'  ){
                continue;               
            }
            
            urlPopReturn returnObj = new urlPopReturn(baseURL + '/' + caseId);
            
            HttpRequest req = new HttpRequest();
            //CSS-110 
            if(Utilities.isSandbox()) {
                req.setEndpoint('callout:DialPad_Sandbox'+dialPadScreenpopEndpoint.replace('<dialpadUserId>', log.Target_Id__c));
            } else{
                req.setEndpoint('callout:DialPad'+dialPadScreenpopEndpoint.replace('<dialpadUserId>', log.Target_Id__c));
            }
            
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer {!$Credential.Password}');
            req.setBody(JSON.serialize(returnObj));
            
            Http h = new Http();
            HttpResponse res; 
            
            if (Test.isRunningTest()){
                res = new HttpResponse();
                res.setStatusCode(testStatusCode);
            }else{
                res = h.send(req);
            }
            
            if(res.getStatusCode() == 200){
                log.URL_Pop_Success_Responses__c += 'STATUS: 200 \n\n' +
                    res.getBody() + 
                    '\n ---------------------- \n\n';
            }else{
                log.URL_Pop_Failure_Responses__c += 'STATUS: ' + res.getStatusCode() + ' \n\n' +
                    res.getBody() + 
                    '\n ---------------------- \n\n';
            }
            
        }
        
    }
}