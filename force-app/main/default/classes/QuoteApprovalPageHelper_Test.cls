@isTest
public class QuoteApprovalPageHelper_Test {
    
    
    @TestSetup
    public static void setupData(){
        
        Test.startTest();
        
        List<Account> testAccts = TestDataFactory.createAccounts(1);
        testAccts[0].Account_Status__c = 'Pending';
        insert testAccts;
        ID acctId = testAccts[0].Id;
        
        List<Opportunity> testOpps = TestDataFactory.createOpps(acctId, 1);
        insert testOpps;
        ID oppId = testOpps[0].Id;
        
        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(acctId, oppId, 1);
        insert quotes;
        ID quoteId = quotes[0].Id;
        
        List<Product2> testProds = TestDataFactory.createProducts(1);
        testProds[0].Require_OM_Review__c = true;
        insert testProds;
        ID prodId = testProds[0].Id;
        
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            quoteId,
            acctId,
            new Set<ID>{prodId}
        )[0];
        
        Test.stopTest();
        
    }
    
    @isTest
    public static void callInvocableUpdateNeeded(){
        List<ID> quoteIds = new List<ID>{[SELECT Id
                                         FROM SBQQ__Quote__c
                                         LIMIT 1][0].Id};
        QuoteApprovalPageHelper.checkOMEntryCriteriaAndReasons(quoteIds);
        QuoteApprovalPageHelper.checkOMEntryCriteriaAndReasons(quoteIds);
    }

    
    
}