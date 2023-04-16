@isTest
private class CG_AccountOwnership_Test {

    @TestSetup
    static void makeData(){
        List<Account> accounts = TestDataFactory.createAccounts(2);
        accounts[0].BillingCountryCode = 'CA';
        accounts[0].BillingStateCode = 'ON';

        accounts[1].BillingCountryCode = 'GB';
        insert accounts;

        Set<String> userRoleNames = new Set<String>{
            'System_Administrator', 
            'Field_Account_Managers', 
            'Field_Account_Executive',
            'Dealer_Account_Executives',
            'CA_Dealer_Account_Executives'
        };
        
        User usr = [Select id from User where Id = :UserInfo.getUserId()];
        UserRole[] userRoles = [SELECT Id, UserRole.DeveloperName FROM UserRole 
            WHERE DeveloperName 
            IN :userRoleNames];
        
        Map<String, Id> uRoleMap = mapUserRolesByName(userRoles);

        System.runAs(usr) {
            Test.startTest();
            Profile[] profiles = [SELECT Id, Name FROM Profile WHERE Name = 'Sales User'];
            
            Profile salesProfile;
            for (Profile p : profiles) {
                if (p.Name == 'Sales User') {
                    salesProfile = p;
                }
            }

            List<User> users = new List<User>();
            User ca_sales_user = TestDataFactory.createUser(true,salesProfile);
            ca_sales_user.username = 'test12345@cg.com';
            ca_sales_user.UserRoleId = uRoleMap.get('CA_Dealer_Account_Executives');
            users.add(ca_sales_user);
            
            User ca_dram_user = TestDataFactory.createUser(true,salesProfile);
            ca_dram_user.username = 'test23456@cg.com';
            ca_dram_user.UserRoleId = uRoleMap.get('CA_Dealer_Account_Executives');
            users.add(ca_dram_user);

            User dram_user_gb = TestDataFactory.createUser(true,salesProfile);
            dram_user_gb.username = 'dram_user_gb@cg.com';
            dram_user_gb.UserRoleId = uRoleMap.get('Dealer_Account_Executives');
            users.add(dram_user_gb);

            User fam_user_gb = TestDataFactory.createUser(true,salesProfile);
            fam_user_gb.username = 'fam_user_gb@cg.com';
            fam_user_gb.UserRoleId = uRoleMap.get('Field_Account_Managers');
            users.add(fam_user_gb);

            User ae_user_gb = TestDataFactory.createUser(true,salesProfile);
            ae_user_gb.username = 'ae_user_gb@cg.com';
            ae_user_gb.UserRoleId = uRoleMap.get('Dealer_Account_Executives');
            users.add(ae_user_gb);

            insert users;

            setupTerritory(accounts, users);
            Test.stopTest();
        }
    }

    public static Map<String, Id> mapUserRolesByName(List<UserRole> uRoles) {
        Map<String, Id> uRoleMap = new Map<String, Id>();
        for(UserRole ur : uRoles) {
            uRoleMap.put(ur.DeveloperName, ur.Id);
        }
        return uRoleMap;
    }

    public static Map<String, Id> mapUsersByName(List<User> users) {
        Map<String, Id> usrMap = new Map<String, Id>();
        for(User usr : users) {
            usrMap.put(usr.UserName, usr.Id);
        }
        return usrMap;
    }

    public static void setupTerritory(List<Account> accounts, List<User> users) {

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

        List<ObjectTerritory2Association> otas = new List<ObjectTerritory2Association>();
        otas.add(
            new ObjectTerritory2Association(
                Territory2Id = newTerritory.Id,
                ObjectId = accounts[0].Id,
                AssociationCause = 'Territory2Manual'
            )
        );

        otas.add(
            new ObjectTerritory2Association(
                Territory2Id = newTerritory.Id,
                ObjectId = accounts[1].Id,
                AssociationCause = 'Territory2Manual'
            )
        );
        insert otas;

        /*Set<String> testUsernames = new Set<String>{
            'test12345@cg.com', 'test23456@cg.com', 'dram_user_gb@cg.com', 'fam_user_gb@cg.com', 'ae_user_gb@cg.com'
        };
        User users = [SELECT Id FROM User WHERE IsActive = true AND UserName IN :testUsernames];*/
        Map<String, Id> usrMap = mapUsersByName(users);

        List<UserTerritory2Association> utas = new List<UserTerritory2Association>();

        utas.add( 
            new UserTerritory2Association(
                UserId = usrMap.get('test23456@cg.com'),
                RoleInTerritory2 = 'DRAM',
                Territory2Id = newTerritory.Id
            )
        );

        utas.add( 
            new UserTerritory2Association(
                UserId = usrMap.get('dram_user_gb@cg.com'),
                RoleInTerritory2 = 'DRAM',
                Territory2Id = newTerritory.Id
            )
        );

        utas.add( 
            new UserTerritory2Association(
                UserId = usrMap.get('fam_user_gb@cg.com'),
                RoleInTerritory2 = 'FAM',
                Territory2Id = newTerritory.Id
            )
        );
        insert utas;

    }

