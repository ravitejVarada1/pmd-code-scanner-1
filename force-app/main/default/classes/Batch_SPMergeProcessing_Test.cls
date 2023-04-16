@isTest
private class Batch_SPMergeProcessing_Test{

    @testsetup static void createTestData() {
        //Creating Current Account
        List<Account> accList = TestDataFactory.createAccounts(2);
        insert accList;
        
        List<Service_Provider__c> spList = new List<Service_Provider__c>();
        spList.addAll(TestDataFactory.createServiceproviders(1, accList[0].Id));
        spList.addAll(TestDataFactory.createServiceproviders(1, accList[1].Id));
        
        spList[0].Service_Provider_Id__c = 10000;
        
        spList[1].Service_Provider_Id__c = 10001;
        spList[1].Merge_SP_ID__c = '10000';
        
        insert spList;
    }
    
    static testMethod void testSPMergeProcess(){
        
        Test.startTest();
        Database.executeBatch(new Batch_SPMergeProcessing());
        Test.stopTest();

        List<Service_Provider__c> resultsSP = new List<Service_Provider__c>([
            SELECT Id,Name FROM Service_Provider__c
            WHERE Merge_SP_ID__c!=null AND SP_Merge_Processed__c=true
        ]);

        System.assert(resultsSP.size() == 1);
        
    }
    
    static testMethod void testSPMergeProcess2(){
        
        Set<String> spIds = new Set<String>();
        
        for(Service_Provider__c spRecord : [
            SELECT Id, Name, Account__c, Merge_SP_ID__c,Service_Provider_Id_text__c, SP_Merge_Processed__c
            FROM Service_Provider__c
            WHERE Merge_SP_ID__c!=null
            AND SP_Merge_Processed__c=false
        ]){
            spIds.add(spRecord.Id);
        }
        
        Test.startTest();
        Database.executeBatch(new Batch_SPMergeProcessing(spIds));
        Test.stopTest();

        List<Service_Provider__c> resultsSP = new List<Service_Provider__c>([
            SELECT Id,Name FROM Service_Provider__c
            WHERE Merge_SP_ID__c!=null AND SP_Merge_Processed__c=true
        ]);

        System.assert(resultsSP.size() == 1);
        
    }

    static testMethod void testSPMergeProcess3(){
        
        Test.startTest();
        Batch_SPMergeProcessing spBatch = new Batch_SPMergeProcessing();
        spBatch.execute(null);
        Test.stopTest();

        List<Service_Provider__c> resultsSP = new List<Service_Provider__c>([
            SELECT Id,Name FROM Service_Provider__c
            WHERE Merge_SP_ID__c!=null AND SP_Merge_Processed__c=true
        ]);

        System.assert(resultsSP.size() == 1);
        
    }
    
}