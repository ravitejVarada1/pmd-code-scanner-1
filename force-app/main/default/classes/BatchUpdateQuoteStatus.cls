public class BatchUpdateQuoteStatus implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

    private Set<Id> quoteIds;

    private static final Set<String> EXCLUDEDSTATUSES = new Set<String>{'Order Generated','Expired'};

    public BatchUpdateQuoteStatus(Set<Id> quoteIds) {
        this.quoteIds = quoteIds;
    }

    public BatchUpdateQuoteStatus() {}

    public Database.QueryLocator start(Database.BatchableContext BC){
        String query = 'SELECT Id from SBQQ__Quote__c where SBQQ__ExpirationDate__c <= TODAY ' +
            'AND SBQQ__ExpirationDate__c != null AND SBQQ__Status__c NOT IN: EXCLUDEDSTATUSES';
        if (quoteIds != null) {
            query += ' AND ID in: quoteIds';
        }

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<SBQQ__Quote__c> quoteList) {
        DocusignFunctions.voidMultipleEnvelopes(DocusignFunctions.getOpenEnvelopeIDs(quoteList), 'Auto-void due to quote expiration');
        CPQQuoteTriggerFunctions.setQuoteExpired(quoteList);
    }

    public void finish(Database.BatchableContext BC) { }

    public void execute (SchedulableContext sc) {
        database.executeBatch(new BatchUpdateQuoteStatus(), 20);
    }

}