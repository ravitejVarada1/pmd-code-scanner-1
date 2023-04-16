/**
* Test class for CancellationQuotesProcessor
* @author 	Nahuel Goldy
* @date 	  06/04/2021
* @module   BR-2169
*/
@isTest
private class CancellationQuotesProcessor_Test {

  @testsetup
	static void testData() {
    Test.startTest();
    TriggerHandler.bypass('AccountTriggerHandler');
    TriggerHandler.bypass('CaseTriggerHandler');
    TriggerHandler.bypass('CPQQuoteLineTriggerHandler');

    Account[] accts = TestDataFactory.createAccounts(2);
    accts[0].BillingCountryCode = 'CA';
    accts[1].Name = 'CarGurus Account';
    insert accts;

    Contact[] cons = TestDataFactory.createContacts(1,accts[0].Id);
    insert cons;

    Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id,1);
    insert opps;

    SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
    quotes[0].SBQQ__StartDate__c = System.today().addMonths(1);
    insert quotes;

    Product2[] prods = new List<Product2>{
        new Product2(Name = 'CG Base Bundle', IsActive = true)
    };
    insert prods;

    Id pricebookId = Test.getStandardPricebookId();
    PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pricebookId, Product2Id = prods[0].Id, UnitPrice = 1020, IsActive = true);
    insert pbe;

    SBQQ__QuoteLine__c[] quoteLines = new List<SBQQ__QuoteLine__c>{
        new SBQQ__QuoteLine__c(
            Fulfillment_Account__c = accts[0].Id,
            SBQQ__Product__c = prods[0].Id,
            SBQQ__Quote__c = quotes[0].Id,
            SBQQ__Quantity__c = 1)
    };
    insert quoteLines;

    Order newOrder = new Order(
        AccountId = accts[0].Id,
        OpportunityId = opps[0].Id,
        Name = 'Test Order',
        SBQQ__Quote__c = quotes[0].Id,
        Status = 'Draft',
        EffectiveDate = date.today(),
        SBQQ__ContractingMethod__c = 'Single Contract',
        Pricebook2Id = pricebookId
    );
    insert newOrder;

    OrderItem item = new OrderItem(
        OrderId = newOrder.Id,
        Product2Id = prods[0].Id,
        Quantity = 1.00,
        UnitPrice = 10.00,
        PricebookEntryId = pbe.Id
    );
    insert item;

    Contract contractRecord = TestDataFactory.createContract(accts[0].Id);
    contractRecord.EndDate = System.today().addMonths(3);
    insert contractRecord;

    quotes[0].SBQQ__MasterContract__c = contractRecord.Id;
    update quotes;

    Case caseRecord = TestDataFactory.createCases(1, accts[0].Id)[0];
    caseRecord.RecordTypeId = [SELECT Id FROM RecordType WHERE sObjectType = 'Case' AND Name = 'Cancellations'][0].Id;
    caseRecord.Related_Contract__c = contractRecord.Id;
    caseRecord.Status = 'New';
    caseRecord.Case_Resolution__c = 'Full Cancellation';
    caseRecord.CountryCode__c = 'CA';
    caseRecord.CurrencyIsoCode = 'CAD';
    insert caseRecord;
    
    TriggerHandler.clearAllBypasses();
    Test.stopTest();

  }

  static testMethod void testProcessingCancellationQuotes() {
    TriggerHandler.bypass('AccountTriggerHandler');
    TriggerHandler.bypass('CaseTriggerHandler');
    TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
    List<Opportunity> opps = [
        SELECT Id, RecordTypeId, Cancellation_Case__c
        FROM Opportunity
    ];
    System.assertEquals(1, opps.size());

    opps[0].RecordTypeId = [SELECT Id FROM RecordType WHERE sObjectType = 'Opportunity' AND Name = 'Retention'][0].Id;
    opps[0].Cancellation_Case__c = [SELECT Id FROM Case WHERE RecordType.Name = 'Cancellations'][0].Id;
    update opps;

    Case caseToClose = new Case(
      Id = opps[0].Cancellation_Case__c,
      Related_Opportunity__c = opps[0].Id,
      Status = 'Closed',
      Sub_Status__c = 'Complete'
    );
    update caseToClose;

    List<SBQQ__Quote__c> quotes = [
      SELECT Id, SBQQ__Primary__c, SBQQ__StartDate__c, SBQQ__Opportunity2__c, SBQQ__MasterContract__c
      FROM SBQQ__Quote__c
      WHERE SBQQ__Opportunity2__c = :opps[0].Id
    ];
		//System.assertEquals(2, quotes.size());

    for(SBQQ__Quote__c q : quotes) {
      if(q.SBQQ__Primary__c == false) {
        q.SBQQ__StartDate__c = System.today();
      }
    }
    update quotes;
    Test.startTest();
    Id jobId = Database.executeBatch(new CancellationQuotesProcessor(), 1);
    Test.stopTest();

    List<SBQQ__Quote__c> quotesRequery = [
      SELECT Id, SBQQ__Primary__c, SBQQ__Status__c, SBQQ__StartDate__c, SBQQ__Opportunity2__r.SBQQ__PrimaryQuote__c
      FROM SBQQ__Quote__c
      WHERE SBQQ__Opportunity2__c = :opps[0].Id
    ];
    SBQQ__Quote__c retentionQuote;
    SBQQ__Quote__c cancellationQuote;
    for(SBQQ__Quote__c q : quotesRequery) {
      if(q.SBQQ__StartDate__c == System.today()) {
        cancellationQuote = q;
      }
      else {
        retentionQuote = q;
      }
    }
    
		/*System.assertEquals(2, quotesRequery.size());
		System.assertEquals(true, retentionQuote.SBQQ__Primary__c);
		System.assertEquals(false, cancellationQuote.SBQQ__Primary__c);
		//System.assertEquals(null, cancellationQuote.SBQQ__Opportunity2__r.SBQQ__PrimaryQuote__c);
		System.assertEquals('Draft', retentionQuote.SBQQ__Status__c);
		System.assertNotEquals('Draft', cancellationQuote.SBQQ__Status__c);*/
	}

  @IsTest
  static void testScheduleCancellationQuotesProcessorBatch() {
    
    Test.startTest();
    CancellationQuotesProcessor cqp = new CancellationQuotesProcessor();
    String cronString = '0 0 23 * * ?';
    String jobId = System.schedule('TEST_CancellationQuotesProcessor', cronString, cqp);
    Test.stopTest();
    
    CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
    System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
  }

}