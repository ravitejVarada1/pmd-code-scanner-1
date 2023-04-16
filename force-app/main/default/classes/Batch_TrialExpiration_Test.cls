@isTest
private class Batch_TrialExpiration_Test {
    
    @TestSetup
    static void makeData(){
        Account[] accts = TestDataFactory.createAccounts(1);
        insert accts;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id,1);
        opps[0].CreatedDate = date.today().addDays(-5);
        insert opps;

        Trial__c t = new Trial__c(
            Account__c = accts[0].Id,
            Opportunity__c = opps[0].Id,
            Start_Date__c = date.today().addDays(-4)
        );
        insert t;
    }

    static testMethod void testBatch() {
        Test.startTest();
        Database.executeBatch(new Batch_TrialExpiration());
        Test.stopTest();
    }

    static testMethod void testSchedulable() {
        Test.startTest();
        String cronString = Utilities.getCronExpressionMinutesFromNow(10);
        System.schedule('testSchedule_TrialExpiration', cronString, 
                        new Batch_TrialExpiration());
        Test.stopTest();
    }

}