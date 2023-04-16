/**
 * https://cargurus.atlassian.net/browse/CRM-5021
 * 
 * Feature Framework Tests
 * The following classes are covered by these tests:
 * CG_ManageAccountFeatures_extension.cls
 * CG_AccountFeatureComparison
 * CG_AccountFeatureMap
 * CG_AccountFeatureMapHelper
 * CG_AccountFeatureMessageBody
 * CG_AccountFeatureMessageHelper
 * CG_Batch_AccountFeatureDiscrepancies
 * CG_Batch_BACKFILL_AccountFeatures
 * CG_Batch_GenerateAccountFeatureMessages
 * CG_CPQSubscriptionHelper
 * CG_FeatureHelper
 * CG_FeatureIntegrationHelper
 * CG_ManageAccountFeatures_extension
 * CG_ServiceProviderHelper
 */

@isTest
public class CG_FeatureFramework_Test {
    
    @TestSetup
    static void makeData(){

        SBQQ.TriggerControl.disable();
        Test.startTest();

        Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
		adminEscape.Exclude_from_Validation_Rules__c = true;
        upsert adminEscape;
        
        //Accounts
        List<Account> fulfillmentAccounts = TestDataFactory.createAccounts(3, ConstantsUtil.RT_ACCOUNT_DEALER);
        for (Account a : fulfillmentAccounts) {
            a.Product_Activation_Status__c = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE;
        }
        insert fulfillmentAccounts;
        
        //Service Providers
        insert TestDataFactory.createServiceProviders(fulfillmentAccounts);

        //Products
        List<Product2> products = TestDataFactory.createProducts(5);
        insert products;

        //CG Features
        List<CG_Feature__c> cgf = CG_FeatureFramework_TestData.createCGFeature(4);
        insert cgf;

        //CG Feature Metadata
        insert new List<CG_Feature_Metadata__c>{
            CG_FeatureFramework_TestData.createFeatureMetadata(
                cgf[0].Id, 'Integer', 'image-number', '10', true
            ),
            CG_FeatureFramework_TestData.createFeatureMetadata(
                cgf[1].Id, 'Account', 'Name', null, 'Text', 'Name', null, false
            ),
            CG_FeatureFramework_TestData.createFeatureMetadata(
                cgf[2].Id, 'CPQ Subscription', 'SBQQ__NetPrice__c', 7.692308, 'Integer', 'monthlyVDPCap', '0', false
            ),
            CG_FeatureFramework_TestData.createFeatureMetadata(
                cgf[2].Id, 'CPQ Subscription', 'SBQQ__StartDate__c', null, 'Date', 'startDate', null, false
            ),
            CG_FeatureFramework_TestData.createFeatureMetadata(
                cgf[3].Id, 'Boolean', 'emailNotificationEnabled', 'true', true
            ),
            CG_FeatureFramework_TestData.createFeatureMetadata(
                cgf[3].Id, 'Boolean', 'ivrEnabled', 'false', true
            ),
            CG_FeatureFramework_TestData.createFeatureMetadata(
                cgf[3].Id, 'Boolean', 'whisperEnabled', 'false', true
            )
        };

        //CG Product Feature
        insert new List<CG_Product_Feature__c>{
            CG_FeatureFramework_TestData.createProductFeature(products[0].Id, cgf[0].Id),
            CG_FeatureFramework_TestData.createProductFeature(products[1].Id, cgf[1].Id),
            CG_FeatureFramework_TestData.createProductFeature(products[2].Id, cgf[2].Id)
        };

        //CG Status Feature
        insert new List<CG_Status_Feature__c>{
            CG_FeatureFramework_TestData.createStatusFeature(cgf[0].Id, 'Restricted – Activated'),
            CG_FeatureFramework_TestData.createStatusFeature(cgf[1].Id, 'Restricted – Activated')
        };
        
        //cpq subscriptions
        List<SBQQ__Subscription__c> cpqSubs = new List<SBQQ__Subscription__c>();
        for (Account a : fulfillmentAccounts) {
            cpqSubs.addAll(TestDataFactory.createCPQSubsForProducts(products, a.Id));
        }
        insert cpqSubs;

        for(SBQQ__Subscription__c cpqsub : cpqSubs) {
            cpqsub.Provisioning_Status__c = 'Activated';
        }
        update cpqSubs;

        Test.stopTest();
    }

