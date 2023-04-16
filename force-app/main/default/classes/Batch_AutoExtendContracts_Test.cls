/*Batch process to Auto extend CPQ Contracts|| https://cargurus.atlassian.net/browse/BR-1269
* author:         amitul
* created:        06/07/2021
* modified:       08/17/2021
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class Batch_AutoExtendContracts_Test {

   @testsetup static void testData() {
        List<Account> testAccs = TestDataFactory.createAccounts(1);
        testAccs[0].Renewal_Eligible__c = false;
        insert testAccs[0];
        
        List<Zuora__CustomerAccount__c>  billingAccount = TestDataFactory.createZuoraAccount(1, testAccs[0]);
        billingAccount[0].Zuora__DefaultPaymentMethod__c='CreditCard';
        insert billingAccount;

        List<Zuora__PaymentMethod__c> paymentMethod = TestDataFactory.createPaymentMethod(1, billingAccount[0]);
        insert paymentMethod;

        billingAccount[0].Zuora__Default_Payment_Method__c=paymentMethod[0].Id;
        update billingAccount;

        List<Account> fullAccs = TestDataFactory.createAccounts(1);
        fullAccs[0].Renewal_Eligible__c = false;
        fullAccs[0].Billing_Account_Zuora__c = billingAccount[0].Id;
        insert fullAccs;

        List<Opportunity> opps = TestDataFactory.createOpps(testAccs[0].Id,1);
        Id RECORDTYPEID = utilities.getRecordTypeId('opportunity','Standard_Opportunity');
        for(Opportunity opp : opps){
            opp.RecordTypeId = RECORDTYPEID;
            opp.Auto_Close_Date__c = Date.today().addDays(3);
        }
     
        insert opps;
        
        List<Product2> products = TestDataFactory.createProducts(1);
        products[0].ProductCode = 'CG-BASE';
        insert products;
       
        Date firstDayOfMonth = System.today().toStartOfMonth();
        Date lastDayOfMonth = firstDayOfMonth.addDays(Date.daysInMonth(firstDayOfMonth.year(), firstDayOfMonth.month())-1);
         
        List<SBQQ__Quote__c> quote =TestDataFactory.createQuotes(testAccs[0].Id,opps[0].Id, 1);
        insert quote[0];
        
        Contract con = TestDataFactory.createContract(testAccs[0].Id);
        con.EndDate = lastDayOfMonth;
        con.SBQQ__Quote__c=quote[0].Id;
        insert con;
        con.status= 'Activated';
        Update con;
              
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

    static testMethod void setAutoExtendContractsForAutoPaymentTest() {
        
        Zuora__CustomerAccount__c zpay = [SELECT Id, Zuora__DefaultPaymentMethod__c FROM Zuora__CustomerAccount__c limit 1];
        zpay.Zuora__DefaultPaymentMethod__c='CreditCard';
        update zpay;
        Contract con1 = [SELECT Id,EndDate FROM Contract Limit 1];
        Test.startTest();
        Database.executeBatch(new Batch_AutoExtendContracts(false,false,false));
        Test.stopTest();
        Contract con = [SELECT Id,EndDate FROM Contract Limit 1];
        
        Date firstDayOftheExtendedMonth = con1.EndDate.addMonths(1).toStartOfMonth();
        Date lastDayOfMonth = firstDayOftheExtendedMonth.addDays(Date.daysInMonth(firstDayOftheExtendedMonth.year(), firstDayOftheExtendedMonth.month())-1);
        System.assertEquals(lastDayOfMonth, con.EndDate);
    } 
    
    static testMethod void setAutoExtendContractsForNonAutoPaymentTest() {
        Zuora__CustomerAccount__c zpay = [SELECT Id, Zuora__DefaultPaymentMethod__c FROM Zuora__CustomerAccount__c limit 1];
        zpay.Zuora__DefaultPaymentMethod__c='Check';
        update zpay;
        Test.startTest();
        Contract con1 = [SELECT Id,EndDate FROM Contract Limit 1];

        Database.executeBatch(new Batch_AutoExtendContracts(false,false,false));
        Test.stopTest(); 
        Contract con = [SELECT Id,EndDate FROM Contract Limit 1];
        Date firstDayOftheExtendedMonth = con1.EndDate.addMonths(1).toStartOfMonth();
        Date lastDayOfMonth = firstDayOftheExtendedMonth.addDays(Date.daysInMonth(firstDayOftheExtendedMonth.year(), firstDayOftheExtendedMonth.month())-1);
        System.assertEquals(lastDayOfMonth, con.EndDate);
    } 

    static testMethod void setAutoExtendContractsForCancelledContractsTest() {
        
        Zuora__CustomerAccount__c zpay = [SELECT Id, Zuora__DefaultPaymentMethod__c FROM Zuora__CustomerAccount__c limit 1];
        zpay.Zuora__DefaultPaymentMethod__c='CreditCard';
        update zpay;
        Contract con1 = [SELECT Id,EndDate,Status FROM Contract Limit 1];
        con1.Status = 'Cancelled';
        update con1;
        Test.startTest();
        Database.executeBatch(new Batch_AutoExtendContracts(false,false,false));
        Test.stopTest();
        Contract processedCon = [SELECT Id,EndDate FROM Contract Limit 1];
        
        System.assertEquals(con1.EndDate, processedCon.EndDate);
    } 
    

}