public inherited sharing class QuoteSelector {

    private String query;
    private String fromObject = ' FROM SBQQ__Quote__c ';
    private String queryLimit;
    private String subSelectQuery;

    // Constructor to setup the base query
    public QuoteSelector() {
        buildBaseQuery();
    }

    // Put fields you intend to almost always select with your quote queries here
    private void buildBaseQuery() {
        this.query = 'SELECT Id, SBQQ__Type__c, SBQQ__Opportunity2__r.SBQQ__RenewedContract__r.EndDate';
    }

    // Set query limit
    public void setQueryLimit(Integer passedLimit) {
        this.queryLimit = 'LIMIT ' + passedLimit;
    }

    public void getQuoteLinesSubSelect() {

    }

    // Select your cases by a set of case ids
    public String selectQuotesById(Set<Id> quoteIds) {
        this.query += this.query + fromObject + 'WHERE Id IN :quoteIds' + this.queryLimit;
        return this.query;
    }

    // Select non-expired quotes
    public String selectNonexpiredQuotesWithQuoteLines(Set<Id> quoteIds) {
        this.query += this.query + fromObject + 'WHERE Id IN :quoteIds ' + 'AND SBQQ__Status__c != \'Expired\' AND SBQQ__Opportunity2__r.IsClosed = false';
        return this.query;
    }

    // query non-expired quotes with related quote line data
    public static List<SBQQ__Quote__c> getQuotesWithQuoteLines(Set<Id> quoteIds) {
        return [SELECT Id, SBQQ__Type__c, SBQQ__Opportunity2__r.SBQQ__RenewedContract__r.EndDate, 
                (SELECT Id, Fulfillment_Account__c, SBQQ__Product__c, SBQQ__Product__r.Sub_Category__c, 
                SBQQ__ProductCode__c, SBQQ__ProductName__c, SBQQ__Quantity__c, SBQQ__Bundled__c, SBQQ__RenewedSubscription__c, 
                Contract_Total_Price__c, SBQQ__UpgradedSubscription__c, Product_Category__c, SBQQ__ProductFamily__c
                FROM SBQQ__LineItems__r)
            FROM SBQQ__Quote__c WHERE Id IN : quoteIds AND SBQQ__Status__c != 'Expired' 
            AND SBQQ__Opportunity2__r.IsClosed = false];
    }
}