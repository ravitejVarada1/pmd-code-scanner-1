/**
* Test class for ChangeOpportunityOwnerController
* @author 	Ramiro Alvarez
* @date 	  11/03/2021
* @module   BR-3994/BR-3972
*/

@isTest
private class ChangeOpportunityOwnerController_Test {

    @TestSetup
    static void makeData() {

        User usr = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]; 
        Profile salesUserProfile = [SELECT Id FROM Profile WHERE Name = 'Sales User'];

        UserRole fieldSDR = [SELECT Id FROM UserRole WHERE Name = 'UK Field SDR'];

        PermissionSetLicense psl = [SELECT Id, DeveloperName
            FROM PermissionSetLicense
            WHERE DeveloperName = 'SalesforceCPQ_CPQStandardPerm'];

        List<PermissionSet> ps = [SELECT Id FROM PermissionSet WHERE Name = 'Salesforce_CPQ_User_Custom' OR Name = 'SteelBrickCPQUser'];        
        
        //Create Field SDR user
        User Field_SDR_SalesUserOne = new User(Alias = 'fSDR1', Email='Field_SDR_SalesUserOne@cg.com.test',
                                     EmailEncodingKey='UTF-8', LastName='One Test', LanguageLocaleKey='en_US', 
                                     LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
                                     TimeZoneSidKey='America/Los_Angeles', UserName='Field_SDR_SalesUserOne@cg.com.test', UserRoleId = fieldSDR.Id);
        insert Field_SDR_SalesUserOne;

        

        List<PermissionSetLicenseAssign> permissionSetLicenseAssignList = new List<PermissionSetLicenseAssign> ();
        List<PermissionSetAssignment> permissionSetAssignmentList = new List<PermissionSetAssignment> ();
        
        permissionSetLicenseAssignList.add(new PermissionSetLicenseAssign(AssigneeId = Field_SDR_SalesUserOne.Id, PermissionSetLicenseId  = psl.Id));
        permissionSetAssignmentList.add(new permissionSetAssignment(AssigneeId = Field_SDR_SalesUserOne.Id, PermissionSetId = ps[0].Id));
        permissionSetAssignmentList.add(new permissionSetAssignment(AssigneeId = Field_SDR_SalesUserOne.Id, PermissionSetId = ps[1].Id));

        // Create Outbound SDR user
        UserRole OutboundSDR = [SELECT Id FROM UserRole WHERE Name = 'UK Outbound SDR'];        
        User Outbound_SDR_SalesUserOne = new User(Alias = 'fSDR1', Email='Outbound_SDR_SalesUserOne@cg.com.test',
                                     EmailEncodingKey='UTF-8', LastName='One Test', LanguageLocaleKey='en_US', 
                                     LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
                                     TimeZoneSidKey='America/Los_Angeles', UserName='Outbound_SDR_SalesUserOne@cg.com.test', UserRoleId = OutboundSDR.Id);
        insert Outbound_SDR_SalesUserOne;

        
        permissionSetLicenseAssignList.add(new PermissionSetLicenseAssign(AssigneeId = Outbound_SDR_SalesUserOne.Id, PermissionSetLicenseId  = psl.Id));
        permissionSetAssignmentList.add(new permissionSetAssignment(AssigneeId = Outbound_SDR_SalesUserOne.Id, PermissionSetId = ps[0].Id));
        permissionSetAssignmentList.add(new permissionSetAssignment(AssigneeId = Outbound_SDR_SalesUserOne.Id, PermissionSetId = ps[1].Id));

        UserRole r = [SELECT Id FROM UserRole WHERE DeveloperName = 'UK_Manager_Sales_Acquisitions'];
        
        User Field_AE_UK_salesUserOne = new User(Alias = 'su1', Email='Field_AE_UK_SalesUserOne@cg.com.test',
                                     EmailEncodingKey='UTF-8', LastName='One', LanguageLocaleKey='en_US', 
                                     LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
                                     TimeZoneSidKey='America/Los_Angeles', UserName='Field_AE_UK_SalesUserOne@cg.com.test', UserRoleId = r.Id);
        insert Field_AE_UK_salesUserOne;
        
        permissionSetLicenseAssignList.add(new PermissionSetLicenseAssign(AssigneeId = Field_AE_UK_salesUserOne.Id, PermissionSetLicenseId  = psl.Id));
        permissionSetAssignmentList.add(new permissionSetAssignment(AssigneeId = Field_AE_UK_salesUserOne.Id, PermissionSetId = ps[0].Id));
        permissionSetAssignmentList.add(new permissionSetAssignment(AssigneeId = Field_AE_UK_salesUserOne.Id, PermissionSetId = ps[1].Id));
        
        // Get Field AE Round Robin group and insert member
        Group Field_AE_UK_group = [SELECT Id, DEveloperName
            FROM Group
            WHERE DeveloperName = 'RR_Field_AE_GB'];
        GroupMember rrFAE_UKGroupMemberOne = new GroupMember();
            rrFAE_UKGroupMemberOne.UserOrGroupId = Field_AE_UK_salesUserOne.Id;
            rrFAE_UKGroupMemberOne.GroupId = Field_AE_UK_group.Id;
        insert rrFAE_UKGroupMemberOne;
        
        // Get AE Round Robin group an insert member
        Group AE_UK_group = [SELECT Id, DEveloperName
            FROM Group
            WHERE DeveloperName = 'RR_AE_GB'];

        User AE_UK_salesUserOne = new User(Alias = 'su1', Email='AE_UK_SalesUserOne@cg.com.test',
                                    EmailEncodingKey='UTF-8', LastName='One', LanguageLocaleKey='en_US', 
                                    LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
                                    TimeZoneSidKey='America/Los_Angeles', UserName='AE_UK_SalesUserOne@cg.com.test', UserRoleId = r.Id);
        insert AE_UK_salesUserOne;

        

