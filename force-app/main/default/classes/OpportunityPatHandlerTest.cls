/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        05/06/2021
* modified:       05/06/2021
* created jira:   BR-878
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class OpportunityPatHandlerTest {
    
    private static String orderingErrorString = 'Test Errors<orderBrokenSpacer>TestErrors';
    
    @TestSetup
    static void testSetup(){
 
        Test.startTest();
        Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
        adminEscape.Exclude_from_Validation_Rules__c = true;
        upsert adminEscape;
        
        Id pricebookId = Test.getStandardPricebookId();
        
        List<Product2> testProds = TestDataFactory.createProducts(2);
        insert testProds;
        Id testProdId = testProds[0].Id;
        
        PriceBookEntry testPbe = new PriceBookEntry(
            isActive = true,
            Pricebook2Id = pricebookId,
            Product2Id  = testProdId,
            UnitPrice = 100
        );  
        insert testPbe;
        
        List<Account> testAccounts = TestDataFactory.createAccounts(1);
        insert testAccounts;
        Id testAccountId = testAccounts[0].Id;
        
        Contact[] conts = TestDataFactory.createContacts(1,testAccounts[0].Id);
        insert conts;

        List<Opportunity> testOpps = TestDataFactory.createOpps(testAccountId , 1);
        testOpps[0].PriceBook2Id = pricebookId;
        testOpps[0].AccountId = testAccounts[0].Id;
        testOpps[0].QuotePrimaryContact__c = conts[0].Id;
        insert testOpps;
        Id testOppId = testOpps[0].Id;
        
        List<SBQQ__Quote__c> testQuotes = TestDataFactory.createQuotes(testAccountId, testOppId, 1);
        testQuotes[0].SBQQ__PriceBook__c = pricebookId;
        insert testQuotes;
        Id quoteId = testQuotes[0].Id;
        
        List<SBQQ__QuoteLine__c> testQuoteLines = TestDataFactory.createQuoteLines(
            quoteId, 
            testAccountId, 
            new Set<ID>{testProdId}
        );
        testQuoteLines[0].SBQQ__PricebookEntryId__c = testPbe.Id;
        testQuoteLines[0].Billing_Account__c = testAccountId;
        
        insert testQuoteLines;
        
        User usr = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]; 
        System.runAs(usr) {
            setupTerritory(testAccounts);   
        }
        Test.stopTest(); 
    }

    private static void setupTerritory(List<Account> accts) {

        Territory2Model tModel = new Territory2Model(
            Name = 'Test Model',
            DeveloperName = 'Test_Model'
        );
        insert tModel;

        Territory2Type tType = [SELECT Id FROM Territory2Type limit 1];

        Territory2 newTerritory = new Territory2(
            AccountAccessLevel = 'Edit',
            OpportunityAccessLevel = 'Edit',
            CaseAccessLevel = 'Read',
            DeveloperName = 'Test_Territory',
            Name = 'Test Territory',
            Territory2ModelId = tModel.Id,
            Territory2TypeId = tType.Id,
            Is_Granular__c = true
        );
        insert newTerritory;

        ObjectTerritory2Association[] otas = new List<ObjectTerritory2Association>();
        for (Account a : accts) {
            ObjectTerritory2Association ota = new ObjectTerritory2Association(
                Territory2Id = newTerritory.Id,
                ObjectId = a.Id,
                AssociationCause = 'Territory2Manual'
            );
            otas.add(ota);
        }
        insert otas;
    }


    
    
    //- Jira: BR-878
    //- Purpose: Tests the main LWC controller method for the pat LWC. Runs the OpportunityPatHandler.getWrapper
    //method, and that method runs the OpportunityPatChecker.checkOpps method. This method is testing the scenario 
    //where all steps have become done, and an order gets generated
    @isTest
    static void testOppAllStepsDone(){
        
        ID oppId = [select id from opportunity limit 1][0].Id;
        
        SBQQ__QuoteLine__c quoteLine = [SELECT SBQQ__Quote__c, Fulfillment_Account__c
                                        FROM SBQQ__QuoteLine__c
                                        LIMIT 1][0];
        
        Account testAccount = new Account(Id = quoteLine.Fulfillment_Account__c);
        Id testAccountId = testAccount.Id;
        AccountTeamMember newTeam = new AccountTeamMember(AccountId = testAccount.ID,
		TeamMemberRole = 'Account Manager',UserId = userInfo.getuserId());
		insert newTeam;
        
        Zuora__CustomerAccount__c billingAccount = new Zuora__CustomerAccount__c(
            Zuora__Status__c = 'Active',
            Zuora__Account__c = testAccountId
        );
        insert billingAccount;
        Id billingAccountId =  billingAccount.Id;
        
        Zuora__PaymentMethod__c billingPaymentMethod = new Zuora__PaymentMethod__c(
            Zuora__PaymentMethodStatus__c = 'Active',
            Zuora__BillingAccount__c = billingAccountId,
            Zuora__Type__c = 'CreditCard'
        );
        insert billingPaymentMethod;
        
        testAccount.Billing_Account_Zuora__c  = billingAccountId;
        update testAccount;
        
        List<Service_Provider__c> testSpids = TestDataFactory.createServiceProviders(1, testAccountId);
        testSpids[0].Inventory_Source__c = 'Test';
        testSpids[0].Dashboard_Admin_Exist__c = true;
        testSpids[0].Dealer_Email_Exist__c = true;
        insert testSpids;
        
        
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(Id = quoteLine.SBQQ__Quote__c);
        testQuote.Payment_Method__c = 'Credit Card';
        testQuote.SBQQ__Status__c = ConstantsUtil.QUOTE_STATUS_APPROVED;
        testQuote.SBQQ__StartDate__c = Date.Today();
        
        dsfs__DocuSign_Status__c testDocuSignStatus = new dsfs__DocuSign_Status__c(
            dsfs__Envelope_Status__c  = 'Completed',
            Quote_CPQ__c = testQuote.Id
        );
        insert testDocuSignStatus;
        
        insert new dsfs__DocuSign_Recipient_Status__c(
            dsfs__Parent_Status_Record__c = testDocuSignStatus.Id,
            dsfs__Account__c = testAccount.Id,
            dsfs__Date_Signed__c = Datetime.now(),
            dsfs__DocuSign_Recipient_Id__c = 'EXT-RCP-001'
        );
        
        update testQuote;
        
        Test.startTest();
        OpportunityPatHandler.getWrapper(oppId, null, false);
        
        update new SBQQ__Quote__c(Id = testQuote.Id,
                                  Payment_Method__c = 'Check');
        
        billingAccount.Zuora__DefaultPaymentMethod__c = 'Check';
        update billingAccount;
        
        OpportunityPatHandler.getWrapper(oppId, null, false);
        Test.stopTest();
        
        Opportunity_Tracker__c oppTracker = [SELECT Zuora_ActivePaymentMethodMatch__c, Zuora_QuotePaymentMethod__c,
                                             Zuora_ActiveBillingAccounts__c, Spid_HasInventory__c,
                                             DocusignComplete__c, Spid_CDA__c, Spid_DealerEmail__c, Quote_Approved__c,
                                             Quote_StartDate__c, QuoteOrderingErrors__c,Granular_Territory_Assigned__c
                                             FROM Opportunity_Tracker__c
                                             LIMIT 1][0];
        
        System.assert(oppTracker.Zuora_ActivePaymentMethodMatch__c);
        System.assert(oppTracker.Zuora_QuotePaymentMethod__c);
        System.assert(oppTracker.Zuora_ActiveBillingAccounts__c);
        System.assert(oppTracker.Spid_HasInventory__c);
        System.assert(oppTracker.DocusignComplete__c);
        System.assert(oppTracker.Spid_CDA__c);
        System.assert(oppTracker.Spid_DealerEmail__c);
        System.assert(oppTracker.Quote_Approved__c);
        System.assert(oppTracker.Quote_StartDate__c);
        System.assert(oppTracker.Granular_Territory_Assigned__c);
        
        
        Opportunity testOpp = [SELECT StageName
                               FROM Opportunity
                               LIMIT 1][0];
        
        System.assertEquals(ConstantsUtil.OPP_STATUS_CLOSED_WON, testOpp.StageName);
        
        testQuote = [SELECT SBQQ__Status__c
                     FROM SBQQ__Quote__c
                     LIMIT 1][0];
        
        System.assertEquals(ConstantsUtil.QUOTE_STATUS_ORDER_GENERATED, testQuote.SBQQ__Status__c);
        
        
        List<Order> orderList = [SELECT Id, OrderNumber
                                 FROM Order
                                 WHERE OpportunityId = :oppId];
        
        OpportunityPatHandler.patWrapper testPatWrap = new OpportunityPatHandler.patWrapper(oppTracker, testOpp.Id, testQuote);
        
    }
    
    //- Jira: BR-878
    //- Purpose: Tests the main LWC controller method for the pat LWC. Runs the OpportunityPatHandler.getWrapper
    //method, and that method runs the OpportunityPatChecker.checkOpps method. This method is testing the scenario 
    //where all steps are not done, and an order does not get generated
    @isTest
    static void testOppNoStepsDone(){
        ID oppId = [select id from opportunity limit 1][0].Id;
        
        Test.startTest();
        OpportunityPatHandler.getWrapper(oppId, null, false);
        Test.stopTest();
        
        Opportunity_Tracker__c oppTracker = [SELECT Zuora_ActivePaymentMethodMatch__c, Zuora_QuotePaymentMethod__c,
                                             Zuora_ActiveBillingAccounts__c, Spid_HasInventory__c,
                                             DocusignComplete__c, Spid_CDA__c, Spid_DealerEmail__c, Quote_Approved__c,
                                             Quote_StartDate__c, QuoteOrderingErrors__c
                                             FROM Opportunity_Tracker__c
                                             LIMIT 1][0];
        
        System.assert(!oppTracker.Zuora_ActivePaymentMethodMatch__c);
        System.assert(!oppTracker.Zuora_QuotePaymentMethod__c);
        System.assert(!oppTracker.Zuora_ActiveBillingAccounts__c);
        System.assert(!oppTracker.Spid_HasInventory__c);
        System.assert(!oppTracker.DocusignComplete__c);
        System.assert(!oppTracker.Spid_CDA__c);
        System.assert(!oppTracker.Spid_DealerEmail__c);
        System.assert(!oppTracker.Quote_Approved__c);
    }
    
    //- Jira: BR-878
    //- Purpose: Tests the method in the pat LWC that updates a single Opportunity Tracker override boolean.
    @isTest
    static void testOverrideChangeHandling(){
        Opportunity_Tracker__c oppTrackerBefore = [SELECT Id
                                                   FROM Opportunity_Tracker__c
                                                   LIMIT 1][0];
        
        Test.startTest();
        OpportunityPatHandler.handleOverrideChangeApex(oppTrackerBefore.Id, 
                                                       'DocusignComplete_Override__c', 
                                                       true, 
                                                       [SELECT Id 
                                                        FROM Opportunity
                                                        LIMIT 1][0].Id);
        Test.stopTest();
        
        Opportunity_Tracker__c oppTrackerAfter = [SELECT DocusignComplete_Override__c
                                                  FROM Opportunity_Tracker__c
                                                  LIMIT 1][0];
        
        System.assert(oppTrackerAfter.DocusignComplete_Override__c);
    }
    
    //- Jira: BR-878
    //- Purpose: Tests the method in the pat LWC that refreshes the page
    @isTest
    static void testPageRefreshWithOverrides(){
        ID oppId = [select id from opportunity limit 1][0].Id;
        
        List<String> currentOverrides = new List<String>();
        
        currentOverrides.add(OpportunityPatHandler.ZUORA_CONFIG_PAYMENT_METHOD);
        
        Test.startTest();
        OpportunityPatHandler.getWrapper(oppId, currentOverrides, true);
        Test.stopTest();
    }

    //- Jira: BR-878
    //- Purpose: Tests the bulkified Batch_CheckOpportunityPats that updates newly completed opportunity trackers
    @isTest
    static void testOppAllStepsDone_Batch(){
        
        ID oppId = [select id from opportunity limit 1][0].Id;
        
        SBQQ__QuoteLine__c quoteLine = [SELECT SBQQ__Quote__c, Fulfillment_Account__c
                                        FROM SBQQ__QuoteLine__c
                                        LIMIT 1][0];
        
        Account testAccount = new Account(Id = quoteLine.Fulfillment_Account__c);
        Id testAccountId = testAccount.Id;
        AccountTeamMember newTeam = new AccountTeamMember(AccountId = testAccount.ID,
		TeamMemberRole = 'Account Manager',UserId = userInfo.getuserId());
		insert newTeam;

        Zuora__CustomerAccount__c billingAccount = new Zuora__CustomerAccount__c(
            Zuora__Status__c = 'Active',
            Zuora__Account__c = testAccountId
        );
        insert billingAccount;
        Id billingAccountId =  billingAccount.Id;
        
        Zuora__PaymentMethod__c billingPaymentMethod = new Zuora__PaymentMethod__c(
            Zuora__PaymentMethodStatus__c = 'Active',
            Zuora__BillingAccount__c = billingAccountId,
            Zuora__Type__c = 'CreditCard'
        );
        insert billingPaymentMethod;

        billingAccount.Zuora__Default_Payment_Method__c = billingPaymentMethod.Id;
        update billingAccount;
        
        testAccount.Billing_Account_Zuora__c  = billingAccountId;
        update testAccount;
        
        List<Service_Provider__c> testSpids = TestDataFactory.createServiceProviders(1, testAccountId);
        testSpids[0].Inventory_Source__c = 'Test';
        testSpids[0].Dashboard_Admin_Exist__c = true;
        testSpids[0].Dealer_Email_Exist__c = true;
        insert testSpids;
        
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(Id = quoteLine.SBQQ__Quote__c);
        testQuote.Payment_Method__c = 'Credit Card';
        testQuote.SBQQ__Status__c = ConstantsUtil.QUOTE_STATUS_APPROVED;
        testQuote.SBQQ__StartDate__c = Date.Today();
        
        dsfs__DocuSign_Status__c testDocuSignStatus = new dsfs__DocuSign_Status__c(
            dsfs__Envelope_Status__c  = 'Completed',
            Quote_CPQ__c = testQuote.Id
        );
        insert testDocuSignStatus;
        
        insert new dsfs__DocuSign_Recipient_Status__c(
            dsfs__Parent_Status_Record__c = testDocuSignStatus.Id,
            dsfs__Account__c = testAccount.Id,
            dsfs__Date_Signed__c = Datetime.now(),
            dsfs__DocuSign_Recipient_Id__c = 'EXT-RCP-001'
        );
        
        update testQuote;
        
        Test.startTest();        
        Database.executeBatch(new Batch_CheckOpportunityPats());
        Test.stopTest();
        
        Opportunity_Tracker__c oppTracker = [SELECT Zuora_ActivePaymentMethodMatch__c, Zuora_QuotePaymentMethod__c,
                                             Zuora_ActiveBillingAccounts__c, Spid_HasInventory__c,
                                             DocusignComplete__c, Spid_CDA__c, Spid_DealerEmail__c, Quote_Approved__c,
                                             Quote_StartDate__c, QuoteOrderingErrors__c
                                             FROM Opportunity_Tracker__c
                                             LIMIT 1][0];
        
        System.assert(oppTracker.Zuora_ActivePaymentMethodMatch__c);
        System.assert(oppTracker.Zuora_QuotePaymentMethod__c);
        System.assert(oppTracker.Zuora_ActiveBillingAccounts__c);
        System.assert(oppTracker.Spid_HasInventory__c);
        System.assert(oppTracker.DocusignComplete__c);
        System.assert(oppTracker.Spid_CDA__c);
        System.assert(oppTracker.Spid_DealerEmail__c);
        System.assert(oppTracker.Quote_Approved__c);
        
        Opportunity testOpp = [SELECT StageName
                               FROM Opportunity
                               LIMIT 1][0];
        
        System.assertEquals(ConstantsUtil.OPP_STATUS_CLOSED_WON, testOpp.StageName);
        
        testQuote = [SELECT SBQQ__Status__c
                     FROM SBQQ__Quote__c
                     LIMIT 1][0];
        
        System.assertEquals(ConstantsUtil.QUOTE_STATUS_ORDER_GENERATED, testQuote.SBQQ__Status__c);
        
    }

    //- Jira: BR-878
    //- Purpose: Tests the bulkified Batch_CheckOpportunityPats that updates newly completed opportunity trackers
    @isTest
    static void testOppAllStepsDone_QueueableQuoteOrder(){
        
        ID oppId = [select id from opportunity limit 1][0].Id;
        
        SBQQ__QuoteLine__c quoteLine = [SELECT SBQQ__Quote__c, Fulfillment_Account__c
                                        FROM SBQQ__QuoteLine__c
                                        LIMIT 1][0];
        
        Account testAccount = new Account(Id = quoteLine.Fulfillment_Account__c);
        Id testAccountId = testAccount.Id;
        AccountTeamMember newTeam = new AccountTeamMember(AccountId = testAccount.ID,
		TeamMemberRole = 'Account Manager',UserId = userInfo.getuserId());
		insert newTeam;

        Zuora__CustomerAccount__c billingAccount = new Zuora__CustomerAccount__c(
            Zuora__Status__c = 'Active',
            Zuora__Account__c = testAccountId
        );
        insert billingAccount;
        Id billingAccountId =  billingAccount.Id;
        
        Zuora__PaymentMethod__c billingPaymentMethod = new Zuora__PaymentMethod__c(
            Zuora__PaymentMethodStatus__c = 'Active',
            Zuora__BillingAccount__c = billingAccountId,
            Zuora__Type__c = 'CreditCard'
        );
        insert billingPaymentMethod;
        
        testAccount.Billing_Account_Zuora__c  = billingAccountId;
        update testAccount;
        
        List<Service_Provider__c> testSpids = TestDataFactory.createServiceProviders(1, testAccountId);
        testSpids[0].Inventory_Source__c = 'Test';
        testSpids[0].Dashboard_Admin_Exist__c = true;
        testSpids[0].Dealer_Email_Exist__c = true;
        insert testSpids;
        
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(Id = quoteLine.SBQQ__Quote__c);
        testQuote.Payment_Method__c = 'Credit Card';
        testQuote.SBQQ__Status__c = ConstantsUtil.QUOTE_STATUS_APPROVED;
        testQuote.SBQQ__StartDate__c = Date.Today();
        
        insert new dsfs__DocuSign_Status__c(
            dsfs__Envelope_Status__c  = 'Completed',
            Quote_CPQ__c = testQuote.Id
        );
        
        update testQuote;
        
        Test.startTest();       
        System.enqueueJob(new QueueableQuoteOrders(new List<Id>{testQuote.Id}));
        Test.stopTest();
        
        Opportunity_Tracker__c oppTracker = [SELECT Zuora_ActivePaymentMethodMatch__c, Zuora_QuotePaymentMethod__c,
                                             Zuora_ActiveBillingAccounts__c, Spid_HasInventory__c,
                                             DocusignComplete__c, Spid_CDA__c, Spid_DealerEmail__c, Quote_Approved__c,
                                             Quote_StartDate__c, QuoteOrderingErrors__c
                                             FROM Opportunity_Tracker__c
                                             LIMIT 1][0];
        
        Opportunity testOpp = [SELECT StageName
                               FROM Opportunity
                               LIMIT 1][0];
        
        System.assertEquals(ConstantsUtil.OPP_STATUS_CLOSED_WON, testOpp.StageName);
        
        testQuote = [SELECT SBQQ__Status__c
                     FROM SBQQ__Quote__c
                     LIMIT 1][0];
        
        System.assertEquals(ConstantsUtil.QUOTE_STATUS_ORDER_GENERATED, testQuote.SBQQ__Status__c);
        
    }

    
    //- Jira: BR-878
    //- Purpose:  Tests the bulkified Batch_CheckOpportunityPats that updates newly completed opportunity trackers
    @isTest
    static void testOppNoStepsDone_Batch(){
        Test.startTest();        
        Database.executeBatch(new Batch_CheckOpportunityPats());
        Test.stopTest();
        
        Opportunity_Tracker__c oppTracker = [SELECT Zuora_ActivePaymentMethodMatch__c, Zuora_QuotePaymentMethod__c,
                                             Zuora_ActiveBillingAccounts__c, Spid_HasInventory__c,
                                             DocusignComplete__c, Spid_CDA__c, Spid_DealerEmail__c, Quote_Approved__c,
                                             Quote_StartDate__c, QuoteOrderingErrors__c
                                             FROM Opportunity_Tracker__c
                                             LIMIT 1][0];
        
        System.assert(!oppTracker.Zuora_ActivePaymentMethodMatch__c);
        System.assert(!oppTracker.Zuora_QuotePaymentMethod__c);
        System.assert(!oppTracker.Zuora_ActiveBillingAccounts__c);
        System.assert(!oppTracker.Spid_HasInventory__c);
        System.assert(!oppTracker.DocusignComplete__c);
        System.assert(!oppTracker.Spid_CDA__c);
        System.assert(!oppTracker.Spid_DealerEmail__c);
        System.assert(!oppTracker.Quote_Approved__c);
    }
    
    //- Jira: BR-878
    //- Purpose: Miscellaneous code coverage tests
    @isTest
    static void miscCodeCoverage(){ 
        Set<Id> oppId = new Set<Id>{[SELECT Id FROM Opportunity][0].Id};
            Delete [SELECT Id FROM SBQQ__Quote__c];
        
        OpportunityPatChecker.checkOpps(oppId);
        
        String cronString = Utilities.getCronExpressionMinutesFromNow(10);
        System.schedule('testSchedule_Batch_CheckOpportunityPats', cronString, 
                        new Batch_CheckOpportunityPats());
    }
    
    //- Jira: BR-3659
    //- Purpose: Test the LWC controller method that retries ordering on opportunities that failed to order
    @isTest
    static void testOppAllStepsDoneRetryWithError(){
        TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
        TriggerHandler.bypass('AccountTriggerHandler');
        TriggerHandler.bypass('CPQQuoteTriggerHandler');
        TriggerHandler.bypass('ServiceProviderTriggerHandler');
        
        ID oppId = [select id from opportunity limit 1][0].Id;

        SBQQ__QuoteLine__c quoteLine = [SELECT SBQQ__Quote__c, Fulfillment_Account__c, SBQQ__Quote__r.SBQQ__PricebookId__c
                                        FROM SBQQ__QuoteLine__c
                                        LIMIT 1][0];
        
        Id pricebookId = quoteLine.SBQQ__Quote__r.SBQQ__PricebookId__c;
            
        Account testAccount = new Account(Id = quoteLine.Fulfillment_Account__c);
        Id testAccountId = testAccount.Id;
        
        Zuora__CustomerAccount__c billingAccount = new Zuora__CustomerAccount__c(
            Zuora__Status__c = 'Active',
            Zuora__Account__c = testAccountId
        );
        insert billingAccount;
        Id billingAccountId =  billingAccount.Id;
        
        Zuora__PaymentMethod__c billingPaymentMethod = new Zuora__PaymentMethod__c(
            Zuora__PaymentMethodStatus__c = 'Active',
            Zuora__BillingAccount__c = billingAccountId,
            Zuora__Type__c = 'CreditCard'
        );
        insert billingPaymentMethod;

        billingAccount.Zuora__Default_Payment_Method__c = billingPaymentMethod.Id;
        update billingAccount;
        
        testAccount.Billing_Account_Zuora__c  = billingAccountId;
        update testAccount;
        
        List<Service_Provider__c> testSpids = TestDataFactory.createServiceProviders(1, testAccountId);
        testSpids[0].Inventory_Source__c = 'Test';
        testSpids[0].Dashboard_Admin_Exist__c = true;
        testSpids[0].Dealer_Email_Exist__c = true;
        insert testSpids;
        
        
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(Id = quoteLine.SBQQ__Quote__c);
        testQuote.Payment_Method__c = 'Credit Card';
        testQuote.SBQQ__Status__c = ConstantsUtil.QUOTE_STATUS_APPROVED;
        testQuote.SBQQ__StartDate__c = Date.Today();
        testQuote.SBQQ__PricebookId__c = null;
        
        dsfs__DocuSign_Status__c testDocuSignStatus = new dsfs__DocuSign_Status__c(
            dsfs__Envelope_Status__c  = 'Completed',
            Quote_CPQ__c = testQuote.Id
        );
        insert testDocuSignStatus;
        
        insert new dsfs__DocuSign_Recipient_Status__c(
            dsfs__Parent_Status_Record__c = testDocuSignStatus.Id,
            dsfs__Account__c = testAccount.Id,
            dsfs__Date_Signed__c = Datetime.now(),
            dsfs__DocuSign_Recipient_Id__c = 'EXT-RCP-001'
        );
        
        update testQuote;
        
        Opportunity_Tracker__c oppTracker = [SELECT Id
                                             FROM Opportunity_Tracker__c
                                             LIMIT 1][0];

        update oppTracker;
        
        Test.startTest();
                
        OpportunityPatHandler.getWrapper(oppId, null, false);
        
        testQuote.SBQQ__PricebookId__c = pricebookId;
        update testQuote;
        OpportunityPatHandler.retryOrderingApex(oppTracker.Id, oppId);
        
        
        Test.stopTest();
        
        oppTracker = [SELECT Zuora_ActivePaymentMethodMatch__c, Zuora_QuotePaymentMethod__c,
                      Zuora_ActiveBillingAccounts__c, Spid_HasInventory__c,
                      DocusignComplete__c, Spid_CDA__c, Spid_DealerEmail__c, Quote_Approved__c,
                      Quote_StartDate__c, QuoteOrderingErrors__c
                      FROM Opportunity_Tracker__c
                      LIMIT 1][0];
        
        System.assert(oppTracker.Zuora_ActivePaymentMethodMatch__c);
        System.assert(oppTracker.Zuora_QuotePaymentMethod__c);
        System.assert(oppTracker.Zuora_ActiveBillingAccounts__c);
        System.assert(oppTracker.Spid_HasInventory__c);
        System.assert(oppTracker.DocusignComplete__c);
        System.assert(oppTracker.Spid_CDA__c);
        System.assert(oppTracker.Spid_DealerEmail__c);
        System.assert(oppTracker.Quote_Approved__c);
        System.assert(oppTracker.Quote_StartDate__c);
        
        Opportunity testOpp = [SELECT StageName
                               FROM Opportunity
                               LIMIT 1][0];
        
        System.assertEquals(ConstantsUtil.OPP_STATUS_CLOSED_WON, testOpp.StageName);
        
        testQuote = [SELECT SBQQ__Status__c
                     FROM SBQQ__Quote__c
                     LIMIT 1][0];
        
        List<Order> orderList = [SELECT Id, OrderNumber
                                 FROM Order
                                 WHERE OpportunityId = :oppId];
        
        OpportunityPatHandler.patWrapper testPatWrap = new OpportunityPatHandler.patWrapper(oppTracker, testOpp.Id, testQuote);
        
    }
    
      //- Jira: BR-3659
    //- Purpose: Test the LWC controller method that retries ordering on opportunities that failed to order
    @isTest
    static void testOppAllStepsDoneBatchRetryWithError(){
        
        ID oppId = [select id from opportunity limit 1][0].Id;

        SBQQ__QuoteLine__c quoteLine = [SELECT SBQQ__Quote__c, Fulfillment_Account__c, SBQQ__Quote__r.SBQQ__PricebookId__c
                                        FROM SBQQ__QuoteLine__c
                                        LIMIT 1][0];
        
        Id pricebookId = quoteLine.SBQQ__Quote__r.SBQQ__PricebookId__c;
            
        Account testAccount = new Account(Id = quoteLine.Fulfillment_Account__c);
        Id testAccountId = testAccount.Id;
        
        Zuora__CustomerAccount__c billingAccount = new Zuora__CustomerAccount__c(
            Zuora__Status__c = 'Active',
            Zuora__Account__c = testAccountId
        );
        insert billingAccount;
        Id billingAccountId =  billingAccount.Id;
        
        Zuora__PaymentMethod__c billingPaymentMethod = new Zuora__PaymentMethod__c(
            Zuora__PaymentMethodStatus__c = 'Active',
            Zuora__BillingAccount__c = billingAccountId,
            Zuora__Type__c = 'CreditCard'
        );
        insert billingPaymentMethod;
        
        testAccount.Billing_Account_Zuora__c  = billingAccountId;
        update testAccount;

        billingAccount.Zuora__Default_Payment_Method__c = billingPaymentMethod.Id;
        update billingAccount;
        
        List<Service_Provider__c> testSpids = TestDataFactory.createServiceProviders(1, testAccountId);
        testSpids[0].Inventory_Source__c = 'Test';
        testSpids[0].Dashboard_Admin_Exist__c = true;
        testSpids[0].Dealer_Email_Exist__c = true;
        insert testSpids;
        
        
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(Id = quoteLine.SBQQ__Quote__c);
        testQuote.Payment_Method__c = 'Credit Card';
        testQuote.SBQQ__Status__c = ConstantsUtil.QUOTE_STATUS_APPROVED;
        testQuote.SBQQ__StartDate__c = Date.Today();
        testQuote.SBQQ__PricebookId__c = null;
        
        dsfs__DocuSign_Status__c testDocuSignStatus = new dsfs__DocuSign_Status__c(
            dsfs__Envelope_Status__c  = 'Completed',
            Quote_CPQ__c = testQuote.Id
        );
        insert testDocuSignStatus;
        
        insert new dsfs__DocuSign_Recipient_Status__c(
            dsfs__Parent_Status_Record__c = testDocuSignStatus.Id,
            dsfs__Account__c = testAccount.Id,
            dsfs__Date_Signed__c = Datetime.now(),
            dsfs__DocuSign_Recipient_Id__c = 'EXT-RCP-001'
        );
        
        update testQuote;
        
        Opportunity_Tracker__c oppTracker = [SELECT Id
                                             FROM Opportunity_Tracker__c
                                             LIMIT 1][0];

        update oppTracker;
        
        Test.startTest();
                
        OpportunityPatHandler.getWrapper(oppId, null, false);
        
        testQuote.SBQQ__PricebookId__c = pricebookId;
        update testQuote;
        
        Database.executeBatch(new Batch_CheckOpportunityPats());
        
        Test.stopTest();
        
        oppTracker = [SELECT Zuora_ActivePaymentMethodMatch__c, Zuora_QuotePaymentMethod__c,
                      Zuora_ActiveBillingAccounts__c, Spid_HasInventory__c,
                      DocusignComplete__c, Spid_CDA__c, Spid_DealerEmail__c, Quote_Approved__c,
                      Quote_StartDate__c, QuoteOrderingErrors__c
                      FROM Opportunity_Tracker__c
                      LIMIT 1][0];
        
        System.assert(oppTracker.Zuora_ActivePaymentMethodMatch__c);
        System.assert(oppTracker.Zuora_QuotePaymentMethod__c);
        System.assert(oppTracker.Zuora_ActiveBillingAccounts__c);
        System.assert(oppTracker.Spid_HasInventory__c);
        System.assert(oppTracker.DocusignComplete__c);
        System.assert(oppTracker.Spid_CDA__c);
        System.assert(oppTracker.Spid_DealerEmail__c);
        System.assert(oppTracker.Quote_Approved__c);
        System.assert(oppTracker.Quote_StartDate__c);
        
        Opportunity testOpp = [SELECT StageName
                               FROM Opportunity
                               LIMIT 1][0];
        
        System.assertEquals(ConstantsUtil.OPP_STATUS_CLOSED_WON, testOpp.StageName);
        
        testQuote = [SELECT SBQQ__Status__c
                     FROM SBQQ__Quote__c
                     LIMIT 1][0];
        
        List<Order> orderList = [SELECT Id, OrderNumber
                                 FROM Order
                                 WHERE OpportunityId = :oppId];
        
        OpportunityPatHandler.patWrapper testPatWrap = new OpportunityPatHandler.patWrapper(oppTracker, testOpp.Id, testQuote);
        
    }
    //BR-4860
    @isTest
    static void testCheckQuoteStartDate_Batch(){
        
        ID oppId = [select id from opportunity limit 1][0].Id;
        
        SBQQ__QuoteLine__c quoteLine = [SELECT SBQQ__Quote__c, Fulfillment_Account__c
                                        FROM SBQQ__QuoteLine__c
                                        LIMIT 1][0];
        
        Account testAccount = new Account(Id = quoteLine.Fulfillment_Account__c);
        Id testAccountId = testAccount.Id;
        
        Zuora__CustomerAccount__c billingAccount = new Zuora__CustomerAccount__c(
            Zuora__Status__c = 'Active',
            Zuora__Account__c = testAccountId
        );
        insert billingAccount;
        Id billingAccountId =  billingAccount.Id;
        
        Zuora__PaymentMethod__c billingPaymentMethod = new Zuora__PaymentMethod__c(
            Zuora__PaymentMethodStatus__c = 'Active',
            Zuora__BillingAccount__c = billingAccountId,
            Zuora__Type__c = 'CreditCard'
        );
        insert billingPaymentMethod;
        
        testAccount.Billing_Account_Zuora__c  = billingAccountId;
        update testAccount;
        
        List<Service_Provider__c> testSpids = TestDataFactory.createServiceProviders(1, testAccountId);
        testSpids[0].Inventory_Source__c = 'Test';
        testSpids[0].Dashboard_Admin_Exist__c = true;
        testSpids[0].Dealer_Email_Exist__c = true;
        insert testSpids;
        
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(Id = quoteLine.SBQQ__Quote__c);
        testQuote.Payment_Method__c = 'Credit Card';
        testQuote.SBQQ__Status__c = ConstantsUtil.QUOTE_STATUS_APPROVED;
        testQuote.SBQQ__StartDate__c = Date.today();
        
        dsfs__DocuSign_Status__c testDocuSignStatus = new dsfs__DocuSign_Status__c(
            dsfs__Envelope_Status__c  = 'Completed',
            Quote_CPQ__c = testQuote.Id
        );
        insert testDocuSignStatus;
        
        insert new dsfs__DocuSign_Recipient_Status__c(
            dsfs__Parent_Status_Record__c = testDocuSignStatus.Id,
            dsfs__Account__c = testAccount.Id,
            dsfs__Date_Signed__c = Datetime.now(),
            dsfs__DocuSign_Recipient_Id__c = 'EXT-RCP-001'
        );
        
        update testQuote;
        
        
        Opportunity_Tracker__c oppTracker = [SELECT Id, Spid_HasInventory__c, Spid_CDA__c, Spid_DealerEmail__c,
                                             Zuora_QuotePaymentMethod__c, Zuora_ActiveBillingAccounts__c, Zuora_ActivePaymentMethodMatch__c,
                                             Quote_Approved__c, Quote_StartDate__c, DocusignComplete__c 
                                             FROM Opportunity_Tracker__c 
                                             LIMIT 1][0];
       
        oppTracker.Spid_HasInventory__c = true;
        oppTracker.Spid_CDA__c = true;
        oppTracker.Spid_DealerEmail__c = true;
        oppTracker.Zuora_QuotePaymentMethod__c = true;
        oppTracker.Zuora_ActiveBillingAccounts__c = true;
        oppTracker.Zuora_ActivePaymentMethodMatch__c = true;
        oppTracker.Quote_Approved__c = true;
        oppTracker.Quote_StartDate__c = false;
        oppTracker.DocusignComplete__c = true;
        update oppTracker;
        
        Test.startTest();        
        Database.executeBatch(new Batch_CheckQuoteStartDate());
        Test.stopTest();
        
        SBQQ__Quote__c quote1 = [SELECT Id, SBQQ__StartDate__c FROM SBQQ__Quote__c LIMIT 1];
        System.assertEquals(Date.today(), quote1.SBQQ__StartDate__c);
           
    }
    
}