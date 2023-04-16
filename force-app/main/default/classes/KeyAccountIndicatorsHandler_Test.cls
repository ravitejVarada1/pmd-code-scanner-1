@isTest
public class KeyAccountIndicatorsHandler_Test {
    
    @testSetup
    public static void setupData(){
        ID dealerAccountRecTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', 'Dealer_Account');
        ID corpAccountRecTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', 'Corporate_Account'); 

        Account testCorpAccount = TestDataFactory.createSingleAccount(corpAccountRecTypeId);
        insert testCorpAccount;
        ID testCorpAccountId = testCorpAccount.Id;

        Account testDealerAccount = TestDataFactory.createSingleAccount(dealerAccountRecTypeId, testCorpAccountId);
        insert testDealerAccount;
        ID testDealerAccountId = testDealerAccount.Id;
        
        Zuora__CustomerAccount__c testZAccount = TestDataFactory.createZuoraAccount(1, testCorpAccount)[0];
        testZAccount.Writeoffbalance__c = '100';
        insert testZAccount;
        ID testZAccountId = testZAccount.Id;
        
        Product2 testProd = TestDataFactory.createProducts(1)[0];
        insert testProd;
        ID testProdId = testProd.Id;
        
        Zuora__Subscription__c testZSub = TestDataFactory.createZSubscriptions(testDealerAccountId, 1)[0];
        testZSub.BillingStatus__c = 'Delinquent';
        insert testZSub;
        ID testZSubId = testZSub.Id;
        
        SBQQ__Subscription__c testSub = TestDataFactory.createCPQSubsForProducts(new List<Product2>{testProd}, testDealerAccountId)[0];
        testSub.Zuora_Subscription__c = testZSubId;
        insert testSub;
        
        testCorpAccount.Billing_Account_Zuora__c = testZAccountId;
        update testCorpAccount; 
    }
    
    //- Jira: BR-3373
    //- Purpose: Test KeyAccountIndicatorsHandler when all alerts are needed
    @isTest
    public static void testAllAlertsTrue(){

        KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators returnedKeyIndicators = 
            (KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators)
            JSON.deserialize
            (
                KeyAccountIndicatorsHandler.getKeyAccountIndicators
                (
                    [SELECT Id
                     FROM Account
                     LIMIT 1][0].Id
                ), 
                KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators.class
            );
        
        System.assertEquals(1, returnedKeyIndicators.parentIndicators.indicators.size());
        System.assertEquals(1, returnedKeyIndicators.childIndicators.size());
        System.assertEquals(1, returnedKeyIndicators.childIndicators[0].indicators.size());

        KeyAccountIndicatorsHandler.KeyIndicator indicator = returnedKeyIndicators.parentIndicators.indicators[0];
        
        indicator.compareTo(indicator);
    }

    @isTest 
    public static void testOutstandingComplianceCaseAlert(){
        //used testAllAlerts test as a baseline to create this one
        //Create new accounts, to ensure they will not have any other KAIs set on them

        ID dealerAccRecTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', 'Dealer_Account');
        ID corpAccRecTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', 'Corporate_Account');
        ID caseORt = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Integrity'); 

        Account testCorpAcc = TestDataFactory.createSingleAccount(corpAccRecTypeId);
        insert testCorpAcc;
        ID testCorpAccId = testCorpAcc.Id;
        testCorpAcc.Name = 'TestCorpAccount';

        Account testDealerAcc = TestDataFactory.createSingleAccount(dealerAccRecTypeId, testCorpAccId);
        insert testDealerAcc;
        ID testDealerAccId = testDealerAcc.Id;
        
        //create one case meeting the requirements to set the KAI
        List<Case> testOpenIntegrityCase = TestDataFactory.createCases(1, testDealerAccId);
        testOpenIntegrityCase[0].Status = 'New'; 
        testOpenIntegrityCase[0].CreatedDate = Datetime.now().addDays(-1);
        ID caseRt = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Integrity'); 
        testOpenIntegrityCase[0].RecordTypeId = caseORt; 
        insert testOpenIntegrityCase[0];

        Test.startTest();
        KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators returnedKeyIndicators = 
            (KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators)
            JSON.deserialize
            (
                KeyAccountIndicatorsHandler.getKeyAccountIndicators
                (testCorpAccId), 
                KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators.class
            ); 
            
        Test.stopTest();

        System.assertEquals(1, returnedKeyIndicators.childIndicators.size()); 
        System.assertEquals(1, returnedKeyIndicators.childIndicators[0].indicators.size()); 

        String checkOutstandingString = returnedKeyIndicators.childIndicators.toString();
        System.assertEquals(true, checkOutStandingString.contains('OUTSTANDING'));
    }

