/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        09/27/2021
* modified:       09/27/2021
* created jira:   BR-4209
* purpose:  	  Deletes all Dialpad Call Event Logs more than 7 days old. Also has constructor to
* - manually populate the cutOffDate if needed. We need this batch because as of 09/2021, about 30,000 records
* - per week are being created, and we only need the records for max a few days
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class Batch_DialpadCallEventLogDelete implements Database.Batchable<sObject>, Schedulable{
    Date cutOffDate;
    
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_DialpadCallEventLogDelete());
    }
    
    //Custom date constructor - sets cutOffDate to custom value
    public Batch_DialpadCallEventLogDelete(Date cutOffDate){
        this.cutOffDate = cutOffDate;
    }
    
    //Base constructor - sets cutOffDate to 7 days ago
    public Batch_DialpadCallEventLogDelete(){
        this.cutOffDate = Date.today()-7;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id ' +
            		   'FROM Dialpad_Call_Event_Log__c ' +
                       'WHERE CreatedDate < :cutOffDate';
        
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<Dialpad_Call_Event_Log__c> logsToDelete) {
        delete logsToDelete;
    }
    
    public void finish(Database.BatchableContext bc){}
}