    static testMethod void updateAcctOwnerToOppOwner() {

        User salesUser = [SELECT Id FROM User WHERE Username = 'test12345@cg.com' AND isActive = true limit 1];

        Account[] accts = [SELECT Id FROM Account];
        accts[0].OwnerId = salesUser.Id;
        update accts;
        
        Test.startTest();

        System.runAs(salesUser) {

            List<Opportunity> oppInsert = TestDataFactory.createOpps(accts[0].Id,1);
            oppInsert[0].Type = 'New Business';
            insert oppInsert;

        }

        Test.stopTest();

        accts = [SELECT Id, OwnerId FROM Account];
        List<Opportunity> opps = [SELECT Id, OwnerId FROM Opportunity];

        System.assert(accts[0].OwnerId == opps[0].OwnerId);

    }

    static testMethod void returnAccountOwnerToCGAPIUser() {

        
        User salesUser = [SELECT Id FROM User WHERE username = 'test12345@cg.com' AND isActive = true limit 1];
        
        Account[] accts = [SELECT Id,Name, BillingCountry FROM Account];
        accts[0].OwnerId = salesUser.Id;
        update accts;

        Test.startTest();

        System.runAs(salesUser) {

            List<Opportunity> oppInsert = TestDataFactory.createOpps(accts[0].Id,1);
            oppInsert[0].Type = 'New Business';
            insert oppInsert;

            oppInsert[0].StageName = 'Closed Lost';
            oppInsert[0].Closed_Lost_Reason__c = 'Auto Close Stale';
            update oppInsert;

        }

        Test.stopTest();

        accts = [SELECT Id, OwnerId FROM Account];
        System.assertEquals(accts[0].OwnerId, CG_AccountOwnership.getCGAPIUser());

    }

    static testMethod void assignAccountToDRAM() {

        Account[] accts = [SELECT Id FROM Account];

        User salesUser = [SELECT Id FROM User WHERE username = 'test12345@cg.com' AND isActive = true limit 1];

        Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
        adminEscape.Exclude_from_Validation_Rules__c = true;
        upsert adminEscape;

        Test.startTest();
        
        accts[0].OwnerId = salesUser.Id;
        update accts;

        Contact[] conts = TestDataFactory.createContacts(1,accts[0].Id);
        insert conts;
        
        AccountTeamMember atm = new AccountTeamMember(
            AccountId = accts[0].Id,
            UserId = salesUser.Id,
            TeamMemberRole = 'Acquisitions'
        );
        insert atm;
        
        List<Opportunity> oppInsert = TestDataFactory.createOpps(accts[0].Id,1);
        oppInsert[0].Type = 'New Business';
        oppInsert[0].OwnerId = salesUser.Id;
        oppInsert[0].AccountId = accts[0].Id;
        oppInsert[0].QuotePrimaryContact__c = conts[0].Id;
        insert oppInsert;
        
        Opportunity_Tracker__c ot = [SELECT Id FROM Opportunity_Tracker__c WHERE Id IN (SELECT Opportunity_Tracker__c FROM Opportunity WHERE Id =: oppInsert[0].Id) limit 1];
        TestDataFactory.completeOppTracker(ot);
        update ot;

        oppInsert[0].StageName = 'Closed Won';
        update oppInsert;


        Test.stopTest();

        accts = [SELECT Id, OwnerId, Owner.UserName FROM Account];
        System.assertEquals(accts[0].Owner.UserName, 'test23456@cg.com');

    }