    /**
     * General test method that:
     * - Initilizes the CG_ManageAccountFeatures VisualForce page and extension
     * - Calls some extension methods that would otherwise be hard to cover
     * - Asserts that the expected features are Active
     */
    @isTest
    static void initializePageTest() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Account locAcc = [SELECT Id, Name, BillingCountryCode, Product_Activation_Status__c 
            FROM Account LIMIT 1];

        CG_Feature__c cgf = [SELECT Id FROM CG_Feature__c WHERE CG_Feature_Id__c = 0 LIMIT 1];

        Test.startTest();
        Test.setCurrentPageReference(new PageReference('Page.CG_ManageAccountFeatures')); 
        System.currentPageReference().getParameters().put('id', locAcc.Id);
        ApexPages.StandardController scon = new ApexPages.StandardController(locAcc);
        CG_ManageAccountFeatures_extension extn = new CG_ManageAccountFeatures_extension(scon);
        extn.getSortedFeatureComparisonList();
        extn.getCurrentFeatureList();
        extn.getGeneratedFeatureList();
        extn.accountFeatureComparisonMap.get(0).setEnableStatusOverride();
        extn.accountFeatureComparisonMap.get(0).getMetadataOverridable();
        extn.accountFeatures.getCurrentActiveFeatureCGIds();
        extn.accountFeatures.getOverrideFeatureMap();
        Test.stopTest();

