@IsTest
public class OpportunityTriggerFunctions_Test {
    
  @testsetup
	static void testData(){
    
    TriggerHandler.bypass('AccountTriggerHandler');
    TriggerHandler.bypass('CaseTriggerHandler');
    TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
    TriggerHandler.bypass('OrderTriggerHandler');

    User[] usersWithManager = [SELECT Id FROM User WHERE IsActive = true AND Profile.UserLicense.Name = 'Salesforce' AND ManagerId != NULL LIMIT 1];
    Account[] accts = TestDataFactory.createAccounts(1);
    accts[0].OwnerId = UserInfo.getUserId();
    insert accts;

    Contact[] conts = TestDataFactory.createContacts(1,accts[0].Id);
    insert conts;

    Product2[] prods = new List<Product2>{
        new Product2(Name = 'CG Base Bundle', IsActive = true)
    };
    insert prods;

    Id pricebookId = Test.getStandardPricebookId();
    PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pricebookId, Product2Id = prods[0].Id, UnitPrice = 1020, IsActive = true);
    insert pbe;

    Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id,1);
    opps[0].RecordTypeId = [SELECT Id FROM RecordType WHERE sObjectType = 'Opportunity' AND Name = 'Retention'][0].Id;
   // opps[0].OwnerId = UserInfo.getUserId(); Changed below for SA-436
    opps[0].OwnerId = usersWithManager[0].Id;
    opps[0].Pricebook2Id = pricebookId;
    opps[0].AccountId = accts[0].Id;
    opps[0].QuotePrimaryContact__c = conts[0].Id;
    insert opps;

    SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
    quotes[0].SBQQ__StartDate__c = System.today().addMonths(1);
    quotes[0].OwnerId = UserInfo.getUserId();
    insert quotes;

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
        Pricebook2Id = pricebookId,
        OwnerId = UserInfo.getUserId()
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
    contractRecord.Initial_Term_End_Date__c = System.today().addMonths(3);
    contractRecord.OwnerId = UserInfo.getUserId();
    insert contractRecord;

    SBQQ__Subscription__c sub = TestDataFactory.createCPQSubsForProducts(prods, accts[0].Id)[0];
    sub.SBQQ__Contract__c = contractRecord.Id;
    sub.SBQQ__NetPrice__c = 100;
    insert sub;    

    quotes[0].SBQQ__MasterContract__c = contractRecord.Id;
    update quotes;

    Case caseRecord = TestDataFactory.createCases(1, accts[0].Id)[0];
    caseRecord.RecordTypeId = [SELECT Id FROM RecordType WHERE sObjectType = 'Case' AND Name = 'Cancellations'][0].Id;
    caseRecord.Related_Contract__c = contractRecord.Id;
    caseRecord.Related_Opportunity__c = opps[0].Id;
    caseRecord.Status = 'Closed';
    caseRecord.Sub_Status__c='Complete';
    caseRecord.Case_Resolution__c = 'Full Cancellation';
    caseRecord.OwnerId = UserInfo.getUserId();
    caseRecord.CountryCode__c = 'CA';
    caseRecord.CurrencyIsoCode = 'CAD';
    insert caseRecord;

    opps[0].Cancellation_Case__c = caseRecord.Id;
    opps[0].SBQQ__AmendedContract__c = contractRecord.Id;
    update opps;

    TriggerHandler.clearAllBypasses();
	}

  static testMethod void closeWonRetentionOppTest() {
    
    Test.startTest();

    List<Opportunity> opps = [
      SELECT Id, StageName, Cancellation_Case__c, Cancellation_Case__r.Cancellation_Effective_Date__c
      FROM Opportunity
      WHERE RecordType.Name = 'Retention' AND IsClosed = FALSE
      LIMIT 1
    ];
    Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
    adminEscape.Exclude_from_Validation_Rules__c = true;
    upsert adminEscape;
    
    CaseTriggerFunctions.clonePrimaryQuoteWithRelatedForFullCancellation(new List<Id>{opps[0].Id});
    opps[0].Original_Contract_Spend__c = 1000;
    opps[0].StageName = 'Closed Saved';
    update opps;

		Test.stopTest();

    SBQQ__Quote__c cancellationQuote = [
      SELECT Id, SBQQ__Opportunity2__c, SBQQ__ExpirationDate__c
      FROM SBQQ__Quote__c
      WHERE SBQQ__Opportunity2__c = :opps[0].Id AND SBQQ__Type__c = 'Cancellation'
      LIMIT 1
    ];
    System.assertEquals(System.today(), cancellationQuote.SBQQ__ExpirationDate__c);
	}

  static testMethod void test_stampOpportunitySplit() {

    Test.startTest();

    Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
    adminEscape.Exclude_from_Validation_Rules__c = true;
    upsert adminEscape;

    Opportunity testOpp = [SELECT Id, StageName FROM Opportunity LIMIT 1];
    testOpp.Original_Contract_Spend__c = 1000;
    testOpp.StageName = 'Closed Won';
    update testOpp;

    Test.stopTest();

    OpportunitySplit oppSplit =  [
      SELECT Id, Split_Owner_Role_when_Closed__c, Split_Owner_s_Role__c
      FROM  OpportunitySplit
      WHERE OpportunityId =: testOpp.id LIMIT 1
    ];

    System.assertEquals(oppSplit.Split_Owner_Role_when_Closed__c, oppSplit.Split_Owner_s_Role__c);
  }
  static testMethod void setRenewalEligibleToFalseTest() {
    
    String recordType =  Utilities.getrecordTypeId('opportunity','Renewal');
    Contract con = [SELECT Id FROM Contract LIMIT 1];
    Opportunity opp = [SELECT Id, IsClosed, stageName, RecordTypeId, SBQQ__RenewedContract__c 
                       FROM Opportunity LIMIT 1];
    
    Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
    adminEscape.Exclude_from_Validation_Rules__c = true;
    upsert adminEscape;
      
    opp.RecordTypeId = recordType;
    opp.stageName = 'Closed Won';
    opp.SBQQ__RenewedContract__c = con.Id;
    
    Test.startTest();
    update opp;
    Test.stopTest();
    
    Account a = [SELECT Id,Renewal_Eligible__c FROM Account LIMIT 1];
    System.assertEquals(a.Renewal_Eligible__c, false); 

  }

  
  @IsTest
  static void deltaOLITest() {

    Test.startTest();

    List<Opportunity> opps = [
      SELECT Id, StageName, Cancellation_Case__c, Cancellation_Case__r.Cancellation_Effective_Date__c
      FROM Opportunity
      LIMIT 1
    ];

    Contract con = [SELECT Id FROM Contract LIMIT 1];

    opps[0].SBQQ__Renewal__c = true;
    opps[0].SBQQ__RenewedContract__c = con.Id;
    opps[0].Cancellation_Case__c = null;
    opps[0].SBQQ__AmendedContract__c = null;

    update opps;    

    Test.stopTest();

    List<OpportunityLineItem> oli = [SELECT ID FROM OpportunityLineItem WHERE Quantity < 0];

    System.assertEquals(1, oli.size(), 'There should be 1 OpportunityLineItem record with Qty < 0');
    
  }

  static testMethod void setDefaultOppTypeTest() {

    Test.startTest();

    Opportunity originalOppty = [SELECT Id FROM Opportunity LIMIT 1];
    originalOppty.Type = 'Existing Business';
    update originalOppty;

    Contract contract = [SELECT Id FROM Contract LIMIT 1];
    contract.SBQQ__Opportunity__c = originalOppty.Id;
    update contract;
  
    Account acct = [SELECT Id FROM Account LIMIT 1];
    Opportunity[] amendOppty = TestDataFactory.createOpps(acct.Id,1);
    amendOppty[0].SBQQ__AmendedContract__c = contract.Id;

    insert amendOppty;

    amendOppty = [SELECT Id, Type FROM Opportunity WHERE Id = :amendOppty[0].Id]; 
    
    Test.stopTest();

    System.assertEquals('Existing Business', amendOppty[0].Type);

  }

  //SA-289
  static testMethod void closeLostOpptyDateTest() {

    Test.startTest();

    Opportunity originalOppty = [SELECT Id FROM Opportunity LIMIT 1];
    originalOppty.StageName = 'Closed Lost';
    update originalOppty;    

    originalOppty = [SELECT Id, CloseDate FROM Opportunity WHERE Id = :originalOppty.Id]; 
    
    Test.stopTest();

    System.assertEquals(System.today(), originalOppty.CloseDate);

  }
  //SA-436
  static testmethod void setManagerEmailTest(){

    Opportunity testOpp = [SELECT Id, Opp_Owner_Manager_Auto_Close__c, Opp_Owner_Manager_Email__c, OwnerId FROM Opportunity LIMIT 1];
    testOpp.Opp_Owner_Manager_Auto_Close__c = NULL;
    
    Test.startTest();
    update testOpp;
    testOpp = [SELECT Id, Opp_Owner_Manager_Auto_Close__c, Opp_Owner_Manager_Email__c, OwnerId FROM Opportunity LIMIT 1];
    System.assertNotEquals(testOpp.Opp_Owner_Manager_Auto_Close__c, NULL);
    Test.stopTest();
  }

}