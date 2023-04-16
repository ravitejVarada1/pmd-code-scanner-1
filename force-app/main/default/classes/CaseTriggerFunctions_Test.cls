@IsTest
private class CaseTriggerFunctions_Test {

    @testsetup static void testData() {
        
        Test.startTest();

        TriggerHandler.bypass('OpportunityTriggerHandler');
        TriggerHandler.bypass('CPQQuoteTriggerHandler');
        TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
        TriggerHandler.bypass('OrderTriggerHandler');
        TriggerHandler.bypass('ContractTriggerHandler');
        TriggerHandler.bypass('CPQ_Subscription_TriggerHandler');

        TriggerHandler.bypass('AccountTriggerHandler');
        // TriggerHandler.bypass('CaseTriggerHandler');
        TriggerHandler.bypass('OpportunityTriggerHandler');
        TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
        TriggerHandler.bypass('OrderTriggerHandler');

        // accounts
        List<Account> accs = TestDataFactory.createAccounts(2);
        accs[0].BillingCountryCode = 'US';
        accs[0].Name = 'View on CG Test';
        accs[1].Name = 'CarGurus Account';
        insert accs;
        
        // service providers
        List<Service_Provider__c> serviceProvider = TestDataFactory.createServiceProviders(1, accs[0].Id);
        serviceProvider[0].Billing_Country__c = 'US';
        insert serviceProvider;

        // users
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        List<User> users = new List<User>();
        User userSobject = TestDataFactory.createUser(true, p);
        User userSobject2 = TestDataFactory.createUser(true, p);
        userSobject2.userName = 'standarduser2345@testorg.com';
        users.add(userSobject);
        users.add(userSobject2);
        insert users;

        // account team members
        List<String> teamRole = new List<String>{'Dealer Relations', 'Acquisitions'};
        List<Id> userList = new List<Id>{userSobject.Id, userSobject2.Id};    
        List<AccountTeamMember> teamMemberList = TestDataFactory.createAccountTeamMember(accs[0].Id, TeamRole, userList);
        insert teamMemberList;

        // zuora accounts
        List<Zuora__CustomerAccount__c>  billingAccount = TestDataFactory.createZuoraAccount(1, accs[0]);
        billingAccount[0].Zuora__DefaultPaymentMethod__c = 'Check';
        insert billingAccount[0];
        accs[0].Billing_Account_Zuora__c = billingAccount[0].Id;
        update accs[0];

        // payment methods
        List<Zuora__PaymentMethod__c> paymentMethod = TestDataFactory.createPaymentMethod(1, billingAccount[0]);
        insert paymentMethod [0];
        
        // products
        List<Product2> product = TestDataFactory.createProducts(1);
        product[0].Name = 'Area Boost - 300 Miles';
        product[0].Activation_Case_Queue__c ='Area Boost Activation Case Queue';
        product[0].Deactivation_Case_Queue__c ='Area Boost Activation Case Queue';
        product[0].Manually_Provisioned__c = true;
        product.add(new Product2(Name = 'CG Base Bundle', IsActive = true));
        insert product;       

        //Instantiate the Pricebook2 record with StandardPricebookId
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        //Execute an update DML on the Pricebook2 record, to make IsStandard to true
        update standardPricebook;

        PricebookEntry pbe = TestDataFactory.createPriceBookEntry(standardPricebook.Id, product[0].Id);
        insert pbe;

        // opportunities
        Opportunity[] opps = TestDataFactory.createOpps(accs[0].Id,1);
        opps[0].RecordTypeId = [SELECT Id FROM RecordType WHERE sObjectType = 'Opportunity' AND Name = 'Retention'][0].Id;
        insert opps;

        // quotes
        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accs[0].Id, opps[0].Id, 1);
        insert quotes;
    
