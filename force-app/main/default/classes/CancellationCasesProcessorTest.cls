/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ralvarez
* created:        12/08/2021
* modified:       05/09/2022
* created jira:   BR-5044 / BR-9060
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
@isTest
public class CancellationCasesProcessorTest {

  @testSetup
  static void setupRecords() {

    TriggerHandler.bypass('ContractTriggerHandler');
    TriggerHandler.bypass('CPQ_Subscription_TriggerHandler');
    TriggerHandler.bypass('AccountTriggerHandler');
    TriggerHandler.bypass('CaseTriggerHandler');
    
    Test.startTest();
    // accounts
    List<Account> accs = TestDataFactory.createAccounts(1);
    accs[0].BillingCountryCode = 'US';
    accs[0].Name = 'Dealer #1 Account';
    insert accs;

    // products
    List<Product2> products = new List<Product2>();
    Product2 cgBaseBundle = new Product2(Name = 'CG Base Bundle', IsActive = true, SBQQ__SubscriptionPricing__c = 'Fixed Price');
    Product2 EnhPlacement = new Product2(Name = 'Enhanced Placement', IsActive = true, SBQQ__SubscriptionPricing__c = 'Fixed Price');
    products.add(cgBaseBundle);
    products.add(EnhPlacement);
    insert products;

    //Instantiate the Pricebook2 record with StandardPricebookId
    Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
    //Execute an update DML on the Pricebook2 record, to make IsStandard to true
    update standardPricebook;

    List<PricebookEntry> pbeList = new List<PricebookEntry> ();
    PricebookEntry pbe_1 = new PricebookEntry(Pricebook2Id = standardPricebook.Id, Product2Id = cgBaseBundle.Id, UnitPrice = 0, IsActive = true);
    PricebookEntry pbe_2 = new PricebookEntry(Pricebook2Id = standardPricebook.Id, Product2Id = EnhPlacement.Id, UnitPrice = 1020, IsActive = true);
    pbeList.add(pbe_1);
    pbeList.add(pbe_2);
    insert pbeList;

    // contracts
    Contract contractRecord = TestDataFactory.createContract(accs[0].Id);
    contractRecord.EndDate = System.today().addMonths(3);
    contractRecord.SBQQ__AmendmentPricebookId__c = standardPricebook.Id;
    contractRecord.Initial_Term_End_Date__c = System.today().addMonths(3);
    contractRecord.SBQQ__AmendmentRenewalBehavior__c = 'Latest End Date';
    insert contractRecord;

    // CPQ subscriptions
    List<SBQQ__Subscription__c> subs = TestDataFactory.createCPQSubsForProducts(products, accs[0].Id);
    for(SBQQ__Subscription__c sub : subs) {
      sub.SBQQ__Contract__c =  contractRecord.Id;
      sub.SBQQ__NetPrice__c = 1;
      sub.Fulfillment_Account__c = accs[0].Id;
    }
    insert subs;

    // cases
    Case caseRecord = TestDataFactory.createCases(1, accs[0].Id)[0];
    caseRecord.RecordTypeId = [SELECT Id FROM RecordType WHERE sObjectType = 'Case' AND Name = 'Cancellations'][0].Id;
    caseRecord.Status = 'New';
    caseRecord.Case_Resolution__c = 'Full Cancellation';
    caseRecord.Origin = 'Web';
    caseRecord.Cancel_Override__c = System.today().addDays(5);
    caseRecord.Related_Contract__c = contractRecord.Id;
    insert caseRecord;

    TriggerHandler.clearAllBypasses();
    Test.stopTest();

  }

  @IsTest
  static void testProcessingCancellationCase() {

    Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
    adminEscape.Exclude_from_Validation_Rules__c = true;
    upsert adminEscape;

    Test.startTest();
    
    TriggerHandler.bypass('OpportunityTriggerHandler');
    TriggerHandler.bypass('CPQQuoteTriggerHandler');
    TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
    TriggerHandler.bypass('CaseTriggerHandler');

    Case caseRecord = [SELECT Id, Status FROM Case WHERE RecordType.Name = 'Cancellations' LIMIT 1];
    System.assertEquals('New', caseRecord.Status);
    Contract contractRecord = [SELECT Id FROM Contract LIMIT 1];
    Database.executeBatch(new CancellationCasesProcessor(caseRecord.Id), 1);

    TriggerHandler.clearAllBypasses();

    Test.stopTest();

    List<SBQQ__Quote__c> quotes = [
      SELECT Id, SBQQ__Opportunity2__r.Cancellation_Case__r.Status, SBQQ__Opportunity2__c, SBQQ__Opportunity2__r.Original_Contract_Spend__c
      FROM SBQQ__Quote__c
      WHERE SBQQ__Opportunity2__r.Cancellation_Case__c = :caseRecord.Id
    ];
    System.assertEquals(2, quotes.size());
    System.assertEquals('Closed', quotes[0].SBQQ__Opportunity2__r.Cancellation_Case__r.Status);
    System.assertEquals(2, quotes[0].SBQQ__Opportunity2__r.Original_Contract_Spend__c);

    Id oppId = quotes[0].SBQQ__Opportunity2__c;
    List<OpportunityLineItem> opptyLines = [
      SELECT Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :oppId
      AND Quantity < 0
    ];
        
    System.assertEquals(true, !opptyLines.isEmpty(), 'Negative Lines were created for Retention Opp');

  }

}