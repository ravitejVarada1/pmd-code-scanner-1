/**
 * @author      Adam LaPlante
 * @created     09/21/2021
 * @modified    09/28/2021
 */

@isTest
public class DealerClassification_Test {    
    private static final String FRANCHISE_ACCOUNT_NAME = 'FRANCHISE';
    private static final String INDEPENDENT_ACCOUNT_NAME = 'INDY';
    
    @testSetup
    static void testSetup(){

        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        
        Account franchiseAccount = TestDataFactory.createSingleAccount(dealerAccountRecordTypeId);
        franchiseAccount.Name = FRANCHISE_ACCOUNT_NAME;
        insert franchiseAccount;
        ID franchiseID = franchiseAccount.Id;

        Account independentAccount = TestDataFactory.createSingleAccount(dealerAccountRecordTypeId);
        independentAccount.Name = INDEPENDENT_ACCOUNT_NAME;
        insert independentAccount;
        ID independentID = independentAccount.Id;

        List<Dealer_Classification__mdt> dcs = new List<Dealer_Classification__mdt>();

        dcs.add(new Dealer_Classification__mdt(
            Classification_Level__c = 'Independent L1', 
            Minimum_Total_Locations__c = 0,
            Maximum_Total_Locations__c = 2, 
            Minimum_Used_Inventory_Avg__c = 0,
            Maximum_Used_Inventory_Avg__c = 55
        ));

        dcs.add(new Dealer_Classification__mdt(
            Classification_Level__c = 'Independent L2', 
            Minimum_Total_Locations__c = 0,
            Maximum_Total_Locations__c = null, 
            Minimum_Used_Inventory_Avg__c = 0,
            Maximum_Used_Inventory_Avg__c = 120
        ));

        dcs.add(new Dealer_Classification__mdt(
            Classification_Level__c = 'Independent L3', 
            Minimum_Total_Locations__c = 0,
            Maximum_Total_Locations__c = null, 
            Minimum_Used_Inventory_Avg__c = 0,
            Maximum_Used_Inventory_Avg__c = null
        ));

        dcs.add(new Dealer_Classification__mdt(
            Classification_Level__c = 'Franchise L1', 
            Minimum_Total_Locations__c = 0,
            Maximum_Total_Locations__c = 4, 
            Minimum_Used_Inventory_Avg__c = 0,
            Maximum_Used_Inventory_Avg__c = 90
        ));

        dcs.add(new Dealer_Classification__mdt(
            Classification_Level__c = 'Franchise L2', 
            Minimum_Total_Locations__c = 0,
            Maximum_Total_Locations__c = 8, 
            Minimum_Used_Inventory_Avg__c = 0,
            Maximum_Used_Inventory_Avg__c = 140
        ));

        dcs.add(new Dealer_Classification__mdt(
            Classification_Level__c = 'Franchise L3', 
            Minimum_Total_Locations__c = 0,
            Maximum_Total_Locations__c = null, 
            Minimum_Used_Inventory_Avg__c = 140,
            Maximum_Used_Inventory_Avg__c = null
        ));
    
        
    }

    /**
     * Test criteria for Independent L1 step 1
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void independentL1Step1(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':INDEPENDENT_ACCOUNT_NAME'
                    ];


        for (Account account : accounts) {
            account.Group_Total_Locations__c = 2;
            account.Group_Total_Used_Inventory_Avg__c = 55;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Independent L1');
        }
    }

    /**
     * Test criteria for Independent L2 step 1
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void independentL2Step1(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':INDEPENDENT_ACCOUNT_NAME'
                    ];

        for (Account account : accounts) {
            account.Group_Total_Locations__c = 2;
            account.Group_Total_Used_Inventory_Avg__c = 120;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Independent L2');
        }
    }

    /**
     * Test criteria for Independent L2 step 2
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void independentL2Step2(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':INDEPENDENT_ACCOUNT_NAME'
                    ];

        for (Account account : accounts) {
            account.Group_Total_Locations__c = 10;
            account.Group_Total_Used_Inventory_Avg__c = 120;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Independent L2');
        }
    }

    /**
     * Test criteria for Independent L3 step 1
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void independentL3Step1(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':INDEPENDENT_ACCOUNT_NAME'
                    ];

        for (Account account : accounts) {
            account.Group_Total_Locations__c = 2;
            account.Group_Total_Used_Inventory_Avg__c = 121;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Independent L3');
        }
    }

    /**
     * Test criteria for Independent L3 step 2
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void independentL3Step2(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':INDEPENDENT_ACCOUNT_NAME'
                    ];

        for (Account account : accounts) {
            account.Group_Total_Locations__c = 10;
            account.Group_Total_Used_Inventory_Avg__c = 121;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Independent L3');
        }
    }

    /**
     * Test criteria for franchise L1 step 1
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void franchiseL1Step1(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':FRANCHISE_ACCOUNT_NAME'
                    ];

        for (Account account : accounts) {
            account.Group_Total_Locations__c = 4;
            account.Group_Total_Used_Inventory_Avg__c = 90;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Franchise L1');
        }
    }

    /**
     * Test criteria for franchise L2 step 1
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void franchiseL2Step1(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':FRANCHISE_ACCOUNT_NAME'
                    ];

        for (Account account : accounts) {
            account.Group_Total_Locations__c = 4;
            account.Group_Total_Used_Inventory_Avg__c = 140;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Franchise L2');
        }
    }

    /**
     * Test criteria for franchise L2 step 2
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void franchiseL2Step2(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':FRANCHISE_ACCOUNT_NAME'
                    ];

        for (Account account : accounts) {
            account.Group_Total_Locations__c = 8;
            account.Group_Total_Used_Inventory_Avg__c = 140;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Franchise L2');
        }
    }

    /**
     * Test criteria for franchise L3 step 1
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void franchiseL3Step1(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':FRANCHISE_ACCOUNT_NAME'
                    ];

        for (Account account : accounts) {
            account.Group_Total_Locations__c = 4;
            account.Group_Total_Used_Inventory_Avg__c = 141;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Franchise L3');
        }
    }

    /**
     * Test criteria for franchise L3 step 2
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void franchiseL3Step2(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':FRANCHISE_ACCOUNT_NAME'
                    ];

        for (Account account : accounts) {
            account.Group_Total_Locations__c = 8;
            account.Group_Total_Used_Inventory_Avg__c = 141;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Franchise L3');
        }
    }

    /**
     * Test criteria for franchise L3 step 3
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */
    
    @isTest
    static void franchiseL3Step3(){
        List<Account> accounts = [
                        SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, 
                        Group_Total_Locations__c, Group_Total_Used_Inventory_Avg__c 
                        FROM Account 
                        WHERE Name = ':FRANCHISE_ACCOUNT_NAME'
                    ];

        for (Account account : accounts) {
            account.Group_Total_Locations__c = 9;
            account.Group_Total_Used_Inventory_Avg__c = 1;
        }

        update accounts;

        try {
            Test.startTest();
            DealerClassification dc = new DealerClassification();
            update dc.returnClassifiedDealers(accounts);
        } catch(DmlException e) {
            System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
        } finally {
            Test.stopTest();
        }  
        
        for (Account account : accounts) {
            System.assertEquals(account.Dealer_Classification__c, 'Franchise L3');
        }
    }
    

}