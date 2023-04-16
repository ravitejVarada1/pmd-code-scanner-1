/**
 * @description       : 
 * @author            : LZhao
 * @group             : 
 * @last modified on  : 12-07-2021
 * @last modified by  : LZhao
**/
@isTest
private class CPQQuoteLineTriggerFunctions_Test {

    Id baseBundleId;

    @TestSetup
    static void makeData(){

        Test.startTest();
        SBQQ.TriggerControl.disable();

        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].BillingCountryCode = 'US';
        insert accts;

        List<Zuora__CustomerAccount__c>  billingAccount = TestDataFactory.createZuoraAccount(1, accts[0]);
        billingAccount[0].Zuora__DefaultPaymentMethod__c = 'Check';
        billingAccount[0].Zuora__Batch__c = 'Batch9';
        insert billingAccount[0];
        accts[0].Billing_Account_Zuora__c = billingAccount[0].Id;
        update accts[0];

        Service_Provider__c[] sps = TestDataFactory.createServiceProviders(1,accts[0].id);
        sps[0].Dealer_Type__c = 'New';
        sps[0].New_Makes_Sold__c = 'GMC';
        insert sps;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 1);
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        quotes[0].Billing_Type__c = 'Advance';
        insert quotes;

        Co_Op_Program__c[] coopPrograms = TestDataFactory.coopPrograms();
        insert coopPrograms;

        Product2[] products = new List<Product2>();
        products.add(new Product2(
            Name = 'CG Base Bundle',
            IsActive = true,
            ProductCode = 'CG-BASE'
        ));
        products.add(new Product2(
            Name = 'Enhanced Placement',
            IsActive = true,
            ProductCode = 'ENH-PLC',
            Family = 'Listings',
            Product_Category__c = 'Core Products',
            Sub_Category__c = 'Enhanced'
        ));
        products.add(new Product2(
            Name = 'Enhanced Package',
            IsActive = true,
            ProductCode = 'PKG-ENH',
            Product_Category__c = 'Core Products',
            Sub_Category__c = 'Enhanced'
        ));
        insert products;

        SBQQ__ProductOption__c prodOption = new SBQQ__ProductOption__c();
        prodOption.SBQQ__OptionalSKU__c = products[2].Id;
        prodOption.SBQQ__Number__c = 10;
        insert prodOption;
        
        /*
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            quotes[0].Id,
            accts[0].Id,
            new Set<ID>{products[0].Id}
        )[0];
        insert testQuoteLine;
        */

        APXT_Redlining__Clause_Type__c clauseType = TestDataFactory.createClauseType('OrderForm_English');
        insert clauseType;
        APXT_Redlining__Clause__c clause = TestDataFactory.createClause('[DISCOUNT_PERCENT]% off current calendar month','Discount_IntroRateOneMonth',clauseType);
        insert clause;

        Test.stopTest();
    }

    static testMethod void testIntroDiscountInsert() {
        SBQQ.TriggerControl.disable();

        SBQQ__Quote__c[] quotes = [SELECT Id FROM SBQQ__Quote__c];
        Product2[] prod = [SELECT Id, ProductCode FROM Product2 ORDER BY ProductCode asc];

        Map<String, Product2> pdtsByCode = new Map<String, Product2>();
        for(Product2 pdt : prod) {
            pdtsByCode.put(pdt.ProductCode, pdt);
        }

        Account[] accts = [SELECT Id FROM Account];

        Test.startTest();

        SBQQ__QuoteLine__c[] insertLines = new List<SBQQ__QuoteLine__c>();
        SBQQ__QuoteLine__c baseBundle = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = pdtsByCode.get('CG-BASE').Id,
            SBQQ__Quote__c = quotes[0].Id,
            Fulfillment_Account__c = accts[0].Id,
            Intro_Discount_Percentage__c = 1,
            Intro_Discount_Period__c = 1
        );
        insertLines.add(baseBundle);
        SBQQ__QuoteLine__c enhanced = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = pdtsByCode.get('ENH-PLC').Id,
            SBQQ__Quote__c = quotes[0].Id,
            Fulfillment_Account__c = accts[0].Id,
            SBQQ__Quantity__c = 1
        );
        insertLines.add(enhanced);
        insert insertLines;

        Test.stopTest();

        SBQQ__QuoteLine__c result = [SELECT Id, Intro_Discount_Percentage__c, Intro_Discount_Period__c, Contract_Discount_Language__c FROM SBQQ__QuoteLine__c
            WHERE SBQQ__ProductCode__c = 'ENH-PLC' limit 1];

        System.assertEquals(result.Intro_Discount_Percentage__c,1);
        System.assertEquals(result.Intro_Discount_Period__c,1);
        System.assertNotEquals(result.Contract_Discount_Language__c, null);
    }

    static testMethod void testIntroDiscountUpdate() {
        SBQQ.TriggerControl.disable();

        SBQQ__Quote__c[] quotes = [SELECT Id FROM SBQQ__Quote__c];
        Product2[] prod = [SELECT Id, ProductCode FROM Product2 ORDER BY ProductCode asc];

        Map<String, Product2> pdtsByCode = new Map<String, Product2>();
        for(Product2 pdt : prod) {
            pdtsByCode.put(pdt.ProductCode, pdt);
        }

        Account[] accts = [SELECT Id FROM Account];

        SBQQ__QuoteLine__c[] insertLines = new List<SBQQ__QuoteLine__c>();
        SBQQ__QuoteLine__c baseBundle = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = pdtsByCode.get('CG-BASE').Id,
            SBQQ__Quote__c = quotes[0].Id,
            Fulfillment_Account__c = accts[0].Id,
            Intro_Discount_Percentage__c = 1,
            Intro_Discount_Period__c = 1,
            SBQQ__Quantity__c = 1
        );
        insertLines.add(baseBundle);
        insert insertLines;

        Test.startTest();

        SBQQ__QuoteLIne__c enhanced = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = pdtsByCode.get('ENH-PLC').Id,
            SBQQ__Quote__c = quotes[0].Id,
            Fulfillment_Account__c = accts[0].Id,
            SBQQ__Quantity__c = 1
        );
        insert enhanced;

        Test.stopTest();

        SBQQ__QuoteLine__c result = [SELECT Id, Intro_Discount_Percentage__c, Intro_Discount_Period__c, Contract_Discount_Language__c FROM SBQQ__QuoteLine__c
            WHERE SBQQ__ProductCode__c = 'ENH-PLC' limit 1];

        System.assertEquals(result.Intro_Discount_Percentage__c,1);
        System.assertEquals(result.Intro_Discount_Period__c,1);
        System.assertNotEquals(result.Contract_Discount_Language__c, null);

    }

    static testMethod void testIntroUpdate() {
        SBQQ.TriggerControl.disable();

        SBQQ__Quote__c[] quotes = [SELECT Id FROM SBQQ__Quote__c];
        Product2[] prod = [SELECT Id, ProductCode FROM Product2 ORDER BY ProductCode asc];

        Map<String, Product2> pdtsByCode = new Map<String, Product2>();
        for(Product2 pdt : prod) {
            pdtsByCode.put(pdt.ProductCode, pdt);
        }

        Account[] accts = [SELECT Id FROM Account];

        SBQQ__QuoteLine__c[] insertLines = new List<SBQQ__QuoteLine__c>();
        SBQQ__QuoteLine__c baseBundle = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = pdtsByCode.get('CG-BASE').Id,
            SBQQ__Quote__c = quotes[0].Id,
            Fulfillment_Account__c = accts[0].Id,
            SBQQ__Quantity__c = 1
        );
        insertLines.add(baseBundle);
        SBQQ__QuoteLine__c enhanced = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = pdtsByCode.get('ENH-PLC').Id,
            SBQQ__Quote__c = quotes[0].Id,
            Fulfillment_Account__c = accts[0].Id,
            SBQQ__Quantity__c = 1
        );
        insertLines.add(enhanced);
        insert insertLines;

        Test.startTest();

        baseBundle.Intro_Discount_Percentage__c = 1;
        baseBundle.Intro_Discount_Period__c = 1;
        update baseBundle;

        Test.stopTest();

        SBQQ__QuoteLine__c result = [SELECT Id, Intro_Discount_Percentage__c, Intro_Discount_Period__c FROM SBQQ__QuoteLine__c
            WHERE SBQQ__ProductCode__c = 'ENH-PLC' limit 1];

        System.assertEquals(result.Intro_Discount_Percentage__c,1);
        System.assertEquals(result.Intro_Discount_Period__c,1);
    }
    
    
    
    @isTest
    static void checkNumFulfillmentAccountsInsert(){

        Account acc = [SELECT Id FROM Account LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2[] prod = [SELECT Id FROM Product2 WHERE ProductCode = 'CG-BASE'];

        Test.startTest();
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            quote.Id,
            acc.Id,
            new Set<ID>{prod[0].Id}
        )[0];
        insert testQuoteLine;
        Test.stopTest();

        Decimal NumFulfillmentAccounts = [SELECT NumFulfillmentAccounts__c
                                          FROM SBQQ__Quote__c][0].NumFulfillmentAccounts__c;
        
        System.assertEquals(1, NumFulfillmentAccounts, 'NumFulfillmentAccounts__c did not update as expected');
    }
    
    @isTest
    static void checkNumFulfillmentAccountsDeleteAndUndelete(){

        Account acc = [SELECT Id FROM Account LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2[] prod = [SELECT Id FROM Product2 WHERE ProductCode = 'CG-BASE'];

        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            quote.Id,
            acc.Id,
            new Set<ID>{prod[0].Id}
        )[0];
        insert testQuoteLine;
        
        List<SBQQ__QuoteLine__c> childLines = [SELECT Id
                                               FROM SBQQ__QuoteLine__c];
        
        Test.startTest();
        delete childLines;
        undelete childLines;
        Test.stopTest();
        
        Decimal NumFulfillmentAccounts = [SELECT NumFulfillmentAccounts__c
                                          FROM SBQQ__Quote__c][0].NumFulfillmentAccounts__c;
        
        System.assertEquals(1, NumFulfillmentAccounts, 'NumFulfillmentAccounts__c did not update as expected');

    }
    
    @isTest
    static void checkNumFulfillmentAccountsUpdate(){
        Account parentAccount = [SELECT Id
                                FROM Account
                                LIMIT 1];
        
        Account childAccount = TestDataFactory.createAccounts(1)[0];
        childAccount.parentId = parentAccount.Id;
        insert childAccount;

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2[] prod = [SELECT Id FROM Product2 WHERE ProductCode = 'CG-BASE'];

        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            quote.Id,
            parentAccount.Id,
            new Set<ID>{prod[0].Id}
        )[0];
        insert testQuoteLine;
        
        SBQQ__QuoteLine__c existingLine = [SELECT Id
                                           FROM SBQQ__QuoteLine__c
                                           LIMIT 1];
        
        existingLine.Fulfillment_Account__c = childAccount.Id;
        
        Test.startTest();
        update existingLine;
        Test.stopTest();
        
        for (SBQQ__QuoteLine__c ql : [SELECT Fulfillment_Account__c
                                      FROM SBQQ__QuoteLine__c])
        {
            system.debug(ql.Fulfillment_Account__c);
        }
        
        Decimal NumFulfillmentAccounts = [SELECT NumFulfillmentAccounts__c
                                          FROM SBQQ__Quote__c][0].NumFulfillmentAccounts__c;
        
        System.assertEquals(1, NumFulfillmentAccounts, 'NumFulfillmentAccounts__c did not update as expected');
    }

    static testMethod void testNullCGBaseBundleQuantity() {
        SBQQ.TriggerControl.disable();

        SBQQ__Quote__c[] quotes = [SELECT Id,SBQQ__Status__c FROM SBQQ__Quote__c];
        Product2[] prod = [SELECT Id FROM Product2 ORDER BY ProductCode asc];
        Account[] accts = [SELECT Id FROM Account];

        SBQQ__QuoteLine__c[] insertLines = new List<SBQQ__QuoteLine__c>();
        SBQQ__QuoteLine__c baseBundle = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = prod[0].Id,
            SBQQ__Quote__c = quotes[0].Id,
            Fulfillment_Account__c = accts[0].Id,
            Intro_Discount_Percentage__c = 1,
            Intro_Discount_Period__c = 1
        );
        insertLines.add(baseBundle);
        insert insertLines;

        Test.startTest();
        SBQQ__QuoteLine__c baseBundle1 = [SELECT Id, SBQQ__Quantity__c,SBQQ__RequiredBy__c
		                              FROM SBQQ__QuoteLine__c
		                              WHERE SBQQ__Product__r.name='CG Base Bundle' limit 1];
        
            SBQQ__QuoteLIne__c enhanced = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = prod[1].Id,
            SBQQ__Quote__c = quotes[0].Id,
            SBQQ__RequiredBy__c=baseBundle1.Id,
            Fulfillment_Account__c = accts[0].Id
        );
        insert enhanced;

        SBQQ__QuoteLine__c enchanced1 = [SELECT Id, SBQQ__Quantity__c,SBQQ__RequiredBy__c
		                                 FROM SBQQ__QuoteLine__c
		                                 WHERE SBQQ__ProductCode__c = 'ENH-PLC' limit 1];
        
        enchanced1.SBQQ__Quantity__c = 0.00;
        update enchanced1;
             
        Test.stopTest();
        SBQQ__QuoteLine__c baseBundle2 = [SELECT Id, SBQQ__Quantity__c,SBQQ__RequiredBy__c
		                              FROM SBQQ__QuoteLine__c
		                              WHERE SBQQ__Product__r.name='CG Base Bundle' limit 1];
        
        System.assertEquals(0, baseBundle2.SBQQ__Quantity__c);

    }    

   @IsTest
    static void setDefaultPaymentMethodTest() {

        //Delete existing quote Lines
        List<SBQQ__QuoteLine__c> quoteLines = [SELECT Id FROM SBQQ__QuoteLine__c];
        delete quoteLines;

        //Update quote status to amendment and set PM to null
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        quote.SBQQ__Type__c = ConstantsUtil.QUOTE_TYPE_AMENDMENT;
        quote.Payment_Method__c = null;
        update quote;

        //Create Zuora Account and update relation to SF Account
        Account account = [SELECT Id, Billing_Account_Zuora__c FROM Account];
        List<Zuora__CustomerAccount__c>  billingAccount = TestDataFactory.createZuoraAccount(1, account);
        billingAccount[0].Zuora__DefaultPaymentMethod__c = 'CreditCard';
        insert billingAccount[0];
        account.Billing_Account_Zuora__c = billingAccount[0].Id;
        update account;

        //Insert new line with the related billing account        
        Product2 product = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode = 'CG-BASE' LIMIT 1];
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            quote.Id,
            account.Id,
            new Set<ID>{product.Id}
        )[0];

        testQuoteLine.Billing_Account__c = account.Id;
        insert testQuoteLine;

        //Re-Query quote to get updated PM value
        SBQQ__Quote__c quote2 = [SELECT Id , Payment_Method__c FROM SBQQ__Quote__c LIMIT 1];
        //Quote PM should be Credit Card
        System.assertEquals('Credit Card', quote2.Payment_Method__c);

    }

    static testMethod void testCoopEligible() {
        SBQQ.TriggerControl.disable();

        SBQQ__Quote__c[] quotes = [SELECT Id FROM SBQQ__Quote__c];
        Product2[] prod = [SELECT Id, ProductCode, Family FROM Product2 ORDER BY ProductCode asc];

        Map<String, Product2> pdtsByCode = new Map<String, Product2>();
        for(Product2 pdt : prod) {
            pdtsByCode.put(pdt.ProductCode, pdt);
        }

        Account[] accts = [SELECT Id FROM Account];

        Test.startTest();

        SBQQ__QuoteLine__c[] insertLines = new List<SBQQ__QuoteLine__c>();
        SBQQ__QuoteLine__c baseBundle = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = pdtsByCode.get('CG-BASE').Id,
            SBQQ__Quote__c = quotes[0].Id,
            Fulfillment_Account__c = accts[0].Id
        );
        insertLines.add(baseBundle);
        SBQQ__QuoteLine__c enhanced = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = pdtsByCode.get('ENH-PLC').Id,
            SBQQ__Quote__c = quotes[0].Id,
            Fulfillment_Account__c = accts[0].Id,
            SBQQ__Quantity__c = 1
        );
        insertLines.add(enhanced);
        insert insertLines;

        Test.stopTest();
        SBQQ__QuoteLine__c result = [SELECT Id, Potential_Co_Op_Eligible__c, Contract_Discount_Language__c FROM SBQQ__QuoteLine__c
            WHERE SBQQ__ProductCode__c = 'ENH-PLC' limit 1];

        System.assertEquals(true, result.Potential_Co_Op_Eligible__c);
    }

    @IsTest
    static void testreplacePlacementProductsOnRenewal() {
        SBQQ.TriggerControl.disable();
        List<Account> accts = [SELECT Id FROM Account];
        List<Product2> pdts = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN ('PKG-ENH', 'ENH-PLC')];
        Map<String, Product2> pdtsByCode = new Map<String, Product2>();
        for(Product2 pdt : pdts) {
            pdtsByCode.put(pdt.ProductCode, pdt);
        }

        List<SBQQ__Quote__c> qts = [SELECT Id FROM SBQQ__Quote__c];
        qts[0].SBQQ__Type__c = 'Renewal';
        update qts;

        List<SBQQ__QuoteLine__c> qtLines = new List<SBQQ__QuoteLine__c>();
        SBQQ__QuoteLine__c enhPlcQl = new SBQQ__QuoteLine__c (
           SBQQ__Quote__c = qts[0].Id,
           SBQQ__Product__c = pdtsByCode.get('ENH-PLC').Id,
           SBQQ__ListPrice__c = -120,
           SBQQ__NetPrice__c = -120,
           SBQQ__Quantity__c = 0,
           SBQQ__Existing__c = true,
           Fulfillment_Account__c = accts[0].Id,
           Retain_Current_Net_Total__c = false
        );
        qtLines.add(enhPlcQl);
        
        Test.startTest();
        insert qtLines;
        Test.stopTest();
   
        SBQQ__QuoteLine__c result = [SELECT Id, SBQQ__Product__c, SBQQ__Product__r.Name FROM SBQQ__QuoteLine__c WHERE SBQQ__Product__r.Name = 'Enhanced Package'];
        System.assertEquals('Enhanced Package', result.SBQQ__Product__r.Name);
       
   }

    static testMethod void testBillingTypeMisMatchTrue() {
        SBQQ.TriggerControl.disable();
        Account[] accts = [SELECT Id FROM Account];
        Product2[] prod = [SELECT ID FROM Product2];

        accts[0].Field_Group_Type__c = 'National';
        update accts;

        Zuora__Subscription__c[] zSubs = TestDataFactory.createZSubscriptions(accts[0].id, 1);
        zSubs[0].Zuora__Status__c = 'Active';
        insert zSubs;

        Zuora__SubscriptionProductCharge__c zspc = new Zuora__SubscriptionProductCharge__c(
            Name = 'Monthly Charge',
            Zuora__Account__c = accts[0].id,
            Zuora__BillingPeriod__c = 'Month',
            Zuora__Subscription__c = zSubs[0].id,
            Zuora__Zuora_Id__c = '8a8aa2c87d585004017d6ab0b1257bed',
            Zuora__Model__c = 'Flat Fee Pricing',
            Zuora__BillingTiming__c = 'In Advance'
        );

        insert zspc;

        List<SBQQ__Subscription__c> subList = testDataFactory.createCPQSubsForProducts(prod, accts[0].id);
        for(SBQQ__Subscription__c sub : subList) {
            sub.Zuora_Subscription__c = zSubs[0].id;
        }
        insert subList;

        SBQQ__Quote__c[] quotes = [SELECT Id,SBQQ__Status__c,Billing_Type__c FROM SBQQ__Quote__c];
        quotes[0].Billing_Type__c = 'Arrears';
        update quotes;
        
        SBQQ__Quoteline__c[] quotelines = [SELECT Id FROM SBQQ__Quoteline__c];

        Test.startTest();
        try{
			update quotelines;
		}catch (DmlException e){
			//Assert Error Message 
			System.assert( e.getMessage().contains('A billing account with a mismatching billing type has been selected.'),e.getMessage() );
		}
        Test.stopTest();
    }
    @IsTest
    static void testsetPreventAutomatedInvoiceToTrue() {
        Account acc = [SELECT Id,Billing_Account_Zuora__c  FROM Account LIMIT 1];
        system.debug('acc'+acc);
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(acc.Id, opp.Id, 1);
        quotes[0].Billing_Type__c = 'Advance';
        insert quotes;

        List<SBQQ__QuoteLine__c> qtLines = new List<SBQQ__QuoteLine__c>();
        SBQQ__QuoteLine__c enhPlcQl = new SBQQ__QuoteLine__c (
           SBQQ__Quote__c = quotes[0].Id,
           Billing_Account__c = acc.Id,
           Fulfillment_Account__c = acc.Id
        );
        Test.startTest();
        insert qtLines;
        Test.stopTest();
   }

   //SA-295
   @IsTest
   static void testOEMQuoteandQuoteLineValidations() {
        
        Account acc = [SELECT Id,Name,Billing_Account_Zuora__c FROM Account LIMIT 1];

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Id oemRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('OEM').getRecordTypeId();
        Product2 prod2 = [SELECT Id FROM Product2 WHERE ProductCode = 'CG-BASE'];
        
        List<Account> acctList = new List<Account>();
        
        for(Account acct : TestDataFactory.createAccounts(5)){
            acct.Name += ' Child To ' + acc.Name;
            acct.Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
            acct.External_Dealer_ID__c = '1234-5';
            acct.Enrollment_Status__c = 'Active';
            acct.ParentId = acc.Id;
            acct.Ultimate_Parent_Account__c = acc.Id;
            acctList.add(acct);
        }
        
        acctList[4].ParentId = null;
        acctList[4].Ultimate_Parent_Account__c = null;
        acctList[4].recordTypeId = oemRecordTypeId;
        insert acctList;

        acctList[0].OEM_Billing_Account__c = acctList[4].Id;
        update acctList[0];
        
        List<Service_Provider__c> testSpids = new List<Service_Provider__c>();
        
        Service_Provider__c spid = TestDataFactory.createSingleServiceProvider(acctList[0].Id);
        spid.Used_Inventory_Avg__c = 5;
        spid.New_Makes_Sold__c = 'Buick,Chevrolet';
        spid.Dealer_Type__c = AccountCategoryCalculator.DEALER_TYPE_NEW;
        testSpids.add(spid);
        insert testSpids;

        List<Zuora__CustomerAccount__c>  billingAccount = TestDataFactory.createZuoraAccount(1, acctList[4]);
        billingAccount[0].Zuora__DefaultPaymentMethod__c = 'CreditCard';
        billingAccount[0].Zuora__Batch__c = 'Batch9';
        insert billingAccount[0];
        
        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(acc.Id, opp.Id, 1);
        quotes[0].Billing_Type__c = 'Arrears';
        quotes[0].Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
        insert quotes;
        
        List<SBQQ__QuoteLine__c> qtLines = TestDataFactory.createQuoteLines(
            quotes[0].Id,
            acctList[0].Id,
            new Set<ID>{prod2.Id}
        );

        for(SBQQ__QuoteLine__c qlLines : qtLines){
            qlLines.SBQQ__BillingType__c = 'Arrears';
        }

        Test.startTest();
        insert qtLines;
        Test.stopTest();
        
        for(SBQQ__QuoteLine__c qlLine : [
            SELECT Fulfillment_Account__c,Billing_Account__c 
            FROM SBQQ__QuoteLine__c 
            WHERE SBQQ__Quote__c=:quotes[0].Id
        ]){
            //Check OEM Billing criteria
            System.assert(qlLine.Billing_Account__c!=null);
            System.assert(qlLine.Billing_Account__c==acctList[4].Id);
        }
   }

   //SA-295
   @IsTest
   static void testOEMQuoteandQuoteLineValidations2() {
    
        Account acc = [SELECT Id,Name,Billing_Account_Zuora__c FROM Account LIMIT 1];

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Id oemRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('OEM').getRecordTypeId();
        Product2 prod2 = [SELECT Id FROM Product2 WHERE ProductCode = 'CG-BASE'];
        
        List<Account> acctList = new List<Account>();
        
        for(Account acct : TestDataFactory.createAccounts(5)){
            acct.Name += ' Child To ' + acc.Name;
            acct.Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
            acct.External_Dealer_ID__c = '1234-5';
            acct.Enrollment_Status__c = 'Active';
            acct.ParentId = acc.Id;
            acct.Ultimate_Parent_Account__c = acc.Id;
            acctList.add(acct);
        }
        
        acctList[4].ParentId = null;
        acctList[4].Ultimate_Parent_Account__c = null;
        acctList[4].recordTypeId = oemRecordTypeId;
        insert acctList;

        acctList[0].OEM_Billing_Account__c = acctList[4].Id;
        update acctList[0];
        
        List<Zuora__CustomerAccount__c>  billingAccount = TestDataFactory.createZuoraAccount(1, acctList[4]);
        billingAccount[0].Zuora__DefaultPaymentMethod__c = 'BankTransfer';
        billingAccount[0].Zuora__Batch__c = 'Batch9';
        insert billingAccount[0];
        
        SBQQ.TriggerControl.disable();

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(acc.Id, opp.Id, 1);
        quotes[0].Billing_Type__c = 'Arrears';
        quotes[0].Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
        insert quotes;
        
        List<SBQQ__QuoteLine__c> qtLines = TestDataFactory.createQuoteLines(
            quotes[0].Id,
            acctList[0].Id,
            new Set<ID>{prod2.Id}
        );
        insert qtLines;

        SBQQ.TriggerControl.enable();
        Test.startTest();

        try{
            qtLines[0].Fulfillment_Account__c = acctList[1].Id;
            update qtLines;
        }catch(Exception e){
            System.AssertEquals(e.getMessage().contains('no relation with the Billing Account'),true);
        }
        Test.stopTest();
        
        for(SBQQ__QuoteLine__c qlLine : [
            SELECT Fulfillment_Account__c,Billing_Account__c 
            FROM SBQQ__QuoteLine__c 
            WHERE SBQQ__Quote__c=:quotes[0].Id
        ]){
            //Billing and Fulfillment Account remained unchanged due to validation
            System.assert(qlLine.Billing_Account__c!=null);
            System.assert(qlLine.Billing_Account__c==acctList[4].Id);
            System.assert(qlLine.Fulfillment_Account__c==acctList[0].Id);
        }
   }

   //SA-869
   @IsTest
   static void testOEMQuoteandQuoteLineValidations3() {
    
        Account acc = [SELECT Id,Name,Billing_Account_Zuora__c FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Id oemRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('OEM').getRecordTypeId();
        Product2 prod2 = [SELECT Id FROM Product2 WHERE ProductCode = 'CG-BASE'];
        
        List<Account> acctList = new List<Account>();
        
        for(Account acct : TestDataFactory.createAccounts(5)){
            acct.Name += ' Child To ' + acc.Name;
            acct.Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
            acct.External_Dealer_ID__c = '1234-5';
            acct.Enrollment_Status__c = 'Active';
            acct.ParentId = acc.Id;
            acct.Ultimate_Parent_Account__c = acc.Id;
            acctList.add(acct);
        }
        
        acctList[4].ParentId = null;
        acctList[4].Ultimate_Parent_Account__c = null;
        acctList[4].recordTypeId = oemRecordTypeId;
        insert acctList;
        acctList[0].OEM_Billing_Account__c = acctList[4].Id;
        update acctList[0];
        
        Service_Provider__c[] sps = TestDataFactory.createServiceProviders(1,acctList[0].id);
        sps[0].Dealer_Type__c = 'New';
        sps[0].New_Makes_Sold__c = 'GMC';
        sps[0].reviewStatus__c = 'APPROVED';
        insert sps;
        
        List<Zuora__CustomerAccount__c>  billingAccount = TestDataFactory.createZuoraAccount(1, acctList[4]);
        billingAccount[0].Zuora__DefaultPaymentMethod__c = 'BankTransfer';
        billingAccount[0].Zuora__Batch__c = 'Batch9';
        insert billingAccount[0];
        
        SBQQ.TriggerControl.disable();
        
        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(acc.Id, opp.Id, 1);
        quotes[0].Billing_Type__c = 'Advance';
        quotes[0].Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
        insert quotes;
        
        List<SBQQ__QuoteLine__c> qtLines = TestDataFactory.createQuoteLines(
            quotes[0].Id,
            acctList[0].Id,
            new Set<ID>{prod2.Id}
        );
        
        insert qtLines;
        
        SBQQ.TriggerControl.enable();
        Test.startTest();
        qtLines[0].Fulfillment_Account__c = acctList[0].Id;
        update qtLines;
        Test.stopTest();
        
        for(SBQQ__QuoteLine__c qlLine : [
            SELECT Fulfillment_Account__c,Billing_Account__c 
            FROM SBQQ__QuoteLine__c 
            WHERE SBQQ__Quote__c=:quotes[0].Id
        ]){
            //Billing and Fulfillment Account remained unchanged due to validation
            System.assert(qlLine.Billing_Account__c!=null);
            System.assert(qlLine.Billing_Account__c==acctList[4].Id);
            System.assert(qlLine.Fulfillment_Account__c==acctList[0].Id);
        }
   }
   
   //SA-869
   @IsTest
   static void testOEMQuoteandQuoteLineValidations4() {
    
        Account acc = [SELECT Id,Name,Billing_Account_Zuora__c FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Id oemRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('OEM').getRecordTypeId();
        Product2 prod2 = [SELECT Id FROM Product2 WHERE ProductCode = 'CG-BASE'];
        
        List<Account> acctList = new List<Account>();
        
        for(Account acct : TestDataFactory.createAccounts(5)){
            acct.Name += ' Child To ' + acc.Name;
            acct.Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
            acct.External_Dealer_ID__c = '1234-5';
            acct.Enrollment_Status__c = 'Active';
            acct.ParentId = acc.Id;
            acct.Ultimate_Parent_Account__c = acc.Id;
            acctList.add(acct);
        }
        
        acctList[4].ParentId = null;
        acctList[4].Ultimate_Parent_Account__c = null;
        acctList[4].recordTypeId = oemRecordTypeId;
        insert acctList;
        acctList[0].OEM_Billing_Account__c = acctList[4].Id;
        update acctList[0];
        
        Service_Provider__c[] sps = TestDataFactory.createServiceProviders(2,acctList[0].id);
        sps[0].Dealer_Type__c = 'New';
        sps[0].New_Makes_Sold__c = 'GMC';
        sps[0].reviewStatus__c = 'APPROVED';
        
        sps[1].Dealer_Type__c = 'New';
        sps[1].New_Makes_Sold__c = 'GMC,Cadillac';
        sps[1].reviewStatus__c = 'APPROVED';
        insert sps;
        
        List<Zuora__CustomerAccount__c>  billingAccount = TestDataFactory.createZuoraAccount(1, acctList[4]);
        billingAccount[0].Zuora__DefaultPaymentMethod__c = 'BankTransfer';
        billingAccount[0].Zuora__Batch__c = 'Batch9';
        insert billingAccount[0];
        
        SBQQ.TriggerControl.disable();
        
        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(acc.Id, opp.Id, 1);
        quotes[0].Billing_Type__c = 'Advance';
        quotes[0].Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
        insert quotes;
        
        List<SBQQ__QuoteLine__c> qtLines = TestDataFactory.createQuoteLines(
            quotes[0].Id,
            acctList[0].Id,
            new Set<ID>{prod2.Id}
        );
        try{
            insert qtLines;
            
            SBQQ.TriggerControl.enable();
        }catch(Exception e){
            System.AssertEquals(e.getMessage().contains('does not satisfy the GM Turnkey Billing requirements. A separate account needs to be created with the allowed OEM makes'),true);
        }
   }
   
   //SA-869
   @IsTest
   static void testOEMQuoteandQuoteLineValidations5() {
    
        Account acc = [SELECT Id,Name,Billing_Account_Zuora__c FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Id oemRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('OEM').getRecordTypeId();
        Product2 prod2 = [SELECT Id FROM Product2 WHERE ProductCode = 'CG-BASE'];
        
        List<Account> acctList = new List<Account>();
        
        for(Account acct : TestDataFactory.createAccounts(5)){
            acct.Name += ' Child To ' + acc.Name;
            acct.Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
            acct.External_Dealer_ID__c = '1234-5';
            acct.Enrollment_Status__c = 'Active';
            acct.ParentId = acc.Id;
            acct.Ultimate_Parent_Account__c = acc.Id;
            acctList.add(acct);
        }
        
        acctList[4].ParentId = null;
        acctList[4].Ultimate_Parent_Account__c = null;
        acctList[4].recordTypeId = oemRecordTypeId;
        insert acctList;
        acctList[0].OEM_Billing_Account__c = acctList[4].Id;
        update acctList[0];
        
        Service_Provider__c[] sps = TestDataFactory.createServiceProviders(2,acctList[0].id);
        sps[0].Dealer_Type__c = 'New';
        sps[0].New_Makes_Sold__c = 'GMC';
        sps[0].reviewStatus__c = 'APPROVED';
        
        sps[1].Dealer_Type__c = 'New';
        sps[1].New_Makes_Sold__c = 'GMC,Buick';
        sps[1].reviewStatus__c = 'APPROVED';
        insert sps;
        
        List<Zuora__CustomerAccount__c>  billingAccount = TestDataFactory.createZuoraAccount(1, acctList[4]);
        billingAccount[0].Zuora__DefaultPaymentMethod__c = 'BankTransfer';
        billingAccount[0].Zuora__Batch__c = 'Batch9';
        insert billingAccount[0];
        
        SBQQ.TriggerControl.disable();
        
        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(acc.Id, opp.Id, 1);
        quotes[0].Billing_Type__c = 'Advance';
        quotes[0].Co_Op_Program_Opt_in__c = 'GM Turnkey Billing';
        insert quotes;
        
        List<SBQQ__QuoteLine__c> qtLines = TestDataFactory.createQuoteLines(
            quotes[0].Id,
            acctList[0].Id,
            new Set<ID>{prod2.Id}
        );
        insert qtLines;
        
        SBQQ.TriggerControl.enable();
        Test.startTest();
        qtLines[0].Fulfillment_Account__c = acctList[0].Id;
        update qtLines;
        Test.stopTest();
    }

   //SA-591
   static testMethod void getTranslatedValuesTest() {

        Set<Id> quoteIds = new Set<Id> ();
        Set<Id> accIds = new Set<Id> ();

        SBQQ__Quote__c quote = [SELECT Id, SBQQ__Account__c
            FROM SBQQ__Quote__c
            LIMIT 1];

        quoteIds.add(quote.Id);
        accIds.add(quote.SBQQ__Account__c);
        
        Product2 product = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode = 'ENH-PLC'];    
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            quote.Id,
            quote.SBQQ__Account__c,
            new Set<ID>{product.Id}
        )[0];
        
        Test.startTest();
        SBQQ.TriggerControl.disable();
        insert testQuoteLine;    
        CPQQuoteLineTriggerFunctions.updateQuoteLineTranslations(quoteIds,accIds);
        SBQQ.TriggerControl.enable();
        Test.stopTest();

        testQuoteLine = [SELECT Id,Translated_Product_Name__c, Translated_Product_Description__c 
            FROM SBQQ__QuoteLine__c WHERE Id = :testQuoteLine.Id];

        Map<String,String> productNameLangMap = Utilities.getTranslatedProductName();
        Map<String,String> productDescriptionLangMap = Utilities.getTranslatedProductDescription();

        System.assertEquals(productNameLangMap.get('English-ENH-PLC'), testQuoteLine.Translated_Product_Name__c, 'Product Name translation was properly stamped');
        System.assertEquals(productDescriptionLangMap.get('English-ENH-PLC'), testQuoteLine.Translated_Product_Description__c, 'Product Description translation was properly stamped');

    }

    //SA-350
    static testMethod void testValidatePendingSubs_OnInsert() {
        
        SBQQ.TriggerControl.disable();
        Test.startTest();
        Account[] accts = [SELECT Id FROM Account];
        Product2[] prod = [SELECT ID FROM Product2];        
        
        Contract contract = TestDataFactory.createContract(accts[0].Id);
        contract.StartDate = System.today().addDays(2);
        insert contract;

        List<SBQQ__Subscription__c> subList = testDataFactory.createCPQSubsForProducts(prod, accts[0].id);
        for(SBQQ__Subscription__c sub : subList) {
            sub.SBQQ__Contract__c = contract.Id;
            sub.FulFillment_Account__c = accts[0].Id;
            sub.Provisioning_Status__c = 'Pending Activation';
            sub.SBQQ__SubscriptionStartDate__c = System.today().addDays(2);
        }
        insert subList;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 1);
        insert opps;

        SBQQ__Quote__c[] amnedQuote = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        amnedQuote[0].SBQQ__Type__c = 'Amendment';        
        insert amnedQuote;       
        
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            amnedQuote[0].Id,
            accts[0].Id,
            new Set<ID>{prod[0].Id}        
        )[0];
        testQuoteLine.SBQQ__Existing__c = false;
        testQuoteLine.FulFillment_Account__c = accts[0].Id;

        try{
            insert testQuoteLine;
        }catch (DmlException e) {
            //Assert Error Message 
            System.assert(e.getMessage().contains('has future Pending Activation Subscriptions starting'),e.getMessage());
        }

        Test.stopTest();
    }

    
    @IsTest 
    static void testEOMExpirationDate(){
        Account ac = [SELECT Id, Billing_Account_Zuora__c FROM Account LIMIT 1];
        Opportunity op = [SELECT Id FROM Opportunity LIMIT 1];

        //query for test data
        SBQQ__Quote__c[] qu = [SELECT Id, SBQQ__Account__c, CreatedDate, SBQQ__ExpirationDate__c, SBQQ__StartDate__c
        FROM SBQQ__Quote__c];

        Product2 product = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode = 'ENH-PLC'];    
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            qu[0].Id,
            qu[0].SBQQ__Account__c,
            new Set<ID>{product.Id}
        )[0];
        insert testQuoteLine;

       //query for quotelines in test setup
        SBQQ__Quoteline__c[] quLi = [SELECT Id, Billing_Account__c, Intro_Discount_Percentage__c, Fulfillment_Account__c, Intro_Discount_Period__c, 
         SBQQ__StartDate__c, SBQQ__Quantity__c FROM SBQQ__Quoteline__c
        WHERE SBQQ__Quote__c = :qu[0].Id];
        quLi[0].Billing_Account__c = ac.Id; 
        quLi[0].Intro_Discount_Percentage__c = 100;
        quLi[0].Fulfillment_Account__c = ac.Id;
        quLi[0].Intro_Discount_Period__c = 1;
        quLi[0].SBQQ__Quantity__c = 1;

        Test.startTest();

        update quLi;
        system.debug('qu[0] expiration is '+qu[0].SBQQ__ExpirationDate__c);
        system.debug('qu[0] created date is '+qu[0].CreatedDate);
        system.debug('qu[0]start date is '+qu[0].SBQQ__StartDate__c);

        //requery for data
        qu = [SELECT Id, CreatedDate, SBQQ__ExpirationDate__c, SBQQ__StartDate__c
        FROM SBQQ__Quote__c];

        system.debug('qu[0] expiration is '+qu[0].SBQQ__ExpirationDate__c);
        system.debug('qu[0] created date is '+qu[0].CreatedDate);
        system.debug('qu[0]start date is '+qu[0].SBQQ__StartDate__c);
        System.assertEquals(qu[0].SBQQ__ExpirationDate__c.Month(), qu[0].CreatedDate.Month());
        Test.stopTest();
    }

    static testMethod void testIntroDiscountsOnRenewals() {        
        
        Test.startTest();
        SBQQ.TriggerControl.disable();
        TriggerHandler.bypass('CPQ_Subscription_TriggerHandler');
        
        Account[] accts = [SELECT Id FROM Account];
        Product2[] prod = [SELECT ID FROM Product2 WHERE ProductCode = 'ENH-PLC'];
        
        Contract contract = TestDataFactory.createContract(accts[0].Id);
        contract.StartDate = System.today().addDays(2);
        insert contract;

        List<SBQQ__Subscription__c> subList = testDataFactory.createCPQSubsForProducts(prod, accts[0].id);
        for(SBQQ__Subscription__c sub : subList) {
            sub.SBQQ__Contract__c = contract.Id;
            sub.FulFillment_Account__c = accts[0].Id;            
            sub.SBQQ__SubscriptionStartDate__c = System.today().addDays(2);
            sub.SBQQ__NetPrice__c = 150;
            sub.Provisioning_Status__c = 'Activated';
        }
        insert subList;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 1);
        insert opps;

        SBQQ__Quote__c[] renewalQuote = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        renewalQuote[0].SBQQ__Type__c = 'Renewal';        
        insert renewalQuote;       
        
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            renewalQuote[0].Id,
            accts[0].Id,
            new Set<ID>{prod[0].Id}        
        )[0];
        testQuoteLine.SBQQ__RenewedSubscription__c = subList[0].Id;
        testQuoteLine.FulFillment_Account__c = accts[0].Id;
        testQuoteLine.SBQQ__ListPrice__c = 200;
        insert testQuoteLine;        

        testQuoteLine.Intro_Discount_Period__c = 1;
        testQuoteLine.Intro_Discount_Percentage__c = 33;
        update testQuoteLine;
        
        TriggerHandler.clearAllBypasses();
        SBQQ.TriggerControl.enable();
        Test.stopTest();

        SBQQ__Quoteline__c quoteLine = [
            SELECT Id,Intro_Discount_Period__c, Intro_Discount_Percentage__c, Retain_Current_Net_Total__c
            FROM SBQQ__Quoteline__c
            WHERE Id = :testQuoteLine.Id
        ];

        System.assertEquals(25, quoteline.Intro_Discount_Percentage__c);
        System.assertEquals(true, quoteline.Retain_Current_Net_Total__c);
    }

    static testMethod void testIntroDiscountsOnRenewals_ROMF() {        
        
        Test.startTest();
        SBQQ.TriggerControl.disable();
        TriggerHandler.bypass('CPQ_Subscription_TriggerHandler');
        
        Account[] accts = [SELECT Id FROM Account];
        Product2[] prod = [SELECT ID FROM Product2 WHERE ProductCode = 'ENH-PLC'];
        
        Contract contract = TestDataFactory.createContract(accts[0].Id);
        contract.StartDate = System.today().addDays(2);
        insert contract;

        List<SBQQ__Subscription__c> subList = testDataFactory.createCPQSubsForProducts(prod, accts[0].id);
        for(SBQQ__Subscription__c sub : subList) {
            sub.SBQQ__Contract__c = contract.Id;
            sub.FulFillment_Account__c = accts[0].Id;            
            sub.SBQQ__SubscriptionStartDate__c = System.today().addDays(2);
            sub.SBQQ__NetPrice__c = 150;
            sub.Provisioning_Status__c = 'Activated';
        }
        insert subList;
        
        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 1);
        insert opps;

        SBQQ__Quote__c[] renewalQuote = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        renewalQuote[0].SBQQ__Type__c = 'Renewal';        
        insert renewalQuote;       
        
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            renewalQuote[0].Id,
            accts[0].Id,
            new Set<ID>{prod[0].Id}        
        )[0];
        testQuoteLine.SBQQ__RenewedSubscription__c = subList[0].Id;
        testQuoteLine.FulFillment_Account__c = accts[0].Id;
        testQuoteLine.SBQQ__ListPrice__c = 200;
        testQuoteLine.Retain_Current_Net_Total__c = true;
        insert testQuoteLine;

        testQuoteLine.Intro_Discount_Period__c = 1;
        testQuoteLine.Intro_Discount_Percentage__c = 100;
        update testQuoteLine;
        
        TriggerHandler.clearAllBypasses();
        SBQQ.TriggerControl.enable();
        Test.stopTest();

        SBQQ__Quoteline__c quoteLine = [
            SELECT Id,Intro_Discount_Period__c, Intro_Discount_Percentage__c, Retain_Current_Net_Total__c
            FROM SBQQ__Quoteline__c
            WHERE Id = :testQuoteLine.Id];

        System.assertEquals(100, quoteline.Intro_Discount_Percentage__c); // Allow ROMF
        System.assertEquals(false, quoteline.Retain_Current_Net_Total__c); // Retain Net Total is false
    }

}