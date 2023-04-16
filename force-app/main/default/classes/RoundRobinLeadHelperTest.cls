@isTest
private class RoundRobinLeadHelperTest {
    
    @testsetup 
    static void testSetup(){
        
        User sysu = [ SELECT Id FROM User WHERE Id = :UserInfo.getUserId() ];
        System.runAs ( sysu ) {
            
            Profile salesUserProfile = [SELECT Id FROM Profile WHERE Name='Sales User'];
            Profile sysAdminProfile = [SELECT Id FROM Profile WHERE Name='System Administrator']; 
            
            UserRole r = new UserRole(DeveloperName = 'Acquisitions', Name = 'Acquisitions');
            insert r;
            
            
            User salesUserOne = new User(Alias = 'su1', Email='SalesUserOne@cg.com',
                                         EmailEncodingKey='UTF-8', LastName='One', LanguageLocaleKey='en_US', 
                                         LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
                                         TimeZoneSidKey='America/Los_Angeles', UserName='SalesUserOne@cg.com', UserRoleId = r.Id);
            insert salesUserOne;
            
            User salesUserTwo = new User(Alias = 'su2', Email='SalesUserTwo@cg.com',
                                         EmailEncodingKey='UTF-8', LastName='Two', LanguageLocaleKey='en_US', 
                                         LocaleSidKey='en_US', ProfileId = salesUserProfile.Id, 
                                         TimeZoneSidKey='America/Los_Angeles', UserName='SalesUserTwo@cg.com', UserRoleId = r.Id);
            insert salesUserTwo;
            
            User marketingAdmin = new User(Alias = 'mar', Email='martech@cg.com',
                                           EmailEncodingKey='UTF-8', LastName='martech', LanguageLocaleKey='en_US', 
                                           LocaleSidKey='en_US', ProfileId = sysAdminProfile.Id, 
                                           TimeZoneSidKey='America/Los_Angeles', UserName='martech@cg.com', UserRoleId = r.Id);
            insert marketingAdmin;
            
            
            Id dealerAccountRecordType= Utilities.getRecordTypeId('Account','Dealer_Account');
            Id standardOpportunityRecordType= Utilities.getRecordTypeId('Opportunity','Standard_Opportunity');
            
            Group rrSDRCAGroup = new Group();
            rrSDRCAGroup.Name='RR SDR CA';
            rrSDRCAGroup.type='Queue';
            insert rrSDRCAGroup;


            //Create Group for Inbound Sales Team - US
            Group rrUSGroup = new Group();
            rrUSGroup.Name='RR_IST_US';
            rrUSGroup.type='Queue';
            insert rrUSGroup;            

            //Create Group Member for Inbound Sales Team - US
            GroupMember rrSDRCAGroupMemberOne = new GroupMember();
            rrSDRCAGroupMemberOne.UserOrGroupId = salesUserOne.id;
            rrSDRCAGroupMemberOne.GroupId = rrUSGroup.Id;
            Insert rrSDRCAGroupMemberOne;

            QueuesObject rrSDRCAQueue = new QueueSObject();
            rrSDRCAQueue.QueueID = rrSDRCAGroup.id; 
            rrSDRCAQueue.SobjectType = 'Lead';
            insert rrSDRCAQueue;
            
            GroupMember rrUSGroupMemberUser = new GroupMember();
            rrUSGroupMemberUser.UserOrGroupId = salesUserOne.id;
            rrUSGroupMemberUser.GroupId = rrSDRCAGroup.Id;
            Insert rrUSGroupMemberUser;
            
            GroupMember rrSDRCAGroupMemberTwo = new GroupMember();
            rrSDRCAGroupMemberTwo.UserOrGroupId = salesUserTwo.id;
            rrSDRCAGroupMemberTwo.GroupId = rrSDRCAGroup.Id;
            Insert rrSDRCAGroupMemberTwo;
            
            Account dealerAccount = new Account();
            dealerAccount.name = 'Test Dealer';
            dealerAccount.recordTypeID = dealerAccountRecordType;
            dealerAccount.Account_Status__c ='Pending';
            insert dealerAccount;
            
            Opportunity standardOpportunity = new Opportunity();
            standardOpportunity.name = 'Test Opportunity';
            standardOpportunity.recordTypeID = standardOpportunityRecordType;
            standardOpportunity.StageName = 'Discover/Qualify';
            standardOpportunity.CloseDate = system.Date.today();
            standardOpportunity.AccountId = dealerAccount.id;
            insert standardOpportunity;
        }
    }
    
    static testMethod void CanadaRRLeadTest () {
        
        try {
            User martechUser = [SELECT Id FROM User WHERE UserName = 'martech@cg.com' ];
            
            System.runAs ( martechUser ) {
                
                Lead newJunkLead = new Lead();
                newJunkLead.FirstName = 'Test';
                newJunkLead.LastName = 'New Junk Lead';
                newJunkLead.CountryCode = Null;
                insert newJunkLead;
                
                Lead newLead = new Lead();
                newLead.FirstName = 'Test';
                newLead.LastName = 'New Lead';
                newLead.CountryCode = 'CA';
                insert newLead;
                
                Lead workingLead = new Lead();
                workingLead.FirstName = 'Test';
                workingLead.LastName = 'Working Lead';
                newLead.CountryCode = 'CA';
                workingLead.Lead_Account__c = [Select Id from Account where Name = 'Test Dealer' Limit 1].id;
                insert workingLead;
                
                Lead anotherNewLead = new Lead();
                anotherNewLead.FirstName = 'Another';
                anotherNewLead.LastName = 'New Lead';
                newLead.CountryCode = 'CA';
                insert anotherNewLead;
                
                Lead anotherWorkingLead = new Lead();
                anotherWorkingLead.FirstName = 'Another';
                anotherWorkingLead.LastName = 'Working Lead';
                newLead.CountryCode = 'CA';
                anotherWorkingLead.Lead_Account__c = [Select Id from Account where Name = 'Test Dealer' Limit 1].id;
                insert anotherWorkingLead;
            }
            
        } catch (DmlException e) {
            system.debug(e);
        }
    }

    @istest
    static void USRRLeadTest () {        

        User oldRRUser = [SELECT Id, Name, UserName, Email FROM User WHERE UserName = 'martech@cg.com'];
        
        //Create an 'old' Round Robin User in the table
        Round_Robin_User__c rrUser = new Round_Robin_User__c(
                        User__c = oldRRUser.Id,
                        Round_Robin_Group__c = 'RR_IST_US'
                    );

        insert rrUser;

        Test.startTest();
        Lead workingLead = new Lead();
        workingLead.FirstName = 'Test';
        workingLead.LastName = 'Working Lead';
        workingLead.CountryCode = 'US';
        workingLead.Company = 'US Company';
        insert workingLead;

        Test.stopTest();
        Lead lead = [SELECT Id, OwnerId FROM Lead];
        User user = [SELECT Id FROM User WHERE UserName = 'SalesUserOne@cg.com'];

        // Query RR users
        List<Round_Robin_User__c> rrUsers = [SELECT Id, User__c, User__r.Name, Territory_Name__c, Territory_Role_Name__c FROM Round_Robin_User__c];
        Boolean userRemovedFromRR = true;
        for (Round_Robin_User__c rr : rrUsers) { 
            if(rr.User__c == oldRRUser.Id) {
                userRemovedFromRR = false;
            }
        }

        System.assertEquals(user.Id, lead.OwnerId);
        System.assertEquals(true, userRemovedFromRR, 'The user was successfully removed from the Round Robin table');
    }
    
}