        permissionSetLicenseAssignList.add(new PermissionSetLicenseAssign(AssigneeId = AE_UK_salesUserOne.Id, PermissionSetLicenseId  = psl.Id));
        permissionSetAssignmentList.add(new permissionSetAssignment(AssigneeId = AE_UK_salesUserOne.Id, PermissionSetId = ps[0].Id));
        permissionSetAssignmentList.add(new permissionSetAssignment(AssigneeId = AE_UK_salesUserOne.Id, PermissionSetId = ps[1].Id));

        GroupMember rrAE_UKGroupMemberOne = new GroupMember();
            rrAE_UKGroupMemberOne.UserOrGroupId = AE_UK_salesUserOne.Id;
            rrAE_UKGroupMemberOne.GroupId = AE_UK_group.Id;
        insert rrAE_UKGroupMemberOne;

        insert permissionSetLicenseAssignList;
        insert permissionSetAssignmentList;

        System.runAs(usr) {
            Test.startTest();
            setupData();            
            Test.stopTest();     
        }        
    }

    private static void setupData() {
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Active';
        insert accts;

        //Create contact
        Contact tstContact = new Contact(AccountId=accts[0].Id, 
            FirstName='fname1', LastName='lname1', Email='test1@cargurus.com');
        insert tstContact;

        User fSDRuser = [SELECT Id FROM User WHERE UserName = 'Field_SDR_SalesUserOne@cg.com.test'];

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 1);
        opps[0].OwnerId = fSDRuser.Id;
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        insert quotes;

        Product2[] products = new List<Product2>();
        products.add(new Product2(
            Name = 'CG Base Bundle',
            IsActive = true,
            ProductCode = 'CG-BASE'
        ));
        
        insert products;

        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createQuoteLines(
            quotes[0].Id,
            accts[0].Id,
            new Set<ID>{products[0].Id}
        )[0];
        testQuoteLine.Used_Inventory_Cap__c = 15;
        insert testQuoteLine;
    }

    @istest
    public static void sendToFAE_Test() {

        Test.startTest();
        Account acc = [SELECT Id,Account_Saturation_Percentage__c,Account_Saturation_Percentage_Formula__c FROM Account];
        acc.Account_Saturation_Percentage__c = 0;
        update acc;

        Opportunity oppty = [SELECT Id, Account.Account_Saturation_Percentage_Formula__c, OwnerId FROM Opportunity LIMIT 1];
        ChangeOpportunityOwnerController.sendOppty(oppty.Id,'RR_Field_AE_GB');
        Test.stopTest();
        
        
        User fieldAE_user = [SELECT Id FROM User WHERE Username = 'Field_AE_UK_SalesUserOne@cg.com.test'];

        Set<Id> FAE_GB_MemberIds = new Set<Id> ();
        List<GroupMember> AE_Field_GB_GroupMembers = [
            SELECT Id, Group.DeveloperName, UserOrGroupId
            FROM GroupMember
            WHERE Group.DeveloperName = 'RR_Field_AE_GB'
        ];
        
        for (GroupMember gm : AE_Field_GB_GroupMembers) {
            FAE_GB_MemberIds.add(gm.UserOrGroupId);
        }

        Opportunity oppty2 = [SELECT Id, Account.Account_Saturation_Percentage_Formula__c, OwnerId, SBQQ__PrimaryQuote__r.OwnerId FROM Opportunity LIMIT 1];
        System.assert(FAE_GB_MemberIds.contains(oppty2.OwnerId), 'The Oppty Owner belongs to Field AE team');
        System.assertEquals(oppty2.OwnerId, oppty2.SBQQ__PrimaryQuote__r.OwnerId, 'Quote Owner has been updated properly');
    }

    @istest
    public static void sendToAE_Test() {

        Test.startTest();
        Account acc = [SELECT Id FROM Account];

        List<Service_Provider__c> testSpids = new List<Service_Provider__c>();
        Service_Provider__c spid = TestDataFactory.createSingleServiceProvider(acc.Id);
        spid.Total_Used_Inventory_Units__c = 15;
        spid.reviewStatus__c = 'APPROVED';
        testSpids.add(spid);
        insert testSpids;

        Opportunity oppty = [SELECT Id, OwnerId FROM Opportunity LIMIT 1];
        ChangeOpportunityOwnerController.sendOppty(oppty.Id, 'RR_AE_GB');
        Test.stopTest();        
        
        Set<Id> AE_GB_MemberIds = new Set<Id> ();
        List<GroupMember> AE_Field_GB_GroupMembers = [
            SELECT Id, Group.DeveloperName, UserOrGroupId
            FROM GroupMember
            WHERE Group.DeveloperName = 'RR_AE_GB'
        ];
        
        for (GroupMember gm : AE_Field_GB_GroupMembers) {
            AE_GB_MemberIds.add(gm.UserOrGroupId);
        }

        Opportunity oppty2 = [SELECT Id, Account.Account_Saturation_Percentage_Formula__c, OwnerId, SBQQ__PrimaryQuote__r.OwnerId FROM Opportunity LIMIT 1];        
        System.assert(AE_GB_MemberIds.contains(oppty2.OwnerId), 'The Oppty Owner belongs to AE team');
        System.assertEquals(oppty2.OwnerId, oppty2.SBQQ__PrimaryQuote__r.OwnerId, 'Quote Owner has been updated properly');
    }

    @IsTest
    static void checkRoleTest() {
        Boolean checkRole = ChangeOpportunityOwnerController.checkUserRole();
    }

}
