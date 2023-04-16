/**
 * @author      Adam LaPlante
 * @created     10/04/2021
 * @modified    
 */

@isTest
public class AccountGroupStatisticsCalculator_Test {    
    
    @testSetup
    static void testSetup(){

        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        
        // insert franchise acocunt
        Account parent = TestDataFactory.createSingleAccount(dealerAccountRecordTypeId);
        parent.Name = 'Parent';
        parent.Account_Status__c = 'Active';
        parent.Type = 'Customer';
        insert parent;

        // insert independent account
        Account child = TestDataFactory.createSingleAccount(dealerAccountRecordTypeId);
        child.Name = 'Child';
        child.ParentId = parent.Id;
        child.Listings_CMRR__c = 100;
        insert child;

        List<Service_Provider__c> sps = new List<Service_Provider__c>();
        sps.add(TestDataFactory.createSingleServiceProvider(parent.Id));
        sps.add(TestDataFactory.createSingleServiceProvider(child.Id));
        

        for (Service_Provider__c sp : sps) {
            sp.Total_New_Inventory_Units__c = 100;
            sp.Total_Used_Inventory_Units__c = 100;
        }

        insert sps;


    }

    @isTest
    static void testGroupTotalLocations() {

        Account parent = [SELECT Id FROM Account WHERE Is_Ultimate_Parent__c = true LIMIT 1];

        Test.startTest();
        Database.executeBatch(new Batch_CalculateAccountGroupStatistics());
        Test.stopTest();

        Account child = [SELECT Id, Group_Total_Locations_Formula__c FROM Account WHERE ParentId = :parent.Id];

        System.assertEquals(child.Group_Total_Locations_Formula__c, 2);

    }

    @isTest
    static void testGroupPayingLocations() {

        Account parent = [SELECT Id FROM Account WHERE Is_Ultimate_Parent__c = true LIMIT 1];

        Test.startTest();
        Database.executeBatch(new Batch_CalculateAccountGroupStatistics());
        Test.stopTest();

        Account child = [SELECT Id, Group_Total_Paying_Locations_Formula__c FROM Account WHERE ParentId = :parent.Id];

        System.assertEquals(child.Group_Total_Paying_Locations_Formula__c, 1);
        
    }

    @isTest
    static void testGroupTotalUsedInventoryAvg() {

        Account parent = [SELECT Id FROM Account WHERE Is_Ultimate_Parent__c = true LIMIT 1];

        Test.startTest();
        Database.executeBatch(new Batch_CalculateAccountGroupStatistics());
        Test.stopTest();

        Account child = [SELECT Id, Group_Total_Used_Inventory_Avg_Formula__c FROM Account WHERE ParentId = :parent.Id];

        System.assertEquals(child.Group_Total_Used_Inventory_Avg_Formula__c, 3);
        
    }

    @isTest
    static void testGroupTotalUsedInventory() {

        Account parent = [SELECT Id FROM Account WHERE Is_Ultimate_Parent__c = true LIMIT 1];

        Test.startTest();
        Database.executeBatch(new Batch_CalculateAccountGroupStatistics());
        Test.stopTest();

        Account child = [SELECT Id, Group_Total_Used_Inventory_Formula__c FROM Account WHERE ParentId = :parent.Id];

        System.assertEquals(child.Group_Total_Used_Inventory_Formula__c, 200);
        
    }

    @isTest
    static void testGroupTotalNewInventory() {

        Account parent = [SELECT Id FROM Account WHERE Is_Ultimate_Parent__c = true LIMIT 1];

        Test.startTest();
        Database.executeBatch(new Batch_CalculateAccountGroupStatistics());
        Test.stopTest();

        Account child = [SELECT Id, Group_Total_New_Inventory_Formula__c FROM Account WHERE ParentId = :parent.Id];

        System.assertEquals(child.Group_Total_New_Inventory_Formula__c, 200);
        
    }

    @isTest
    static void testGroupTotalCMRR() {        

        Test.startTest();
        Database.executeBatch(new Batch_CalculateAccountGroupStatistics());
        Test.stopTest();

        Account parent = [SELECT Id, Group_Total_CMRR__c FROM Account WHERE Is_Ultimate_Parent__c = true LIMIT 1];

        System.assertEquals(parent.Group_Total_CMRR__c, 100);
        
    }
}