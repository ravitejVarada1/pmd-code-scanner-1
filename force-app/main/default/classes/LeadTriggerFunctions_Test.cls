/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         bthalvayapati
* modifiedBy:     bthalvayapati
* created:        06/14/2021
* modified:       06/14/2021
* created jira:   BR-1386
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class LeadTriggerFunctions_Test {    
    private static final STring DEALER_ACCOUNT_NAME = 'DEALER';
    
    @testSetup
    static void testSetup(){

        //Insert a Dealer Accounts
        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        List<Account> dealerAccountList = TestDataFactory.createAccounts(3, dealerAccountRecordTypeId);
		List<Contact> contactList = new List<Contact>();
        List<Service_Provider__c> serviceProviderList = new List<Service_Provider__C>();
		Integer i = 0;
        Integer k = 0;
        
        insert dealerAccountList;
        
        //Create a Contacts and Service Providers and associte to Dealer Accounts.
        for (Account dealerAccount : dealerAccountList){
            Service_Provider__c serviceProvider = TestDataFactory.createSingleServiceProvider(dealerAccount.Id);
            serviceProvider.Used_Inventory_Avg__c = 5;
            serviceProvider.Dealer_Type__c = AccountCategoryCalculator.DEALER_TYPE_NEW;
            serviceProviderList.add(serviceProvider);
            
            List<Contact> matchContactList = TestDataFactory.createContacts(1, dealerAccount.Id);	
            matchContactList[0].Email = 'leadEmailMatch' + String.valueOf(k) + '@cargurus.com';
            contactList.addAll(matchContactList);   
            k++;
        }
        
        insert serviceProviderList;
        insert contactList;
    }
    

    /*
     * Insert New lead with matching Contact Email and check Account, Contact and 
     * Service Provider Ref Fields are populated
    */
 
    static testmethod void singleMatchedContactWithSingleSP() {
        List<Lead> leadList = TestDataFactory.createLeads(1);

        Contact dealerContact = [Select Id, Email from Contact where Email = 'leadEmailMatch0@cargurus.com' Limit 1];
        dealerContact.Email = 'leadEmailMatchSingleSP0@cargurus.com';
        
        update dealerContact;
        
        for (Integer i=0;i < leadList.size(); i++) {
            leadList[i].LastName = 'leadLastNameSingleSP' + String.valueOf(i);
            leadList[i].Company = 'leadCompanySingleSP' + String.valueOf(i);
            leadList[i].Email = 'leadEmailMatchSingleSP' + String.valueOf(i) + '@cargurus.com';
        }

        insert leadList;
        
        update dealerContact;
        
		List<Lead> assertLeadList = [Select Id, Email, Parent_Contact__c, Lead_Account__c, 
                                     Service_Provider__c FROM Lead];
        
		system.assert(assertLeadList[0].Parent_Contact__c != null);
		system.assert(assertLeadList[0].Lead_Account__c != null);        
		system.assert(assertLeadList[0].Service_Provider__c != null);        
    }     
    
    /*
     * Insert New lead with matching Contact Email and check Account, Contact and 
     * Service Provider Ref Fields are populated. The followiing method fetches Dealer Type = 'Used'
     * Service Provider.
    */
 
    static testmethod void singleMatchedContactWithMultipleSP() {

        Contact dealerContact = [Select Id, Email from Contact where Email = 'leadEmailMatch1@cargurus.com' Limit 1];
        dealerContact.Email = 'leadEmailMatch1@cargurus.com';
        
        update dealerContact;
        
        List<Lead> leadList = TestDataFactory.createLeads(3);

        Account dealerAccount = [Select Id, Name from Account LIMIT 1];
        
        Service_Provider__c serviceProvider = TestDataFactory.createSingleServiceProvider(dealerAccount.Id);
        serviceProvider.Dealer_Type__c = AccountCategoryCalculator.DEALER_TYPE_USED;  
        serviceProvider.reviewStatus__c = 'Approved';
        
        insert serviceProvider;
        
        for (Integer i=0;i < leadList.size(); i++) {
            leadList[i].LastName = 'leadLastName' + String.valueOf(i);
            leadList[i].Company = 'leadCompany' + String.valueOf(i);
            leadList[i].Email = 'leadEmailMatch' + String.valueOf(i) + '@cargurus.com';
        }

        insert leadList;
        
		List<Lead> assertLeadList = [Select Id, Email, Parent_Contact__c, Lead_Account__c, 
                                     Service_Provider__c FROM Lead];
        
		system.assert(assertLeadList[0].Parent_Contact__c != null);
		system.assert(assertLeadList[0].Lead_Account__c != null);        
		system.assert(assertLeadList[0].Service_Provider__c != null);        
    }     

    /*
     * Insert New lead without matching Contact Email and check Account, Contact and 
     * Service Provider Ref Fields are NOT populated
    */
    
    static testmethod void nonExistentLeadEmail() {
        List<Lead> leadList = TestDataFactory.createLeads(3);
        
        for (Integer i=0;i < leadList.size(); i++) {
            leadList[i].LastName = 'leadLastNameNA' + String.valueOf(i);
            leadList[i].Company = 'leadCompanyNA' + String.valueOf(i);
            leadList[i].Email = 'leadEmailMatchNA' + String.valueOf(i) + '@cargurus.com';
        }
        insert leadList;
        
		List<Lead> assertLeadList = [Select Id, Email, Parent_Contact__c, Lead_Account__c, Service_Provider__c 
                              FROM Lead];
        
		system.assert(assertLeadList[0].Parent_Contact__c == null);
		system.assert(assertLeadList[0].Lead_Account__c == null);        
		system.assert(assertLeadList[0].Service_Provider__c == null);        
    }     
    
    /* Insert new Lead records with CarGurus Tracking Id and process
     * should create a new Campaign if one does not exist with that 
     * tracking Id and associate a Lead as campaign Member. If there 
     * is a Campaign already, it should simply associate a Lead to
     * Campaign as a member.
    */ 
    
    static testmethod void campaignMemberTest() {
        List<Lead> leadList = TestDataFactory.createLeads(2);
        
        for (Integer i=0;i < leadList.size(); i++) {
            leadList[i].LastName = 'leadLastNameNA' + String.valueOf(i);
            leadList[i].Company = 'leadCompanyNA' + String.valueOf(i);
            leadList[i].Email = 'leadEmailMatchNA' + String.valueOf(i) + '@cargurus.com';
            leadList[i].CarGurus_Tracking_Id__c = 'CreateNewCampaign_CG';
        }
        insert leadList;
        
		List<CampaignMember> campaignMemberList = [Select Id from CampaignMember where Campaign.Name = 'CreateNewCampaign_CG'];
        
		system.assert(campaignMemberList.size() == 2);
    }         
}