@isTest
private class CaseCommentTriggerFunctions_Test {

    // get system manager & rep profiles
    Static Id editPermissionId = [Select Id, DeveloperName From CustomPermission WHERE DeveloperName = 'Allow_Internal_Case_Comment_Editing' LIMIT 1][0].Id;
    Static Id deletePermissionId = [Select Id, DeveloperName From CustomPermission WHERE DeveloperName = 'Allow_Internal_Case_Comment_Deletion' LIMIT 1][0].Id;

    @TestSetup
	static void testData() {
        
        // create & insert account
        Account account = TestDataFactory.createSingleAccount(Utilities.getrecordTypeId('Account', 'Dealer_Account'));
        account.Name = 'Test Account';
        insert account;
        ID accountId = account.Id;
        
        // create and insert case
        List<Case> cases = TestDataFactory.createCases(1, accountId);
        cases[0].Origin = 'Internal';
        insert cases;
    }

    @isTest
    public static void editCaseCommentTest() {

        //  get account
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account'];
        
        // get case
        Case testCase = [SELECT Id FROM Case WHERE AccountId = :account.Id];
        
        // create case comment
        CaseComment comment = TestDataFactory.createCaseComment(testCase.Id);
        insert comment;
        
        // support rep negative test
        Test.startTest();
        try {
            comment.CommentBody = 'Update!';
            update comment;
        } catch (Exception e) {
            system.debug(e.getMessage());
            System.assert(
                e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')
            );
        }
        Test.stopTest();

    }

    @isTest
    public static void deleteCaseCommentTest() {
        //  get account
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account'];
        
        // get case
        Case testCase = [SELECT Id FROM Case WHERE AccountId = :account.Id];
        
        // create case comment
        CaseComment comment = TestDataFactory.createCaseComment(testCase.Id);
        insert comment;
        
        // support rep negative test
        Test.startTest();
        try {
            delete comment;
        } catch (Exception e) {
            system.debug(e.getMessage());
            System.assert(
                e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')
            );
        }
        Test.stopTest();
    }

}