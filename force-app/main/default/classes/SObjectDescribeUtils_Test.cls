@isTest
public with sharing class SObjectDescribeUtils_Test {
    
    @isTest
    static void testGetRecordTypeByName() {
        Test.startTest();
        Id dealerRTId = SObjectDescribeUtils.getRecordTypeIdByName('Account', 'Dealer Account');
        Test.stopTest();

        System.assert(dealerRTId != null);
    }

    @isTest
    static void testGetRecordTypeByDevName() {
        Test.startTest();
        Id dealerRTId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', 'Dealer_Account');
        Test.stopTest();

        System.assert(dealerRTId != null);
    }

    /**
     * Test with an SObject type that is not setup for the describe
     */
    @isTest
    static void testGetRecordTypeByNameNegative() {
        Test.startTest();
        Id nonExistRTId = SObjectDescribeUtils.getRecordTypeIdByName('NonExistant', 'NonExistant');
        Test.stopTest();

        System.assert(nonExistRTId == null);
    }

    /**
     * Test with an SObject type that is not setup for the describe
     */
    @isTest
    static void testGetRecordTypeByDevNameNegative() {
        Test.startTest();
        Id nonExistRTId = SObjectDescribeUtils.getRecordTypeIdByDevName('NonExistant', 'NonExistant');
        Test.stopTest();

        System.assert(nonExistRTId == null);
    }

    /**
     * //SA-1492 - KS - Test with an SObject type that is not setup for the describe
     */
    @isTest
    static void testGetPicklistValuesByFieldNegative() {
        Test.startTest();
        List<Schema.PicklistEntry> nonExistObjField = SObjectDescribeUtils.getPicklistValuesByField('NonExistant', 'NonExistant');
        Test.stopTest();

        System.assertEquals(nonExistObjField, null, 'List is not null');
    }

    /**
     * //SA-1492 - KS - Test with an SObject type setup for the describe
     */
    @isTest
    static void testGetPicklistValuesByField() {
        Test.startTest();
        List<Schema.PicklistEntry> caseReasonPicklist = SObjectDescribeUtils.getPicklistValuesByField('Case', 'Reason');
        Test.stopTest();

        System.assertEquals(!caseReasonPicklist.isEmpty(), true, 'List is empty');
    }
}
