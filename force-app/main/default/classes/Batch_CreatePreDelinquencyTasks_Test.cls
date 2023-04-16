@isTest
private class Batch_CreatePreDelinquencyTasks_Test {
    
    @TestSetup
    static void makeData(){

        User accountOwner = TestDataFactory.createUser(
            true, [Select Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1]
        );

        insert accountOwner;

        List<Account> accounts = TestDataFactory.createAccounts(1);
        accounts[0].OwnerId = accountOwner.Id;

        insert accounts;

        // create past due invoice
        Zuora__ZInvoice__c invoice = new Zuora__ZInvoice__c(
            Zuora__Account__c = accounts[0].Id,
            Zuora__Status__c = 'Posted', 
            Zuora__Balance2__c = 1000.00,
            Zuora__InvoiceDate__c = System.Today() - 16,
            Zuora__DueDate__c	= System.Today() - 16,
            Zuora__TargetDate__c = System.Today(),
            Zuora__PaymentAmount__c = 0.00
        );

        insert invoice;

    }

    
    static testMethod void testAccountManagerAsOwner() {
        
        Zuora__ZInvoice__c invoice = [
            SELECT Id, Name, Zuora__Account__c, Zuora__Account__r.OwnerId, Zuora__Balance2__c, Zuora__DueDate__c 
            FROM Zuora__ZInvoice__c 
            LIMIT 1
        ];
        
        List<String> teamRoleList = new List<String>{'Account Manager', 'Field Account Manager'};
        List<User> userList = new List<User>();

        // create 2 users and add to list
        userList.add(
            TestDataFactory.createRandomUser(true, [Select Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1])
        );

        userList.add(
            TestDataFactory.createRandomUser(true, [Select Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1])
        );

        insert userList;

        List<Id> userIds = new List<Id>();

        for (User user : userList) {
            userIds.add(user.Id);
        }
        
        List<AccountTeamMember> accountTeamMemberList = TestDataFactory.createAccountTeamMember(invoice.Zuora__Account__c, teamRoleList, userIds);

        insert accountTeamMemberList;

        // get accountTeamMembers to check owner
        List<AccountTeamMember> accountTeamMembers = new List<AccountTeamMember>([
            SELECT Id, UserId, TeamMemberRole 
            FROM AccountTeamMember
            WHERE AccountId = :invoice.Zuora__Account__c
        ]);
        
        system.debug('accountTeamMemberList1:'+accountTeamMembers);

        Id desiredOwnerId;

        // determine account manager
        for (AccountTeamMember teamMember : accountTeamMembers) {
            if (teamMember.TeamMemberRole == 'Account Manager') {
                desiredOwnerId = teamMember.UserId;
            } else {
                delete teamMember;
            }
        }
        
        try {
            Test.startTest();
            Database.executeBatch(new Batch_CreatePreDelinquencyTasks());
            Test.stopTest();
        } finally {
            Task task = [SELECT Id, WhoId, OwnerId, Subject FROM Task LIMIT 1];
            system.assert(task.Subject.contains(invoice.Name));
            system.assert(task.OwnerId == desiredOwnerId);
        }
    }


    static testMethod void testFieldManagerAsOwner() {

        Zuora__ZInvoice__c invoice = [
            SELECT Id, Name, Zuora__Account__c, Zuora__Account__r.OwnerId, Zuora__Balance2__c, Zuora__DueDate__c 
            FROM Zuora__ZInvoice__c 
            LIMIT 1
        ];
        
        List<String> teamRoleList = new List<String>{'Field Account Manager'};
        List<User> userList = new List<User>();
        // create 2 users and add to list
        userList.add(
            TestDataFactory.createRandomUser(true, [Select Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1])
        );

        insert userList;

        List<Id> userIds = new List<Id>();

        for (User user : userList) {
            userIds.add(user.Id);
        }
        
        List<AccountTeamMember> accountTeamMemberList = TestDataFactory.createAccountTeamMember(invoice.Zuora__Account__c, teamRoleList, userIds);

        insert accountTeamMemberList;

        // get accountTeamMembers to check owner
        List<AccountTeamMember> accountTeamMembers = new List<AccountTeamMember>([
            SELECT Id, UserId, TeamMemberRole 
            FROM AccountTeamMember
            WHERE AccountId = :invoice.Zuora__Account__c
        ]);
        
        system.debug('accountTeamMemberList2:'+accountTeamMembers);

        Id desiredOwnerId;

        // determine account manager
        for (AccountTeamMember teamMember : accountTeamMembers) {
            if (teamMember.TeamMemberRole == 'Field Account Manager') {
                desiredOwnerId = teamMember.UserId;
            } else {
                delete teamMember;
            }
        }
        
        try {
            Test.startTest();
            Database.executeBatch(new Batch_CreatePreDelinquencyTasks());
            Test.stopTest();
        } finally {
            Task task = [SELECT Id, WhoId, OwnerId, Subject FROM Task LIMIT 1];
            system.assert(task.Subject.contains(invoice.Name));
            system.assert(task.OwnerId == desiredOwnerId);
        }
    }


    static testMethod void testAccountExecutive() {

        Zuora__ZInvoice__c invoice = [
            SELECT Id, Name, Zuora__Account__c, Zuora__Account__r.OwnerId, Zuora__Balance2__c, Zuora__DueDate__c 
            FROM Zuora__ZInvoice__c 
            LIMIT 1
        ];

        Id desiredOwnerId = invoice.Zuora__Account__r.OwnerId;
        
        try {
            Test.startTest();
            Database.executeBatch(new Batch_CreatePreDelinquencyTasks());
            Test.stopTest();
        } finally {
            Task task = [SELECT Id, WhoId, OwnerId, Subject FROM Task LIMIT 1];
            system.assert(task.Subject.contains(invoice.Name));
            system.assert(task.OwnerId == desiredOwnerId);
        }
    }

}