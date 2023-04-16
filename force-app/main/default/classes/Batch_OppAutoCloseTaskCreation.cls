/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         amitul
* modifiedBy:     amitul
* created:        02/26/2021
* modified:       09/15/2021
* created jira:   BR-501/BR-3980
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

global class Batch_OppAutoCloseTaskCreation implements Database.Batchable<sObject>,Schedulable {
    private final Date CUT_OFF_DATE = System.today().addDays(3);
    private final Date TODAY_DATE = System.today();
    public static final String SUBJECT = 'Your Opportunity will be closed in the next 3 days.';
    public static final String STATUS = 'Open';   
    public static final String PRIORITY= 'Normal';
    public static final String DESCRIPTION= 'If you want to extend the auto close date, please submit this opportunity for approval.';
   
    //Querying the list of opportunity which are suppose to close in next three days based on Opportunity Auto close date field.
	global Database.QueryLocator start(Database.BatchableContext BC){
        Set<Id> RECORDTYPEIDS = new Set<Id>{
                SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Standard_Opportunity'),
                SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Retention'),
                SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Renewal')
        };
		if(RECORDTYPEIDS == null || RECORDTYPEIDS.isEmpty()) return null;
        Set<String> checkStageName = new Set<String>{'Closed Won','Closed Lost','Closed Saved'};
        String query = 'SELECT Id,Name,OwnerId,Auto_Close_Date__c FROM Opportunity '+
            		   'WHERE RecordTypeId IN:RECORDTYPEIDS AND (Auto_Close_Date__c =: CUT_OFF_DATE OR (Auto_Close_Date__c <=: TODAY_DATE AND StageName NOT IN: checkStageName))';		  				
		return Database.getQueryLocator(query);
	}
	//Creating a Task records to Opportunity Owner once get result from Start method
	global void execute(Database.BatchableContext BC, List<Opportunity> opportunityList) {		
        List<Task> listTaskRecord = new List<Task>();
        List<Opportunity> listOpportunityRecord = new List<Opportunity>();
        for(Opportunity opp:opportunityList){
            if(opp.Auto_Close_Date__c == CUT_OFF_DATE){
                Task taskRecord = new Task();
                taskRecord.Subject = SUBJECT;
                taskRecord.Status = STATUS;
                taskRecord.Priority = PRIORITY;
                taskRecord.WhatId = opp.Id;
                taskRecord.OwnerId = opp.OwnerId;
                taskRecord.ActivityDate = opp.Auto_Close_Date__c;
                taskRecord.Description = DESCRIPTION;
                listTaskRecord.add(taskRecord);
            }
            //Setting the Opportunity Stage to closed lost when Auto Close Date <= Date.Today 
            if(opp.Auto_Close_Date__c <= TODAY_DATE){
                opp.StageName = 'Closed Lost';
                opp.Closed_Lost_Reason__c = 'Auto Close Stale';
                opp.CloseDate = opp.Auto_Close_Date__c; //SA-289
                listOpportunityRecord.add(opp);
            }
        }
        if(!listTaskRecord.isEmpty())Database.insert(listTaskRecord,false);   
        if(!listOpportunityRecord.isEmpty())Database.update(listOpportunityRecord,false); 
	}
    global void execute(SchedulableContext SC) {
        Database.executeBatch(new Batch_OppAutoCloseTaskCreation(),50);
    }
	
	global void finish(Database.BatchableContext BC) {}
}