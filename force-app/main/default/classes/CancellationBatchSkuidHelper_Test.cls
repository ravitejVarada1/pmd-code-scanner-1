@isTest
public class CancellationBatchSkuidHelper_Test {
  
    @testSetup
    static void setupRecords() {
        List<Account> accs = TestDataFactory.createAccounts(1);
        accs[0].BillingCountryCode = 'US';
        accs[0].Name = 'Dealer #1 Account';
        insert accs;
        
        Case caseRecord = TestDataFactory.createCases(1, accs[0].Id)[0];
        caseRecord.RecordTypeId = [SELECT Id FROM RecordType WHERE sObjectType = 'Case' AND Name = 'Cancellations'][0].Id;
        caseRecord.Status = 'New';
        caseRecord.Case_Resolution__c = 'Full Cancellation';
        caseRecord.Origin = 'Web';
        caseRecord.Cancel_Override__c = System.today().addDays(5);
        insert caseRecord;
  }
    static testMethod void testPostCallout() {
        test.StartTest();
        Case c =  [SELECT Id from case Limit 1];
        String batchNumber = CancellationBatchSkuidHelper.executeCancellationBatch(c.Id);
        String status =CancellationBatchSkuidHelper.getBatchStatus(batchNumber);
        test.StopTest();
        system.assertEquals('Queued', status);
    }
}