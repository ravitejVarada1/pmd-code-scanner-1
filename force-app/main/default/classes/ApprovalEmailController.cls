public without sharing class ApprovalEmailController {
    public Id quoteId {get; set;}

    public List<SBQQ__Quoteline__c> getAllQuoteLines() {
        List<SBQQ__Quoteline__c> quoteLines = [SELECT Id, Name, SBQQ__Quantity__c, SBQQ__ProductName__c, Contract_Total_Price__c, SBQQ__ListPrice__c, Minimum_Price__c, SBQQ__NetTotal__c, Fulfillment_Account__r.Name  
                FROM SBQQ__Quoteline__c WHERE SBQQ__ProductCode__c != 'CG-BASE' AND SBQQ__Quote__c = :quoteId ORDER BY Fulfillment_Account__r.Name ASC];
        for(SBQQ__Quoteline__c ql : quoteLines) {
            ql.SBQQ__Quantity__c = ql.SBQQ__Quantity__c == null ? null : ql.SBQQ__Quantity__c.intValue();
            ql.SBQQ__ListPrice__c = ql.SBQQ__ListPrice__c == null ? null : ql.SBQQ__ListPrice__c.intValue();
            ql.Minimum_Price__c = ql.Minimum_Price__c == null ? null : ql.Minimum_Price__c.intValue();
        }
        return quoteLines;
    }
}