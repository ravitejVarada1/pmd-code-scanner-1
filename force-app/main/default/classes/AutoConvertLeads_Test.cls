/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         bthalvayapati
* modifiedBy:     bthalvayapati
* created:        06/10/2021
* modified:       06/10/2021
* created jira:   BR-2659
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@IsTest
public class AutoConvertLeads_Test {

    	static testmethod void autoConvertLead() {

        LeadStatus leadStatus= [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];

		//Create a Dealer Account
        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        List<Account> dealerAccountList = TestDataFactory.createAccounts(1, dealerAccountRecordTypeId);

        insert dealerAccountList;        
        
        //Create a Dealer Conatct
		List<Contact> contactList = TestDataFactory.createContacts(1, dealerAccountList[0].Id);	
		contactList[0].Email = 'leadEmailConvertTest@CarGurus.com';    
        
		insert contactList;
            
        /* Create a Lead and populate Lead Account and Parent Contact fields.
         * When Lead Conversion happens, Lead should converted to the Account and Contact
         * added on the Lead object
        */ 
		
        Lead lead = new Lead(LastName='dealerLastName',FirstName='dealerFirstName', Email='leadEmailConvertTest@CarGurus.com',
                         Company='DealerCompany',Lead_Account__c=dealerAccountList[0].Id,Parent_Contact__c=contactList[0].Id );
		insert lead;
    
        Test.startTest();
        AutoConvertLeads.leadAssign(New List<Id>{lead.Id});
        Test.stopTest();
    
        Lead convertedLead = [SELECT Id, Status FROM Lead WHERE Id = :lead.Id];
        system.assertEquals(leadStatus.MasterLabel, convertedLead.Status);
    }

    @isTest
    static void validateUSProfileTest() {

        LeadStatus leadStatus= [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];

		//Create a Dealer Account
        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        List<Account> dealerAccountList = TestDataFactory.createAccounts(1, dealerAccountRecordTypeId);

        insert dealerAccountList;        

        List<Service_Provider__c> spList = TestDataFactory.createServiceProviders(1,dealerAccountList[0].Id);
        spList[0].Total_Used_Inventory_Units__c = 11;
        insert spList;
        
        //Create a Dealer Conatct
		List<Contact> contactList = TestDataFactory.createContacts(1, dealerAccountList[0].Id);	
		contactList[0].Email = 'leadEmailConvertTest@CarGurus.com';    
        
		insert contactList;
        
        User salesUserOne = [SELECT Id FROM User WHERE Profile.Name = 'Sales User' AND IsActive = true limit 1];
		
        Lead lead = new Lead(LastName='dealerLastName',FirstName='dealerFirstName', Email='leadEmailConvertTest@CarGurus.com',
                         Company='DealerCompany',Lead_Account__c=dealerAccountList[0].Id,Parent_Contact__c=contactList[0].Id);
		insert lead;

        lead.OwnerId = salesUserOne.Id;
        update lead;
    
        Test.startTest();
        try{
            AutoConvertLeads.leadAssign(New List<Id>{lead.Id});
        }
        catch(Exception ex) {

            System.assertEquals('The used car inventory associated to the Account, '+
             'Service provider is > 10, please use the Send to Rep button to route the lead to appropriate Sales team member.', ex.getMessage());

        }

        Test.stopTest();
        
    }
}