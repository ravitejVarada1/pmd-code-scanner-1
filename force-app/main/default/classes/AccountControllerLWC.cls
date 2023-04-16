/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*   https://cargurus.atlassian.net/browse/BR-325
*   Dealer Account Statistics - Lightening Web Component
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Alexander Mitul
* @created        01/04/2021
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public with sharing class AccountControllerLWC {
	//static constants
	public static final string STRDENIED='DENIED';
    public static final string STRDEALERACC='Dealer Account';
    
    //Return more than one Inventory related Information to Group & Current Account
    @AuraEnabled(cacheable=true)
    public static List<DealerStatsWrapper> getDealerDetails(String accId) {
       
        //Created list to assign more than one Inventory Information
        List<DealerStatsWrapper> dealerStatsWrapperLst=new List<DealerStatsWrapper>();      
        DealerStatsWrapper dealerStatsWrapper = new DealerStatsWrapper();
        
        String parentAccountId='';
        
        List<Service_Provider__c> serviceProviderList = new List<Service_Provider__c>();
        Boolean isDealerAccount = false;
        //Querying Account and related Service Provider details by using Current Account Id
        for(Account a:[SELECT Id,Name,Parentid,RecordType.Name,
                        (SELECT Id,Total_New_Inventory_Units__c,Total_Used_Inventory_Units__c,Account__r.Recordtype.Name 
                         FROM Service_Provider__r
                         WHERE reviewStatus__c!=: STRDENIED)
                         FROM Account 
                         WHERE Id=:accId LIMIT 1]){

            dealerStatsWrapper.acc = a.Id;
            //Identifying whether it is Current/Group Account using ParentId field                  
            if (a.Parentid != null) {
                dealerStatsWrapper.isParent = true;
                ParentAccountId=a.Parentid;
             } 
             else 
             {
                parentAccountId=a.Id;
            if (a.RecordType.Name == STRDEALERACC){isDealerAccount = true;}
            }
            //Assigning Account related Service Provider records into List
            if (!a.Service_Provider__r.isEmpty()) {
                serviceProviderList = a.Service_Provider__r;
            }
        }
        
        if (!serviceProviderList.isEmpty() && (dealerStatsWrapper.isParent || isDealerAccount)){
           for (Service_Provider__c sp: serviceProviderList) {
                //Aggregating New & Used Inventory Information on the individual account
               if (sp.Total_New_Inventory_Units__c != null){                   
                   if (isDealerAccount){
                       dealerStatsWrapper.aggregateAccountNewInventory += sp.Total_New_Inventory_Units__c;
                   }
                   else
                   {
                       dealerStatsWrapper.individualAccountNewInventory += sp.Total_New_Inventory_Units__c;
                   }
               }                
               if (sp.Total_Used_Inventory_Units__c != null){
                   if (isDealerAccount){
                       dealerStatsWrapper.aggregateAccountUsedInventory += sp.Total_Used_Inventory_Units__c;
                   }
                   else
                   {
                       dealerStatsWrapper.individualAccountUsedInventory += sp.Total_Used_Inventory_Units__c;
                   }                   
               }                
            }
        }

        //Querying New & Used Inventory related to Group Account
        for(Service_Provider__c sp : [SELECT Id,Name,Total_New_Inventory_Units__c,Total_Used_Inventory_Units__c 
                                    FROM Service_Provider__c
                                    WHERE Account__r.ParentId =: parentAccountId 
                                    AND reviewStatus__c !=: STRDENIED]) {	

            //Aggregating New & Used Inventory Information on the group account                        
            if (sp.Total_New_Inventory_Units__c != null)
            dealerStatsWrapper.aggregateAccountNewInventory += sp.Total_New_Inventory_Units__c;

            if (sp.Total_Used_Inventory_Units__c != null)
            dealerStatsWrapper.aggregateAccountUsedInventory += sp.Total_Used_Inventory_Units__c;
        }

        dealerStatsWrapperLst.add(dealerStatsWrapper);
        return dealerStatsWrapperLst;
    }
    
    //Returns DealerLeadMetrics wrapper class for 30 & 90 days Lead Metrics from Service Provider
    @AuraEnabled(cacheable=true)
    public static List<DealerLeadMetrics> getDealerLeadMetrics(String accId) {
        
        List<DealerLeadMetrics> leadMetricList = new List<DealerLeadMetrics>();
        DealerLeadMetrics dealerLeadMetrics = new DealerLeadMetrics();
       
        List<Service_Provider__c> serviceProviderList = new List<Service_Provider__c>();
        
        //Querying Account related Service Provider records to calculate 30 days & 90 days Lead Metrics
        for(Account a : [SELECT Id,Name,ParentId,RecordType.Name,
                        (SELECT Id,Name,Account__c,
                                    X30_Day_Lead_Volume_Email_Unique__c ,X30_Day_Lead_Volume_Phone_Unique__c,
                                    X30_Day_Lead_Volume_SMS_Unique__c ,X30_Day_Lead_Volume_Web_Clicks_Total__c,
                                    X90_Day_Lead_Vol_Current_Email_c__c,X90_Day_Lead_Vol_Current_Phone__c,
                                    X90_Day_Lead_Vol_Current_SMS__c,X90_Day_Lead_Vol_Current_Web_Clicks__c,
                                    Account__r.Name,Account__r.ParentId
                                    FROM Service_Provider__r 
                                    WHERE reviewStatus__c!=: STRDENIED)
                         			FROM Account 
                       				WHERE Id=:accId LIMIT 1]) {
                 
            if (a.Parentid == null && a.RecordType.Name != STRDEALERACC)
                return null;       

            if (!a.Service_Provider__r.isEmpty())
                serviceProviderList = a.Service_Provider__r;
        }

        if (!serviceProviderList.isEmpty())  {
            for (Service_Provider__c sp:serviceProviderList) {                           
                //Calculate 30 days Email count
                if (sp.X30_Day_Lead_Volume_Email_Unique__c  != null) {
                dealerLeadMetrics.email30 += sp.X30_Day_Lead_Volume_Email_Unique__c ;                            
                }
                //Calculate 90 days Email count
                if (sp.X90_Day_Lead_Vol_Current_Email_c__c != null) {
                dealerLeadMetrics.email90 += sp.X90_Day_Lead_Vol_Current_Email_c__c;                            
                }
                //Calculate 30 days Phone count
                if (sp.X30_Day_Lead_Volume_Phone_Unique__c  != null) {
                dealerLeadMetrics.phone30 += sp.X30_Day_Lead_Volume_Phone_Unique__c ;                            
                }
                //Calculate 90 days Phone count
                if (sp.X90_Day_Lead_Vol_Current_Phone__c != null) {
                dealerLeadMetrics.phone90 += sp.X90_Day_Lead_Vol_Current_Phone__c;                            
                }
                //Calculate 30 days SMS count                            
                if (sp.X30_Day_Lead_Volume_SMS_Unique__c  != null) {
                dealerLeadMetrics.sms30 += sp.X30_Day_Lead_Volume_SMS_Unique__c ;                            
                }
                //Calculate 90 days SMS count
                if (sp.X90_Day_Lead_Vol_Current_SMS__c != null) {
                dealerLeadMetrics.sms90 += sp.X90_Day_Lead_Vol_Current_SMS__c;                            
                }
                //Calculate 30 days Web Click count
                if (sp.X30_Day_Lead_Volume_Web_Clicks_Total__c != null) {
                dealerLeadMetrics.webClick30 += sp.X30_Day_Lead_Volume_Web_Clicks_Total__c;                            
                }
                //Calculate 90 days Web Click count 
                if (sp.X90_Day_Lead_Vol_Current_Web_Clicks__c != null) {
                dealerLeadMetrics.webClick90 += sp.X90_Day_Lead_Vol_Current_Web_Clicks__c;  
                }
            }
        }

        leadMetricList.add(dealerLeadMetrics);
        return leadMetricList;
    }
    //Wrapper class created to store Current and Group Account related Service Provider New & Used Inventory
    public class DealerStatsWrapper{
        @AuraEnabled public String acc {get; set;}
        @AuraEnabled public boolean isParent {get; set;}
        @AuraEnabled public decimal individualAccountNewInventory {get; set;}
        @AuraEnabled public decimal individualAccountUsedInventory {get; set;}
        @AuraEnabled public decimal aggregateAccountNewInventory {get; set;}
        @AuraEnabled public decimal aggregateAccountUsedInventory {get; set;}
        
        public DealerStatsWrapper() {
            this.individualAccountNewInventory = 0;
            this.individualAccountUsedInventory = 0;
            this.aggregateAccountNewInventory = 0;
            this.aggregateAccountUsedInventory = 0;
            this.isParent = false;
        }
    }
    //Wrapper class created to Store Current and Group Account related
    // Service Provider Lead Metrics for 30 days & 90 days
    public class DealerLeadMetrics{
        @AuraEnabled public String accId {get; set;}
        @AuraEnabled public decimal email30 {get; set;}
        @AuraEnabled public decimal phone30 {get; set;}
        @AuraEnabled public decimal webClick30 {get; set;}
        @AuraEnabled public decimal sms30 {get; set;}  
        @AuraEnabled public decimal email90 {get; set;}
        @AuraEnabled public decimal phone90 {get; set;}
        @AuraEnabled public decimal webClick90 {get; set;}
        @AuraEnabled public decimal sms90 {get; set;}
        
        public DealerLeadMetrics() {
            this.email30 = 0;
            this.phone30 = 0;
            this.webClick30 = 0; 
            this.sms30 = 0;
            this.email90 = 0;
            this.phone90 = 0;
            this.webClick90 = 0;
            this.sms90 = 0;
        }
    }
}