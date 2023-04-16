@isTest
public class Batch_UpdateAccountContactRelation_Test {
 
    static Set<String> testAccountNames;

    @testSetup static void setupRecords() {
        
        Id DealerAcctRTId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        List<Account> acctList = new List<Account>();
        List<Contact> contactList = new List<Contact>();
        List<Contact> contactUpdateList = new List<Contact>();
        List<Service_Provider__c> spList = new List<Service_Provider__c>();
        AccountContactRelation[] acrList = new List<AccountContactRelation>();

        for (Integer i = 0; i < 5; i++) {
            acctList.add(new Account(Name='testaccount'+String.valueOf(i), BillingCountryCode='CA',
                                     BillingCity = 'Huntsville', BillingStateCode = 'ON',
									 Type = 'Customer', Product_Activation_Status__c ='Active', RecordTypeId = DealerAcctRTId));
        }

        insert acctList;
        
        List<Product2> products = TestDataFactory.createProducts(3);

        Schema.DescribeFieldResult subCategoryDescription = Product2.Sub_Category__c.getDescribe();
        List<Schema.PicklistEntry> subCategoryValues = subCategoryDescription.getPicklistValues();
        for (Schema.PicklistEntry subCategory : subCategoryValues) {
            if (subCategory.getValue() == 'Enhanced') {
                products[0].Name = 'Enhanced Placement';
                products[0].Sub_Category__c = subCategory.getValue();
                continue;
            }

            if (subCategory.getValue() == 'Area Boost') {
                products[1].Name = 'Area Boost - 400 km';
                products[1].Sub_Category__c = subCategory.getValue();
                continue;                
            }

            if (subCategory.getValue() == 'Display_Focus') {
                products[2].Name = 'Display - Focus - Enhanced';
                products[2].Sub_Category__c = subCategory.getValue();
                continue;                
            }
        }        
        
        insert products;

        List<SBQQ__Subscription__c> cpqSubs = new List<SBQQ__Subscription__c>();
        
        for (Account a : acctList) {
            for (SBQQ__Subscription__c cpqSub : TestDataFactory.createCPQSubsForProducts(products, a.Id)) {
				cpqSub.SBQQ__NetPrice__c = 100;
                cpqSubs.add(cpqSub);
            }
        }
                
        insert cpqSubs;

        for (SBQQ__Subscription__c cpqSub : cpqSubs) {
            cpqSub.Provisioning_Status__c = 'Activated';
        }

        update cpqSubs;        

        for (Account a : acctList) {
            for (Service_Provider__c sp : TestDataFactory.createServiceProviders(2, a.Id)) {
                sp.Total_Used_Inventory_Units__c = 100;
                sp.Total_New_Inventory_Units__c = 50;
				spList.add(sp);
            }
        }
        
        insert spList;
                
        //Cotact to Account direct relationship and traditional way of tagging contacts to account
        for (Integer i = 0; i < 5; i++) {
            contactList.add(new Contact(FirstName='TestFirstName'+String.valueOf(i), LastName = 'TestLastName'+String.valueOf(i),
                                       Email = 'TTestLastName@testcg.com', AccountId = acctList[0].Id));
        }
        
        insert contactList;

        //Contact to Account indirect relationship
        for (Integer j = 1; j < acctList.size(); j++) {
            for (Integer k = 0; k < contactList.size(); k++) {
                 acrList.add(new AccountContactRelation(ContactId = contactList[k].Id, AccountId = acctList[j].Id)); 
            }
        }
        
        insert acrList;
        
    }
    
    static testmethod void updateAccountContactRelations() {
        
        Test.startTest();
        Batch_UpdateAccountContactRelation Batch_acr_update = new Batch_UpdateAccountContactRelation();
        Database.executeBatch(Batch_acr_update);
        Test.stopTest();
        
        List<Account> acctList = [SELECT Id, BillingCity FROM Account];
        List<AccountContactRelation> acrList = [SELECT Id, Account_Billing_City__c FROM AccountContactRelation WHERE AccountId =: acctList[0].Id];
        
        system.assert(acctList[0].BillingCity == acrList[0].get('Account_Billing_City__c'));
        
    }
    
    static testmethod void updateACRBatchSingleIdConstructor() {
        
		Account acct = [SELECT Id FROM Account WHERE Name IN ('testaccount1')];
        Id acctId = acct.Id;
        
        Test.startTest();
        Batch_UpdateAccountContactRelation Batch_acr_update = new Batch_UpdateAccountContactRelation(acctId);
        Database.executeBatch(Batch_acr_update);
        Test.stopTest();
        
        List<Account> acctList = [SELECT Id, BillingCity FROM Account];
        List<AccountContactRelation> acrList = [SELECT Id, Account_Billing_City__c FROM AccountContactRelation WHERE Account.Name = 'testaccount1'];
        
        system.assert(acctList[0].BillingCity == acrList[0].get('Account_Billing_City__c'));
        
    }   
    
