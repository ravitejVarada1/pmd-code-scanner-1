@isTest
private class Batch_ExpireContracts_Test {
    
    @TestSetup
    static void makeData(){
       Date firstDayOfMonth = System.today().toStartOfMonth();
       Date lastDayOfMonth = firstDayOfMonth.addDays(Date.daysInMonth(firstDayOfMonth.year(), firstDayOfMonth.month())-1);
        Account[] accts = TestDataFactory.createAccounts(1);
        insert accts;

        Contract contract = TestDataFactory.createContract(accts[0].Id);
        contract.EndDate = lastDayOfMonth;
        contract.Auto_Renewal_Disable_Date__c = System.today();
        contract.Cancellation_Effective_Date__c = System.today();
        insert contract;
        contract.Status = 'Activated';
        update contract;
    }

    static testMethod void testBatch() {
        Test.startTest();
        Database.executeBatch(new Batch_ExpireContracts());
        Test.stopTest();
        Date firstDayOfNextMonth = System.today().addMonths(1).toStartOfMonth();

        Contract[] contracts = [SELECT Id, Status, Cancellation_Effective_Date__c FROM Contract];
        system.assertEquals(firstDayOfNextMonth, contracts[0].Cancellation_Effective_Date__c);
    }

}