    static testMethod void testGBNonFieldClosedWon() {

        Account[] accts = [SELECT Id FROM Account WHERE BillingCountryCode = 'GB'];

        Contact[] conts = TestDataFactory.createContacts(1,accts[0].Id);
        insert conts;

        User salesUser = [SELECT Id FROM User WHERE username = 'ae_user_gb@cg.com' LIMIT 1];

        Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
        adminEscape.Exclude_from_Validation_Rules__c = true;
        upsert adminEscape;

        Test.startTest();
        
        accts[0].OwnerId = salesUser.Id;
        update accts;
        
        List<Opportunity> oppInsert = TestDataFactory.createOpps(accts[0].Id,1);
        oppInsert[0].Type = 'New Business';
        oppInsert[0].OwnerId = salesUser.Id;
        oppInsert[0].AccountId = accts[0].Id;
        oppInsert[0].QuotePrimaryContact__c = conts[0].Id;
        insert oppInsert;
        
        Opportunity_Tracker__c ot = [SELECT Id FROM Opportunity_Tracker__c WHERE Id IN (SELECT Opportunity_Tracker__c FROM Opportunity WHERE Id =: oppInsert[0].Id) limit 1];
        TestDataFactory.completeOppTracker(ot);
        update ot;

        oppInsert[0].StageName = 'Closed Won';
        update oppInsert;


        Test.stopTest();

        accts = [SELECT Id, OwnerId, Owner.UserName FROM Account WHERE BillingCountry = 'GB'];
        System.debug('accts owner::'+accts[0].Owner.UserName);
        //System.assertEquals(accts[0].Owner.UserName, 'test23456@cg.com');

    }

    static testMethod void testGBFieldClosedWon() {

        Account[] accts = [SELECT Id, Field_Group_Type__c FROM Account WHERE BillingCountryCode = 'GB'];
        Account acc = accts[0];
        acc.Field_Group_Type__c = 'National';
        update acc;

        Contact[] conts = TestDataFactory.createContacts(1,accts[0].Id);
        insert conts;

        User salesUser = [SELECT Id FROM User WHERE username = 'ae_user_gb@cg.com' LIMIT 1];

        Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
        adminEscape.Exclude_from_Validation_Rules__c = true;
        upsert adminEscape;

        Test.startTest();
        
        accts[0].OwnerId = salesUser.Id;
        update accts;
        
        List<Opportunity> oppInsert = TestDataFactory.createOpps(acc.Id,1);
        oppInsert[0].Type = 'New Business';
        oppInsert[0].OwnerId = salesUser.Id;
        oppInsert[0].AccountId = accts[0].Id;
        oppInsert[0].QuotePrimaryContact__c = conts[0].Id;
        insert oppInsert;
        
        Opportunity_Tracker__c ot = [SELECT Id FROM Opportunity_Tracker__c WHERE Id IN (SELECT Opportunity_Tracker__c FROM Opportunity WHERE Id =: oppInsert[0].Id) limit 1];
        TestDataFactory.completeOppTracker(ot);
        update ot;

        oppInsert[0].StageName = 'Closed Won';
        update oppInsert;


        Test.stopTest();

        accts = [SELECT Id, OwnerId, Owner.UserName FROM Account WHERE BillingCountry = 'GB'];
        
        System.assertEquals(accts[0].Owner.UserName, 'fam_user_gb@cg.com');

    }

    static testMethod void updateAccountOwner() {
         Account[] accts = [SELECT Id , Type FROM Account];

          User salesUser = [SELECT Id FROM User WHERE username = 'test12345@cg.com' AND isActive = true limit 1];
          Id CGAPIUserId = [SELECT Id
			               FROM User
			               WHERE Name LIKE '%Cargurus API%' AND isActive = True
			               Limit 1].Id;

        Test.startTest();
        
        accts[0].OwnerId = CGAPIUserId;
        accts[0].Type='Prospect';
        update accts;
        
        AccountTeamMember atm = new AccountTeamMember(
            AccountId = accts[0].Id,
            UserId = salesUser.Id,
            TeamMemberRole = 'Acquisitions'
        );
        insert atm;
        
        List<Opportunity> oppInsert = TestDataFactory.createOpps(accts[0].Id,1);
        oppInsert[0].Type = 'New Business';
        oppInsert[0].OwnerId = salesUser.Id;
        insert oppInsert;
        Test.stopTest();
        
        accts = [SELECT Id, OwnerId, Owner.Name FROM Account];
        System.assertEquals(accts[0].Owner.Name, 'Testing1');
    }
        
}