@isTest
public class Batch_MonthlyStatsEmailData_Test {

        @testSetup static void setupRecords() {

            Profile p = [
                SELECT Id 
                FROM Profile 
                WHERE Name = 'System Administrator'
            ];
            UserRole role = [
                SELECT Id
                FROM UserRole
                WHERE Name = 'System Administrator'
            ];
            User u = TestDataFactory.createUser(true, p);
            u.UserRoleId = role.Id;
            insert u;
            
            System.runAs(u){            
                
                Id DealerAcctRTId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
                List<Account> acctList = new List<Account>();
                List<Contact> contactList = new List<Contact>();
                List<Contact> contactUpdateList = new List<Contact>();
                List<Service_Provider__c> spList = new List<Service_Provider__c>();
                List<AccountContactRelation> acrList = new List<AccountContactRelation>();
                List<Contact_Dashboard_Access__c> cdaList = new List<Contact_Dashboard_Access__c>();
                List<Account_History_Snapshot__c> ahsList = new List<Account_History_Snapshot__c>();
		        List<Monthly_Stats_Listings_Email_Data__c> insertMsedList = new List<Monthly_Stats_Listings_Email_Data__c>();                
                
                Integer m =0;
                for (Integer i = 0; i < 5; i++) {
                    acctList.add(new Account(Name='testAccountCustomer'+String.valueOf(i), BillingCountryCode='CA',
                                             BillingCity = 'Huntsville', BillingStateCode = 'ON',
                                             Type = 'Customer', Product_Activation_Status__c ='Active', 
                                             RecordTypeId = DealerAcctRTId, OwnerId = u.Id));
                }
                
                for (Integer i = 0; i < 3; i++) {
                    acctList.add(new Account(Name='testAccountProspect'+String.valueOf(i), BillingCountryCode='CA',
                                             BillingCity = 'Huntsville', BillingStateCode = 'ON',
                                             Type = 'Prospect', Product_Activation_Status__c ='Active', 
                                             RecordTypeId = DealerAcctRTId, OwnerId = u.Id));
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
                                                AccountId = acctList[i].Id, OwnerId = u.Id));
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
                                                                    status__c = true, Associated_Service_Providers__c = '1;2;3')); 
                    }
                }
                
                insert cdaList;
                
                
                //Create Account History Snapshot records
                for (Integer j = 0; j < acctList.size(); j++) {
                    Id acctId = acctList[j].Id;
                    ahsList.add(new Account_History_Snapshot__c(
                        Account__c = acctList[j].Id, 
                        X30_Day_SRP_Volume__c = 500,
                        X30_Day_VDP_Volume__c = 100,
                        X30_Day_Lead_Volume_Web_Clicks_Total__c = 1000,
                        X30_Day_Lead_Volume_Map_Views_Total__c = 1000,
                        X30_Day_Lead_Volume_Phone_Total__c = 10,
                        X30_Day_Lead_Volume_SMS_Total__c = 250,
                        X30_Day_Lead_Volume_Chat_Total__c = 220,
                        Total_New_Inventory_Units__c = 50,
                        Total_Used_Inventory_Units__c = 200,
                    	Snapshot_Date__c = System.today())); 
                }
                insert ahsList;
        
		        Monthly_Stats_Listings_Email_Data__c msed = new Monthly_Stats_Listings_Email_Data__c(name = 'TTestLastName_0@testcontactcg.com', 
                                            X30_Day_SRP_Volume__c = 1,
                                            X30_Day_VDP_Volume__c = 2, 
                                            Total_New_Inventory_Units__c = 19,
                                            Total_Used_Inventory_Units__c = 20,
                                            Stats_Category__c = 'Paying',                                                  		
                                            Account__c = acctList[0].id);
    
                insertMsedList.add(msed);
                insert insertMsedList;
                
                
            }
		}
        
    
    static testmethod void newMonthlyStatsForSingleRecord(){
        Test.startTest();
        
        Batch_MonthlyStatsEmailData batchMSED = new Batch_MonthlyStatsEmailData('TTestLastName_1@testcontactcg.com');
        Database.executeBatch(batchMSED);

        Test.stopTest();
        
        List<Monthly_Stats_Listings_Email_Data__c> newMSEDList = [select id, name from Monthly_Stats_Listings_Email_Data__c];
        system.assert(newMSEDList.size() > 0);
    }
    
    static testmethod void newMonthlyStatsForSetOfRecords(){
        Test.startTest();
        
        Batch_MonthlyStatsEmailData batchMSED = new Batch_MonthlyStatsEmailData(new set<string>{'TTestLastName_1@testcontactcg.com', 'TTestLastName_2@testcontactcg.com'});
        Database.executeBatch(batchMSED);

        Test.stopTest();
        
        List<Monthly_Stats_Listings_Email_Data__c> newMSEDList = [select id, name from Monthly_Stats_Listings_Email_Data__c];
        system.assert(newMSEDList.size() > 0);
    }
    
    static testmethod void newMonthlyStatsBulk(){
        Test.startTest();
        
        Batch_MonthlyStatsEmailData batchMSED = new Batch_MonthlyStatsEmailData();
        Database.executeBatch(batchMSED);

        Test.stopTest();
        
        List<Monthly_Stats_Listings_Email_Data__c> newMSEDList = [select id, name from Monthly_Stats_Listings_Email_Data__c];
        system.assert(newMSEDList.size() > 0);
    }

    static testmethod void testScheduleMSEDBatch() {
        Batch_MonthlyStatsEmailData MSEDBatch = new Batch_MonthlyStatsEmailData();
        String cronString = '0 0 23 * * ?';
        Test.startTest();
        String jobId = System.schedule('TEST_Batch_MSED_Data', cronString, MSEDBatch);
        Test.stopTest();
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronString, ct.CronExpression, 'Schedule job cron string mismatch');
    }
}