@IsTest
public class OpportunityProductTriggerFunctions_Test {
    
    @testsetup
    
    static void testSetup() {
    SBQQ.TriggerControl.disable();

    Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
	  adminEscape.Exclude_from_Validation_Rules__c = true;
    upsert adminEscape;

    List<account> accts = TestDataFactory.createAccounts(1,'Location');
    accts[0].BillingCountryCode = 'US';
    insert accts;

    List<Contact> cons = TestDataFactory.createContacts(1,accts[0].Id);
    insert cons;

    List<product2> products = TestDataFactory.createProducts(2);
    Products[0].ProductCode = 'ENH-PLC';
    Products[1].ProductCode = 'ENH-PLC';     
    insert products;

    ID pricebookId = Test.getStandardPricebookId();
    List<PriceBookEntry> pbes = new List<PriceBookEntry>();
    pbes.add( new PricebookEntry( Product2Id = products[0].Id, Pricebook2Id = pricebookId,
        CurrencyIsoCode = 'USD', UnitPrice = 100, IsActive = true
    ));

    pbes.add( new PricebookEntry( Product2Id = products[1].Id, Pricebook2Id = pricebookId,
         CurrencyIsoCode = 'USD', UnitPrice = 200, IsActive = true
    ));
    insert pbes;

    List<opportunity> opportunities = TestDataFactory.createOpps(accts[0].Id,1);    
    opportunities[0].SBQQ__Renewal__c = true;
    opportunities[0].PriceBook2Id = pricebookId;
    opportunities[0].QuotePrimaryContact__c = cons[0].Id;
    insert opportunities;

    Date startDate = Date.today().addMonths(-12);
    Date endDate = Date.today().addMonths(1).toStartOfMonth();
       
    Contract testContract = new Contract(
    AccountId = accts[0].Id,
    CurrencyISOCode='USD',
    Name = 'CPQ Backfill',
    StartDate = startDate,
    EndDate = endDate,
    SBQQ__PreserveBundleStructureUponRenewals__c = true,
    SBQQ__RenewalForecast__c = true,
    SBQQ__RenewalQuoted__c = true,
    SBQQ__RenewalOpportunity__c = opportunities[0].Id
    );
    insert testContract;

    testContract.startDate = startDate;
    testContract.endDate = endDate;
    update testContract;

    SBQQ__Subscription__c sub = TestDataFactory.createCPQSubsForProducts(products, accts[0].Id)[0];
    sub.SBQQ__Contract__c = testContract.Id;
   	sub.SBQQ__NetPrice__c = 100;
    insert sub;

    opportunities[0].SBQQ__RenewedContract__c = testContract.Id;
    update opportunities;
		
    List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
    olis.add(new OpportunityLineItem( PricebookEntryId = pbes[0].Id, OpportunityId = opportunities[0].Id, Fulfillment_Account__c = accts[0].Id,
        Product2Id = products[0].Id, Quantity = 1, UnitPrice = 100
    ));
        
    olis.add(new OpportunityLineItem( PricebookEntryId = pbes[0].Id, OpportunityId = opportunities[0].Id, Fulfillment_Account__c = accts[0].Id,
        Product2Id = products[1].Id, Quantity = 1, UnitPrice = 200
    ));
    insert olis;

    }

    @IsTest
    static void replaceProductsTest() {

    Test.startTest();
    List<Opportunity> opps = [
      SELECT Id FROM Opportunity
      LIMIT 1
    ];

    Contract con = [SELECT Id FROM Contract LIMIT 1];
    opps[0].SBQQ__RenewedContract__c = con.Id;
    opps[0].Cancellation_Case__c = null;
    opps[0].SBQQ__AmendedContract__c = null;
    update opps;    

    Test.stopTest();
    List<PricebookEntry> pbe = [SELECT Id,Product2.ProductCode,Pricebook2Id,Pricebook2.Name  FROM PricebookEntry];  

    List<OpportunityLineItem> oli = [SELECT ID FROM OpportunityLineItem WHERE Quantity > 0];
         system.debug('oli'+oli);
  }

  @IsTest
  static void deleteProductsTest() {

  Test.startTest();
  Id RECORDTYPEIDRETENTION = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Retention').getRecordTypeId();

  List<Opportunity> opps = [
    SELECT Id, StageName, Cancellation_Case__c, Cancellation_Case__r.Cancellation_Effective_Date__c
    FROM Opportunity
    LIMIT 1
  ];  

  opps[0].SBQQ__RenewedContract__c = null;
  opps[0].Cancellation_Case__c = null;
  opps[0].SBQQ__AmendedContract__c = null;
  opps[0].REcordTypeId = RECORDTYPEIDRETENTION;
  opps[0].SBQQ__Renewal__c = false;

  update opps;

  List<OpportunityLineItem> oli = [SELECT Id, Quantity FROM OpportunityLineItem];
  oli[0].Quantity = -1;
  update oli;
  delete oli;

  Test.stopTest(); 

  List<OpportunityLineItem> oliAfter = [SELECT ID FROM OpportunityLineItem];
  System.assertEquals(1, oli.size());
  
}

}