@IsTest
private class Batch_MassAmendOpportunityTest {

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
              
      
    }

    static testMethod void CheckBatchMassAmendOpps() {
      
        List<Contract> contractList = [Select Id From contract Limit 1];   
        Test.startTest();
        database.executeBatch(new Batch_MassAmendOpportunity(new list<Id>{contractList[0].Id}), 1);
        Test.stopTest();
    }
    
}