@isTest
private class CG_LeadOwnership_Test {

    @TestSetup
    static void makeData() {

        User usr = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]; 
        
        Profile salesUserProfile = [SELECT Id FROM Profile WHERE Name = 'Sales User'];
        UserRole r = [SELECT Id FROM UserRole WHERE DeveloperName = 'UK_Manager_Sales_Acquisitions'];
        
        User AE_UK_salesUserOne = new User(Alias = 'su1', Email='AE_UK_SalesUserOne@cg.com.test',
                                     EmailEncodingKey='UTF-8', LastName='One', LanguageLocaleKey='en_US', 
                                     LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
                                     TimeZoneSidKey='America/Los_Angeles', UserName='AE_UK_SalesUserOne@cg.com.test', UserRoleId = r.Id);
        insert AE_UK_salesUserOne;
        
        Group AE_UK_group = [SELECT Id, DEveloperName
            FROM Group
            WHERE DeveloperName = 'RR_AE_GB'];

        GroupMember rrAE_UKGroupMemberOne = new GroupMember();
            rrAE_UKGroupMemberOne.UserOrGroupId = AE_UK_salesUserOne.id;
            rrAE_UKGroupMemberOne.GroupId = AE_UK_group.Id;
        insert rrAE_UKGroupMemberOne;
       
        User SDR_UK_salesUserOne = new User(Alias = 'su2', Email='SDR_UK_SalesUserOne@cg.com.test',
            EmailEncodingKey='UTF-8', LastName='One', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='SDR_UK_SalesUserOne@cg.com.test', UserRoleId = r.Id);
        insert SDR_UK_salesUserOne;
        
        Group SDR_UK_group = [SELECT Id, DEveloperName
            FROM Group
            WHERE DeveloperName = 'RR_SDR_GB'];

        GroupMember SDR_UKGroupMemberOne = new GroupMember();
            SDR_UKGroupMemberOne.UserOrGroupId = SDR_UK_salesUserOne.Id;
            SDR_UKGroupMemberOne.GroupId = SDR_UK_group.Id;
        insert SDR_UKGroupMemberOne;