        // quote lines
        SBQQ__QuoteLine__c[] quoteLines = new List<SBQQ__QuoteLine__c>{
            new SBQQ__QuoteLine__c(
                Fulfillment_Account__c = accs[0].Id,
                SBQQ__Product__c = product[0].Id,
                SBQQ__Quote__c = quotes[0].Id,
                SBQQ__Quantity__c = 1)
        };
        insert quoteLines;

        // orders
        List<Order> orders = TestDataFactory.createOrders(1, accs[0].Id, null, standardPricebook.Id);
        insert orders;

        // order products
        List<OrderItem> orderProducts = TestDataFactory.createOrderItems(orders[0].Id, product);
        for(OrderItem oi : orderProducts) {
          oi.PricebookEntryId = pbe.id;
          oi.SBQQ__Status__c ='Pending Activation';
        }
        insert orderProducts;

        // contracts
        Contract contractRecord = TestDataFactory.createContract(accs[0].Id);
        contractRecord.EndDate = System.today().addMonths(3);
        insert contractRecord;

        // zuora subscriptions
        List<Zuora__Subscription__c> zsubs = TestDataFactory.createZSubscriptions(accs[0].Id, 1);
        zsubs[0].Zuora__AutoRenew__c = true;
        insert zsubs[0];
        
        List<SBQQ__Subscription__c> subs = TestDataFactory.createCPQSubsForProducts(product, accs[0].Id);
        for(SBQQ__Subscription__c sub : subs) {
          sub.Zuora_Subscription__c = zsubs[0].Id;
          sub.SBQQ__Contract__c =  contractRecord.Id;
          sub.Fulfillment_Account__c = accs[0].Id;
        }
        insert subs;

        // cases
        List<Case> caseList = TestDataFactory.createCases(1, accs[0].id);
        Id devRecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case','Onboarding');
        caseList[0].RecordTypeId = devRecordTypeId;

        Case entitlementCase = TestDataFactory.createCases(1, accs[0].id)[0];
        Id SSDId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case','Sales_Support_Desk');
        entitlementCase.RecordTypeId = SSDId;
        entitlementCase.Reason = 'Activation Issue';
        entitlementCase.Origin = 'Internal';
        entitlementCase.Related_Dealer_Account__c = accs[0].id;
        caseList.add(entitlementCase);

        Case caseRecord = TestDataFactory.createCases(1, accs[0].Id)[0];
        caseRecord.RecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case','Cancellations');
        caseRecord.Status = 'New';
        caseRecord.Case_Resolution__c = 'Full Cancellation';
        caseRecord.Related_Opportunity__c = opps[0].Id;
        caseRecord.Related_Contract__c = contractRecord.Id;
        caseRecord.Origin = 'Web';
        caseList.add(caseRecord);
        
        Case activationCaseRecord = TestDataFactory.createCases(1, accs[0].Id)[0];
        activationCaseRecord.RecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Product_Provision');
        activationCaseRecord.Status = 'New';
        activationCaseRecord.Subject = 'Product Activation';
        activationCaseRecord.AccountId = accs[0].Id;
        activationCaseRecord.Order__c = orders[0].Id;
        activationCaseRecord.Order_Product__c = orderProducts[0].Id;
        caseList.add(activationCaseRecord);
        insert caseList;

        opps[0].Cancellation_Case__c = caseRecord.Id;
        opps[0].SBQQ__AmendedContract__c = contractRecord.Id;
        update opps;

        TriggerHandler.clearAllBypasses();

