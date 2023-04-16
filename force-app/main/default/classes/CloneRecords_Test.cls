@isTest
private class CloneRecords_Test {
    @isTest
    static void testClone() {
        Account a = TestDataFactory.createSingleAccount(null);
        insert a;
        
        Case c = TestDataFactory.createCases(1,a.id)[0];
        List<Case> caseList = new List<Case>{c};
        Case clonedCase = (Case)CloneRecords.cloneSObjects(caseList)[0];

        System.assert(c == clonedCase);
    }
}