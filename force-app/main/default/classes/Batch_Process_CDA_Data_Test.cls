@isTest
public class Batch_Process_CDA_Data_Test {
    
    @testSetup static void setupRecords() {
        
        Id DealerAcctRTId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        List<Account> acctList = new List<Account>();
        List<Contact> contactList = new List<Contact>();
        List<Contact> contactUpdateList = new List<Contact>();
        List<Service_Provider__c> spList = new List<Service_Provider__c>();
        List<AccountContactRelation> acrList = new List<AccountContactRelation>();
        List<Contact_Dashboard_Access__c> cdaList = new List<Contact_Dashboard_Access__c>();
        
        Integer m =0;
        for (Integer i = 0; i < 5; i++) {
            acctList.add(new Account(Name='testaccount'+String.valueOf(i), BillingCountryCode='CA',
                                     BillingCity = 'Huntsville', BillingStateCode = 'ON',
                                     Type = 'Customer', Product_Activation_Status__c ='Active', 
                                     RecordTypeId = DealerAcctRTId));
        }
        
        insert acctList;
        
        for (Account a : acctList) {
            for (Service_Provider__c sp : TestDataFactory.createServiceProviders(2, a.Id)) {
                Integer assignSPValue = m++;
                String associateEmails = '{ "associatedEmails": ' +
                    '[{"personId": 6236063,"firstName": "reny",' +
                    '"lastName": "bryu","email": "pat@newportcarloans' + assignSPValue + '.com", '+
                    '"roles": [ "Dashboard Administrator" ]}]}';
                sp.Total_Used_Inventory_Units__c = 100;
                sp.Total_New_Inventory_Units__c = 50;
                sp.service_provider_id__c = assignSPValue;
                sp.Unique_Id__c = a.BillingCountryCode + assignSPValue;
                sp.Contact_Dashboard_Access_Data__c = associateEmails;
                spList.add(sp);
            }
        }
        
        insert spList;

        //Cotact to Account direct relationship and traditional way of tagging contacts to account
        for (Integer i = 0; i < 5; i++) {
            contactList.add(new Contact(FirstName='TestFirstName'+String.valueOf(i), 
                                        LastName = 'TestLastName'+String.valueOf(i),
                                        Email = 'TTestLastName_' + i + '@testcontactcg.com', 
                                        AccountId = acctList[i].Id));
        }
        
        insert contactList;
        
        //Create Contact Dashboard Access records
        for (Integer j = 0; j < acctList.size(); j++) {
            for (Integer k = 0; k < contactList.size(); k++) {
                
                Id acctId = acctList[j].Id;
                string acctname = acctList[j].Name;
                Id contactId = contactList[k].Id;
                string contactFirstName = contactList[k].FirstName;
                string contactEmail = contactList[k].Email;                
                
                cdaList.add(new Contact_Dashboard_Access__c(Account__c = acctList[j].Id, First_Name__c = contactList[k].FirstName,
                                                            Last_Name__c = contactList[k].LastName, Email__c = contactList[k].Email,
                                                           	Associated_Service_Providers__c = '1;2;3')); 
            }
        }
        
        insert cdaList;
        
    }

    static testmethod void checkSingleIdConstructor() {
        
        Account acct = 	   [SELECT Id, Name, 
                            (SELECT Id, Account__c, Unique_Id__c, Contact_Dashboard_Access_Data__c, 
                             service_provider_id__c FROM Service_Provider__r),
                            (SELECT Id, AccountId, Lastname, Email FROM Contacts), 
                            (SELECT Id, First_Name__c, Last_Name__c, Email__c, CG_Role__c, 
                             Associated_Service_Providers__c, Status__c, Unique_Key__c, 
                             Account__c, Contact__c FROM Account_CDA__r)
                            FROM Account WHERE Name IN ('testaccount1') LIMIT 1];
        
        Id acctId = acct.Id;          
        
        Test.startTest();
        Batch_Process_CDA_Data cda_insert = new Batch_Process_CDA_Data(acctId);
		Batch_UpdateCDA_With_Contact_References cda_contact_ref = new Batch_UpdateCDA_With_Contact_References(acctId);        
        Database.executeBatch(cda_insert);
        Database.executeBatch(cda_contact_ref);
        Test.stopTest();
        
        List<Contact_Dashboard_Access__c> cdaList = [SELECT Id FROM Contact_Dashboard_Access__c WHERE Account__c =: acctId];
        
        system.assert(cdaList.size() == 7);
        
    }    
    
