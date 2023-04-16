@IsTest
public without sharing class UserPauseAssignmentController_Test {
    
    @TestSetup
    static void makeData(){
        String orgId = UserInfo.getOrganizationId(); 
        Profile salesUserProfile = [SELECT Id FROM Profile WHERE Name = 'Sales User'];
        User currentUser = [SELECT Id FROM User WHERE Id = :System.UserInfo.getUserId()];
        System.runAs(currentUser) {
            List<User> users = new List<User>();
            for(Integer i = 0; i < 4; i++) {
                User u = TestDataFactory.createUser(true, salesUserProfile);
                u.FirstName = 'Tty'+i;
                u.LastName = 'Acquisitions'+i;
                u.Username = orgId+'cgtestuser'+i+'@cargurustest.com';
                users.add(u);
            }
            insert users;

            Territory2Model ttyModel = new Territory2Model(
                Name = 'Test RR Model',
                DeveloperName = 'Test_RR_Model'
            );
            insert ttyModel;

            Territory2Type ttyType = [SELECT Id FROM Territory2Type limit 1];

            Territory2 tty = new Territory2(
                AccountAccessLevel = 'Edit',
                OpportunityAccessLevel = 'Edit',
                CaseAccessLevel = 'Read',
                DeveloperName = 'Territory1',
                Name = 'Test Territory 1',
                Territory2ModelId = ttyModel.Id,
                Territory2TypeId = ttyType.Id,
                Is_Granular__c = true
            );
            insert tty;

            Group rrGroup = new Group(Name='RR_TEST_GROUP', DeveloperName='RRTESTGROUP');
            insert rrGroup;

            List<UserTerritory2Association> utas = new List<UserTerritory2Association>();
            List<Round_Robin_User__c> rrusers = new List<Round_Robin_User__c>();
            List<GroupMember> gms = new List<GroupMember>();
            for(User u : users) {
                utas.add(
                    new UserTerritory2Association(
                        UserId = u.Id,
                        RoleInTerritory2 = 'Acquisitions',
                        Territory2Id = tty.Id
                    )
                );

                rrusers.add(
                    new Round_Robin_User__c(
                        User__c = u.Id,
                        Territory_Name__c = tty.Name,
                        Territory_Role_Name__c = 'Acquisitions'
                    )
                );

                gms.add(
                    new GroupMember(
                        GroupId = rrGroup.Id, 
                        UserOrGroupId = u.Id
                    )
                );
            }
            insert rrusers;
            insert utas;

            insert gms;
        }
        
    }

    @IsTest
    public static void testAllUsersPausedTerritory() {
        //UserPauseAssignmentController upac = new UserPauseAssignmentController();
        List<User> users = UserPauseAssignmentController.getUsers(null, null, System.UserInfo.getUserId());
        for(User u : users) {
            u.Pause_Assignments__c = true;
        }

        try {
            Test.startTest();
            UserPauseAssignmentController.updateUsers(users);
            Test.stopTest();
        } catch (AuraHandledException ahe) {
            System.debug(ahe.getMessage());
        } catch (Exception e) {
            System.debug(e.getMessage());
        }

        List<Round_Robin_User__c> rrUsersPaused = [SELECT Id FROM Round_Robin_User__c 
            WHERE User_Paused__c = true];
        System.assert(rrUsersPaused.size() == 0, 'Error: All users in the territory/role were allowed to be paused.');
    }
    
    @IsTest
    public static void testAllUsersPausedGroups() {
        //UserPauseAssignmentController upac = new UserPauseAssignmentController();
        List<Round_Robin_User__c> rrusers = [SELECT Id, Round_Robin_Group__c, Territory_Name__c, Territory_Role_Name__c 
            FROM Round_Robin_User__c];
        
        for(Round_Robin_User__c rruser : rrusers) {
            rruser.Territory_Name__c = '';
            rruser.Territory_Role_Name__c = '';
            rruser.Round_Robin_Group__c = 'RRTESTGROUP';
        }
        update rrusers;

        List<User> users = UserPauseAssignmentController.getUsers(null, null, System.UserInfo.getUserId());
        for(User u : users) {
            u.Pause_Assignments__c = true;
        }

        try {
            Test.startTest();
            User runninguser = [SELECT Id FROM User WHERE Id =:UserInfo.getUserId() LIMIT 1];
            System.runAs(runninguser) {
                UserPauseAssignmentController.updateUsers(users);
            }
            Test.stopTest();
        } catch (AuraHandledException ahe) {
            System.debug(ahe.getMessage());
            System.debug(ahe.getStackTraceString());
        } 

        List<Round_Robin_User__c> rrUsersPaused = [SELECT Id FROM Round_Robin_User__c 
            WHERE User_Paused__c = true];
        System.debug(rrUsersPaused.size());
        System.assert(rrUsersPaused.size() == 0, 'Error: All users in the group were allowed to be paused.');
    }

    @IsTest
    public static void testSuccessfulPauseTerritory() {
        List<User> users = UserPauseAssignmentController.getUsers(null, null, System.UserInfo.getUserId());
        Id userIdToAssert = users[0].Id;
        users[0].Pause_Assignments__c = true;

        try {
            Test.startTest();
            UserPauseAssignmentController.updateUsers(users);
            Test.stopTest();
        } catch (AuraHandledException ahe) {
            System.debug(ahe.getMessage());
        } catch (Exception e) {
            System.debug(e.getMessage());
        }

        User u = [SELECT Id, Pause_Assignments__c FROM User WHERE Id = :userIdToAssert];
        System.assert(u.Pause_Assignments__c == true, 'User pause unsuccessful');
    }

    @IsTest
    public static void testSuccessfulPauseGroup() {
        List<Round_Robin_User__c> rrusers = [SELECT Id, Round_Robin_Group__c, Territory_Name__c, Territory_Role_Name__c 
            FROM Round_Robin_User__c];
        
        for(Round_Robin_User__c rruser : rrusers) {
            rruser.Territory_Name__c = '';
            rruser.Territory_Role_Name__c = '';
            rruser.Round_Robin_Group__c = 'RRTESTGROUP';
        }
        update rrusers;

        List<User> users = UserPauseAssignmentController.getUsers(null, null, System.UserInfo.getUserId());
        Id userIdToAssert = users[0].Id;
        users[0].Pause_Assignments__c = true;

        try {
            Test.startTest();
            User runninguser = [SELECT Id FROM User WHERE Id =:UserInfo.getUserId() LIMIT 1];
            System.runAs(runninguser) {
                UserPauseAssignmentController.updateUsers(users);
            }
            Test.stopTest();
        } catch (AuraHandledException ahe) {
            System.debug(ahe.getMessage());
            System.debug(ahe.getStackTraceString());
        } 

        User u = [SELECT Id, Pause_Assignments__c FROM User WHERE Id = :userIdToAssert];
        System.assert(u.Pause_Assignments__c == true, 'User pause unsuccessful');
    }

    @IsTest
    public static void testGetSubordinateUsers() {
        Test.startTest();
        List<User> byRoleUsers = UserPauseAssignmentController.getAllSubRoleUsers();
        List<User> byManagerUsers = UserPauseAssignmentController.getUsersForManager();
        Test.stopTest();
    }
}