        System.runAs(usr) {
            Test.startTest();
            setupTerritory();
            setupUSTerritory();
            Test.stopTest();     
        }
    }

    private static void setupTerritory() {

        Account[] accts = TestDataFactory.createAccounts(2);
        for (Account a : accts) {
            a.BillingCountryCode = 'CA';
            a.OwnerId = CG_AccountOwnership.getCGAPIUser();
            a.Account_Status__c = 'Active';
        }
        insert accts;

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

        User acqUser = [SELECT Id FROM User WHERE isActive = true AND Profile.Name = 'Sales User'
            AND Username != 'AE_UK_SalesUserOne@cg.com.test' LIMIT 1];

        UserTerritory2Association uta = new UserTerritory2Association(
            UserId = acqUser.Id,
            RoleInTerritory2 = 'Acquisitions',
            Territory2Id = newTerritory.Id
        );
        insert uta;

    }

    private static void setupUSTerritory() {

        Account[] accts = TestDataFactory.createAccounts(1);
        for (Account a : accts) {
            a.BillingCountryCode = 'US';
            a.OwnerId = CG_AccountOwnership.getCGAPIUser();
            a.Account_Status__c = 'Active';
            a.BillingState = 'TX';
            a.Dealer_Classification__c = 'Independent L1';
        }
        insert accts;

        List<Service_Provider__c> sps = new List<Service_Provider__c>();
        sps.add(TestDataFactory.createSingleServiceProvider(accts[0].Id));
        sps[0].Total_New_Inventory_Units__c = 100;
        sps[0].Total_Used_Inventory_Units__c = 100;
        insert sps;


        Territory2Model tModel = new Territory2Model(
            Name = 'US Test Model',
            DeveloperName = 'US_Test_Model'
        );
        insert tModel;

        Territory2Type tType = [SELECT Id FROM Territory2Type limit 1];

        Territory2 newTerritory = new Territory2(
            AccountAccessLevel = 'Edit',
            OpportunityAccessLevel = 'Edit',
            CaseAccessLevel = 'Read',
            DeveloperName = 'US_Test_Territory',
            Name = 'US Test Territory',
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

        User acqUser = [SELECT Id FROM User WHERE isActive = true AND Profile.Name = 'Sales User' limit 1];

        UserTerritory2Association uta = new UserTerritory2Association(
            UserId = acqUser.Id,
            RoleInTerritory2 = 'USIndependent',
            Territory2Id = newTerritory.Id
        );
        insert uta;

    }

    static testMethod void testAssignmentRule() {
        Lead l = TestDataFactory.createLeads(1)[0];
        l.CountryCode = 'CA';
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.assignmentRuleHeader.useDefaultRule = true;
        l.setOptions(dmo);
        
        insert l;

        l = [SELECT Id,OwnerId FROM Lead WHERE Id =: l.Id limit 1];
        Id expectedOwner = [SELECT Id FROM Group WHERE DeveloperName = 'RR_SDR_CA' limit 1].Id;
        System.assertEquals(l.OwnerId, expectedOwner);
    }

    static testMethod void testSendToRep() {
        Lead l = TestDataFactory.createLeads(1)[0];
        l.CountryCode = 'CA';
        Account[] accts = [SELECT Id FROM Account limit 1];
        l.Lead_Account__c = accts[0].Id;
        l.LeadSource = 'Inbound: Case';
        insert l;

        Test.startTest();
        CG_LeadOwnership.sendToRep(l.Id);
        Test.stopTest();

        Lead[] leads = [SELECT Id, OwnerId FROM Lead WHERE Id =: l.Id];
        Id userId = [SELECT UserId FROM UserTerritory2Association 
                WHERE Territory2Id IN (SELECT Territory2Id FROM ObjectTerritory2Association WHERE ObjectId =: accts[0].Id) limit 1].UserId;
        System.assertEquals(leads[0].OwnerId, userId);

    }

    @isTest
    static void testSendToRepRemoveOldRRUsers() {    
        
        User user = [SELECT Id, Name, UserName, Email FROM User WHERE UserName = 'AE_UK_SalesUserOne@cg.com.test'];
        System.debug('Test, users: ' + user);

        //Create and 'old' Round Robin User
        Round_Robin_User__c rrUser = new Round_Robin_User__c(
                        User__c = user.Id,
                        Territory_Name__c = 'Test Territory',
                        Territory_Role_Name__c = 'Acquisitions'
                    );

        insert rrUser;

        Lead l = TestDataFactory.createLeads(1)[0];
        l.CountryCode = 'CA';
        Account[] accts = [SELECT Id FROM Account limit 1];
        l.Lead_Account__c = accts[0].Id;
        l.LeadSource = 'Inbound: Case';
        insert l;

        Test.startTest();
        CG_LeadOwnership.sendToRep(l.Id);
        Test.stopTest();

        // Query RR users
        List<Round_Robin_User__c> rrUsers = [SELECT Id, User__c, User__r.Name, Territory_Name__c, Territory_Role_Name__c FROM Round_Robin_User__c];
        Boolean userRemovedFromRR = true;
        for (Round_Robin_User__c rr : rrUsers) { 
            if(rr.User__c == user.Id && rr.Territory_Name__c == 'Test Territory' && rr.Territory_Role_Name__c == 'Acquisitions') {
                userRemovedFromRR = false;
            }
        }
        System.assertEquals(true, userRemovedFromRR, 'The user was successfully removed from the Round Robin table');
    }

    static testMethod void testSendToQueue() {
        Lead l = TestDataFactory.createLeads(1)[0];
        l.CountryCode = 'CA';
        Account[] accts = [SELECT Id FROM Account limit 1];
        l.Lead_Account__c = accts[0].Id;
        insert l;

        Test.startTest();
        CG_LeadOwnership.sendToQueue(l.Id);
        Test.stopTest();

        Lead[] leads = [SELECT Id, OwnerId FROM Lead WHERE Id =: l.Id];
        Id CanadianQueueId = [SELECT Id, Name 
                              FROM Group 
                              WHERE Type = 'Queue' 
                              AND Name = 'International: CA'].Id;
        System.assertEquals(leads[0].OwnerId, CanadianQueueId);
    }

    static testMethod void testLeadAccountUpdate() {
        User acqUser = [SELECT Id FROM User WHERE isActive = true AND Profile.Name = 'Sales User' limit 1];
        Account a = [SELECT Id FROM Account limit 1];
        a.OwnerId = acqUser.Id;
        update a;

        Lead l = TestDataFactory.createLeads(1)[0];
        l.CountryCode = 'CA';
        insert l;

        l.Lead_Account__c = a.Id;
        update l;

        l = [SELECT Id,OwnerId FROM Lead WHERE Id =: l.Id limit 1];

        System.assertEquals(l.OwnerId, acqUser.Id);
    }

    @isTest
    static void testLeadAccountCountryUpd() {
        
        Test.startTest();
        Account a = [SELECT Id, BillingCountry FROM Account limit 1];
        Lead l = TestDataFactory.createLeads(1)[0];
        l.Lead_Account__c = a.Id;
        insert l;

        l = [SELECT Id, Country FROM Lead WHERE Id =: l.Id limit 1];

        Test.stopTest();

        System.assertEquals(a.BillingCountry, l.Country);
    }

    @isTest
    static void testUSLeadOwner() {

        Set<Id> itUSMemberIds = new Set<Id> ();

        Test.startTest();
        
        List<GroupMember> isUSGroupMembers = [
            SELECT Id, Group.DeveloperName, UserOrGroupId
            FROM GroupMember
            WHERE Group.DeveloperName = 'RR_IST_US'
        ];
        for (GroupMember gm : isUSGroupMembers) {
            itUSMemberIds.add(gm.UserOrGroupId);
        }

        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        itUSMemberIds.add(user.Id);        
                
        Lead workingLead = new Lead();
        workingLead.FirstName = 'Test';
        workingLead.LastName = 'Working Lead';
        workingLead.CountryCode = 'US';
        workingLead.Company = 'US Company';
        insert workingLead;

        Test.stopTest();

        Lead lead = [SELECT Id, OwnerId FROM Lead];        
        System.assert(itUSMemberIds.contains(lead.OwnerId), 'Lead Owner belongs to the US Inbound Sales Team');
        
    }

    @isTest
    static void testSendToRepUK() {
        
        Set<Id> AE_GB_MemberIds = new Set<Id> ();
        List<GroupMember> AE_GB_GroupMembers = [
            SELECT Id, Group.DeveloperName, UserOrGroupId
            FROM GroupMember
            WHERE Group.DeveloperName = 'RR_AE_GB'
        ];
        
        for (GroupMember gm : AE_GB_GroupMembers) {
            AE_GB_MemberIds.add(gm.UserOrGroupId);
        }

        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].BillingCountryCode = 'GB';
        accts[0].OwnerId = CG_AccountOwnership.getCGAPIUser();
        accts[0].Account_Status__c = 'Active';
        
        insert accts;
        
        Lead l = TestDataFactory.createLeads(1)[0];
        l.CountryCode = 'GB';
        l.Lead_Account__c = accts[0].Id;
        l.LeadSource = 'Inbound: Case';
        insert l;

        Test.startTest();
        CG_LeadOwnership.sendToRep(l.Id);
        Test.stopTest();

        Lead lead = [SELECT Id, OwnerId FROM Lead];        
        System.assert(AE_GB_MemberIds.contains(lead.OwnerId), 'Lead Owner belongs to the UK AE-Team');
        

    }

    @isTest
    static void testUSLeadSendToRep() {

        //Test.startTest();
        
        Account[] accts = [SELECT Id FROM Account WHERE BillingCountryCode = 'US' AND BillingState = 'TX'];

        Lead workingLead = new Lead();
        workingLead.FirstName = 'Test';
        workingLead.LastName = 'Working Lead';
        workingLead.CountryCode = 'US';
        workingLead.State = 'TX';
        workingLead.StateCode = 'TX';
        workingLead.Company = 'US Company';
        workingLead.LeadSource = 'Inbound: Case';
        workingLead.Lead_Account__c = accts[0].Id;
        insert workingLead;

        /* TEMPORARY COMMENTED OUT
        CG_LeadOwnership.sendToRep(workingLead.Id);

        Test.stopTest();

        Lead[] leads = [SELECT Id, OwnerId FROM Lead WHERE Id =: workingLead.Id];
        Id userId = [SELECT UserId
            FROM UserTerritory2Association 
            WHERE Territory2Id IN (SELECT Territory2Id FROM ObjectTerritory2Association WHERE ObjectId =: accts[0].Id) limit 1].UserId;
        
        System.assertEquals(leads[0].OwnerId, userId);
        */
    }
}