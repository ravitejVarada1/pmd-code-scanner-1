/**
 * @description       : 
 * @author            : LZhao
 * @group             : 
 * @last modified on  : 12-01-2021
 * @last modified by  : LZhao
**/
@isTest
private class CPQQuoteTriggerFunctions_Test {

    @TestSetup
    static void makeData(){
        
        Test.startTest();
        
        Account[] accts = TestDataFactory.createAccounts(1);
        insert accts;

        List<Zuora__CustomerAccount__c> zuoraAcc = TestDataFactory.createZuoraAccount(1, accts[0]);
        zuoraAcc[0].GraceDate__c = System.today().addDays(30);
        insert zuoraAcc;
        
        accts[0].Billing_Account_Zuora__c = zuoraAcc[0].id;
        update accts;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 1);
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        quotes[0].Contract_Commitment_Term_Months__c = '12';
        insert quotes;
        Id quoteId = quotes[0].Id;
        
        List<Product2> testProds = TestDataFactory.createProducts(2);
        insert testProds;
        
        Test.stopTest();
    }

    static testMethod void validateQuoteInsertExpDate() {

        SBQQ__Quote__c[] q = [select Id, SBQQ__ExpirationDate__c from SBQQ__Quote__c];
        Date expectedDate = ConstantsUtil.STANDARD_QUOTE_EXPIRATION;
        System.assertEquals(q[0].SBQQ__ExpirationDate__c, expectedDate);

    }

    static testMethod void validateRenewalQuoteInsertExpDate() {

        List<Account> accts = [SELECT Id FROM Account];
        List<Opportunity> opps = [SELECT Id FROM Opportunity];

        Date startDateNextMonth = System.today().toStartOfMonth().addMonths(1);

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        quotes[0].SBQQ__Type__c = 'Renewal';
        quotes[0].SBQQ__StartDate__c = startDateNextMonth;
        insert quotes;
        
        SBQQ__Quote__c[] q = [SELECT Id, SBQQ__ExpirationDate__c FROM SBQQ__Quote__c WHERE Id = :quotes[0].Id];
        Date expectedDate = startDateNextMonth.toStartOfMonth().addMonths(1).addDays(9);
        System.assertEquals(expectedDate,q[0].SBQQ__ExpirationDate__c);

    }

    static testMethod void validateQuoteUpdateWithROMF() {

        SBQQ__Quote__c[] q = [select Id, SBQQ__ExpirationDate__c, SBQQ__Account__c from SBQQ__Quote__c];
        system.debug(q[0].SBQQ__ExpirationDate__c);

        Product2 p = new Product2(Name = 'CG Base Bundle', isActive = true);
        insert p;

        Test.startTest();

        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q[0].Id,
            Fulfillment_Account__c = q[0].SBQQ__Account__c,
            SBQQ__Product__c = p.Id,
            SBQQ__Quantity__c = 1,
            Intro_Discount_Percentage__c = 100,
            Intro_Discount_Period__c = 1
        );

        insert ql;

        Test.stopTest();

        q = [SELECT Id, SBQQ__ExpirationDate__c, SBQQ__Account__c FROM SBQQ__Quote__c];
        Date expectedDate = date.today().toStartOfMonth().addMonths(1).addDays(-1);
        System.assertEquals(q[0].SBQQ__ExpirationDate__c, expectedDate);

    }

    static testMethod void validateQuoteUpdateWithROMF2() {

        SBQQ__Quote__c[] q = [select Id, SBQQ__ExpirationDate__c, SBQQ__Account__c from SBQQ__Quote__c];
        system.debug(q[0].SBQQ__ExpirationDate__c);

        Product2 p = new Product2(Name = 'CG Base Bundle', isActive = true);
        insert p;

        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q[0].Id,
            Fulfillment_Account__c = q[0].SBQQ__Account__c,
            SBQQ__Product__c = p.Id,
            SBQQ__Quantity__c = 1
        );
        insert ql;

        ql = [select Id from SBQQ__QuoteLine__c limit 1];

        Test.startTest();

        ql.Intro_Discount_Percentage__c = 100;
        ql.Intro_Discount_Period__c = 1;
        update ql;

        Test.stopTest();

        q = [SELECT Id, SBQQ__ExpirationDate__c, SBQQ__Account__c FROM SBQQ__Quote__c];
        Date expectedDate = date.today().toStartOfMonth().addMonths(1).addDays(-1);
        System.assertEquals(q[0].SBQQ__ExpirationDate__c, expectedDate);

    }

    static testMethod void testQuoteExpirationBatch() {
        SBQQ__Quote__c[] qList = [SELECT Id, SBQQ__ExpirationDate__c from SBQQ__Quote__c];
        qList[0].SBQQ__ExpirationDate__c = date.today();
        update qList;

        Test.startTest();
        Database.executeBatch(new BatchUpdateQuoteStatus(new Set<Id>{qList[0].Id}));
        Test.stopTest();

        qList = [SELECT Id, SBQQ__Status__c from SBQQ__Quote__c];

        System.assertEquals(qList[0].SBQQ__Status__c, 'Expired');
    }

    // Validate Initial Term End Date - Docusign Date is blank
    static testMethod void validateInitialTermEndDate1() {
        SBQQ__Quote__c[] qList = [SELECT Id, SBQQ__StartDate__c, Last_Docusign_Sent_Date__c, Contract_Commitment_Term_Months__c 
                                  FROM SBQQ__Quote__c];
        qList[0].SBQQ__StartDate__c = date.today();
        
        Test.startTest();
        update qList;
        Test.stopTest();

        qList = [SELECT Id, Initial_Term_End_Date__c, Contract_Commitment_Term_Months__c  FROM SBQQ__Quote__c];

        Date expectedDate = date.today().addMonths(Integer.valueOf(qList[0].Contract_Commitment_Term_Months__c));
        Integer numberOfDays = Date.daysInMonth(expectedDate.year(), expectedDate.month());
        expectedDate = Date.newInstance(expectedDate.year(), expectedDate.month(), numberOfDays);  

        System.assertEquals(qList[0].Initial_Term_End_Date__c, expectedDate);
    }

    // Validate Initial Term End Date - Docusign Sent Date is Before Start Date
    static testMethod void validateInitialTermEndDate2() {
        SBQQ__Quote__c[] qList = [SELECT Id, SBQQ__StartDate__c, Last_Docusign_Sent_Date__c, Contract_Commitment_Term_Months__c 
                                  FROM SBQQ__Quote__c];
        qList[0].SBQQ__StartDate__c = date.today();
        qList[0].Last_Docusign_Sent_Date__c = date.today().addDays(-5);
        
        Test.startTest();
        update qList;
        Test.stopTest();

        qList = [SELECT Id, SBQQ__StartDate__c, Initial_Term_End_Date__c, Contract_Commitment_Term_Months__c  FROM SBQQ__Quote__c];
        Date baseDate = qList[0].SBQQ__StartDate__c;
        Date expectedDate = baseDate.addMonths(Integer.valueOf(qList[0].Contract_Commitment_Term_Months__c));
        Integer numberOfDays = Date.daysInMonth(expectedDate.year(), expectedDate.month());
        expectedDate = Date.newInstance(expectedDate.year(), expectedDate.month(), numberOfDays);  

        System.assertEquals(qList[0].Initial_Term_End_Date__c, expectedDate);
    }
    
    @isTest
    static void checkDocusignUpdateOMRequired(){
        SBQQ__Quote__c testQuote = [SELECT Id, SBQQ__Account__c
                                    FROM SBQQ__Quote__c
                                   LIMIT 1];
        
        testQuote.SBQQ__Status__c = CPQQuoteTriggerFunctions.DOCUSIGN_COMPLETE;
        testQuote.NumFulfillmentAccounts__c	= 2;
        
        Account testAccount = [SELECT Id
                               FROM Account
                               LIMIT 1];
        
        testAccount.System_BillingContactFirst__c = 'FIRST';
        testAccount.System_BillingContactLast__c = 'LAST';
        testAccount.System_BillingContactEmail__c = 'EMAIL@testApprovalOM.com';
        
        update testAccount;
        
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            testQuote.Id,
            testQuote.SBQQ__Account__c,
            new Set<ID>{[SELECT Id FROM Product2][0].Id}
        )[0];
        
        testQuoteLine.Billing_Account__c = testAccount.Id;
        
        insert testQuoteLine;

        Test.startTest();
        
        testQuoteLine.SBQQ__ListPrice__c = 50001;
        testQuoteLine.Intro_Discount_Percentage__c = 1;
        testQuoteLine.Intro_Discount_Period__c = 2;
        update testQuoteLine;
        
        Product2 testProd = [SELECT Id
                            FROM Product2
                            WHERE Id = :testQuoteLine.SBQQ__Product__c
                            LIMIT 1];
        testProd.Require_OM_Review__c = true;
        update testProd;

        
        update testQuote;
        Test.stopTest();
        
        String currentApprovalStatus = [SELECT Status
                                       FROM ProcessInstance
                                       LIMIT 1][0].Status;
        
        System.assertEquals('Pending', currentApprovalStatus);
    }
    
    @isTest
    static void checkDocusignUpdateOMNotRequired(){
        SBQQ__Quote__c testQuote = [SELECT Id
                                    FROM SBQQ__Quote__c
                                    LIMIT 1];
        
        testQuote.SBQQ__Status__c = CPQQuoteTriggerFunctions.DOCUSIGN_COMPLETE;
        
        Test.startTest();
        update testQuote;
        Test.stopTest();
        
        String currentApprovalStatus = [SELECT Status
                                        FROM ProcessInstance
                                        LIMIT 1][0].Status;
        
        System.assertEquals('Approved', currentApprovalStatus);
    }
        
    @isTest
    static void checkDocusignUpdateEntryCriteriaNotMet(){
        
        Account testAccount = [SELECT Id
                               FROM Account
                               LIMIT 1];
        
        testAccount.Account_Status__c = 'Pending';

        update testAccount;

        SBQQ__Quote__c testQuote = [SELECT Id, SBQQ__Account__c
                                    FROM SBQQ__Quote__c
                                    LIMIT 1];
        
        testQuote.SBQQ__Status__c = CPQQuoteTriggerFunctions.DOCUSIGN_COMPLETE;
        
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            testQuote.Id,
            testQuote.SBQQ__Account__c,
            new Set<ID>{[SELECT Id FROM Product2][0].Id}
        )[0];
        
        insert testQuoteLine;
        
        Test.startTest();
        update testQuote;
        System.assertEquals(1, Limits.getEmailInvocations());
        Test.stopTest();
        
        Integer numActiveApprovals = [SELECT COUNT()
                                      FROM ProcessInstance
                                      LIMIT 1];
        
        System.assertEquals(0, numActiveApprovals);
    }

    static testMethod void validateQuoteCommitTermEndDateWithROMF() {

        SBQQ__Quote__c[] q = [SELECT Id, SBQQ__StartDate__c, SBQQ__Account__c FROM SBQQ__Quote__c];
        Product2 p = new Product2(Name = 'CG Base Bundle', isActive = true);
        insert p;

        Test.startTest();

        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q[0].Id,
            Fulfillment_Account__c = q[0].SBQQ__Account__c,
            SBQQ__Product__c = p.Id,
            SBQQ__Quantity__c = 1,
            Intro_Discount_Percentage__c = 100,
            Intro_Discount_Period__c = 1
        );

        insert ql;

        // Set startDate - cover scenario where never will be the first day of the month
        Date startDate =  System.today().day() == 1 ? System.today().addDays(1) : System.today();
        q[0].SBQQ__StartDate__c = startDate;
        update q;

        Test.stopTest();

        q = [SELECT Id, Initial_Term_End_Date__c, SBQQ__StartDate__c FROM SBQQ__Quote__c];
        
        Integer commitmentTermMonths = 12 + 1 - 1; // 12 month commit + 1 intro discount - 1 current month
        Date expectedCommittedTermEndDate = startDate.addMonths(commitmentTermMonths).addMonths(1).toStartofMonth().addDays(-1);
        System.assertEquals(expectedCommittedTermEndDate, q[0].Initial_Term_End_Date__c);
    }

    static testMethod void validateQuoteCommitTermEndDateWithROMFPlus() {

        SBQQ__Quote__c[] q = [SELECT Id, SBQQ__StartDate__c, SBQQ__Account__c FROM SBQQ__Quote__c];

        Product2 p = new Product2(Name = 'CG Base Bundle', isActive = true);
        insert p;

        Test.startTest();

        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q[0].Id,
            Fulfillment_Account__c = q[0].SBQQ__Account__c,
            SBQQ__Product__c = p.Id,
            SBQQ__Quantity__c = 1,
            Intro_Discount_Percentage__c = 100,
            Intro_Discount_Period__c = 2
        );

        insert ql;

        // Set startDate - cover scenario where never will be the first day of the month
        Date startDate =  System.today().day() == 1 ? System.today().addDays(1) : System.today();
        q[0].SBQQ__StartDate__c = startDate;
        q[0].Contract_Commitment_Term_Months__c = '1';
        update q;

        Test.stopTest();
        q = [SELECT Id, Initial_Term_End_Date__c, SBQQ__StartDate__c FROM SBQQ__Quote__c];
        
        Integer commitmentTermMonths = 1 + 2 - 1; // 1 month commit + 2 intro discount - 1 current month
        Date expectedCommittedTermEndDate = startDate.addMonths(commitmentTermMonths).addMonths(1).toStartofMonth().addDays(-1);
        System.assertEquals(expectedCommittedTermEndDate, q[0].Initial_Term_End_Date__c);
    }

    //SA-591
    static testMethod void setDefaultQuoteLanguageTest() {

        Test.startTest();
        
        SBQQ__Quote__c quote = [SELECT Id, SBQQ__QuoteLanguage__c FROM SBQQ__Quote__c LIMIT 1];
        quote.SBQQ__QuoteLanguage__c = 'English';
        update quote;
        
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Contract contractSobject = TestDataFactory.createContract(acc.Id);
        contractSobject.SBQQ__Quote__c = quote.Id;
        contractSobject.ContractLanguage__c = 'English';
        insert contractSobject;

        // Amendment oppty
        Opportunity[] opps = TestDataFactory.createOpps(acc.Id, 1);
        insert opps;

        // Amendmet quote
        SBQQ__Quote__c amendQuote = TestDataFactory.createQuotes(acc.Id, opps[0].Id, 1)[0];
        amendQuote.Contract_Commitment_Term_Months__c = '12';
        amendQuote.SBQQ__Type__c = 'Amendment';
        amendQuote.SBQQ__MasterContract__c = contractSobject.Id;
        insert amendQuote;        

        Test.stopTest();
        
        contractSobject = [SELECT Id, ContractLanguage__c FROM Contract WHERE Id = :contractSobject.Id];
        amendQuote = [SELECT Id, SBQQ__QuoteLanguage__c FROM SBQQ__Quote__c WHERE Id = :amendQuote.Id];
        
        System.assertEquals(contractSobject.ContractLanguage__c, amendQuote.SBQQ__QuoteLanguage__c);
    }

    //SA-591
    static testMethod void updateQuoteLineTranslationsTest() {

        Test.startTest();
        
        SBQQ__Quote__c q = [SELECT Id, SBQQ__ExpirationDate__c, SBQQ__Account__c FROM SBQQ__Quote__c LIMIT 1];

        Product2 p = new Product2(Name = 'Enhanced Placement', ProductCode = 'ENH-PLC',  isActive = true);
        insert p;        

        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q.Id,
            Fulfillment_Account__c = q.SBQQ__Account__c,
            SBQQ__Product__c = p.Id,
            SBQQ__Quantity__c = 1
        );

        insert ql;

        q.SBQQ__QuoteLanguage__c = 'French';
        update q;

        Test.stopTest();

        ql = [SELECT Id, Translated_Product_Name__c, Translated_Product_Description__c
        FROM SBQQ__Quoteline__c WHERE Id = :ql.Id]; 
    }

    static testMethod void validateGraceDateApproval() {

        SBQQ__Quote__c[] q = [SELECT Id, SBQQ__StartDate__c, SBQQ__Account__c FROM SBQQ__Quote__c];

        Product2 p = new Product2(Name = 'CG Base Bundle', isActive = true);
        insert p;

        Test.startTest();

        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q[0].Id,
            Fulfillment_Account__c = q[0].SBQQ__Account__c,
            SBQQ__Product__c = p.Id,
            SBQQ__Quantity__c = 1,
            Intro_Discount_Percentage__c = 100,
            Intro_Discount_Period__c = 2
        );

        insert ql;

        // Set startDate - cover scenario where never will be the first day of the month
        Date startDate =  System.today().day() == 1 ? System.today().addDays(1) : System.today();
        q[0].SBQQ__StartDate__c = startDate;
        q[0].Contract_Commitment_Term_Months__c = '1';
        update q;

        Test.stopTest();
        q = [SELECT Id, Has_Account_With_Grace_Date__c FROM SBQQ__Quote__c];
        
        System.assertEquals(true, q[0].Has_Account_With_Grace_Date__c);
    }
    @IsTest
    static void testpreventQuoteFromDeletion() {
      
        User usr = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]; 
        Profile salesUserProfile = [SELECT Id FROM Profile WHERE Name = 'Sales User'];

        UserRole fieldSDR = [SELECT Id FROM UserRole WHERE Name = 'UK Field SDR'];

        PermissionSetLicense psl = [SELECT Id, DeveloperName
            FROM PermissionSetLicense
            WHERE DeveloperName = 'SalesforceCPQ_CPQStandardPerm'];

        List<PermissionSet> ps = [SELECT Id FROM PermissionSet WHERE Name = 'Salesforce_CPQ_User_Custom'];        
        List<PermissionSetLicenseAssign> permissionSetLicenseAssignList = new List<PermissionSetLicenseAssign> ();
        List<PermissionSetAssignment> permissionSetAssignmentList = new List<PermissionSetAssignment> ();
   
        UserRole OutboundSDR = [SELECT Id FROM UserRole WHERE Name = 'UK Outbound SDR'];        
        User Outbound_SDR_SalesUserOne = new User(Alias = 'fSDR1', Email='Outbound_SDR_SalesUserOne@cg.com.test',
                                     EmailEncodingKey='UTF-8', LastName='One Test', LanguageLocaleKey='en_US', 
                                     LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
                                     TimeZoneSidKey='America/Los_Angeles', UserName='Outbound_SDR_SalesUserOne@cg.com.test', UserRoleId = OutboundSDR.Id);
        insert Outbound_SDR_SalesUserOne;

        permissionSetLicenseAssignList.add(new PermissionSetLicenseAssign(AssigneeId = Outbound_SDR_SalesUserOne.Id, PermissionSetLicenseId  = psl.Id));
        permissionSetAssignmentList.add(new permissionSetAssignment(AssigneeId = Outbound_SDR_SalesUserOne.Id, PermissionSetId = ps[0].Id));
        
        insert permissionSetLicenseAssignList;
        insert permissionSetAssignmentList;

        System.runAs(usr){
      	Test.startTest();
      	SBQQ__Quote__c quotes = [
        SELECT Id, SBQQ__Status__c
        FROM SBQQ__Quote__c Limit 1
        ];
            
        try{ 
        	delete quotes;
        } catch(exception e){
            system.debug('the error is'+e.getMessage());
            String expectedError = 'INSUFFICIENT_ACCESS_OR_READONLY';
            Boolean containsErrorMessage = e.getMessage().contains(expectedError);
            System.assertEquals(true, containsErrorMessage);
        }
        Test.stopTest();
        }
    }

    static testMethod void checkStartDateOnAmendmentsTest() {    
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Product2[] prod = [SELECT ID FROM Product2];

        List<SBQQ__Subscription__c> subList = testDataFactory.createCPQSubsForProducts(prod, acc.id);
        for(SBQQ__Subscription__c sub : subList) {
            sub.FulFillment_Account__c = acc.Id;
            sub.Provisioning_Status__c = 'Pending Activation';
            sub.SBQQ__SubscriptionStartDate__c = System.today().addDays(2);
            sub.SBQQ__Quantity__c = -1;
        }
        insert subList;


        // Amendment oppty
        Opportunity[] opps = TestDataFactory.createOpps(acc.Id, 1);
        insert opps;

        // Amendmet quote
        SBQQ__Quote__c amendQuote = TestDataFactory.createQuotes(acc.Id, opps[0].Id, 1)[0];
        amendQuote.SBQQ__Type__c = 'Amendment';
        amendQuote.SBQQ__StartDate__c = System.today().addDays(5);
        insert amendQuote;
        
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            amendQuote.Id,
            acc.Id,
            new Set<ID>{prod[0].Id}        
        )[0];
        testQuoteLine.SBQQ__Existing__c = false;
        testQuoteLine.FulFillment_Account__c = acc.Id;
        insert testQuoteLine;

        Test.startTest(); 

        try{
            amendQuote.SBQQ__StartDate__c = System.today();
            update amendQuote;
        } catch (DmlException e) {
            //Assert Error Message 
            System.assert(e.getMessage().contains('has future Pending Activation Subscriptions starting'),e.getMessage());
        }
        
        Test.stopTest();
    }
    
    //SA-223
    static testMethod void testRecordTypeReset(){

        SBQQ.TriggerControl.disable();
        SBQQ__Quote__c[] q = [SELECT Id,RecordTypeId,SBQQ__StartDate__c, 
                              SBQQ__Account__c, SBQQ__Status__c, SBQQ__Type__c 
                              FROM SBQQ__Quote__c];
        q[0].RecordTypeId = SObjectDescribeUtils.getRecordTypeIdByName('Quote','Approved Quote');
        update q;
        
        //Cloning an Approved Quote
        SBQQ__Quote__c clonedQuoteRec = q[0].clone(false,true,true,false);
        
        Test.startTest();
            insert clonedQuoteRec;   
        Test.stopTest();
        
        SBQQ__Quote__c[] clonedQ = [
            SELECT Id,RecordTypeId  
            FROM SBQQ__Quote__c 
            WHERE Id=:clonedQuoteRec.Id
        ];
        //Cloned Output is a Standard Quote
        System.assertEquals(clonedQ[0].RecordTypeId,SObjectDescribeUtils.getRecordTypeIdByName('Quote','Standard Quote'));
    }
    //DSS-450 / DSS-839
    static testMethod void updateRenewalOppTest(){
        Account testAcct = [SELECT Id, Name FROM Account LIMIT 1];
        Opportunity[] opps = TestDataFactory.createOpps(testAcct.Id,1);
        Id renewalRecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity', 'Renewal');
        opps[0].RecordTypeId = renewalRecordTypeId;
        insert opps[0];

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(testAcct.Id, opps[0].Id, 1);
        quotes[0].SBQQ__StartDate__c = System.today();
        Date deconstructDate = system.today(); //can't use system.now because doesn't support timezones
        Integer y = deconstructDate.year();
        Integer m = deconstructDate.month();
        Integer d = deconstructDate.day();
        DateTime convertedDT = dateTime.newInstance(y,m,d);
        String month = convertedDT.format('MMMM');
        Integer convertedYear = convertedDT.year();
        
        quotes[0].SBQQ__Type__c = 'Renewal';
        
        Test.startTest();
        insert quotes[0];
        Opportunity testOpp = [SELECT Id, Name, AccountId, recordtypeid FROM Opportunity WHERE AccountID = :testAcct.Id 
        AND RecordtypeId = :renewalRecordTypeId LIMIT 1];
        system.assertEquals(testOpp.Name, testAcct.Name + ' - Annual Business Review - ' + month + ' 1 '+convertedYear);
        Test.stopTest();
    }
}