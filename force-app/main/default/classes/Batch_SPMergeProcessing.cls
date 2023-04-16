/**
 * BR-8870
 * 
 * Batch that looks for service provider records with a
 * populated Merge_SP_Id to check against the service provider records
 * and compare the Accounts on the SP pair
 * 
 * Unit tests in Batch_SPMergeProcessingTest
 * 
 */

public without sharing class Batch_SPMergeProcessing  implements Database.Batchable<sObject>, Schedulable {

    //default constructor
    public Batch_SPMergeProcessing() {}

    Set<String> spIds;

    public Batch_SPMergeProcessing(Set<String> spIds) {
        this.spIds = spIds;
    }

    //Execute for the scheduleable
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_SPMergeProcessing(), 100);
    }

    //modified to now verify that the Account does not have any Activated subscriptions
    //before we set them to former customer and canceling 57 days
    public Database.QueryLocator start(Database.BatchableContext BC) { 
        String spQuery = 'SELECT Id, Name,Unique_Id__c, Account__c, Merge_SP_ID__c,Service_Provider_Id_text__c, SP_Merge_Processed__c '+
            'FROM Service_Provider__c '+
            'WHERE Merge_SP_ID__c!=null '+
            'AND SP_Merge_Processed__c=false';
        
        spQuery = spIds!=null && !spIds.isEmpty() ? spQuery +' AND Id IN:spIds' : spQuery;

        return Database.getQueryLocator(spQuery);
    }
    
    //set the type to former customer and set the product activation status to
    //Canceling - 57
    public void execute(Database.BatchableContext BC, List<Service_Provider__c> serviceProviders) {
        
        Map<String,List<Service_Provider__c>> spMergeIdToServiceProviders = new Map<String,List<Service_Provider__c>>();

        List<Case> dataCorrectionCases = new List<Case>();
        List<Service_Provider__c> updateServiceProviders = new List<Service_Provider__c>();
        String caseRecordTypeId = CaseTriggerFunctions.caseRTNameIdMap.get('Data Correction');

        for(Service_Provider__c spRec : serviceProviders) {

            String spMergId = spRec.Merge_SP_ID__c;

            if(!spMergeIdToServiceProviders.containskey(spMergId)){
                spMergeIdToServiceProviders.put(spMergId,new List<Service_Provider__c>());    
            }
            spMergeIdToServiceProviders.get(spMergId).add(spRec);

            spRec.SP_Merge_Processed__c = true;
            updateServiceProviders.add(spRec);
        }

        for(Service_Provider__c parentSP : [SELECT Id,Name,Unique_Id__c, Account__c, Merge_SP_ID__c,
        Service_Provider_Id_text__c,SP_Merge_Processed__c 
        FROM Service_Provider__c
        WHERE Service_Provider_Id_text__c!=null 
        AND Service_Provider_Id_text__c IN:spMergeIdToServiceProviders.keyset()]){

            for(Service_Provider__c childSP : spMergeIdToServiceProviders.get(parentSP.Service_Provider_Id_text__c)){
                
                //account don't match on the merged SP
                if(parentSP.Account__c!=childSP.Account__c){
                    dataCorrectionCases.add(
                        setCaseFields(parentSP,childSP,caseRecordTypeId)
                    );
                }
            }
        }

        if(!dataCorrectionCases.isEmpty()){
            insert dataCorrectionCases; 
        }

        if(!updateServiceProviders.isEmpty()){
            update updateServiceProviders;
        }
    }

    static Case setCaseFields(Service_Provider__c parentSP,Service_Provider__c childSP,String caseRecordTypeId){
        
        //Run Case assignment rule from apex
        Database.DMLOptions dmlOption = new Database.DMLOptions();
        dmlOption.assignmentRuleHeader.useDefaultRule = true;

        Case cs = new Case();
        cs.RecordTypeId = caseRecordTypeId;
        cs.Subject = 'Service Provider records merged';
        cs.Description = 'Service Provider:'+childSP.Name+'('+childSP.Unique_Id__c+') has been merged into this Service Provider '+parentSP.Name+'('+parentSP.Unique_Id__c+'), please update Salesforce records to match';
        cs.AccountId = parentSP.Account__c;
        cs.Origin = 'Internal';
        cs.Reason = 'SP Merge/Deny';
        cs.setOptions(dmlOption);
        return cs;
    }
    
    public void finish(Database.BatchableContext BC) {
        
    }

}