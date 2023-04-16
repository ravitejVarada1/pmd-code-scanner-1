/**
* Test class for OneOffCancellationController
* @author 	Ramiro Alvarez
* @date 	  03/02/2022
* @module   BR-5515
*/

@isTest
private class OneOffCancellationController_Test {

    @TestSetup
    static void makeData() {

        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Active';
        insert accts;        
    }

    @istest
    public static void callBatch_positiveTest() {

        Test.startTest();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        OneOffCancellationController.callCancellationBatch(acc.Id);
        Test.stopTest();
    }    

    @istest
    public static void callBatch_negativeTest() {

        Test.startTest();
        OneOffCancellationController.callCancellationBatch(null);
        Test.stopTest();
    }    

    @isTest
    static void checkRoleTest() {
        Boolean checkRole = OneOffCancellationController.checkUserProfile();
    }    
}