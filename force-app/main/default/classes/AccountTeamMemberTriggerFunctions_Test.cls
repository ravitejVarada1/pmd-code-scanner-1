@isTest
public class AccountTeamMemberTriggerFunctions_Test {

    @TestSetup
    static void makeData(){
        List<Account> accounts = TestDataFactory.createAccounts(1);
        accounts[0].BillingCountryCode = 'CA';
        accounts[0].BillingStateCode = 'ON';

        insert accounts;

        Set<String> userRoleNames = new Set<String>{
            'System_Administrator',
            'CA_Dealer_Account_Executives'
        };
        
        User usr = [SELECT id from User where Id = :UserInfo.getUserId()];
        UserRole[] userRoles = [SELECT Id, UserRole.DeveloperName FROM UserRole 
            WHERE DeveloperName 
            IN :userRoleNames];
        
        Map<String, Id> uRoleMap = mapUserRolesByName(userRoles);
        System.runAs(usr) {

            Test.startTest();
            Profile salesProfile = [SELECT Id, Name FROM Profile WHERE Name = 'Sales User' LIMIT 1];
            List<User> users = new List<User>();
            User ca_sales_user = TestDataFactory.createUser(true,salesProfile);
            ca_sales_user.username = 'test12345@cg.com';
            ca_sales_user.UserRoleId = uRoleMap.get('CA_Dealer_Account_Executives');
            users.add(ca_sales_user);        

            insert users;
            Test.stopTest();
        }
        
    }

    static testMethod void createAccTeamMemberHistory_Test() {

        Test.startTest();

        Account account = [SELECT Id FROM Account LIMIT 1];
        User salesUser = [SELECT Id, UserRole.Name FROM User WHERE UserName = 'test12345@cg.com' LIMIT 1];
        AccountTeamMember atm = new AccountTeamMember(AccountId = account.Id, UserId = salesUser.Id, TeamMemberRole = 'Account Executive');

        insert atm;

        List<Account_Team_Member_History__c> atmHistoryList = [SELECT Id, Account__c, Action__c, User__c, User_Role_Hierarchy__c FROM Account_Team_Member_History__c];

        System.assertEquals(1, atmHistoryList.size());
        System.assertEquals(atm.AccountId, atmHistoryList[0].Account__c);
        System.assertEquals('Insert', atmHistoryList[0].Action__c);
        System.assertEquals(atm.UserId, atmHistoryList[0].User__c);
        System.assertEquals(salesUser.UserRole.Name, atmHistoryList[0].User_Role_Hierarchy__c);

        Test.stopTest();

    }

    static testMethod void updateAccTeamMemberHistory_Test() {

        

        Account account = [SELECT Id FROM Account LIMIT 1];
        User salesUser = [SELECT Id, UserRole.Name FROM User WHERE UserName = 'test12345@cg.com' LIMIT 1];
        AccountTeamMember atm = new AccountTeamMember(AccountId = account.Id, UserId = salesUser.Id, TeamMemberRole = 'Account Executive');

        insert atm;
        atm.TeamMemberRole = 'Account Manager';

        Test.startTest();

        update atm;

        List<Account_Team_Member_History__c> atmHistoryList = [
            SELECT Id, Account__c, Action__c, User__c, User_Role_Hierarchy__c,
            TeamMemberRole__c
            FROM Account_Team_Member_History__c
            ORDER BY Id DESC
        ];

        System.assertEquals(2, atmHistoryList.size());
        System.assertEquals(atm.AccountId, atmHistoryList[0].Account__c);
        System.assertEquals('Update', atmHistoryList[0].Action__c);
        System.assertEquals(atm.TeamMemberRole, atmHistoryList[0].TeamMemberRole__c);

        Test.stopTest();

    }

    static testMethod void deleteAccTeamMemberHistory_Test() {        

        Account account = [SELECT Id FROM Account LIMIT 1];
        User salesUser = [SELECT Id, UserRole.Name FROM User WHERE UserName = 'test12345@cg.com' LIMIT 1];
        AccountTeamMember atm = new AccountTeamMember(AccountId = account.Id, UserId = salesUser.Id, TeamMemberRole = 'Account Executive');

        insert atm;        

        Test.startTest();

        delete atm;

        List<Account_Team_Member_History__c> atmHistoryList = [
            SELECT Id, Account__c, Action__c, User__c, User_Role_Hierarchy__c
            FROM Account_Team_Member_History__c
            ORDER BY Id DESC
        ];

        System.assertEquals(2, atmHistoryList.size());
        System.assertEquals('Delete', atmHistoryList[0].Action__c);
        Test.stopTest();
    }

    public static Map<String, Id> mapUserRolesByName(List<UserRole> uRoles) {
        Map<String, Id> uRoleMap = new Map<String, Id>();
        for(UserRole ur : uRoles) {
            uRoleMap.put(ur.DeveloperName, ur.Id);
        }
        return uRoleMap;
    }
    
}
