@isTest
private class Batch_UnlockAccounts_Test {

    static testMethod void unlockAccount() {

        Account a = TestDataFactory.createAccounts(1)[0];
        insert a;

        Approval.lock(a.Id);

        Test.startTest();
        Database.executeBatch(new Batch_UnlockAccounts(new Set<Id>{a.Id}));
        Test.stopTest();

        System.assertEquals(Approval.isLocked(a.Id),false);

    }

}