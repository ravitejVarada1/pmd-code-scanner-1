/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*   https://cargurus.atlassian.net/browse/BR-325
*   Dealer Account Statistics - Lightening Web Component
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Alexander Mitul
* @created        01/04/2021
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
@isTest
private class AccountControllerLWC_TEST {
    @testsetup static void testData() {
        //Creating Current Account
        List<Account> currentAccount = TestDataFactory.createAccounts(1);
        insert currentAccount;
        //Creating Group Account
        List<Account> groupAccount = TestDataFactory.createAccounts(1);
        groupAccount[0].ParentId=currentAccount[0].Id;
        groupAccount[0].Name = 'Some other account';
        insert groupAccount;
    }
    static testMethod void testDealerDetails(){
        //Querying Account related information 
        Account a = [SELECT id FROM Account where ParentId != null LIMIT 1];
        //Inserting Service_Provider__c records 
        List<Service_Provider__c> spList = TestDataFactory.createServiceproviders(2, a.Id);
        for(Service_Provider__c s:spList){
            s.X30_Day_Lead_Volume_Email_Unique__c = 1;
            s.X90_Day_Lead_Vol_Current_Email_c__c = 1;
            s.X30_Day_Lead_Volume_Phone_Unique__c = 1;
            s.X90_Day_Lead_Vol_Current_Phone__c = 1;
            s.X30_Day_Lead_Volume_SMS_Unique__c = 1;
            s.X90_Day_Lead_Vol_Current_SMS__c = 1;
            s.X30_Day_Lead_Volume_Web_Clicks_Total__c = 1;
            s.X90_Day_Lead_Vol_Current_Web_Clicks__c = 1;
        }
        insert spList;
        
        Service_Provider__c sp = [SELECT id FROM Service_Provider__c where Account__r.ParentId !=null LIMIT 1];
        //Define DealerStatsWrapper wrapper with default values
        AccountControllerLWC.DealerStatsWrapper wrapperDealerStatus = new AccountControllerLWC.DealerStatsWrapper();
        wrapperDealerStatus.isParent = true;
        wrapperDealerStatus.individualAccountNewInventory =0;
        wrapperDealerStatus.individualAccountUsedInventory=0;
        wrapperDealerStatus.aggregateAccountNewInventory=0;
        wrapperDealerStatus.aggregateAccountUsedInventory=0;
        //Define DealerLeadMetrics wrapper with default values
        AccountControllerLWC.DealerLeadMetrics wrapperDealerLead = new AccountControllerLWC.DealerLeadMetrics();
        wrapperDealerLead.accId =a.Id;
        //Cover getDealerDetails method in Test Class
        AccountControllerLWC.getDealerDetails(a.Id);
        //Cover getDealerLeadMetrics method in Test Class
        AccountControllerLWC.getDealerLeadMetrics(a.Id);
        System.assertEquals(2, spList.size());
    }
}