        Test.stopTest();
          
    }
    
    
    static testMethod void viewOnCGtest() {
      Test.startTest(); 
        
      Account a = [SELECT Id FROM Account WHERE Name = 'View on CG Test' LIMIT 1];
      Service_Provider__c sp = [SELECT Id, View_On_CG__c from Service_Provider__c where Account__c =:a.Id];
      List<Case> cases = TestDataFactory.createCases(1, a.Id);
      insert cases;

      Case c = [SELECT Id, AccountId, Service_Provider_URL__c, View_On_CG__c FROM Case WHERE Id=:cases[0].Id];
      c.Related_Dealer_Account__c = a.Id;
      c.Status = 'Closed';
      update c;
      c = [SELECT Id, AccountId, Related_Dealer_Account__c, Service_Provider_URL__c, View_On_CG__c FROM Case WHERE Id=:cases[0].Id];
      Test.stopTest();
      System.assert(c.View_On_CG__c.contains(sp.View_On_CG__c.split('\"')[1]), 'Service Provider URL not succesfully set');
    }


    static testMethod void businessHoursTest() {
        Test.startTest();
        Account a = [SELECT id FROM Account LIMIT 1];
        List<Case> cases = TestDataFactory.createCases(1, a.Id);
        insert cases;

        Case c = [SELECT id, IsCreatedDuringBusinessHours__c, Account.BillingCountryCode, CreatedDate FROM Case LIMIT 1];

        Boolean isDuringBusinessHours = false;
        if(c.Account.BillingCountryCode != null) {
            isDuringBusinessHours = Utilities.isDateDuringBusinessHours(c.CreatedDate, c.Account.BillingCountryCode);
        }
        Test.stopTest();
        //System.assertEquals(isDuringBusinessHours, c.IsCreatedDuringBusinessHours__c);
    }
    
    static testMethod void populateCountryCodeTest() {
        Test.startTest();
        Account a = [SELECT id,BillingCountry FROM Account LIMIT 1];
        List<Case> cases = TestDataFactory.createCases(1, a.Id);
        insert cases;
        Case c = [SELECT id,CountryCode__c,accountId FROM Case LIMIT 1];
        System.assertEquals('US', c.CountryCode__c);
        
        List<Account> accs1 = TestDataFactory.createAccounts(1);
        accs1[0].BillingCountryCode = 'CA';
        insert accs1;
        
        c.accountId =accs1[0].id;
        update c;
        
        Case c1 = [SELECT id,accountId,CountryCode__c FROM Case LIMIT 1];
        System.assertEquals('CA', c1.CountryCode__c);

        test.stopTest();
    }

    static testMethod void activateRelatedOrderProductTest(){
        Test.startTest();
        OrderItem oProd = [SELECT Id FROM OrderItem LIMIT 1 ];
        Case c = [SELECT Id, Status FROM Case WHERE Order_Product__c =:oProd.Id LIMIT 1];
        c.Status='Closed';
        update c ;
        Test.stopTest();
        OrderItem oProd1 = [SELECT Id, SBQQ__Status__c FROM OrderItem LIMIT 1 ];
        System.assertEquals('Activated', oProd1.SBQQ__Status__c);
    }

    /*static testMethod void updateAndInsertRelatedDataForCancellationsTest() {
      Test.startTest();

      Case caseRecord = [
        SELECT Id, Status, Related_Contract__c, Related_Opportunity__c
        FROM Case
        WHERE RecordType.Name = 'Cancellations' AND Status = 'New'
        LIMIT 1
      ];

      Contract contractRecord = [
        SELECT Id
        FROM Contract
        LIMIT 1
      ];
      
      caseRecord.Status = 'Closed';
      caseRecord.Sub_Status__c='Complete';
      caseRecord.Related_Contract__c = contractRecord.Id;
      update caseRecord ;
      Test.stopTest();

      List<SBQQ__Subscription__c> subs = [
        SELECT Id, Cancellation_Notice_Date_Formula__c
        FROM SBQQ__Subscription__c
        WHERE SBQQ__Contract__c = :contractRecord.Id
      ];
      System.assert(subs.size() > 0);
      System.assertEquals(System.today(), subs[0].Cancellation_Notice_Date_Formula__c);

      List<SBQQ__Quote__c> quotes = [
        SELECT Id
        FROM SBQQ__Quote__c
        WHERE SBQQ__Opportunity2__c = :caseRecord.Related_Opportunity__c
      ];
      System.assertEquals(2, quotes.size());

      List<Contract> contracts = [
        SELECT Id, Cancellation_Effective_Date__c
        FROM Contract
        WHERE Id = :contractRecord.Id AND Cancellation_Effective_Date__c != NULL
      ];
      System.assert(contracts.size() > 0);

    }*/
  
    static testMethod void sendNotification(){
        Test.startTest();
        Case caseSobject = [SELECT ID, OwnerId FROM Case WHERE Origin = 'Email' LIMIT 1];
        User userSobject = [SELECT ID FROM User WHERE UserName = 'standarduser234@testorg.com'];
        caseSobject.OwnerId = userSobject.Id;
        update caseSobject;
        Test.stopTest();
    }

    static testMethod void testCGAccountAssociation() {

      Test.startTest();
      Case caseRecord = new Case(
        RecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Planning_and_Commissions'][0].Id
      );
      insert caseRecord;

      Case caseRecordRequeried = [
        SELECT Id, AccountId, Account.Name
        FROM Case
        WHERE Id = :caseRecord.Id
      ];
      Test.stopTest();

      //System.assertEquals('CarGurus Account', caseRecordRequeried.Account.Name);

    }
    
        static testMethod void testCaseAssignment() {
        
        List<Account> accs = TestDataFactory.createPersonalAccounts(1);
        insert accs;
        
        List<Offer__c> offer = TestDataFactory.createOffer(1,accs);
        insert offer;
        List<Case> createCase = TestDataFactory.createCSCase(1,accs);
        
        
        Test.startTest();
        setupSOSLResults(true, true, true,true);
        insert createCase;
        Test.stopTest();
                
        case c1 = [select Id, CreatedById, OwnerId, status From Case WHERE Id=: createCase[0].id LIMIT 1];
        System.assertEquals('New', c1.Status);
        System.assertNotEquals(c1.CreatedById, c1.OwnerId);
        
    }
    
    static testMethod void testUpperAssignment() {
        
        
        List<Account> accs = TestDataFactory.createPersonalAccounts(1);
        insert accs;
        
        List<Offer__c> offer = TestDataFactory.createOffer(1,accs);
        offer[0].NewStage__c='ACCEPTED';
        insert offer;
        
        List<Case> createCase = TestDataFactory.createCSCase(1,accs);
        
        Test.startTest();
        setupSOSLResults(true, true, true,true);
        insert createCase;
        Test.stopTest();
        
        case c1 = [select Id,status From Case LIMIT 1];
        System.assertEquals('New', c1.Status);
        
    }
    
    static testMethod void testMulAssignment() {
        
        
        List<Account> accs = TestDataFactory.createPersonalAccounts(2);
        insert accs;
        
        List<Offer__c> offer = TestDataFactory.createOffer(2,accs);
        offer[0].NewStage__c='LINK_SENT';
        offer[1].NewStage__c='LINK_SENT';
       	insert offer;
        
        List<Case> testcreateCase = TestDataFactory.createCSCase(1,accs);
        List<Case> createCase = TestDataFactory.createCSCase(1,accs);
        insert testcreateCase;
        
        Test.startTest();
        setupSOSLResults(true, true, true,true);
        insert createCase;
        Test.stopTest();
        
        case c1 = [select Id,status From Case LIMIT 1];
        System.assertEquals('New', c1.Status);
        
    }

    static testMethod void testManualEntryCaseAssignment() {
      Profile csp = [SELECT Id FROM Profile WHERE Name='Consumer Support - Rep'];
      User csUserSobject = TestDataFactory.createUser(true, csp);
      csUserSobject.userName = 'csuser234@testorg.com';
      insert csUserSobject;

      system.runAs(csUserSobject){
        List<Account> accs = TestDataFactory.createPersonalAccounts(1);
        insert accs;
        
        List<Offer__c> offer = TestDataFactory.createOffer(1,accs);
        insert offer;
        List<Case> createCase = TestDataFactory.createCSCase(1,accs);
        Test.startTest();
        setupSOSLResults(true, true, true,true);
        insert createCase;
        Test.stopTest();

        case c1 = [select Id,status, createdbyid, ownerid From Case WHERE Id =: createCase[0].Id LIMIT 1];
        System.assertEquals(csUserSobject.id, c1.OwnerId);
        System.assertEquals(c1.CreatedById, c1.OwnerId);

      }
    }

    static testMethod void testConvertedCaseAssignment() {
        
      Account acc = [SELECT Id,BillingCountry FROM Account LIMIT 1];
      Case billingCase = TestDataFactory.createCases(1, acc.Id)[0];
      billingCase.RecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Billing');
      billingCase.Subject = 'Test';
      billingCase.Description = 'Test';
      billingCase.Status = 'New';
      billingCase.Reason = 'Billing: Address/Contact/Info Update';
      billingCase.AccountId = acc.Id;
      billingCase.Force_Run_Assignment_Rules__c = true;
      insert billingCase;

      String originalOwnerId = billingCase.ownerId;
      billingCase.RecordTypeId = CaseTriggerFunctions.caseRTNameIdMap.get('Consumer Support');
      Test.startTest();
      update billingCase;
      Test.stopTest();

      case c1 = [select Id,status, createdbyid, ownerid From Case WHERE id =: billingCase.Id LIMIT 1];
      System.assertNotEquals(originalOwnerId, c1.ownerId);
      System.assertNotEquals(c1.CreatedById, c1.ownerId);        
    }
    
    private static void setupSOSLResults(Boolean addAccount, Boolean addContact, Boolean addCase,Boolean addOffer)
    {
        
        Id consumerSupportRTId = CaseTriggerFunctions.caseRTNameIdMap.get('Consumer Support');
        Contact testContact = [SELECT Id, AccountId
                               FROM Contact
                               WHERE IsPersonAccount= True LIMIT 1][0];
        
        ID testCaseId;
        for (Case c : [SELECT Id
                       FROM Case WHERE RecordTypeId = : consumerSupportRTId 
                       LIMIT 1])
        {
            testCaseId = c.Id;
        }
        
        Offer__c testOffer = [select id,Offer_Expiration_Date__c,NewStage__c from Offer__c Limit 1]; 
        
        List<ID> searchResultIds = new List<ID>();
        
        if (addAccount){
            searchResultIds.add(testContact.AccountId);
        }
        
        if (addContact){
            searchResultIds.add(testContact.Id);
        }
        
        if (addCase){
            searchResultIds.add(testCaseId);
        }
        if(addOffer){
            searchResultIds.add(testOffer.Id);
        }
        
        Test.setFixedSearchResults(searchResultIds);
    }

    static testMethod void setPriorityBillingCaseTest() {

      Test.startTest();    

      Account acc = [SELECT Id,BillingCountry FROM Account LIMIT 1];
      
      Case billingCase = TestDataFactory.createCases(1, acc.Id)[0];
        billingCase.RecordTypeId = Utilities.getrecordTypeId('Case', 'Billing');
        billingCase.Status = 'New';
        billingCase.Reason = 'Billing: Address/Contact/Info Update';
        billingCase.AccountId = acc.Id;

      insert billingCase;
      
      Test.stopTest();

      Case c = [SELECT Id, Priority FROM CASE WHERE Id = :billingCase.Id];

      System.assertEquals('Low', c.Priority, 'The Billing Case Priority is Low');

    }

    static testMethod void testpopulateContactOnCase() {
      
        List<Account> accs = TestDataFactory.createPersonalAccounts(1);
        insert accs;
        List<Account> accs1 = TestDataFactory.createPersonalAccounts(1);
        insert accs1;

        List<Case> testcreateCase = TestDataFactory.createCSCase(1,accs);
        insert testcreateCase;
        
        Test.startTest();
        for(case c : testcreateCase){
            c.AccountId= accs1[0].id;
            update c;
        }
        Test.stopTest();
        
        case c1 = [select Id,status From Case LIMIT 1];
        System.assertEquals('New', c1.Status);
        
    }
    
    static testMethod void testRemoveContactOnCase() {
        
        List<Account> accs = TestDataFactory.createPersonalAccounts(1);
        insert accs;
        
        List<Case> testcreateCase = TestDataFactory.createCSCase(1,accs);
        insert testcreateCase;
        
        Test.startTest();
            for(case c : testcreateCase){
                c.AccountId= null;
                update c;
            }
        Test.stopTest();
        
        case c1 = [select Id,status From Case LIMIT 1];
        System.assertEquals('New', c1.Status);
        
    }

    static testMethod void getCGDurationTimeTest() {

      Test.startTest();    

      Account acc = [SELECT Id,BillingCountry FROM Account LIMIT 1];
      
      Case billingCase = TestDataFactory.createCases(1, acc.Id)[0];
        billingCase.RecordTypeId = Utilities.getrecordTypeId('Case', 'Billing');
        billingCase.Status = 'New';
        billingCase.Reason = 'Billing: Address/Contact/Info Update';
        billingCase.AccountId = acc.Id;

      insert billingCase;

      billingCase.Status = 'Closed';
      billingCase.Case_Resolution__c = 'No Action Needed';
      update billingCase;

      Case c = [SELECT Id, CG_Case_Duration__c, Re_Opened_Date_Time__c FROM CASE WHERE Id = :billingCase.Id];
      System.assertEquals(true, c.CG_Case_Duration__c != null, 'CG Case Duration was calculated');

      c.Status = 'Reopen';
      update c;

      Case c2 = [SELECT Id, CG_Case_Duration__c, Re_Opened_Date_Time__c FROM CASE WHERE Id = :billingCase.Id];
      System.assertEquals(true, c2.Re_Opened_Date_Time__c != null, 'Re-Opened Date Time was stamped');

      Test.stopTest();

    }

    // Commented out for SA-870
    /*
    static testMethod void createSecondUSOnboardingCase() {

      Test.startTest();    

      Account acc = [SELECT Id,BillingCountry FROM Account WHERE BillingCountryCode = 'US' LIMIT 1];
      acc.Type = 'Customer';
      update acc;
      SBQQ__Quote__c quote = [SELECT Id, SBQQ__Opportunity2__c FROM SBQQ__Quote__c LIMIT 1];
      
      Case USonboadringCase = TestDataFactory.createCases(1, acc.Id)[0];
        USonboadringCase.RecordTypeId = Utilities.getrecordTypeId('Case', 'Onboarding');
        USonboadringCase.Status = 'New';
        USonboadringCase.Reason = 'Onboarding Value Review';
        USonboadringCase.AccountId = acc.Id;
        USonboadringCase.Related_Quote__c = quote.Id;
        USonboadringCase.Related_Opportunity__c = quote.SBQQ__Opportunity2__c;

      insert USonboadringCase;

      USonboadringCase.Case_Resolution__c = 'Fully engaged';
      USonboadringCase.Resolution_Comments__c = 'test';
      USonboadringCase.Dealer_Review_Assessment__c = 'Needs Improvement';
      USonboadringCase.Status = 'Closed';

      update USonboadringCase;

      List<Case> secondUSCase = [SELECT Id, Reason FROM CASE WHERE Reason = '3 Month Value Review'];
      System.assertEquals(1, secondUSCase.size(),'Second US Onboarding case was created');

      Test.stopTest();

    }
    */

    static testMethod void testDataIntegrityCaseCreation() {
      Test.startTest(); 
      ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
      List<Account> accs = TestDataFactory.createAccounts(1);
        accs[0].BillingCountryCode = 'US';
        accs[0].Name = 'View on CG Test';
        accs[0].recordTypeID = dealerAccountRecordTypeId;
        insert accs;
        
      List<Account> accs1 = TestDataFactory.createPersonalAccounts(1);
      insert accs1;
    
      Case ConsumerSupportCase = TestDataFactory.createCases(1, accs[0].id)[0];
      ConsumerSupportCase.RecordTypeId = Utilities.getrecordTypeId('Case', 'Consumer_Support');
      ConsumerSupportCase.Status = 'New';
      ConsumerSupportCase.AccountId = accs1[0].id;
      
      insert ConsumerSupportCase;

      ConsumerSupportCase.Case_Resolution__c = 'Reported to Integrity';
      ConsumerSUpportCase.Related_Dealer_Account__c = accs[0].id;
      ConsumerSupportCase.Reason = 'Digital Deal'; 
      ConsumerSupportCase.Category__c = 'Trade-in';
      ConsumerSupportCase.Status = 'Closed';
      update ConsumerSupportCase;

      List<Case> diCase = [SELECT Id, Reason FROM case WHERE Reason = 'Need PI Investigation'];
      System.assertEquals(1, diCase.size(),'Product Integrity case is created');
      Test.stopTest();
    }

    static testmethod void testAssignDDCases(){
      Test.startTest();
      //create account
      ID DdAccountRTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
      Account DdAccount = TestDataFactory.createAccounts(1)[0];
      DdAccount.recordtypeId = DdAccountRTypeId;
      DdAccount.BillingCountryCode = 'US';
      DdAccount.Name = 'DealerName';
      insert DdAccount;
      //create case
      
      Id autoFiUpdateId = Utilities.getCaseQueueMap().get('Digital Deal - AutoFi Update');
      Case DdCase = TestDataFactory.createCases(1, DdAccount.Id)[0];
      DdCase.RecordTypeId = Utilities.getrecordTypeId('Case', 'Product_Provision');
      DdCase.Status = 'New';
      DdCase.OwnerId = autoFiUpdateId;
      String caseSubject = 'AutoFi Update' + ':' + DdAccount.Id;
      //setting case subject to what it would be from alchemer
      DdCase.Subject = caseSubject;
      DdCase.Origin = 'Email';
      
      insert DdCase;
      system.debug('subject is '+ DdCase.Subject);
     
      //requery for case
      Case DdCase2 = [SELECT Id, Subject, Origin FROM Case WHERE ID = :DdCase.Id];
      system.debug('subject is '+DdCase2.Subject);
      system.debug('origin is '+DdCase2.Origin);
      system.assertEquals('AutoFi Update:DealerName',DdCase2.Subject);
      Test.stopTest();

    }

    static testMethod void testCGCaseAssignment() {

        User supportUser = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name = 'Support - Rep' limit 1];
        Account a = [SELECT Id, Name FROM Account limit 1];
        Case issueProcessorCase = new Case(
            AccountId = a.Id,
            Origin = 'Issue Processor',
            RecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case','Support'),
            Force_Run_Assignment_Rules__c = true,
            Status = 'New',
            Subject = 'Inventory is Missing'
        );
        insert issueProcessorCase;

        Test.startTest();

        issueProcessorCase.OwnerId = supportUser.Id;
        issueProcessorCase.Status = 'In Progress';
        update issueProcessorCase;

        issueProcessorCase.Status = 'Closed';
        update issueProcessorCase;

        Test.stopTest();

        issueProcessorCase = [SELECT Id, OwnerId, Force_Run_Assignment_Rules__c FROM Case WHERE Id =: issueProcessorCase.Id limit 1];
        System.assertEquals(issueProcessorCase.OwnerId,supportUser.Id);
        System.assertEquals(issueProcessorCase.Force_Run_Assignment_Rules__c, false);

    }
}