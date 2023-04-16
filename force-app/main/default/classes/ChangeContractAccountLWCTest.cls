/**
* Test class for ChangeInvoiceOwnerControllerTest
* @author   Navdeep Singh
* @date     31/08/2021
* @module   SA-142
*/

@isTest
private class ChangeContractAccountLWCTest {

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
        
        Contract contr = TestDataFactory.createContract(accts[0].Id);
        insert contr;

        Opportunity[] opps = TestDataFactory.createOpps(accts[0].Id, 2);
        opps[1].RecordTypeId = Utilities.getrecordTypeId('Opportunity', 'Retention');
        opps[1].Retention_Contract__c = contr.Id;
        opps[1].SBQQ__AmendedContract__c = contr.Id;
        opps[1].SBQQ__RenewedContract__c = contr.Id;
        insert opps;

        SBQQ__Quote__c[] quotes = TestDataFactory.createQuotes(accts[0].Id, opps[0].Id, 1);
        quotes[0].SBQQ__MasterContract__c = contr.Id;
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
    public static void setNewAccount_test() {

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

        Test.startTest();
        ChangeContractAccountLWC.processAccountUpdate(contract.Id,accts[0].Id);
        Test.stopTest();
    }

    @istest
    public static void setNewAccount_test2() {

        Contract contract = [SELECT Id,AccountId FROM Contract LIMIT 1];        
        
        Account[] accts = TestDataFactory.createAccounts(1);
        accts[0].Product_Activation_Status__c = 'Active';
        accts[0].Name = 'New Billing Accout';
        insert accts;

        //Create contact
        Contact tstContact = new Contact(AccountId=accts[0].Id, 
            FirstName='Fame2', LastName='lname2', Email='test2@cargurus.com');
        insert tstContact;

        Blob bodyBlob=Blob.valueOf('Unit Test ContentVersion Body'); 
        ContentVersion contentVersion_1 = new ContentVersion(
            Title='Header_Picture1', 
            PathOnClient ='/Header_Picture1.jpg',
            VersionData = bodyBlob, 
            origin = 'H'
        );
        insert contentVersion_1;

        ContentVersion contentVersion_2 = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion_1.Id LIMIT 1];

        ContentDocumentLink contentlink = new ContentDocumentLink();
        contentlink.LinkedEntityId = contract.Id;
        contentlink.contentdocumentid = contentVersion_2.contentdocumentid;
        contentlink.ShareType = 'V';
        insert contentlink;

        Test.startTest();
        ChangeContractAccountLWC.processAccountUpdate(contract.Id,accts[0].Id);
        Test.stopTest();
    }

}