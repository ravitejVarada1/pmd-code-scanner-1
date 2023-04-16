@isTest
private class AccountLimitHandler_Test {

    static testMethod void testAccountLimitGB() {

        User u = [SELECT Id FROM User WHERE Profile.Name = 'Sales User' AND IsActive = true limit 1];

        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        List<Account> dealerAccounts = TestDataFactory.createAccounts(150, dealerAccountRecordTypeId);

        for (Account a : dealerAccounts) {
            a.BillingCountryCode = 'GB';
            a.OwnerId = u.Id;
        }
        Account a = TestDataFactory.createSingleAccount(dealerAccountRecordTypeId);
        a.BillingCountryCode = 'GB';
        a.OwnerId = CG_AccountOwnership.getCGAPIUser();
        dealerAccounts.add(a);
        insert dealerAccounts;

        Test.startTest();


        a.OwnerId = u.Id;
        try {
            update a;
        } catch (Exception e) {
            System.assert(e.getMessage().contains('You have hit the Account limit for this Owner Id:'));
        }


        Test.stopTest();

    }

}