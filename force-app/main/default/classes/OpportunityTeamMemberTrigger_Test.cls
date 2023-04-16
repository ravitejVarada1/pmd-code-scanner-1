@isTest
private class OpportunityTeamMemberTrigger_Test {

    @TestSetup
    static void makeData(){

        Test.startTest();

        Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
        adminEscape.Exclude_from_Validation_Rules__c = true;
        upsert adminEscape;
        
        Profile[] ps = [SELECT Id, Name FROM Profile Where Name = 'Sales Admin'];

        User salesAdmin = TestDataFactory.createUser(true, ps[0]);
        salesAdmin.Termination_Date__c = null;
        salesAdmin.LastName = 'Test';
        insert salesAdmin;

        Account[] accts = TestDataFactory.createAccounts(1);
        insert accts;
        
        Contact[] conts = TestDataFactory.createContacts(1,accts[0].Id);
        insert conts;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id,1);
        opps[0].OwnerId = salesAdmin.Id;
        opps[0].AccountId = accts[0].Id;
        opps[0].QuotePrimaryContact__c = conts[0].Id;
        insert opps;

        Test.stopTest();
    }

    @IsTest
    static void teamAdd(){
        
        User salesAdmin = [SELECT Id FROM User WHERE LastName = 'Test' limit 1];
        Opportunity o = [SELECT Id FROM Opportunity limit 1];
        
        Opportunity_Tracker__c ot = [SELECT Id FROM Opportunity_Tracker__c WHERE Id IN (SELECT Opportunity_Tracker__c FROM Opportunity WHERE Id =: o.Id) limit 1];
		TestDataFactory.completeOppTracker(ot);
        update ot;

        o.StageName = 'Closed Won';
        update o;

        Account a = [SELECT Id FROM Account limit 1];

        AccountTeamMember atm = new AccountTeamMember();
        atm.UserId = salesAdmin.Id;
        atm.AccountId = a.Id;
        atm.TeamMemberRole = 'Acquisitions';
        atm.AccountAccessLevel = 'Edit';
        atm.OpportunityAccessLevel = 'Edit';
        atm.CaseAccessLevel = 'Read';
        atm.ContactAccessLevel = 'Edit';
        insert atm;

        Test.startTest();

        User u = [SELECT Id FROM User WHERE IsActive = true AND Profile.UserLicense.Name = 'Salesforce' 
            AND Id !=: salesAdmin.Id limit 1];

        System.runAs(salesAdmin){
            OpportunityTeamMember otm = new OpportunityTeamMember();
            otm.OpportunityId = o.Id;
            otm.UserId = u.Id;
            otm.TeamMemberRole = 'Acquisitions';
            otm.OpportunityAccessLevel = 'Edit';
            
            try {
                insert otm;
            } catch (Exception e) {
                System.assert(e.getMessage().contains(System.Label.Restrict_Operations_On_Opportunity_Team_Member));
            }
        }
        Test.stopTest();
        
    }

}