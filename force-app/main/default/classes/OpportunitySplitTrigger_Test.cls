@isTest
private class OpportunitySplitTrigger_Test {

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
        opps[0].Amount = 500;
        opps[0].AccountId = accts[0].Id;
        opps[0].QuotePrimaryContact__c = conts[0].Id;
        insert opps;

        Test.stopTest();
    }

    @IsTest
    static void addSplitRegUser(){

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Sales User' limit 1];
        User u = [SELECT Id FROM User WHERE IsActive = true AND ProfileId =: p.Id limit 1];
        Opportunity o = [SELECT Id FROM Opportunity limit 1];
        OpportunitySplitType ost = [SELECT Id FROM OpportunitySplitType WHERE MasterLabel = 'Comp' limit 1];

        System.debug('inserting team member');
        OpportunityTeamMember otm = new OpportunityTeamMember();
        otm.OpportunityId = o.Id;
        otm.UserId = u.Id;
        otm.TeamMemberRole = 'Acquisitions';
        otm.OpportunityAccessLevel = 'Edit';
        insert otm;

        Test.startTest();
        System.runAs(u){
        
            OpportunitySplit os = new OpportunitySplit();
            os.OpportunityId = o.Id;
            os.SplitOwnerId = u.Id;
            os.SplitTypeId = ost.Id;
            os.SplitPercentage = 50;
            
            try {
                insert os;
            } catch (Exception e) {
                System.assert(e.getMessage().contains(System.Label.OpportunitySplit_Direct_Edit_Error));
            }
        }
        Test.stopTest();
        
    }

    @IsTest
    static void addSplitAdmin(){

        Admin_Escape__c adminEscape = Admin_Escape__c.getOrgDefaults();
        adminEscape.Exclude_from_Validation_Rules__c = true;
        upsert adminEscape;

        Account a = [SELECT Id FROM Account limit 1];
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Sales Admin' limit 1];
        User u = [SELECT Id FROM User WHERE IsActive = true AND ProfileId =: p.Id limit 1];

        AccountTeamMember atm = new AccountTeamMember();
        atm.UserId = u.Id;
        atm.AccountId = a.Id;
        atm.TeamMemberRole = 'Acquisitions';
        atm.AccountAccessLevel = 'Edit';
        atm.OpportunityAccessLevel = 'Edit';
        atm.CaseAccessLevel = 'Read';
        atm.ContactAccessLevel = 'Edit';
        insert atm;
        
        Opportunity o = [SELECT Id FROM Opportunity limit 1];
        
        System.debug('inserting team member');
        OpportunityTeamMember otm = new OpportunityTeamMember();
        otm.OpportunityId = o.Id;
        otm.UserId = u.Id;
        otm.TeamMemberRole = 'Acquisitions';
        otm.OpportunityAccessLevel = 'Edit';
        insert otm;

        Opportunity_Tracker__c ot = [SELECT Id FROM Opportunity_Tracker__c WHERE Id IN (SELECT Opportunity_Tracker__c FROM Opportunity WHERE Id =: o.Id) limit 1];
		TestDataFactory.completeOppTracker(ot);

        update ot;
        
        o.StageName = 'Closed Won';
        update o;
        OpportunitySplitType ost = [SELECT Id FROM OpportunitySplitType WHERE MasterLabel = 'Comp' limit 1];

        Test.startTest();
        System.runAs(u){
            System.debug('inserting split');
            OpportunitySplit os = new OpportunitySplit();
            os.OpportunityId = o.Id;
            os.SplitOwnerId = u.Id;
            os.SplitTypeId = ost.Id;
            os.SplitPercentage = 50;
            
            try {
                insert os;
            } catch (Exception e) {
                System.assert(e.getMessage().contains(System.Label.Restrict_To_Edit_Opportunity_Splits));
            }
        }
        Test.stopTest();
        
    }

    static testMethod void testNormalOpp() {
        
        Test.startTest();
        Opportunity o = [SELECT Id, OwnerId FROM Opportunity limit 1];

        Product2 prod = TestDataFactory.createProducts();
        insert prod;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry pbe = TestDataFactory.createPriceBookEntry(standardPricebookId, prod.Id);
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = o.Id,
            Product2Id = prod.Id,
            Quantity = 1,
            UnitPrice = 1000,
            PricebookEntryId = pbe.Id
        );
        insert oli;

        o.StageName = 'Closed Won';
        update o;

        Test.stopTest();

        OpportunitySplit[] oSplit = [SELECT Id, SplitAmount FROM OpportunitySplit 
                WHERE SplitOwnerId =: UserInfo.getUserId() 
                AND SplitTypeId =: OpportunityTriggerFunctions.getSplitTypeIds('Commissions')];

        System.assert(oSplit.size() == 1);
        System.assert(oSplit[0].SplitAmount == 1000); 
    }

    static testMethod void testRetentionPositiveAmount() {

        User u = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name = 'Sales User' limit 1];

        Account a = [SELECT Id FROM Account limit 1];
        a.OwnerId = u.Id;
        update a;

        Contact c = [SELECT Id FROM Contact limit 1];

        Opportunity o = TestDataFactory.createOpps(a.Id,1)[0];
        Id retentionRTId = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity', 'Retention');
        o.RecordTypeId = retentionRTId;
        o.Original_Contract_Spend__c = 1000;
        o.QuotePrimaryContact__c = c.Id;
        insert o;

        Product2 prod = TestDataFactory.createProducts();
        insert prod;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry pbe = TestDataFactory.createPriceBookEntry(standardPricebookId, prod.Id);
        insert pbe;

        OpportunityLineItem[] oliInsert = new List<OpportunityLineItem>();
        oliInsert.add(new OpportunityLineItem(
            OpportunityId = o.Id,
            Product2Id = prod.Id,
            Quantity = -1,
            UnitPrice = 1000,
            PricebookEntryId = pbe.Id
        ));
        oliInsert.add(new OpportunityLineItem(
            OpportunityId = o.Id,
            Product2Id = prod.Id,
            Quantity = 1,
            UnitPrice = 1500,
            PricebookEntryId = pbe.Id
        ));
        insert oliInsert;

        
        Test.startTest();
        o.StageName = 'Closed Saved';
        update o;
        Test.stopTest();

        OpportunitySplit[] posSplit = [SELECT Id, SplitAmount, SplitOwnerId FROM OpportunitySplit 
                WHERE SplitOwnerId =: u.Id
                AND SplitTypeId =: OpportunityTriggerFunctions.getSplitTypeIds('Commissions')];

        System.assert(posSplit.size() == 1);
        System.assert(posSplit[0].SplitAmount == 500);

        OpportunitySplit[] retSplit = [SELECT Id, SplitAmount FROM OpportunitySplit 
                WHERE SplitOwnerId =: UserInfo.getUserId() 
                AND SplitTypeId =: OpportunityTriggerFunctions.getSplitTypeIds('Retention')];

        System.assert(retSplit.size() == 1);
        System.assert(retSplit[0].SplitAmount == 1000); 


    }

}