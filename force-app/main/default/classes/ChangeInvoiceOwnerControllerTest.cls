/**
* Test class for ChangeInvoiceOwnerControllerTest
* @author 	Ramiro Alvarez
* @date 	  11/03/2021
* @module   BR-3733
*/

@isTest
private class ChangeInvoiceOwnerControllerTest {

    @TestSetup
    static void makeData(){
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Active';
        insert accts;

        //Create contact
        Contact tstContact = new Contact(AccountId=accts[0].Id, 
            FirstName='fname1', LastName='lname1', Email='test1@cargurus.com');
        insert tstContact;

        Product2[] products = TestDataFactory.createProducts(2);
        products[0].Name = 'CG Base Bundle';
        products[0].ProductCode = 'CG-BASE';
        products[1].Name = 'Enhanced';
        products[1].Family = 'Listings';
        products[1].product_category__c = 'Core Products';

        insert products;

        // initialize Zuora Billing Accounts
        Zuora__CustomerAccount__c zAccount = new Zuora__CustomerAccount__c(Name='Test BA1', Zuora__Status__c = 'Active', 
            Zuora__Zuora_Id__c ='zuorabilling1', Zuora__Account__c = accts[0].Id, 
            Zuora__BillToWorkEmail__c = tstContact.Email, Zuora__SoldToWorkEmail__c = tstContact.Email);
        insert zAccount;

        //Create Zuora Subscriptions
        Date subStartDate = Date.today().addMonths(-8);

        Zuora__Subscription__c zs = new Zuora__Subscription__c(Name = 'A-S0001', Zuora__Account__c = zAccount.Zuora__Account__c, 
                    Zuora__CustomerAccount__c = zAccount.Id, Zuora__SubscriptionNumber__c = '0001', 
                    Zuora__SubscriptionStartDate__c = subStartDate, Zuora__ServiceActivationDate__c = subStartDate,
                	Zuora__InvoiceOwner__c = zAccount.Id, Zuora__Status__c = 'Active', 
                    Zuora__SubscriptionEndDate__c = subStartDate.addMonths(12), Zuora__External_Id__c = 'zuorasub1',
                    Zuora__InitialTerm__c = '100 Days', Zuora__AutoRenew__c = true);
        insert zs;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 2);
        opps[1].RecordTypeId = Utilities.getrecordTypeId('Opportunity', 'Retention');
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        insert quotes;        

        Id pricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pricebookId, Product2Id = products[0].Id, UnitPrice = 1020, IsActive = true);
        insert pbe;

        SBQQ__QuoteLine__c[] quoteLines = new List<SBQQ__QuoteLine__c>{
            new SBQQ__QuoteLine__c(
                Fulfillment_Account__c = accts[0].Id,
                SBQQ__Product__c = products[0].Id,
                SBQQ__Quote__c = quotes[0].Id,
                SBQQ__Quantity__c = 1)
        };
        insert quoteLines;
        
        Contract contr = TestDataFactory.createContract(accts[0].Id);
        insert contr;        

        SBQQ__Subscription__c[] subs = TestDataFactory.createCPQSubsForProducts(products, accts[0].Id);
        for(SBQQ__Subscription__c sub : subs) {
          sub.SBQQ__Contract__c = contr.Id;
          sub.SBQQ__Account__c = accts[0].Id;
        }
        
        subs[1].SBQQ__RequiredById__c = subs[0].Id;
        subs[0].Zuora_Subscription__c = zs.Id;
        subs[0].SBQQ__QuoteLine__c = quoteLines[0].Id;
        subs[0].Billing_Account__c = accts[0].Id;
        insert subs;
    }

    @istest
    public static void getRelatedSubs_test() {

        Test.startTest();

        Contract contract = [SELECT Id FROM Contract LIMIT 1];        
        List<SBQQ__Subscription__c> relatedSub = ChangeInvoiceOwnerController.getRelatedSubs(contract.Id);

        Test.stopTest();
        
        System.assertEquals(1,relatedSub.size());

    }

    @istest
    public static void setNewBillingAcc_test() {

        Test.startTest();

        Contract contract = [SELECT Id FROM Contract LIMIT 1];        
        
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Active';
        accts[0].Name = 'New Billing Accout';
        insert accts;

        //Create contact
        Contact tstContact = new Contact(AccountId=accts[0].Id, 
            FirstName='Fame2', LastName='lname2', Email='test2@cargurus.com');
        insert tstContact;

        Zuora__CustomerAccount__c zAccount = new Zuora__CustomerAccount__c(Name='Test 2', Zuora__Status__c = 'Active', 
            Zuora__Zuora_Id__c ='zuorabilling2', Zuora__Account__c = accts[0].Id, 
            Zuora__BillToWorkEmail__c = tstContact.Email, Zuora__SoldToWorkEmail__c = tstContact.Email);
        insert zAccount;

        ChangeInvoiceOwnerController.setBillingAccsOnSubs(contract.Id,accts[0].Id);

        List<SBQQ__Subscription__c> subAfterUpdate = [SELECT Id, Billing_Account__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__QuoteLine__r.SBQQ__ProductCode__c = 'CG-BASE'
            AND Zuora_Subscription__c != NULL];
        
        Test.stopTest();

        System.assertEquals(accts[0].Id, subAfterUpdate[0].Billing_Account__c);        

    }

    @IsTest
    static void checkProfile() {
        Boolean checkProfile = ChangeInvoiceOwnerController.checkUserProfile();
        System.assertEquals(true, checkProfile);
    }

}