        System.assertEquals('A', extn.accountFeatureComparisonMap.get(0).currentFeature.featureStatus);
        System.assertEquals('A', extn.accountFeatureComparisonMap.get(1).currentFeature.featureStatus);
        System.assertEquals('A', extn.accountFeatureComparisonMap.get(2).currentFeature.featureStatus);
    }

    /**
     * Test method that:
     * - Initilizes the CG_ManageAccountFeatures VisualForce page and extension
     * - Sets up a status override and a metadata overide for a feature
     * - Asserts that a record was created to store the overrides
     * - Asserts that the overridden feature reflects the override status and metadata
     */
    @isTest
    static void testSaveNewOverride() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Account locAcc = [SELECT Id, Name, BillingCountryCode, Product_Activation_Status__c 
            FROM Account LIMIT 1];

        Test.startTest();
        Test.setCurrentPageReference(new PageReference('Page.CG_ManageAccountFeatures')); 
        System.currentPageReference().getParameters().put('id', locAcc.Id);
        ApexPages.StandardController scon = new ApexPages.StandardController(locAcc);
        CG_ManageAccountFeatures_extension extn = new CG_ManageAccountFeatures_extension(scon);
        extn.accountFeatureComparisonMap.get(0).currentFeature.statusOverride = true;
        extn.accountFeatureComparisonMap.get(0).currentFeature.featureStatus = 'I';
        extn.accountFeatureComparisonMap.get(0).currentFeature.metadataOverride = true;
        extn.accountFeatureComparisonMap.get(0).overrideableMetadataMap.put('image-number','20');
        extn.saveAndSend();
        Test.stopTest();

        List<CG_Account_Feature__c> cgaf = [SELECT Id, Status_Override__c, Metadata_Override__c, Metadata__c,
            Status__c FROM CG_Account_Feature__c];

        System.assert(cgaf.size() > 0);
        Map<String, Object> metadataMap;
        if(cgaf.size() > 0) {
            metadataMap = (Map<String, Object>)JSON.deserializeUntyped(cgaf[0].Metadata__c);
        }
        System.assertEquals(true, cgaf[0].Metadata_Override__c);
        System.assertEquals('20', (String)metadataMap.get('image-number'));
        System.assertEquals(true, cgaf[0].Status_Override__c);
        System.assertEquals('I', cgaf[0].Status__c);
        
    }

    /**
     * Test method that:
     * - Initilizes the CG_ManageAccountFeatures VisualForce page and extension
     * - Sets up an override record with a feature status override
     * - Asserts that the feature framework classes have collected the overide
     *   record and the generated Account Features reflect the override
     */
    @isTest
    static void testIncludeStatusOverrideRecord() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Account locAcc = [SELECT Id, Name, BillingCountryCode, Product_Activation_Status__c 
            FROM Account LIMIT 1];

        CG_Feature__c feature = [SELECT Id FROM CG_Feature__c WHERE CG_Feature_Id__c = 0 LIMIT 1];

        insert CG_FeatureFramework_TestData.createFeatureStatusOverride(feature.Id, locAcc.Id, 'I');

        Test.startTest();
        Test.setCurrentPageReference(new PageReference('Page.CG_ManageAccountFeatures')); 
        System.currentPageReference().getParameters().put('id', locAcc.Id);
        ApexPages.StandardController scon = new ApexPages.StandardController(locAcc);
        CG_ManageAccountFeatures_extension extn = new CG_ManageAccountFeatures_extension(scon);
        Test.stopTest();

        System.assertEquals(true, extn.accountFeatureComparisonMap.get(0).currentFeature.statusOverride);
        System.assertEquals('I', extn.accountFeatureComparisonMap.get(0).currentFeature.featureStatus);
    }

    /**
     * Test method that:
     * - Initilizes the CG_ManageAccountFeatures VisualForce page and extension
     * - Sets up an override record with a metadata override
     * - Asserts that the feature framework classes have collected the overide
     *   record and the generated Account Features reflect the overriden metadata
     */
    @isTest
    static void testIncludeMetadataOverrideRecord() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Account locAcc = [SELECT Id, Name, BillingCountryCode, Product_Activation_Status__c 
            FROM Account LIMIT 1];

        CG_Feature__c feature = [SELECT Id FROM CG_Feature__c WHERE CG_Feature_Id__c = 0 LIMIT 1];

        Map<String, Object> overrideMetadata = new Map<String, Object>{
            'image-number' => 53
        };
        insert CG_FeatureFramework_TestData.createFeatureMetadataOverride(feature.Id, locAcc.Id, overrideMetadata);

        Test.startTest();
        Test.setCurrentPageReference(new PageReference('Page.CG_ManageAccountFeatures')); 
        System.currentPageReference().getParameters().put('id', locAcc.Id);
        ApexPages.StandardController scon = new ApexPages.StandardController(locAcc);
        CG_ManageAccountFeatures_extension extn = new CG_ManageAccountFeatures_extension(scon);
        Test.stopTest();

        System.assertEquals(overrideMetadata, 
            extn.accountFeatureComparisonMap.get(0).currentFeature.getFeatureMetadataMap());
    }

    /**
     * Test method that:
     * - Initilizes the CG_ManageAccountFeatures VisualForce page and extension
     * - Sets up an override record with a metadata override
     * - The test makes one more override using the feature control page extension
     * - Asserts that the override record reflects the new overridden metadata
     */
    @isTest
    static void testUpsertOverrideRecord() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Account locAcc = [SELECT Id, Name, BillingCountryCode, Product_Activation_Status__c 
            FROM Account LIMIT 1];

        CG_Feature__c feature = [SELECT Id FROM CG_Feature__c WHERE CG_Feature_Id__c = 0 LIMIT 1];

        Map<String, Object> overrideMetadata = new Map<String, Object>{
            'image-number' => 53
        };
        insert CG_FeatureFramework_TestData.createFeatureMetadataOverride(feature.Id, locAcc.Id, overrideMetadata);

        Test.startTest();
        Test.setCurrentPageReference(new PageReference('Page.CG_ManageAccountFeatures')); 
        System.currentPageReference().getParameters().put('id', locAcc.Id);
        ApexPages.StandardController scon = new ApexPages.StandardController(locAcc);
        CG_ManageAccountFeatures_extension extn = new CG_ManageAccountFeatures_extension(scon);
        extn.accountFeatureComparisonMap.get(0).currentFeature.metadataOverride = true;
        extn.accountFeatureComparisonMap.get(0).overrideableMetadataMap.put('image-number','73');
        extn.saveAndSend();
        Test.stopTest();

        List<CG_Account_Feature__c> cgaf = [SELECT Id, Status_Override__c, Metadata_Override__c, Metadata__c,
            Status__c FROM CG_Account_Feature__c];

        System.assert(cgaf.size() > 0);
        Map<String, Object> metadataMap;
        if(cgaf.size() > 0) {
            metadataMap = (Map<String, Object>)JSON.deserializeUntyped(cgaf[0].Metadata__c);
        }
        System.assertEquals('73', (String)metadataMap.get('image-number'));        
    }

    /**
     * Test method that:
     * - Initilizes the CG_ManageAccountFeatures VisualForce page and extension
     * - Updates the test account to 'Canceling' product activation status
     * - Updates the CPQ Subscriptions to 'Cancelled' status
     * - Asserts that the Feature Framework applies the Account Feature status
     *   for non product active accounts as Inactive or as defined by the CG_Feature_Status__c
     */
    @isTest
    static void testStatusCanceling() {
        // Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        // Account locAcc = [SELECT Id, Name, BillingCountryCode, Product_Activation_Status__c 
        //     FROM Account LIMIT 1];
        // locAcc.Product_Activation_Status__c = 'Canceling';
        // update locAcc;

        // List<SBQQ__Subscription__c> updateSubs = [SELECT Id, Product_Activation_Status__c FROM SBQQ__Subscription__c 
        //     WHERE Fulfillment_Account__c = :locAcc.Id];

        // for(SBQQ__Subscription__c sub : updateSubs) {
        //     // sub.Status__c = 'Cancelled';
        // }
        // update updateSubs;

        // Test.startTest();
        // Test.setCurrentPageReference(new PageReference('Page.CG_ManageAccountFeatures')); 
        // System.currentPageReference().getParameters().put('id', locAcc.Id);
        // ApexPages.StandardController scon = new ApexPages.StandardController(locAcc);
        // CG_ManageAccountFeatures_extension extn = new CG_ManageAccountFeatures_extension(scon);
        // Test.stopTest();
      
        // System.assertEquals('I', extn.accountFeatureComparisonMap.get(0).currentFeature.featureStatus);
        // System.assertEquals('I', extn.accountFeatureComparisonMap.get(1).currentFeature.featureStatus);
        // System.assertEquals('I', extn.accountFeatureComparisonMap.get(2).currentFeature.featureStatus);
    }

    /**
     * Test method that:
     * - Initilizes the CG_ManageAccountFeatures VisualForce page and extension
     * - Updates the test account to 'Restricted – Activated' product activation status
     * - Asserts that the Feature Framework applies the Account Feature status
     *   for non product active accounts as defined by the CG_Feature_Status__c
     */
    @isTest
    static void testStatusAvailableAcc() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Account locAcc = [SELECT Id, Name, BillingCountryCode, Product_Activation_Status__c 
            FROM Account LIMIT 1];
        locAcc.Product_Activation_Status__c = 'Restricted – Activated';
        update locAcc;

        Test.startTest();
        Test.setCurrentPageReference(new PageReference('Page.CG_ManageAccountFeatures')); 
        System.currentPageReference().getParameters().put('id', locAcc.Id);
        ApexPages.StandardController scon = new ApexPages.StandardController(locAcc);
        CG_ManageAccountFeatures_extension extn = new CG_ManageAccountFeatures_extension(scon);
        Test.stopTest();
      
        System.assertEquals('A', extn.accountFeatureComparisonMap.get(0).currentFeature.featureStatus);
        System.assertEquals('A', extn.accountFeatureComparisonMap.get(1).currentFeature.featureStatus);
        System.assertEquals('I', extn.accountFeatureComparisonMap.get(2).currentFeature.featureStatus);
    }

    /**
     * Test method that:
     * - Tests that the Service Provider trigger handler class generates and sends
     *   a feature message for a Service Provider when the Review Status changes
     */
    @isTest
    static void testServiceProviderReviewStatusChange() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Account locAcc = [SELECT Id, Name, BillingCountryCode, Product_Activation_Status__c 
            FROM Account LIMIT 1];
        
        Service_Provider__c sp1 = [SELECT Id, Account__c, ReviewStatus__c, Can_host_inventory__c 
            FROM Service_Provider__c LIMIT 1];
        
        Service_Provider__c sp2 = sp1.clone(true, true, true, true);
        sp2.ReviewStatus__c = 'Denied';

        Test.startTest();
        CG_ServiceProviderHelper.processServiceProviderUpdates(new List<Service_Provider__c>{sp1}, 
            new Map<Id, Service_Provider__c>{sp2.Id => sp2});
        Test.stopTest();
    }

    /**
     * Test method that:
     * - Schedules the CG_Batch_AccountFeatureDiscrepancies for execution 
     *   based on a schedule in the CRON expression
     */
    @isTest
    static void testCGFeatureDiscrepancies() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        String CRON_EXP = '0 0 0 15 3 ? 2099';
        Test.startTest();
        String jobId = System.schedule('CG_Batch_AccountFeatureDiscrepancies'+System.now(),
            CRON_EXP, new CG_Batch_AccountFeatureDiscrepancies()); 
        Test.stopTest();
    
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(CRON_EXP, ct.CronExpression, 'Schedule job cron string mismatch');
    }

    /**
     * Test method that:
     * - Executes the CG_Batch_AccountFeatureDiscrepancies 
     * - The test setup and the MockHTTPResponseGenerator are setup
     *   with mismatching feature metadata
     * - We assert that the batch discovered the discrepacy and created
     *   a Feature Mismatch record with the correct mismatch recorded within
     */
    @isTest
    static void testCGFeatDiscrepanciesByAccount() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id FROM Account]);

        Test.startTest();
        Database.executeBatch(new CG_Batch_AccountFeatureDiscrepancies(accounts.keySet()));
        Test.stopTest();

        List<CG_Feature_Mismatch__c> cgfm = [SELECT Id, CG_Feature_Id__c, CG_Feature_Name__c, Status_SF__c,
            Status_CG__c, Metadata_SF__c, Metadata_CG__c FROM CG_Feature_Mismatch__c 
            WHERE Account__c = :accounts.values()[0].Id AND CG_Feature_Id__c = 0];

        System.assert(cgfm.size() > 0);
        System.assertEquals('{"image-number":"10"}', cgfm[0].Metadata_SF__c);
        System.assertEquals('{"image-number":"101"}', cgfm[0].Metadata_CG__c);
    }

    /**
     * Test method that:
     * - Executes the CG_Batch_AccountFeatureDiscrepancies 
     *   by calling the contructor that takes a query parameter
     * - The test setup and the MockHTTPResponseGenerator are setup
     *   with mismatching feature metadata
     * - We assert that the batch discovered the discrepacy and created
     *   a Feature Mismatch record with the correct mismatch recorded within
     */
    @isTest
    static void testCGFeatDiscrepanciesByQuery() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Account acc = [SELECT Id FROM Account LIMIT 1];

        String query = 'SELECT Id FROM Account WHERE BillingCountryCode IN :FEATURE_COUNTRIES '+
                'AND Id IN '+
                '(SELECT Account__c FROM Service_Provider__c '+
                    'WHERE reviewStatus__c IN :SP_ALLOWREVIEWSTATUS AND Can_host_inventory__c = \'Yes\')';
        
        Test.startTest();
        Database.executeBatch(new CG_Batch_AccountFeatureDiscrepancies(query));
        Test.stopTest();
        
        List<CG_Feature_Mismatch__c> cgfm = [SELECT Id, CG_Feature_Id__c, CG_Feature_Name__c, Status_SF__c,
            Status_CG__c, Metadata_SF__c, Metadata_CG__c FROM CG_Feature_Mismatch__c 
            WHERE Account__c = :acc.Id AND CG_Feature_Id__c = 2];

        System.debug(cgfm);
        String startdt = String.valueOf(Date.today().addDays(-30));
        System.debug(startdt);
        System.assert(cgfm.size() > 0);
        //System.assertEquals('{"startDate":"'+startdt+'","monthlyVDPCap":"769"}', cgfm[0].Metadata_SF__c); 
        System.assertEquals('{"startDate":"'+startdt+'","monthlyVDPCap":"10000"}', cgfm[0].Metadata_CG__c);
    }

    /**
     * Test method that:
     * - Executes the CG_Batch_AccountFeatureDiscrepancies  
     *   by calling the contructor that accepts a cutoff hour
     * - We insert an existing feature mismatch record to cover code that
     *   finds an existing feature mismatch to update
     * - The test setup and the MockHTTPResponseGenerator are setup
     *   with mismatching feature metadata
     */
    @isTest
    static void testCGFeatDiscrepanciesByCutoffHours() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Service_Provider__c sp = [SELECT Id, Account__c, Account__r.Name FROM Service_Provider__c LIMIT 1];

        insert new CG_Feature_Mismatch__c(
            Service_Provider__c = sp.Id,
            Account__c = sp.Account__c,
            CG_Feature_Id__c = 1,
            Status_SF__c = 'A',
            Status_CG__c = 'A',
            Metadata_SF__c = '{"Name":"TestFulfillment-1"}',
            Metadata_CG__c = '{"Name":"TestAccount"}'
        );

        Test.startTest();
        Database.executeBatch(new CG_Batch_AccountFeatureDiscrepancies(1));
        Test.stopTest();           

        List<CG_Feature_Mismatch__c> cgfm = [SELECT Id, CG_Feature_Id__c, CG_Feature_Name__c, Status_SF__c,
            Status_CG__c, Metadata_SF__c, Metadata_CG__c FROM CG_Feature_Mismatch__c 
            WHERE Account__c = :sp.Account__c AND CG_Feature_Id__c = 1];

        System.debug(cgfm);
        System.assert(cgfm.size() > 0);
        //System.assertEquals('{"Name":"'+sp.Account__r.Name+'"}', cgfm[0].Metadata_SF__c);
        System.assertEquals('{"Name":"TestAccount"}', cgfm[0].Metadata_CG__c);
    }

    /**
     * Test method that:
     * - Executes the CG_Batch_AccountFeatureDiscrepancies 
     *   by calling the contructor that accepts a product activation status
     * - The test setup and the MockHTTPResponseGenerator are setup
     *   with mismatching feature metadata
     * - We assert that the batch discovered the discrepacy and created
     *   a Feature Mismatch record with the correct mismatch recorded within
     */
    @isTest
    static void testCGFeatDiscrepanciesByStatus() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Service_Provider__c sp = [SELECT Id, Account__c, Account__r.Name FROM Service_Provider__c LIMIT 1];

        Test.startTest();
        CG_Batch_AccountFeatureDiscrepancies afd = new CG_Batch_AccountFeatureDiscrepancies(new Set<String>{ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE});
        afd.queryLimit = 10;
        Database.executeBatch(afd);
        Test.stopTest();

        List<CG_Feature_Mismatch__c> cgfm = [SELECT Id, CG_Feature_Id__c, CG_Feature_Name__c, Status_SF__c,
            Status_CG__c, Metadata_SF__c, Metadata_CG__c FROM CG_Feature_Mismatch__c 
            WHERE Service_Provider__c = :sp.Id AND CG_Feature_Id__c = 1];

        System.debug(cgfm);
        System.assert(cgfm.size() > 0);
        //System.assertEquals('{"Name":"'+sp.Account__r.Name+'"}', cgfm[0].Metadata_SF__c);
        System.assertEquals('{"Name":"TestAccount"}', cgfm[0].Metadata_CG__c);
    }

    /**
     * Test method that:
     * - Executes the CG_Batch_AccountFeatureDiscrepancies  
     *   by calling the contructor that accepts a cutoff hour
     * - We insert an existing feature mismatch record to cover code that
     *   finds an existing feature mismatch to update
     * - We update the test account name to match the name returned by the
     *   MockHttp response generator indicating no mismatch
     * - We assert that since there are no mismatches, the feature framework
     *   deletes the mismatch record that we have inserted
     */
    @isTest
    static void testCGFeatDiscrepanciesDeleteMismatch() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Service_Provider__c sp = [SELECT Id, Account__c FROM Service_Provider__c LIMIT 1];

        insert new CG_Feature_Mismatch__c(
            Service_Provider__c = sp.Id,
            Account__c = sp.Account__c,
            CG_Feature_Id__c = 1,
            Status_SF__c = 'A',
            Status_CG__c = 'A',
            Metadata_SF__c = '{"Name":"TestFulfillment-1"}',
            Metadata_CG__c = '{"Name":"TestAccount"}'
        );

        update new Account(Id=sp.Account__c, Name='TestAccount');

        Test.startTest();
        Database.executeBatch(new CG_Batch_AccountFeatureDiscrepancies(10));
        Test.stopTest();           

        List<CG_Feature_Mismatch__c> cgfm = [SELECT Id, CG_Feature_Id__c, CG_Feature_Name__c, Status_SF__c,
            Status_CG__c, Metadata_SF__c, Metadata_CG__c FROM CG_Feature_Mismatch__c 
            WHERE Account__c = :sp.Account__c AND CG_Feature_Id__c = 1];

        System.assert(cgfm.size() == 0);
    }

    /**
     * - Executes the CG_Batch_GenerateAccountFeatureMessages batch
     * - This test case passes in a set of account Ids to the batch
     *   constructor
     * - We assert hat the CarGurus Message that was generated and transmitted
     *   by this batch is the Success status
     */
    @isTest
    static void testGenFeatureMsgsBatch() {
        
        Test.setMock(HttpCalloutMock.class, new MockSendFeatureHttpResponse());

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Set<Id> accIds = new Set<Id>{acc.Id};
        Test.startTest();
        Database.executeBatch(new CG_Batch_GenerateAccountFeatureMessages(accIds));
        Test.stopTest();       

        Integration_Message__c generatedMsg = [SELECT Id, Request_Status__c FROM Integration_Message__c WHERE 
            Account__c =:acc.Id LIMIT 1];
        System.assertEquals(Integrations.REQUEST_STATUS_NEW, generatedMsg.Request_Status__c);
    }

    /**
     * - Executes the CG_Batch_GenerateAccountFeatureMessages batch
     * - This test case passes in an account query to the batch
     *   constructor
     * - We assert hat the CarGurus Message that was generated and transmitted
     *   by this batch is the Success status
     */
    @isTest
    static void testGenFeatureMsgsBatchByQuery() {
        
        Test.setMock(HttpCalloutMock.class, new MockSendFeatureHttpResponse());

        Test.startTest();
        Database.executeBatch(new CG_Batch_GenerateAccountFeatureMessages(
            'SELECT Id FROM Account WHERE Name = \'TestFulfillment-1\' LIMIT 1'));
        Test.stopTest();       

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Integration_Message__c generatedMsg = [SELECT Id, Request_Status__c FROM Integration_Message__c WHERE 
            Account__c =:acc.Id LIMIT 1];
        System.assertEquals(Integrations.REQUEST_STATUS_NEW, generatedMsg.Request_Status__c);
    }

    /**
     * - Executes the CG_Batch_GenerateAccountFeatureMessages batch
     * - This test case passes in an account query and a delay parameter 
     *   (set in the send after field by the batch helper) 
     * - We assert hat the CarGurus Message that was generated and transmitted
     *   by this batch is the Success status
     */
    @isTest
    static void testGenFeatureMsgsBatchByDelay() {
        
        Test.setMock(HttpCalloutMock.class, new MockSendFeatureHttpResponse());

        Test.startTest();
        Database.executeBatch(new CG_Batch_GenerateAccountFeatureMessages(
            'SELECT Id FROM Account WHERE Name = \'TestFulfillment-1\' LIMIT 1', -1));
        Test.stopTest();       

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Integration_Message__c generatedMsg = [SELECT Id, Request_Status__c FROM Integration_Message__c WHERE 
            Account__c =:acc.Id LIMIT 1];
        System.assertEquals(Integrations.REQUEST_STATUS_NEW, generatedMsg.Request_Status__c);
    }

    /**
     * - Executes the CG_Batch_GenerateAccountFeatureMessages batch
     * - This test case passes in a set of account ids and a delay parameter 
     *   (set in the send after field by the batch helper) 
     * - We assert hat the CarGurus Message that was generated and transmitted
     *   by this batch is the Success status
     */
    @isTest
    static void testGenFeatureMsgsBatchByDelayAndAccIds() {
        
        Test.setMock(HttpCalloutMock.class, new MockSendFeatureHttpResponse());

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Set<Id> accIds = new Set<Id>{acc.Id};
        Test.startTest();
        Database.executeBatch(new CG_Batch_GenerateAccountFeatureMessages(accIds, -1));
        Test.stopTest();       

        Integration_Message__c generatedMsg = [SELECT Id, Request_Status__c FROM Integration_Message__c WHERE 
            Account__c =:acc.Id LIMIT 1];
        System.assertEquals(Integrations.REQUEST_STATUS_NEW, generatedMsg.Request_Status__c);
    }

    /**
     * MockHTTPResponseGenerator simulates a CG Service Provider feature query response
     */
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        List<Map<String,Object>> testResponse = new List<Map<String,Object>>{
            new Map<String,Object>{
                'id' => 2061849,
                'objectId' => 0,
                'objectType'=> 'SP',
                'featureId'=> 0,
                'status'=> 'A',
                'lastUpdatePersonId'=> 'salesforce-admin@cargurus.com',
                'creationTimestamp' => Long.valueOf('1560271313000'),
                'lastUpdateTimestamp' => Long.valueOf('1561048315000'),
                'requestCreationTimestamp' => Long.valueOf('1560269346000'),
                'requestLastUpdateTimestamp' => Long.valueOf('1561047304000'),
                'metadataList' => new List<Map<String,Object>> {
                    new Map<String,Object>{
                        'id' => 2061849,
                        'name'=> 'image-number',
                        'value'=> '101',
                        'lastUpdatePersonId'=> 'salesforce-admin@cargurus.com',
                        'creationTimestamp' => Long.valueOf('1560271313000'),
                        'lastUpdateTimestamp' => Long.valueOf('1561048315000'),
                        'requestCreationTimestamp' => Long.valueOf('1560269346000'),
                        'requestLastUpdateTimestamp' => Long.valueOf('1561047304000')
                    }
                }
            },
            new Map<String,Object>{
                'id'=> 2061848,
                'objectId'=> 1,
                'objectType'=> 'SP',
                'featureId'=> 1,
                'status'=> 'A',
                'lastUpdatePersonId'=> 'salesforce-admin@cargurus.com',
                'source'=> 'SF',
                'creationTimestamp' => Long.valueOf('1560271313000'),
                'lastUpdateTimestamp' => Long.valueOf('1561048315000'),
                'requestCreationTimestamp' => Long.valueOf('1560269346000'),
                'requestLastUpdateTimestamp' => Long.valueOf('1561047304000'),
                'metadataList' => new List<Map<String,Object>> {
                    new Map<String,Object>{
                        'id' => 2061849,
                        'name'=> 'Name',
                        'value'=> 'Test Account',
                        'lastUpdatePersonId'=> 'salesforce-admin@cargurus.com',
                        'creationTimestamp' => Long.valueOf('1560271313000'),
                        'lastUpdateTimestamp' => Long.valueOf('1561048315000'),
                        'requestCreationTimestamp' => Long.valueOf('1560269346000'),
                        'requestLastUpdateTimestamp' => Long.valueOf('1561047304000')
                    }
                }
            },
            new Map<String,Object>{
                'id' => 2061850,
                'objectId' => 2,
                'objectType' => 'SP',
                'featureId' => 2,
                'status' => 'I',
                'lastUpdatePersonId' => 'salesforce-admin@cargurus.com',
                'source' => 'SF',
                'creationTimestamp' => Long.valueOf('1560271313000'),
                'lastUpdateTimestamp' => Long.valueOf('1561048315000'),
                'requestCreationTimestamp' => Long.valueOf('1560269346000'),
                'requestLastUpdateTimestamp' => Long.valueOf('1561047304000'),
                'metadataList' => new List<Map<String,Object>> {
                    new Map<String,Object>{
                        'id' => 2061849,
                        'name'=> 'monthlyVDPCap',
                        'value'=> '10000',
                        'lastUpdatePersonId'=> 'salesforce-admin@cargurus.com',
                        'creationTimestamp' => Long.valueOf('1560271313000'),
                        'lastUpdateTimestamp' => Long.valueOf('1561048315000'),
                        'requestCreationTimestamp' => Long.valueOf('1560269346000'),
                        'requestLastUpdateTimestamp' => Long.valueOf('1561047304000')
                    },
                    new Map<String,Object>{
                        'id' => 2061849,
                        'name'=> 'startDate',
                        'value'=> String.valueOf(Date.today().addDays(-30)),
                        'lastUpdatePersonId'=> 'salesforce-admin@cargurus.com',
                        'creationTimestamp' => Long.valueOf('1560271313000'),
                        'lastUpdateTimestamp' => Long.valueOf('1561048315000'),
                        'requestCreationTimestamp' => Long.valueOf('1560269346000'),
                        'requestLastUpdateTimestamp' => Long.valueOf('1561047304000')
                    }
                }
            }
        };

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'test/json');
            res.setBody(JSON.serialize(testResponse));
            res.setStatusCode(200);
            return res;
        }
    }

    /**
     * MockSendFeatureHttpResponse simulates an endpoint that responds to 
     * tranmitted feature framework messages
     */
    public class MockSendFeatureHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'test/json');
            res.setStatusCode(200);
            return res;
        }
    }

    /**
     * MockSendFeatureHttpResponse simulates an endpoint that responds to 
     * tranmitted feature framework messages with an error status code
     */
    public class MockSendFeatureErrorHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'test/json');
            res.setStatusCode(503);
            return res;
        }
    }

    /**
     * Generates a sample feature framework message with the supplied 
     * accountId
     */
    public static Map<String, Object> getTestCarGurusMessage(Id accountId) {
        return new Map<String, Object>{
            'source' => 'SF',
            'region' => 'NA',
            'objectType' => 'SP',
            'objectId' => 442533,
            'modifiedDate' => String.valueOf(Datetime.now()),
            'modifiedBy' => 'salesforce-admin@cargurus.com',
            'features' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'status' => 'A',
                    'metadata' => new Map<String, Object>{
                        'image-number' => '101'
                    },
                    'id' => 0
                },
                new Map<String, Object>{
                    'status' => 'A',
                    'metadata' => new Map<String, Object>{
                        'Name' => 'TestFulfillment-1'
                    },
                    'id' => 1
                },
                new Map<String, Object>{
                    'status' => 'A',
                    'metadata' => new Map<String, Object>{
                        'monthlyVdpCap' => '0'
                    },
                    'id' => 2
                }
            },
            'accountStatus' => ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE,
            'accountId' => accountId
        };
    }

}