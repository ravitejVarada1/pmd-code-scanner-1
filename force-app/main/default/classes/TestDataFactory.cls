/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     ksuh
* created:        01/07/2021
* modified:       06/13/2022
* created jira:   BR-348
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class TestDataFactory {
    
    public static void completeOppTracker(Opportunity_Tracker__c oppTracker){
        oppTracker.Zuora_ActivePaymentMethodMatch__c = true;
        oppTracker.Zuora_QuotePaymentMethod__c = true;
        oppTracker.Zuora_ActiveBillingAccounts__c = true;
        oppTracker.Spid_HasInventory__c = true;
        oppTracker.DocusignComplete__c = true;
        oppTracker.Spid_CDA__c = true;
        oppTracker.Spid_DealerEmail__c = true;
        oppTracker.Quote_Approved__c = true;
        oppTracker.Quote_StartDate__c = true;
    }

    public static List<Account> createAccounts(Integer qty, Id recordTypeId, Id parentId) {
        List<Account> accsToReturn = new List<Account>();

        if (recordTypeId == null) {
            recordTypeId = Utilities.getrecordTypeId('Account', ConstantsUtil.RT_ACCOUNT_DEALER);
        }

        for(Integer i = 0; i<qty; i++) {
            accsToReturn.add(
                new Account(
                    Name = 'Test Account ' + i,
                    BillingCountryCode = 'US',
                    Account_Status__c = ConstantsUtil.ACCOUNT_STATUS_ACTIVE,
                    ParentId = parentId,
                    RecordTypeId = recordTypeId
                )
            );
        }
        return accsToReturn;
    }
    
        public static List<Account> createPersonalAccounts(Integer qty, Id recordTypeId) {
        List<Account> accsToReturn = new List<Account>();

        if (recordTypeId == null) {
            recordTypeId = Utilities.getrecordTypeId('Account', 'PersonAccount');
        }
            
   		        for(Integer i = 0; i<qty; i++) {
            accsToReturn.add(
                new Account(
                    RecordTypeId = recordTypeId,
                    FirstName='Test FName'  + i,
                    LastName='Test LName'  + i,
                    PersonEmail='test@test.com',
                    Phone='5353689087',
                    PersonMailingStreet='test@yahoo.com',
                    PersonMailingPostalCode='12345',
                    PersonMailingCity='SFO',
                    PersonHomePhone='1234567',
                    PersonMobilePhone='12345678'      
                )
            );
        }
 		
        return accsToReturn;
    }
    

    public static Account createSingleAccount(ID recordTypeId) {
        return createAccounts(1, recordTypeId, null)[0];
    }
    
    public static Account createSingleAccount(ID recordTypeId, ID parentId){
        return createAccounts(1, recordTypeId, parentId)[0];
    }

    public static List<Account> createAccounts(Integer qty, ID recordTypeId){
        return createAccounts(qty, recordTypeId, null);
    }

    public static List<Account> createAccounts(Integer qty) {
        return createAccounts(qty, null, null);
    }

    public static List<Account> createAccounts(Integer qty, String recordTypeApiName) {
        Id recordTypeId = (recordTypeApiName != null) ? Utilities.getrecordTypeId('Account', recordTypeApiName) : null;
        return createAccounts(qty, recordTypeId, null);
    }
    
     public static List<Account> createPersonalAccounts(Integer qty) {
        return createPersonalAccounts(qty, null);
    }
    public static List<Contact> createContacts(Integer qty, ID accountId){
        List<Contact> ctcsToReturn = new List<Contact>();
        for(Integer i = 0; i<qty; i++) {
            Contact c = new Contact(
                LastName = 'Test',
                FirstName = 'TestFName',
                Email = 'test@cargurus.com',
                AccountId = accountId
            );
            ctcsToReturn.add(c);
        }
        return ctcsToReturn;
    }
    public static List<Zuora__CustomerAccount__c> createZuoraAccount(Integer qty, Account acc){
        List<Zuora__CustomerAccount__c> createZAccount = new List<Zuora__CustomerAccount__c>();
        for(Integer i = 0; i<qty; i++) {
            Zuora__CustomerAccount__c zac = new Zuora__CustomerAccount__c(
               Name  = 'testZac',
        Zuora__Account__c = acc.Id,
        Zuora__Status__c = 'Active'
            );
            createZAccount.add(zac);
        }
        return createZAccount;
    }
        
    public static List<Campaign> createCampaign(Integer qty){
        List<Campaign> campaignsToReturn = new List<Campaign>();
        for(Integer i = 0; i<qty; i++) {
            Campaign c = new Campaign(
                Name = 'Test Campaign'
            );
            campaignsToReturn.add(c);
        }
        return campaignsToReturn;
    }
    
    public static List<Opportunity> createOpps(ID accountId, Integer qty){
        List<Opportunity> oppsToReturn = new List<Opportunity>();
            for(Integer i = 0; i<qty; i++) {
                Opportunity o = new Opportunity(
                    AccountId = accountId,
                    Name = 'testOpp',
                    StageName = 'Discover/Qualify',
                    CloseDate = Date.Today()
                );
                oppsToReturn.add(o);
            }
        return oppsToReturn;
    }
    

    public static List<SBQQ__Quote__c> createQuotes(Id accountId, Id opportunityId, Integer qty){
        List<SBQQ__Quote__c> quotesToReturn = new List<SBQQ__Quote__c>();
        for(Integer i = 0; i<qty; i++) {
            SBQQ__Quote__C q = new SBQQ__Quote__c(
                SBQQ__Account__c = accountId,
                SBQQ__Opportunity2__c = opportunityId,
                SBQQ__Primary__c = true,
                SBQQ__Status__c	= 'Draft',
                SBQQ__StartDate__c = System.today()
            );
            quotesToReturn.add(q);   
        }
        return quotesToReturn;
    }
     //Create contract
     public static contract createContract(Id accountId){
        Contract cont = new Contract();
        cont.accountID = accountId;
        cont.StartDate = system.today().addMonths(-3).toStartOfMonth();
        cont.ContractTerm = 3;
        cont.Status = 'Draft';
        cont.CurrencyIsoCode = 'USD';
        return cont;
    }
      
  //Create Products
   public static Product2 createProducts()
  {
      Product2 prod = new Product2(Name = 'Test Product ', IsActive = true,CurrencyIsoCode='USD'); 
      return prod;
  }
  
   //Create Orders
   public static List<Order> createOrders(Integer qty,Id accountId,Id contractId,Id Pricebook2Id){
      List<Order> ordersToReturn = new List<Order>();
      for(Integer i=0; i<qty; i++){
          ordersToReturn.add(
              new Order( 
                  AccountId = accountId,
                  EffectiveDate = Date.today(),
                  Status='Draft',
                  pricebook2Id = pricebook2Id,
                  ContractId = contractId
                  
              )
          );
      }
      return ordersToReturn;
   }
        //Create Price Book Entry
    public static PricebookEntry createPriceBookEntry(Id standardPricebookId , Id productId){ 
      PricebookEntry pbe = new PricebookEntry(
      pricebook2Id = standardPricebookId, Product2Id = productId, UnitPrice = 1020, IsActive = true);
      return pbe;

  }
       
      //Create Order Items
    public static List<OrderItem> createOrderItems(Id orderId, List<Product2> products, Id priceBookId){
         List<OrderItem> orderitemsToReturn = new List<OrderItem>();
          for(Integer i=0; i<products.size(); i++){
              orderitemsToReturn.add(
                  new OrderItem(
                      OrderId = orderId,
                      Quantity = 2.00,
                      UnitPrice = 12.00,
                      Product2Id = products[i].id, 
                      PricebookEntryId = priceBookId
                  )
              );
          }
       return orderitemsToReturn;
    }
    
    public static List<SBQQ__QuoteLine__c> createQuoteLines(Id quoteId, Id fullfillmentAccount, Set<Id> productIds){
        List<SBQQ__QuoteLine__c> quotesLinesToReturn = new List<SBQQ__QuoteLine__c>();
        
        for(Id prodId : productIds){
            SBQQ__QuoteLine__C ql = new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = quoteId,
                SBQQ__Product__c = prodId,
                SBQQ__ListPrice__c = 100,
                SBQQ__Quantity__c = 1,
                Fulfillment_Account__c = fullfillmentAccount
            );
			
            quotesLinesToReturn.add(ql);
        }
        
        return quotesLinesToReturn;
    }
    
    public static List<Lead> createLeads(Integer qty){
        List<Lead> leadsToReturn = new List<Lead>();
        for(Integer i = 0; i<qty; i++) {
        Lead l = new Lead(
            LastName = 'Test',
            Company = 'Test Data Unlimited'
        );
            leadsToReturn.add(l);
        }
        
        return leadsToReturn;
    }
    
    public static List<Case> createCases(Integer qty, Id accountId) {
        List<Case> casesToReturn = new List<Case>();
        for(Integer i = 0; i<qty; i++) {
            Case a = new Case(
                Subject = 'Test Case',
                Status = 'New',
                Origin = 'Email',
                AccountId = accountId
            );
            casesToReturn.add(a);
        }
        return casesToReturn;
    }    

    public static CaseComment createCaseComment(Id caseId) {
        return new CaseComment(
            CommentBody = 'Test!',
            ParentId = caseId
        );
    }
    
    public static List<Case> createCSCase(Integer numOfCases, List<Account> accounts){
        Id caseRecTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Consumer_Support').getRecordTypeId();
        List<Case> caseList = new List<Case>();
           String ConId;
    		
           List<account> Alist =[select id,PersonContactId from account where id = : accounts[0].Id];
           for(Account a : Alist){
               
               ConId=A.PersonContactId;
           }
           
           for(Integer i = 0; i < numOfCases; i++){
		
            caseList.add(new Case(Origin= 'Phone',
                                  Status= 'New',
                                  Recordtypeid=caseRecTypeId,
                                  Subject= 'Test Case Subject-' + i,
                                  Description= 'Test Case Description-' + i,
                                  ContactId= ConId,
                                  AccountId= accounts[i].Id));
        }
         
        return caseList;
    }
    
    public static List<Task> createTasks(Integer qty, ID contactId){
        List<Task> tasksToReturn = new List<Task>();
        for(Integer i = 0; i<qty; i++) {
            Task t = new Task(
                WhoId = contactId
            );
            tasksToReturn.add(t);
        }
        return tasksToReturn;
    }
    
    public static List<Dialpad_Call_Event_Log__c> createDialpadCallEventLogs(Integer qty){
        List<Dialpad_Call_Event_Log__c> logsToReturn = new List <Dialpad_Call_Event_Log__c>();
        for(Integer i = 0; i<qty; i++) {
            Dialpad_Call_Event_Log__c l = new Dialpad_Call_Event_Log__c(
                Call_Id__c = '5678',
                Direction__c = 'INBOUND',
                External_Number__c = '555-666-7777',
                Master_Call_Id__c = '5555'
            );
            logsToReturn.add(l);
        }
        return logsToReturn;
    }
    
    public static List<Service_Provider__c> createServiceProviders(Integer qty, Id accountId){
        List<Service_Provider__c> serviceprovidersToReturn = new List<Service_Provider__c>();
        
        for(Integer i=0; i<qty; i++){
            serviceprovidersToReturn.add(
                new Service_Provider__c(
                    Service_Provider_Id__c = i,
                    Name = 'Test SP '+i, 
                    Account__c = accountId,
                    reviewStatus__c = ConstantsUtil.SP_APPROVED,
                    Can_Host_Inventory__c = 'Yes',
                    Used_Inventory_Avg__c = 3,
                    Dealer_Type__c = 'Used'
                )
            );
        }
        return serviceprovidersToReturn;
    }

    public static Service_Provider__c createSingleServiceProvider(Id accountId){
        return createServiceProviders(1, accountId)[0];
    }

    public static List<Service_Provider__c> createServiceproviders(List<Account> accountList){
        List<Service_Provider__c> serviceprovidersToReturn = new List<Service_Provider__c>();
        Integer i = 1;

        for (Account a : accountList) {
            serviceprovidersToReturn.add(
                new Service_Provider__c(
                    Service_Provider_Id__c = i,
                    Name = 'Test SP '+i, 
                    Account__c = a.Id,
                    reviewStatus__c = ConstantsUtil.SP_APPROVED,
                    Can_Host_Inventory__c = 'Yes',
                    Used_Inventory_Avg__c = 3,
                    Dealer_Type__c = 'Used'
                )
            );
            i++;
        }
        return serviceprovidersToReturn;
    }

    public static List<Service_Provider__c> createSPForAccount(List<Account> accList){
        List<Service_Provider__c> serviceprovidersToReturn = new List<Service_Provider__c>();
        for(Integer i=0; i< accList.size(); i++){
            serviceprovidersToReturn.add(
                new Service_Provider__c(
                    Service_Provider_Id__c = i, 
                    Name = 'Test SP '+i, 
                    Account__c = accList[i].Id,
                    reviewStatus__c = 'APPROVED',
                    Used_Inventory_Avg__c = 3,
                    Can_host_inventory__c ='Yes',
                    Dealer_Type__c = 'Used'
                )
            );
        }
        return serviceprovidersToReturn;
    }

    public static User createUser(Boolean isActive, Profile prof) {
        
        User usersToReturn = new User(
            Alias = 'stndt1', 
            Email='standarduser1@testorg.com', 
            EmailEncodingKey='UTF-8', 
            LastName='Testing1', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = prof.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='standarduser234@testorg.com',
            Employee_Number_Workday__c = 'CG'+String.valueOf(Math.random()),
            Termination_Date__c = System.today().addDays(3),
            IsActive = isActive
        );
               
        return usersToReturn;   
    }

    public static User createRandomUser(Boolean isActive, Profile prof) {
        
        User usersToReturn = new User(
            Alias = 'stndt1', 
            Email='standarduser1@testorg.com', 
            EmailEncodingKey='UTF-8', 
            LastName='Testing1', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = prof.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='standarduser'+String.valueOf(Math.random())+'@testorg.com',
            Employee_Number_Workday__c = 'CG'+String.valueOf(Math.random()),
            Termination_Date__c = System.today().addDays(3),
            IsActive = isActive
        );
               
        return usersToReturn;   
    }

    public static List<Product2> createProducts(Integer qty) {
        List<Product2> prodsToReturn = new List<Product2>();
        
        for (Integer i = 0; i < qty; i++) {
            prodsToReturn.add(
                new Product2(
                    Name = 'Test Product '+i,
                    ProductCode = 'Test Product '+i,
                    isActive = true,
                    SBQQ__ProductPictureID__c = 'TEST'
                )
            );
        }
        
        return prodsToReturn;
    }

    // CPQ Subs ************************** will have to update to include new status and mrr fields
    public static List<SBQQ__Subscription__c> createCPQSubsForProducts(List<Product2> products, Id accountId) {
        List<SBQQ__Subscription__c> cpqSubs = new List<SBQQ__Subscription__c>();
        for(Integer i = 0; i < products.size(); i++) {
            SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
                SBQQ__Quantity__c = 1.00,
                SBQQ__Product__c = products[i].Id,
                Fulfillment_Account__c = accountId,
                SBQQ__SubscriptionStartDate__c = Date.today().addDays(-30),
                SBQQ__SubscriptionEndDate__c = Date.today().addDays(335)
                //status__c= 'Active',
                //Monthly_Total__c = 100,
            );
            cpqSubs.add(sub);
        }
        return cpqSubs;
    }

    //Create Order Items
    public static List<OrderItem> createOrderItems(Id orderId, List<Product2> products){
        List<OrderItem> orderitemsToReturn = new List<OrderItem>();
        for(Integer i=0; i<products.size(); i++){
            orderitemsToReturn.add(
                new OrderItem(
                    OrderId = orderId,
                    Quantity = 2.00,
                    UnitPrice = 12.00,
                    Product2Id = products[i].id
                    
                )
            );
        }
        return orderitemsToReturn;
    }

    public static List<Zuora__Subscription__c> createZSubscriptions(Id acc, Integer qty)
    {
        List<Zuora__Subscription__c> returnList = new List<Zuora__Subscription__c>();
        
        for(Integer i=0 ; i<qty ; i++)
        {
            Zuora__Subscription__c tmp = new Zuora__Subscription__c();
            tmp.Zuora__Account__c = acc;
            tmp.Zuora__Status__c = 'Active';
            tmp.Zuora__Zuora_Id__c = acc+String.valueOf(i);
            tmp.Zuora__External_Id__c = acc+String.valueOf(i);
            
            returnlist.add(tmp);
        }
        
        return returnList;
    }

    public static List<Zuora__PaymentMethod__c> createPaymentMethod(Integer qty, Zuora__CustomerAccount__c billingAccount){

        List<Zuora__PaymentMethod__c> createPaymentMethod = new List<Zuora__PaymentMethod__c>();
        for(Integer i = 0; i<qty; i++) {
            Zuora__PaymentMethod__c zpm = new Zuora__PaymentMethod__c(
                Name  = 'testZac'+i,
                Zuora__BillingAccount__c = billingAccount.id
            );
            createPaymentMethod.add(zpm);
        }
        return createPaymentMethod; 
    }

    public static APXT_Redlining__Clause__c createClause(String text, String clauseName, APXT_Redlining__Clause_Type__c clauseType) {
        APXT_Redlining__Clause__c clauseReturn = new APXT_Redlining__Clause__c(
            Name = clauseName,
            APXT_Redlining__Clause_Type__c = clauseType.id,
            APXT_Redlining__Text__c = text
        );
        return clauseReturn;
    }

    public static APXT_Redlining__Clause_Type__c createClauseType(String clauseTypeName) {
        APXT_Redlining__Clause_Type__c clauseTypeReturn = new APXT_Redlining__Clause_Type__c(
            Name = clauseTypeName
        );
        return clauseTypeReturn;
    }
    public static List<AccountTeamMember> createAccountTeamMember(Id accountId, List<string> teamRoleList, List<Id> userListId){
        List<AccountTeamMember> teamList = new List<AccountTeamMember>();
            for (Integer i = 0; i < teamRoleList.size(); i++) {
            AccountTeamMember newTeam = new AccountTeamMember(
                AccountId = accountId,
                TeamMemberRole = teamRoleList[i], 
                UserId = userListId[i]);
            teamList.add(newTeam);
            }
        return teamList;
    }

    public static List<Co_op_Program__c> coopPrograms() {
        List<String> coopOEMs = new List<String>{'Audi', 'BMW', 'Chevrolet', 'Chrysler', 'Dodge', 'GMC'};
        List<Co_op_Program__c> coopReturn = new List<Co_op_Program__c>();
        for(String s : coopOEMs) {
            Co_op_Program__c newCoop = new Co_op_Program__c(Name = s);
            coopReturn.add(newCoop);
        }
        return coopReturn;
    }
    
    public static List<Offer__c> createOffer(Integer numberoffers, List<Account> accounts){
        List<Offer__c> OList = new List<Offer__c>();
        
                 for(Integer i = 0; i < numberoffers; i++){
		
            OList.add(new Offer__c(Offer_ID__c= '12345',
                                  Offer_Accepted_Date__c= System.today(),
                                   Offer_Expiration_Date__c = System.today().addMonths(3),
  								   NewStage__c='DOCS_SUBMITTED',
                                  Person_Account__c= accounts[i].Id));
        }
        
        
        return OList;
    }

}