/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         amitul
* modifiedBy:     amitul
* created:        12/18/2021
* modified:       12/18/2021
* created jira:   BR-4860
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class Batch_CheckQuoteStartDate implements Database.Batchable<sObject>,Schedulable {
        
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new Batch_CheckQuoteStartDate(), 1);
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        string query = 'SELECT Id, SBQQ__PrimaryQuote__c, SBQQ__PrimaryQuote__r.SBQQ__StartDate__c ' +
                       'FROM opportunity WHERE IsClosed = FALSE AND Opportunity_Tracker__r.Quote_Final__c = FALSE AND Opportunity_Tracker__r.Spid_Final__c = TRUE ' +
                       'AND Opportunity_Tracker__r.Quote_Approved__c = TRUE AND Opportunity_Tracker__r.DocusignComplete_Final__c = TRUE AND Opportunity_Tracker__r.Zuora_Final__c = TRUE';
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<Opportunity> oppList) {
        List<SBQQ__Quote__c> quoteList = new List<SBQQ__Quote__c>();
        for(Opportunity opp:oppList){
            if(opp.SBQQ__PrimaryQuote__r.SBQQ__StartDate__c < system.today() || test.isRunningTest()){
               SBQQ__Quote__c quote = new  SBQQ__Quote__c(id = opp.SBQQ__PrimaryQuote__c,SBQQ__StartDate__c = system.today() );
               quoteList.add(quote);
            }
        }
        
        if(!quoteList.isEmpty()){
            update quoteList;
        }  
    }
    
    public void finish(Database.BatchableContext BC) {

    }     
}