//https://cargurus.atlassian.net/browse/B2BM-168 migrated from CRM-965 Wrap Marketo page for access control
@isTest
public class marketoControllerTest {
    @testSetup 
    static void setup(){
        final string MSI_Access = 'MSI_Access';  
        List<User> userList = new List<User>();
        List<PermissionSet> ps = [SELECT Id FROM PermissionSet WHERE Name = :MSI_Access];

        Profile sysAdminProfile = [SELECT Id, Name FROM Profile WHERE Name = 'System Administrator' LIMIT 1];        
        User sysAdminUser = TestDataFactory.createUser(true, sysAdminProfile);
        userList.add(sysAdminUser);

        Profile salesUserProfile = [SELECT Id, Name FROM Profile WHERE Name = 'Sales User' LIMIT 1];
        User salesUser = TestDataFactory.createRandomUser(true, salesUserProfile);
        salesUser.LastName = 'SalesUserLastName';
        userList.add(salesUser);

        insert userList;
        
        PermissionSetAssignment psa = new PermissionSetAssignment(AssigneeID = sysAdminUser.id, PermissionSetID = ps[0].id);
        insert psa;     
    }
    
    static testMethod void testMarketoControllerAccess(){
        Test.startTest();
        User u = [SELECT Id, profile.Name, LastName FROM user WHERE LastName = 'Testing1' LIMIT 1];
        
        System.runAs(u){
            System.Assert(marketoController.isUserAuthorised(),'User should be authorised');
        }
        Test.stopTest();
    }
    
    static testMethod void testMarketoControllerNoAccess(){
        Test.startTest();
        User u = [SELECT Id, profile.Name, LastName FROM user WHERE LastName = 'SalesUserLastName' LIMIT 1];
        System.runAs(u){
            System.Assert(!marketoController.isUserAuthorised(),'User should not be authorised');
        }
        Test.stopTest();
    }
    
    static testMethod void testMarketoContact(){
        Test.startTest();
        User u = [SELECT Id, Profile.Name, LastName FROM user WHERE LastName = 'Testing1' LIMIT 1];
        System.runAs(u){
            Contact c = new Contact(LastName = 'Test');
            insert c;
            marketoContactExtension mce = new marketoContactExtension(new ApexPages.StandardController(c));
            ApexPages.currentPage().getParameters().put('id', c.id);
            
            System.assert(mce.RecordID == c.id, 'Record ID set');
            System.assert(mce.userAccess, 'User should have access');
        } 
        Test.stopTest();
    }
    
    static testMethod void testMarketoLead(){
        test.startTest();
        User u = [SELECT Id, Profile.Name, LastName FROM user WHERE LastName = 'Testing1' LIMIT 1];
        System.runAs(u){
            List<Lead> c = TestDataFactory.createLeads(1);
            insert c;
            marketoLeadExtension mce = new marketoLeadExtension(new ApexPages.StandardController(c[0]));
            ApexPages.currentPage().getParameters().put('id', c[0].id);
            
            System.assert(mce.RecordID == c[0].id, 'Record ID set');
            System.assert(mce.userAccess, 'User should have access');
        } 
        test.stopTest();
    }
    
    static testMethod void testMarketoOpportunity(){
        test.startTest();
        User u = [SELECT Id, Profile.Name, LastName FROM user WHERE LastName = 'Testing1' LIMIT 1];
        ID dealerAccountRTId = utilities.getrecordTypeId('Account','Dealer_Account');
        
        Account a = new Account(Name = 'Test',RecordTypeId = dealerAccountRTId, BillingCountry = 'US');
        insert a;
        
        System.runAs(u){
            Opportunity c = new Opportunity(Name = 'Test', CloseDate=Date.today(), StageName='Prospecting', AccountId=a.id);
            insert c;
            marketoOpportunityExtension mce = new marketoOpportunityExtension(new ApexPages.StandardController(c));
            ApexPages.currentPage().getParameters().put('id', c.id);
            
            System.assert(mce.RecordID == c.id, 'Record ID set');
            System.assert(mce.userAccess, 'User should have access');
        } 
        test.stopTest();
    }
    
    static testMethod void testMarketoAccount(){
        test.startTest();
        User u = [SELECT Id, Profile.Name, LastName FROM user WHERE LastName = 'Testing1' LIMIT 1];
        ID dealerAccountRTId = utilities.getrecordTypeId('Account','Dealer_Account');
        System.runAs(u){
            Account c = new Account(Name = 'Test',RecordTypeId = dealerAccountRTId, BillingCountry = 'US');
            insert c;
            marketoAccountExtension mce = new marketoAccountExtension(new ApexPages.StandardController(c));
            ApexPages.currentPage().getParameters().put('id', c.id);
            
            System.assert(mce.RecordID == c.id, 'Record ID set');
            System.assert(mce.userAccess, 'User should have access');
        } 
        test.stopTest();
    }
}