    static testmethod void checkIdSetConstructor() {
        
        
        List<Account> acctListforIds = [SELECT Id, Name, 
                                        (SELECT Id, Account__c, Unique_Id__c, Contact_Dashboard_Access_Data__c, 
                                         service_provider_id__c FROM Service_Provider__r),
                                        (SELECT Id, AccountId, Lastname, Email FROM Contacts), 
                                        (SELECT Id, First_Name__c, Last_Name__c, Email__c, CG_Role__c, 
                                         Associated_Service_Providers__c, Status__c, Unique_Key__c, 
                                         Account__c, Contact__c FROM Account_CDA__r)
                                        FROM Account WHERE Name IN ('testaccount0', 'testaccount1')];
        
        Set<Id> acctIdSet = new Set<Id>();
        
        for(Account account : acctListforIds){
            acctIdSet.add(account.Id);
        }
        
        
        Test.startTest();
        Batch_Process_CDA_Data cda_insert_set = new Batch_Process_CDA_Data(acctIdSet);
		Batch_UpdateCDA_With_Contact_References cda_contact_ref = new Batch_UpdateCDA_With_Contact_References(acctIdSet);        
        Database.executeBatch(cda_insert_set);
        Database.executeBatch(cda_contact_ref);

        Test.stopTest();
        
        List<Contact_Dashboard_Access__c> cdaList = [SELECT Id FROM Contact_Dashboard_Access__c WHERE Account__c IN : acctIdSet];
        
        system.assert(cdaList.size() == 14);        
        
    }        
    
    static testmethod void checkWithoutIdsConstructor() {
        
        
        List<Account> acctListforIds = [SELECT Id, Name, 
                                        (SELECT Id, Account__c, Unique_Id__c, Contact_Dashboard_Access_Data__c, 
                                         service_provider_id__c FROM Service_Provider__r),
                                        (SELECT Id, AccountId, Lastname, Email FROM Contacts), 
                                        (SELECT Id, First_Name__c, Last_Name__c, Email__c, CG_Role__c, 
                                         Associated_Service_Providers__c, Status__c, Unique_Key__c, 
                                         Account__c, Contact__c FROM Account_CDA__r)
                                        FROM Account];
        
        Set<Id> acctIdSet = new Set<Id>();
        
        for(Account account : acctListforIds){
            acctIdSet.add(account.Id);
        }
        
        
        Test.startTest();
        Batch_Process_CDA_Data cda_insert_set = new Batch_Process_CDA_Data();
        Database.executeBatch(cda_insert_set);
        Test.stopTest();
        
        List<Contact_Dashboard_Access__c> cdaList = [SELECT Id FROM Contact_Dashboard_Access__c WHERE Account__c IN : acctIdSet];
        
        system.assert(cdaList.size() == 35);        
        
    }        

    static testmethod void checkFieldsDiffer() {
        Account acct = 	   [SELECT Id, Name, BillingCountryCode
                            FROM Account WHERE Name IN ('testaccount0') LIMIT 1];
        
        Id acctId = acct.Id;          

	    String associateEmails = '{ "associatedEmails": ' +
                    '[{"personId": 6236063,"firstName": "TestFirstName0",' +
                    '"lastName": "TestLastName0","email": "ttestlastname_0@testcontactcg.com", '+
                    '"roles": [ "Dashboard Administrator" ]}]}';
                Service_Provider__c sp = new Service_Provider__c();
                sp.Total_Used_Inventory_Units__c = 100;
                sp.Total_New_Inventory_Units__c = 50;
                sp.service_provider_id__c = 20;
                sp.Unique_Id__c = acct.BillingCountryCode + '20';
                sp.Contact_Dashboard_Access_Data__c = associateEmails;
        		sp.Account__c = acctId;
        
        insert sp;
        
        Test.startTest();
        Batch_Process_CDA_Data cda_insert1 = new Batch_Process_CDA_Data(acctId);
        Database.executeBatch(cda_insert1); 
        Test.stopTest();

        Account acct2 =    [SELECT Id, Name, 
                            (SELECT Id, Account__c, Unique_Id__c, Contact_Dashboard_Access_Data__c, 
                             service_provider_id__c FROM Service_Provider__r),
                            (SELECT Id, AccountId, Lastname, Email FROM Contacts), 
                            (SELECT Id, First_Name__c, Last_Name__c, Email__c, CG_Role__c, 
                             Associated_Service_Providers__c, Status__c, Unique_Key__c, 
                             Account__c, Contact__c FROM Account_CDA__r)
                            FROM Account WHERE Name IN ('testaccount0') LIMIT 1];                

        List<Contact_Dashboard_Access__c> cdaList1 = acct2.Account_CDA__r;
        
        system.assert(cdaList1.size() == 7);
    }        
    
    
    static testMethod void scheduleTest() {
        
        Test.startTest();
        string cron = '0 0 22 * * ? *';
        System.schedule('Schedule CDA Automation', cron, new Batch_Process_CDA_Data());
        Test.stopTest();
        
    }

    
}