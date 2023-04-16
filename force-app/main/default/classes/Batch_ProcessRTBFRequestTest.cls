@IsTest
public class Batch_ProcessRTBFRequestTest {
    
    @testsetup 
    static void testData() {
        
    Id personAccountRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();    
    List<Account> personAccs = TestDataFactory.createPersonalAccounts(1);
    personAccs[0].RecordTypeId = personAccountRecTypeId;
    personAccs[0].FirstName = '0';
    personAccs[0].LastName = '0';
    personAccs[0].PersonEmail = '0@0.com';
    insert personAccs;
}
    
    static testMethod void testRtbfRecordCreation() {
    Test.startTest();
    Database.executeBatch(new Batch_ProcessRTBFRequest(),200);
    Test.stopTest();

    List<privacycenter__RTBF_Request__c> rtbf = [
    SELECT Id FROM privacycenter__RTBF_Request__c WHERE privacycenter__Status__c = 'Pending'
    LIMIT 1
    ]; 

    System.Assert(rtbf.size() > 0);   
    }
}