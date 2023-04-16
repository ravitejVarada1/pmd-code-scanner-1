@isTest
private class TrialTriggerFunctions_Test {

    @TestSetup
    static void makeData(){
        //1st account is customer, 2nd is normal, 3rd is normal, 4th has old trial
        Account[] accts = TestDataFactory.createAccounts(4);
        accts[0].Type = 'Customer';
        accts[0].Name = 'Customer';
        accts[2].Name = 'Normal';
        accts[3].Name = 'Got a Trial';
        insert accts;

        //opps is normal, opps2 is closed, opps 3 is normal
        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id,1);
        Opportunity[] opps2 = TestDataFactory.createOpps(accts[1].Id,1);
        Opportunity[] opps3 = TestDataFactory.createOpps(accts[2].Id,1);
        Opportunity[] opps4 = TestDataFactory.createOpps(accts[3].Id,1);
        opps2[0].StageName = 'Closed Won';
        opps.addAll(opps2);
        opps.addAll(opps3);
        opps.addAll(opps4);
        insert opps;

    }

    static testMethod void testTrialInsertOnCustomer() {
        Account[] accts = [SELECT Id FROM Account WHERE Name = 'Customer' limit 1];
        Opportunity[] opps = [SELECT Id FROM Opportunity WHERE AccountId =: accts[0].Id];

        Trial__c t = new Trial__c(
            Account__c = accts[0].Id,
            Opportunity__c = opps[0].Id,
            Start_Date__c = date.today()
        );

        Test.startTest();

        try {
            insert t;
        } catch (Exception e) {
            System.assert(e.getMessage().contains('You may not provide a Trial to an existing Customer'));
        }

        Test.stopTest();

    }

    static testMethod void testTrialInsertOnClosedOpp() {
        Account[] accts = [SELECT Id FROM Account WHERE Name NOT IN ('Customer','Normal','Got a Trial') limit 1];
        Opportunity[] opps = [SELECT Id FROM Opportunity WHERE AccountId =: accts[0].Id];

        Trial__c t = new Trial__c(
            Account__c = accts[0].Id,
            Opportunity__c = opps[0].Id,
            Start_Date__c = date.today()
        );

        Test.startTest();

        try {
            insert t;
        } catch (Exception e) {
            System.assert(e.getMessage().contains('You may not provide a Trial from a Closed Opportunity'));
        }

        Test.stopTest();

    }

    static testMethod void testTrialUpdateStartDate() {
        Account[] accts = [SELECT Id FROM Account WHERE Name = 'Normal' limit 1];
        Opportunity[] opps = [SELECT Id FROM Opportunity WHERE AccountId =: accts[0].Id];

        Trial__c t = new Trial__c(
            Start_Date__c = date.today(),
            Account__c = accts[0].Id,
            Opportunity__c = opps[0].Id
        );
        insert t;

        Test.startTest();

        t = [SELECT Id, End_Date__c FROM Trial__c limit 1];

        t.Start_Date__c = date.today().addDays(1);
        try {
            update t;
        } catch (Exception e) {
            System.assert(e.getMessage().contains('You may not change the Start Date of this Trial after insertion'));
        }

        Test.stopTest();
        
    }

}