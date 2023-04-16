/*Batch to process Right tobe forgotten Request 
* author:         amitul
* created:        01/27/2023
* modified:       
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* This class implements the Database.Batchable and Schedulable interfaces
* to perform a batch process that finds and deletes related cases for person accounts,
* and inserts RTBF requests for those accounts.
* The class selects person accounts with first name and last name starting with '0',
* and deletes their associated cases, then creates and inserts privacycenter__RTBF_Request__c records
* with 'Pending' status for those accounts.
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public with sharing class Batch_ProcessRTBFRequest implements Database.Batchable<SObject>, Schedulable {

    /**
     * The start method returns a query locator for person accounts with first name and last name starting with '0'.
     * It filters accounts based on their record type, which is assumed to be 'Person Account'.
     * @param bc The batch context for the batch process.
     * @return A query locator for the selected person accounts.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Id personAccountRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        String query = 'SELECT Id, FirstName, LastName FROM Account WHERE RecordTypeId = :personAccountRecTypeId '+
                        'AND FirstName Like \'0%\' AND LastName Like \'0%\'';
        return Database.getQueryLocator(query);
    }

    /**
     * The execute method performs the batch process for a batch of person accounts.
     * For each account, it finds and deletes any related cases,
     * then creates and adds a privacycenter__RTBF_Request__c record with 'Pending' status for that account.
     * @param context The batch context for the batch process.
     * @param scope The batch scope, which is a list of person accounts to process.
     */
    public void execute(Database.BatchableContext context, List<Account> scope) {
        List<privacycenter__RTBF_Request__c> rtbfList = new List<privacycenter__RTBF_Request__c>();
        Set<Id> accountIds = new Set<Id>();
        for(Account acc : scope) {
            accountIds.add(acc.Id);
        }
        List<Case> relatedCases = [SELECT Id FROM Case WHERE AccountId IN :accountIds];
        if(!relatedCases.isEmpty()) {
            delete relatedCases;
        }
        for(Account acc : scope) {
            privacycenter__RTBF_Request__c rtbf = new privacycenter__RTBF_Request__c();
            rtbf.privacycenter__Record_for_Deletion__c = acc.Id;
            rtbf.privacycenter__Policy_Name__c = 'ConsumerRTBF';
            rtbf.privacycenter__Status__c = 'Pending';
            rtbfList.add(rtbf);
        }
        if(!rtbfList.isEmpty()) {
            insert rtbfList;
        }
    }

    public void finish(Database.BatchableContext context) {
    }
    
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new Batch_ProcessRTBFRequest());
    }
}
