@IsTest

private class Batch_OppAutoCloseTaskCreation_Test {

    @testsetup static void testData() {
        List<Account> testAccs = TestDataFactory.createAccounts(1);
        insert testAccs;
        
        List<Opportunity> opps = TestDataFactory.createOpps(testAccs[0].Id,1);
        Id RECORDTYPEID = utilities.getRecordTypeId('opportunity','Standard_Opportunity');
        for(Opportunity opp : opps){
            opp.RecordTypeId = RECORDTYPEID;
            opp.Auto_Close_Date__c = Date.today().addDays(3);
        }
     
        insert opps;
    }

    static testMethod void businessHoursTest() {

        Opportunity testOpp = [SELECT Id, Auto_Close_Date__c FROM Opportunity LIMIT 1];
        
        Test.startTest();
        Database.executeBatch(new Batch_OppAutoCloseTaskCreation());
        Test.stopTest();
		
        System.assertEquals(testOpp.Auto_Close_Date__c, System.today().addDays(3)); 
        List<Task> tsks = [SELECT Id, ActivityDate FROM Task WHERE WhatId = :testOpp.Id];
        System.assert(tsks.size() > 0);
        System.assertEquals(Date.today().addDays(3), tsks[0].ActivityDate);

    } 
    
     static testMethod void populateAutoCloseDateTest() {
        Test.startTest();
         
        Account acc = [select id,BillingCountryCode  from Account limit 1];
        acc.BillingCountryCode = 'CA';
        update acc;
   
        List<Opportunity> opps = TestDataFactory.createOpps(acc.Id,1);
        Id RECORDTYPEID = utilities.getRecordTypeId('opportunity','Standard_Opportunity');
        for(Opportunity opp : opps){
            opp.RecordTypeId = RECORDTYPEID;
        }
        insert opps;
         
        Test.stopTest();
        Map<String, Opp_Auto_Close__mdt> mapAutoCloseDays = Opp_Auto_Close__mdt.getAll();
        Opportunity testOpp = [SELECT Id, Auto_Close_Date__c,Account_Country_Code__c FROM Opportunity where id =: opps[0].id ];
        System.assertEquals(testOpp.Auto_Close_Date__c, System.today().addDays(Integer.valueOf(mapAutoCloseDays.get(testOpp.Account_Country_Code__c).Days__c)));

    } 
}