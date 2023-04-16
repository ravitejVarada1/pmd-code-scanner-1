@isTest
public class Batch_UpdateOnboardingCaseOwner_Test {
    @testSetup
    static void userSetup(){

    User usr = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]; 
        Profile salesUserProfile = [SELECT Id FROM Profile WHERE Name = 'Sales User'];
        UserRole r = [SELECT Id FROM UserRole WHERE DeveloperName = 'UK_Manager_Sales_Acquisitions'];
        
        User AE_UK_salesUserOne = new User(Alias = 'su1', Email='AE_UK_SalesUserOne@cg.com.test',
                                    EmailEncodingKey='UTF-8', LastName='One', LanguageLocaleKey='en_US', 
                                    LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
                                    TimeZoneSidKey='America/Los_Angeles', UserName='AE_UK_SalesUserOne@cg.com.test', UserRoleId = r.Id);
        insert AE_UK_salesUserOne;
        
        User SDR_UK_salesUserOne = new User(Alias = 'su2', Email='SDR_UK_SalesUserOne@cg.com.test',
                                    EmailEncodingKey='UTF-8', LastName='One', LanguageLocaleKey='en_US', 
                                    LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
                                    TimeZoneSidKey='America/Los_Angeles', UserName='SDR_UK_SalesUserOne@cg.com.test', UserRoleId = r.Id);
        insert SDR_UK_salesUserOne;
            System.runAs(usr) {
            Test.startTest();
            setupData();
            Test.stopTest();     
        }
    }

    private static void setupData() {
        Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
        adminEscape.Exclude_from_Validation_Rules__c = true;
        upsert adminEscape;
        
        List<User> acqUserList = [SELECT Id FROM User WHERE isActive = true AND Profile.Name = 'Sales User'
            			         AND Username IN ('AE_UK_SalesUserOne@cg.com.test','SDR_UK_SalesUserOne@cg.com.test')];
        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        Account[] accts = TestDataFactory.createAccounts(2);
        accts[1].Name = 'CarGurus Account';
        accts[1].OwnerId = acqUserList[0].Id;
        accts[1].BillingCountryCode = 'CA';
        insert accts;

        Contact[] conts = TestDataFactory.createContacts(1,accts[1].Id);
        insert conts;
        
        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id,1);
        opps[0].AccountId = accts[1].Id;
        opps[0].QuotePrimaryContact__c = conts[0].Id;
        opps[0].Type = 'New Business';
        insert opps;
        
        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        quotes[0].SBQQ__StartDate__c = System.today().addMonths(1);
        quotes[0].SBQQ__Opportunity2__c = opps[0].Id;
        quotes[0].SBQQ__Type__c = 'Quote';
        insert quotes;
        
        Case c = new Case();
        c.Status = 'New';
        c.AccountId = accts[0].Id;
        c.RecordTypeId = [SELECT Id FROM RecordType WHERE sObjectType = 'Case' AND Name = 'Onboarding'][0].Id;
        c.Status = 'New';
        c.AccountId = accts[1].Id;
        c.Related_Quote__c = quotes[0].Id;
        c.OwnerId = acqUserList[1].Id;
        insert c;

    }
    
    @isTest
    static void UpdateOnboardingCaseOwner() {
        
        List<Opportunity> oppty = [SELECT Id, SBQQ__PrimaryQuote__c, Type, StageName  FROM Opportunity];
        oppty[0].StageName = 'Closed Won';
        update oppty;
        Case c1 = [Select Id, CountryCode__c from Case limit 1];
        c1.CountryCode__c = 'CA';
        update c1;
        
        Test.startTest();
        Database.executeBatch(new Batch_UpdateOnboardingCaseOwner());
        Test.stopTest();
        Case c = [Select Id,OwnerId,Account.OwnerId FROM Case Limit 1];
        System.assertEquals(c.Account.OwnerId == c.OwnerID, true);
    }
    
}