    @isTest 
    public static void testHistoricalComplianceCaseAlert(){
       
        ID dealerRecTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', 'Dealer_Account');
        ID corpRecTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', 'Corporate_Account'); 
        ID caseRt = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Integrity'); 

        Account testCorp = TestDataFactory.createSingleAccount(corpRecTypeId);
        insert testCorp;
        ID testCorpId = testCorp.Id;
        testCorp.Name = 'TestCorpAccount';

        Account testDealer = TestDataFactory.createSingleAccount(dealerRecTypeId, testCorpId);
        insert testDealer;
        ID testDealerId = testDealer.Id;

       
        List<Case> testClosedIntegrityCase = TestDataFactory.createCases(2, testDealerId);

        for (Case cas : testClosedIntegrityCase){ //loops through, setting both cases to criteria that will set the KAI
            cas.Case_Resolution__c = 'Other'; 
            cas.CreatedDate = Datetime.now().addDays(-1); //sets date to within the last two years for SOQL
            cas.RecordTypeId = caseRt; //sets to intergrity record type for SOQL
            cas.Status = 'Closed';
            
        }
        insert testClosedIntegrityCase;
    
        Test.startTest();
        KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators returnedKeyIndicators = 
            (KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators)
            JSON.deserialize
            (
                KeyAccountIndicatorsHandler.getKeyAccountIndicators
                (testCorpId), 
                KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators.class
            ); 
            
        Test.stopTest();

        System.assertEquals(1, returnedKeyIndicators.childIndicators.size()); 
        System.assertEquals(1, returnedKeyIndicators.childIndicators[0].indicators.size()); 

       //created new test, to check whether the returned indicator includes the Historical text in the string
       //goal is to confirm that it is the correct indicator returned, and not just any indicator
        String checkString = returnedKeyIndicators.childIndicators.toString();
        System.assertEquals(true, checkString.contains('HISTORICAL'));
    }
    
    //- Jira: BR-3373
    //- Purpose: Test KeyAccountIndicatorsHandler when no alerts are needed
    @isTest
    public static void testAllAlertsFalse(){
        Zuora__Subscription__c testZSub = [SELECT Id
                                          FROM Zuora__Subscription__c
                                          LIMIT 1][0];
        testZSub.BillingStatus__c = 'Paying';
        update testZSub;
        
                
        Zuora__CustomerAccount__c testZAccount = [SELECT Id
                                                 FROM Zuora__CustomerAccount__c
                                                 LIMIT 1][0];
        testZAccount.Writeoffbalance__c = '0';
        update testZAccount;


        KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators returnedKeyIndicators = 
            (KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators)
            JSON.deserialize
            (
                KeyAccountIndicatorsHandler.getKeyAccountIndicators
                (
                    [SELECT Id
                     FROM Account
                     LIMIT 1][0].Id
                ), 
                KeyAccountIndicatorsHandler.KeyIndicatorsWithChildIndicators.class
            );
        
        System.assertEquals(0, returnedKeyIndicators.parentIndicators.indicators.size());
        System.assertEquals(0, returnedKeyIndicators.childIndicators.size());
    }
    
    @isTest
    public static void testAllAlertColors(){
        KeyAccountIndicatorsHandler.makeIndicatorGrey(
            'TEST 1', 
            'test', 
            'weeklyview',
            10
        );
        KeyAccountIndicatorsHandler.makeIndicatorYellow(
            'TEST 2', 
            'test', 
            'weeklyview',            
            20
        );
        KeyAccountIndicatorsHandler.makeIndicatorRed(
            'TEST 3', 
            'test', 
            'weeklyview',
            30
        );
        KeyAccountIndicatorsHandler.makeIndicatorGreen(
            'TEST 4', 
            'test', 
            'weeklyview',
            40
        );
    }
       
}