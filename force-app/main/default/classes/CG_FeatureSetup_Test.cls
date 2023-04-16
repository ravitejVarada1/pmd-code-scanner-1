// https://cargurus.atlassian.net/browse/CRM-5021
// https://cargurus.atlassian.net/browse/CRM-5093
@isTest
private class CG_FeatureSetup_Test {

    @TestSetup
    static void makeData(){
        Account testAccount = TestDataFactory.createAccounts(1, ConstantsUtil.RT_ACCOUNT_DEALER)[0];
        testAccount.Restricted_Cap_editable__c = 1;
        insert testAccount;
    }
    
    // covering CG_Account_Feature_TriggerHandler.cls, CG_Account_Feature__c.trigger
    @IsTest
    static void cgAccountFeatureTrigger() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        CG_Feature__c testCGFeature = new CG_Feature__c(Name='Test CG Feature',CG_Feature_Id__c=999,Active__c=true);
        insert testCGFeature;

        CG_Account_Feature__c testAccountFeature = new CG_Account_Feature__c(
            Account__c = testAccount.Id,
            CG_Feature__c = testCGFeature.Id
        );
        
        Test.startTest();
        insert testAccountFeature;
        Test.stopTest();
        
        testAccountFeature = [SELECT Id, Unique_Id__c FROM CG_Account_Feature__c LIMIT 1];

        System.assertEquals(testAccount.Id+'_'+testCGFeature.Id, testAccountFeature.Unique_Id__c, 
            'Unique Id not properly populated');
    }

    // covering batch portion of CG_Batch_UpdateAccountMetadataFields.cls
    @IsTest
    static void testBatchUpdateAccountMetadataFields() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        Database.executeBatch(new CG_Batch_UpdateAccountMetadataFields(new Set<Id>{testAccount.Id}));
        Test.stopTest();
        
        testAccount = [SELECT Id, Restricted_Cap__c, Restricted_Cap_editable__c FROM Account LIMIT 1];

        System.assertEquals(testAccount.Restricted_Cap__c, testAccount.Restricted_Cap_editable__c, 
            'Restricted_Cap_editable__c not updated');
    }

    // covering schedule portion of CG_Batch_UpdateAccountMetadataFields.cls
    @IsTest
    static void testScheduleUpdateAccountMetadataFields() {
        CG_Batch_UpdateAccountMetadataFields updateBatch = new CG_Batch_UpdateAccountMetadataFields();
        String cronString = '0 0 23 * * ?';

        Test.startTest();
        String jobId = System.schedule('TEST_CG_Batch_UpdateAccountMetadataFields', cronString, updateBatch);
        Test.stopTest();
        
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
    }

}