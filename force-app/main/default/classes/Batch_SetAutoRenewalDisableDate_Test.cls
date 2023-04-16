/*Set Auto Renewal Disable Date o Contracts|| https://cargurus.atlassian.net/browse/BR-1271
* author:         amitul
* created:        06/01/2021
* modified:       07/26/2021
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class Batch_SetAutoRenewalDisableDate_Test {

    @testsetup static void testData() {
        List<Account> testAccs = TestDataFactory.createAccounts(1);
        testAccs[0].Renewal_Eligible__c = true;
        insert testAccs[0];

        List<Zuora__CustomerAccount__c>  billingAccount = TestDataFactory.createZuoraAccount(1, testAccs[0]);
        billingAccount[0].Zuora__DefaultPaymentMethod__c='CreditCard';
        insert billingAccount;

        List<Zuora__PaymentMethod__c> paymentMethod = TestDataFactory.createPaymentMethod(1, billingAccount[0]);
        insert paymentMethod;

        billingAccount[0].Zuora__Default_Payment_Method__c=paymentMethod[0].Id;
        update billingAccount;

        List<Account> fullAccs = TestDataFactory.createAccounts(1);
        fullAccs[0].Renewal_Eligible__c = true;
        fullAccs[0].Billing_Account_Zuora__c = billingAccount[0].Id;
        insert fullAccs;

        List<Opportunity> opps = TestDataFactory.createOpps(testAccs[0].Id,1);
        Id RECORDTYPEID = utilities.getRecordTypeId('opportunity','Renewal');
        for(Opportunity opp : opps){
            opp.RecordTypeId = RECORDTYPEID;
            opp.Auto_Close_Date__c = Date.today().addDays(3);
        }
     
        insert opps;
        
        List<Product2> products = TestDataFactory.createProducts(1);
        products[0].ProductCode = 'CG-BASE';
        insert products;
       
        Date firstDayOfMonth = System.today().addMonths(1).toStartOfMonth();
        Date lastDayOfMonth = firstDayOfMonth.addDays(Date.daysInMonth(firstDayOfMonth.year(), firstDayOfMonth.month())-1);
        List<SBQQ__Quote__c> quote =TestDataFactory.createQuotes(testAccs[0].Id,opps[0].Id, 1);
        quote[0].Payment_Method__c='ACH';
        quote[0].Initial_Term_End_Date__c = lastDayOfMonth;
        insert quote[0];
        
        Contract con = TestDataFactory.createContract(testAccs[0].Id);
        con.ContractTerm =1;
        con.StartDate=firstDayOfMonth;
        con.EndDate=lastDayOfMonth;
        con.SBQQ__Quote__c=quote[0].Id;
        insert con;
        
        List<Zuora__Subscription__c> zsubs = TestDataFactory.createZSubscriptions(testAccs[0].Id, 1);
        zsubs[0].Zuora__AutoRenew__c = true;
        insert zsubs;
        
        List<SBQQ__Subscription__c> subs = TestDataFactory.createCPQSubsForProducts(products, testAccs[0].Id);
        subs[0].Zuora_Subscription__c = zsubs[0].Id;
        subs[0].SBQQ__Contract__c =  con.Id;
        subs[0].Provisioning_Status__c = 'Activated';
        subs[0].Fulfillment_Account__c = fullAccs[0].Id;
        subs[0].Billing_Account__c =fullAccs[0].Id;
        subs[0].SBQQ__SubscriptionStartDate__c = con.StartDate;
        subs[0].SBQQ__SubscriptionEndDate__c = con.EndDate;
        insert subs;
         
    }
    
    static testMethod void setAutoRenewalDisableDateForAutoPaymentTest() {

        Zuora__CustomerAccount__c zpay = [SELECT Id, Zuora__DefaultPaymentMethod__c FROM Zuora__CustomerAccount__c limit 1];
        zpay.Zuora__DefaultPaymentMethod__c='CreditCard';
        update zpay;
        
        Test.startTest();
        SBQQ.TriggerControl.disable();
        Database.executeBatch(new Batch_SetAutoRenewalDisableDate());
        Test.stopTest();
	    Contract con = [SELECT Id,Auto_Renewal_Disable_Date__c FROM Contract Limit 1];
        System.assertEquals(System.today().AddMonths(1).toStartOfMonth().addDays(1), con.Auto_Renewal_Disable_Date__c);

    } 
    
    static testMethod void setAutoRenewalDisableDateForNonAutoPaymentTest() {
        Zuora__CustomerAccount__c zpay = [SELECT Id, Zuora__DefaultPaymentMethod__c FROM Zuora__CustomerAccount__c limit 1];
        zpay.Zuora__DefaultPaymentMethod__c='Check';
        update zpay;

        Test.startTest();
        SBQQ.TriggerControl.disable();
        Database.executeBatch(new Batch_SetAutoRenewalDisableDate());
        Test.stopTest(); 
        Contract con = [SELECT Id,Auto_Renewal_Disable_Date__c FROM Contract Limit 1];
        System.assertEquals(System.today(), con.Auto_Renewal_Disable_Date__c);
		 
    } 
    static testMethod void setAutoRenewalDisableDateForNullTest() {

        Zuora__CustomerAccount__c zca = [Select Id,Zuora__DefaultPaymentMethod__c from Zuora__CustomerAccount__c limit 1 ];
        zca.Zuora__DefaultPaymentMethod__c='';
        update zca;
        
        Test.startTest();
        SBQQ.TriggerControl.disable();
        Database.executeBatch(new Batch_SetAutoRenewalDisableDate());
        Test.stopTest();
        Contract con = [SELECT Id,Auto_Renewal_Disable_Date__c FROM Contract Limit 1];
        System.assertEquals(null, con.Auto_Renewal_Disable_Date__c);
		 
    } 

}