    static testmethod void updateACRBatchSetConstructor() {
        
        Set<Id> acctIds = new Set<Id>();
        
        for(Account acct : [SELECT Id FROM Account WHERE Name IN ('testaccount1', 'testaccount2')]){
            acctIds.add(acct.Id);
        }        
        
        Test.startTest();
        Batch_UpdateAccountContactRelation Batch_acr_update = new Batch_UpdateAccountContactRelation(acctIds);
        Database.executeBatch(Batch_acr_update);
        Test.stopTest();
        
        List<Account> acctList = [SELECT Id, BillingCity FROM Account];
        List<AccountContactRelation> acrList = [SELECT Id, Account_Billing_City__c FROM AccountContactRelation WHERE Account.Name IN ('testaccount1', 'testaccount2')];
        
        system.assert(acctList[0].BillingCity == acrList[0].get('Account_Billing_City__c'));
        
    }        
    
    static testmethod void updateACRIntegerConstructor() {
        
		Integer i = 10;
        
        Test.startTest();
        Batch_UpdateAccountContactRelation Batch_acr_update = new Batch_UpdateAccountContactRelation(i);
        Database.executeBatch(Batch_acr_update);
        Test.stopTest();
        
        List<Account> acctList = [SELECT Id, BillingCity FROM Account];
        List<AccountContactRelation> acrList = [SELECT Id, Account_Billing_City__c FROM AccountContactRelation WHERE AccountId =: acctList[0].Id];
        
        system.assert(acctList[0].BillingCity == acrList[0].get('Account_Billing_City__c'));
        
    }      
    
    static testmethod void updateCPQSubInfo() {
        
        Set<Id> acctIds = new Set<Id>();
        
        for(Account acct : [SELECT Id, (SELECT Id, SBQQ__Product__r.Name, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__NetPrice__c ,
								        SBQQ__TerminatedDate__c FROM CPQ_Subscriptions_Fulfillment__r) FROM Account WHERE Name IN ('testaccount1')]){
            acctIds.add(acct.Id);
        }        

        Test.startTest();
        Batch_UpdateAccountContactRelation Batch_acr_update = new Batch_UpdateAccountContactRelation(acctIds);
        Database.executeBatch(Batch_acr_update);
        Test.stopTest();

        List<AccountContactRelation> acrList = [SELECT Id, Listings_Product__c , Listings_Monthly_Total__c FROM 
                                                AccountContactRelation WHERE Account.Name IN ('testaccount1')];
        
        system.assertEquals('Enhanced Placement', acrList[0].get('Listings_Product__c'));
        system.assertEquals(100, acrList[0].get('Listings_Monthly_Total__c'));
        
    }
    
    static testmethod void cancelCPQSubInfo() {
        
        Set<Id> acctIds = new Set<Id>();
        List<Account> acctsWithSubsList = new List<Account>();
        List<SBQQ__Subscription__c> cpqSubList = new List<SBQQ__Subscription__c>();
        
        for(Account acct : [SELECT Id, Type, (SELECT Id, SBQQ__Product__r.Name, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__NetPrice__c ,
								        SBQQ__TerminatedDate__c FROM CPQ_Subscriptions_Fulfillment__r) FROM Account WHERE Name IN ('testaccount1')]){
			for(SBQQ__Subscription__c cpqSub : acct.CPQ_Subscriptions_Fulfillment__r){
                cpqSub.Provisioning_Status__c = 'De-activated';
                cpqSub.SBQQ__TerminatedDate__c = Date.today().addDays(-3);
                cpqSubList.add(cpqSub);
            }
			acctIds.add(acct.Id);                                            
        }       

        update cpqSubList;
        
        Test.startTest();
        Batch_UpdateAccountContactRelation Batch_acr_update = new Batch_UpdateAccountContactRelation(acctIds);
        Database.executeBatch(Batch_acr_update);
        Test.stopTest();

        List<AccountContactRelation> acrList = [SELECT Id, Listings_Cancellation_Date__c FROM 
                                                AccountContactRelation WHERE Account.Name IN ('testaccount1')];
        
        system.assert(acrList[0].get('Listings_Cancellation_Date__c') != null);
        
    }            
    

    static testMethod void scheduleTest() {
        
        Test.startTest();
        string cron = '0 0 5 * * ?';
        System.schedule('Schedule ACR Automation', cron, new Batch_UpdateAccountContactRelation());
        Test.stopTest();
        
    }

}