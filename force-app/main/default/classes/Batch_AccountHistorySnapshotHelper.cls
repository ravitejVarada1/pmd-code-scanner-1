/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ngoldy
* created:        06/11/2021
* modified:       06/11/2021
* created jira:   BR-2045
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
global class Batch_AccountHistorySnapshotHelper {

  private static final String[] spTextFields = new List<String>{
    //'Account__c', already populated
    'Account__r.BillingCountryCode',
    'Account__r.Account_Category_Formula__c',
    'Account__r.Name',
    'Account__r.OwnerId',
    'Account__r.CurrencyIsoCode',
    'Inventory_Source__c',
    'Account__r.Product_Activation_Status__c',
    'Account__r.Owner.Title'
  };

  private static final String[] spFixedNumberFields = new List<String>{
    'X30_Day_Ad_Clicks__c',
    'X30_Day_Lead_Volume_Chat_Total__c',
    'X30_Day_Lead_Volume_Chat_Unique__c',
    'X30_Day_Lead_Volume_Map_Views_Total__c',
    'X30_Day_Lead_Volume_Email_Total__c',
    'X30_Day_Lead_Volume_Email_Unique__c',
    'X30_Day_Lead_Volume_Phone_Total__c',
    'X30_Day_Lead_Volume_Phone_Unique__c',
    'X30_Day_Lead_Volume_SMS_Total__c',
    'X30_Day_Lead_Volume_SMS_Unique__c',
    'X30_Day_Lead_Volume_Total_Total__c',
    'X30_Day_Lead_Volume_Web_Clicks_Total__c',
    'X30_Day_Matching_Ad_Impressions__c',
    // 'X30_Day_Reviews__c',
    'X30_Day_SRP_Volume__c',
    'X30_Day_VDP_Volume__c',
    'X90_Day_Lead_Vol_Current_Chat__c',
    'X90_Day_Lead_Vol_Current_Email_c__c',
    'X90_Day_Lead_Vol_Current_Phone__c',
    'X90_Day_Lead_Vol_Current_SMS__c',
    'X90_Day_Lead_Vol_Current_Total__c',
    'Dashboard_Logins_Last_30_Days__c',
    'New_Cars_Fair_Qty__c',
    'New_Cars_Good_Qty__c',
    'New_Cars_Great_Qty__c',
    'New_Cars_High_Qty__c',
    'New_Cars_Missing_Photos_Qty__c',
    'New_Cars_Missing_Price_Qty__c',
    'New_Cars_Missing_Trim_Qty__c',
    'New_Cars_Missing_Trim_Opts_Qty__c',
    'New_Cars_No_Analysis_Qty__c',
    'New_Cars_Outliers_Qty__c',
    'New_Cars_Overpriced_Qty__c',
    'Total_New_Inventory_Units__c',
    'Total_Used_Inventory_Units__c',
    'Used_Cars_Fair_Qty__c',
    'Used_Cars_Good_Qty__c',
    'Used_Cars_Great_Qty__c',
    'Used_Cars_High_Qty__c',
    'Used_Cars_Missing_Photos_Qty__c',
    'Used_Cars_Missing_Price_Qty__c',
    'Used_Cars_Missing_Trim_Qty__c',
    'Used_Cars_Missing_Trim_Opts_Qty__c',
    'Used_Cars_No_Analysis_Qty__c',
    'Used_Cars_Outliers_Qty__c',
    'Used_Cars_Overpriced_Qty__c'
  };

  // mappings: SP field to AHS field
  private static Map<String,String> getMappings() {
    return new Map<String,String>{
      //'Account__c' => 'Account__c',
      'Account__r.BillingCountryCode' => 'Account_Billing_Country_Code__c',
      'Account__r.Account_Category_Formula__c' => 'Account_Category_formula__c',
      'Account__r.Name' => 'Account_Name_At_Snapshot__c',
      'Account__r.OwnerId' => 'Account_Owner__c',
      'Account__r.Owner.Email' => 'Account_Owner_Email__c',
      'Account__r.CurrencyIsoCode' => 'CurrencyIsoCode',
      'Inventory_Source__c' => 'Inventory_Source__c',
      'Account__r.Owner.Title' => 'Owner_Role__c',
      'Account__r.Product_Activation_Status__c' => 'Product_Activation_Status__c',
      'X30_Day_Ad_Clicks__c' => 'X30_Day_Ad_Clicks__c',
      'X30_Day_Lead_Volume_Chat_Total__c' => 'X30_Day_Lead_Volume_Chat_Total__c',
      'X30_Day_Lead_Volume_Chat_Unique__c' => 'X30_Day_Lead_Volume_Chat__c',
      'X30_Day_Lead_Volume_Map_Views_Total__c' => 'X30_Day_Lead_Volume_Map_Views_Total__c',
      'X30_Day_Lead_Volume_Email_Total__c' => 'X30_Day_Lead_Volume_Online_Total__c',
      'X30_Day_Lead_Volume_Email_Unique__c' => 'X30_Day_Lead_Volume_Online__c',
      'X30_Day_Lead_Volume_Phone_Total__c' => 'X30_Day_Lead_Volume_Phone_Total__c',
      'X30_Day_Lead_Volume_Phone_Unique__c' => 'X30_Day_Lead_Volume_Phone__c',
      'X30_Day_Lead_Volume_SMS_Total__c' => 'X30_Day_Lead_Volume_SMS_Total__c',
      'X30_Day_Lead_Volume_SMS_Unique__c' => 'X30_Day_Lead_Volume_SMS__c',
      'X30_Day_Lead_Volume_Total_Total__c' => 'X30_Day_Lead_Volume_Total_Total__c',
      'X30_Day_Lead_Volume_Web_Clicks_Total__c' => 'X30_Day_Lead_Volume_Web_Clicks_Total__c',
      'X30_Day_Matching_Ad_Impressions__c' => 'X30_Day_Matching_Ad_Impressions__c',
      'X30_Day_Reviews__c' => 'X30_Day_Reviews__c',
      'X30_Day_SRP_Volume__c' => 'X30_Day_SRP_Volume__c',
      'X30_Day_VDP_Volume__c' => 'X30_Day_VDP_Volume__c',
      'X90_Day_Lead_Vol_Current_Chat__c' => 'X90_Day_Lead_Vol_Current_Chat__c',
      'X90_Day_Lead_Vol_Current_Email_c__c' => 'X90_Day_Lead_Vol_Current_Online__c',
      'X90_Day_Lead_Vol_Current_Phone__c' => 'X90_Day_Lead_Vol_Current_Phone__c',
      'X90_Day_Lead_Vol_Current_SMS__c' => 'X90_Day_Lead_Vol_Current_SMS__c',
      'X90_Day_Lead_Vol_Current_Total__c' => 'X90_Day_Lead_Vol_Current_Total__c',
      'Dashboard_Logins_Last_30_Days__c' => 'Dashboard_Logins_Last_30_Days__c',
      'New_Cars_Fair_Qty__c' => 'New_Cars_Fair_Qty__c',
      'New_Cars_Good_Qty__c' => 'New_Cars_Good_Qty__c',
      'New_Cars_Great_Qty__c' => 'New_Cars_Great_Qty__c',
      'New_Cars_High_Qty__c' => 'New_Cars_High_Qty__c',
      'New_Cars_Missing_Photos_Qty__c' => 'New_Cars_Missing_Photos_Qty__c',
      'New_Cars_Missing_Price_Qty__c' => 'New_Cars_Missing_Price_Qty__c',
      'New_Cars_Missing_Trim_Qty__c' => 'New_Cars_Missing_Trim_Qty__c',
      'New_Cars_Missing_Trim_Opts_Qty__c' => 'New_Cars_Missing_Trim_Opts_Qty__c',
      'New_Cars_No_Analysis_Qty__c' => 'New_Cars_No_Analysis_Qty__c',
      'New_Cars_Outliers_Qty__c' => 'New_Cars_Outliers_Qty__c',
      'New_Cars_Overpriced_Qty__c' => 'New_Cars_Overpriced_Qty__c',
      'Total_New_Inventory_Units__c' => 'Total_New_Inventory_Units__c',
      'Total_Used_Inventory_Units__c' => 'Total_Used_Inventory_Units__c',
      'Used_Cars_Fair_Qty__c' => 'Used_Cars_Fair_Qty__c',
      'Used_Cars_Good_Qty__c' => 'Used_Cars_Good_Qty__c',
      'Used_Cars_Great_Qty__c' => 'Used_Cars_Great_Qty__c',
      'Used_Cars_High_Qty__c' => 'Used_Cars_High_Qty__c',
      'Used_Cars_Missing_Photos_Qty__c' => 'Used_Cars_Missing_Photos_Qty__c',
      'Used_Cars_Missing_Price_Qty__c' => 'Used_Cars_Missing_Price_Qty__c',
      'Used_Cars_Missing_Trim_Qty__c' => 'Used_Cars_Missing_Trim_Qty__c',
      'Used_Cars_Missing_Trim_Opts_Qty__c' => 'Used_Cars_Missing_Trim_Opts_Qty__c',
      'Used_Cars_No_Analysis_Qty__c' => 'Used_Cars_No_Analysis_Qty__c',
      'Used_Cars_Outliers_Qty__c' => 'Used_Cars_Outliers_Qty__c',
      'Used_Cars_Overpriced_Qty__c' => 'Used_Cars_Overpriced_Qty__c'
    };
  }
  
  public static List<Account_History_Snapshot__c> createAccountHistorySnapshotsFromSPs(List<Service_Provider__c> spList, Boolean doInsert) {
    
    Set<Id> accountIds = new Set<Id>();
    Account_History_Snapshot__c[] insAHSList = new List<Account_History_Snapshot__c>();
    Account_History_Snapshot__c[] delAHSList = new List<Account_History_Snapshot__c>();
    // in BR we will build the AHS based off of the sum of each account's SPs - so we build a map to hold that data
    Map<Id,List<Service_Provider__c>> accountToSPsMap = new Map<Id,List<Service_Provider__c>>();
    
    for (Service_Provider__c sp : spList) {
		  accountIds.add(sp.Account__c);
      if(!accountToSPsMap.containsKey(sp.Account__c)) {
        accountToSPsMap.put(sp.Account__c, new List<Service_Provider__c>());
      }
      accountToSPsMap.get(sp.Account__c).add(sp);
    }
    
    Map<Id,Account> accountAHSMap = new Map<Id,Account>(
        [SELECT Id, OwnerId, (SELECT Id, Account__c, Snapshot_Date__c 
          FROM Account_History_Snapshots__r 
          ORDER BY Snapshot_Date__c DESC) 
          FROM Account WHERE Id IN : accountIds]
      );    
    
    for (String accountId : accountIds) {
      Integer snapNum = 0;
      
      Account acc = accountAHSMap.get(accountId);
      Account_History_Snapshot__c[] accountAHSList = new List<Account_History_Snapshot__c>();
      if(acc != null) {
        accountAHSList.addAll(acc.Account_History_Snapshots__r);
      }
      
      for (Account_History_Snapshot__c ahs : accountAHSList) {
        snapNum++;
        if (snapNum > 23) {
          delAHSList.add(ahs);
        }
      }

      Account_History_Snapshot__c newAHS = createAndPopulateAHS(accountId, accountToSPsMap.get(accountId));
      insAHSList.add(newAHS);
    }
	
    if (!insAHSList.isEmpty() && doInsert) {
      insert insAHSList;
    }
    if (!delAHSList.isEmpty()) {
      delete delAHSList;
    }

    return insAHSList;
  }

  private static Account_History_Snapshot__c createAndPopulateAHS(String accountId, List<Service_Provider__c> spsList) {
    Map<String,String> fieldMappings = getMappings();
    Account_History_Snapshot__c newAHS = new Account_History_Snapshot__c(Account__c=accountId);
    newAHS.Name = Utilities.getEndOfLastMonth(date.today());

    for(Service_Provider__c sp : spsList) {
      // populate text fields (as-is)
      for(String textField : spTextFields) {
        String spFieldValue;
        String[] fieldSplit = textField.split('\\.');
        sObject temp = sp;

        if(fieldSplit.size() > 1) {
          // if field in dictionary is like Account__r.Owner.Email, we need to navigate through the relationships
          while(fieldSplit.size() > 1 && temp != null) {
            temp = temp.getsObject(fieldSplit.remove(0));
          }
          // when only one element remains in the split list, it is the final field we want to get
          if(temp != null) {
            spFieldValue = (String)temp.get(fieldSplit[0]);
          }
        }
        else {
          spFieldValue = (String)sp.get(textField);
        }

        if (newAHS.get(fieldMappings.get(textField)) == null) {
          newAHS.put(fieldMappings.get(textField), spFieldValue);
        }
      }

      // populate numeric fields (sum). If null, replace with 0
      for(String numericField : spFixedNumberFields) {
        Decimal spFieldValue = (Decimal)sp.get(numericField);
        spFieldValue = spFieldValue == null ? 0 : spFieldValue;
        Decimal previousAhsFieldValue = (Decimal)newAHS.get(fieldMappings.get(numericField));
        previousAhsFieldValue = previousAhsFieldValue == null ? 0 : previousAhsFieldValue;
        newAHS.put(fieldMappings.get(numericField), previousAhsFieldValue + spFieldValue);
      }

      newAHS.Total_Inventory_Units_All__c = newAHS.Total_New_Inventory_Units__c + newAHS.Total_Used_Inventory_Units__c;
    }
    
    // calculate & populate percentage fields
    newAHS = calculatePercentageFieldValues(newAHS);
    newAHS.Snapshot_Date__c = System.today();

    return newAHS;
  }

  // method to encapsulate the calculation of percentage fields off of field-specific quantities and total quantities
  private static Account_History_Snapshot__c calculatePercentageFieldValues(Account_History_Snapshot__c ahs) {

    ahs.with_Photos_New__c = ahs.Total_New_Inventory_Units__c != 0 ? (ahs.Total_New_Inventory_Units__c - ahs.New_Cars_Missing_Photos_Qty__c) / ahs.Total_New_Inventory_Units__c : 0;
    ahs.with_Pricing_New__c = ahs.Total_New_Inventory_Units__c != 0 ? (ahs.Total_New_Inventory_Units__c -ahs.New_Cars_Missing_Price_Qty__c) / ahs.Total_New_Inventory_Units__c : 0;
    ahs.with_Trim_Options_New__c = ahs.Total_New_Inventory_Units__c != 0 ? (ahs.Total_New_Inventory_Units__c - ahs.New_Cars_Missing_Trim_Opts_Qty__c) / ahs.Total_New_Inventory_Units__c : 0;
    ahs.with_Trims_New__c = ahs.Total_New_Inventory_Units__c != 0 ? (ahs.Total_New_Inventory_Units__c - ahs.New_Cars_Missing_Trim_Qty__c) / ahs.Total_New_Inventory_Units__c : 0;
    ahs.Fair_Deals__c = ahs.Total_New_Inventory_Units__c != 0 ? ahs.New_Cars_Fair_Qty__c / ahs.Total_New_Inventory_Units__c : 0;
    ahs.Good_Deals__c = ahs.Total_New_Inventory_Units__c != 0 ? ahs.New_Cars_Good_Qty__c / ahs.Total_New_Inventory_Units__c : 0;
    ahs.Great_Deals__c = ahs.Total_New_Inventory_Units__c != 0 ? ahs.New_Cars_Great_Qty__c / ahs.Total_New_Inventory_Units__c : 0;
    ahs.High_Price__c = ahs.Total_New_Inventory_Units__c != 0 ? ahs.New_Cars_High_Qty__c / ahs.Total_New_Inventory_Units__c : 0;
    ahs.Cars_Missing_Photos__c = ahs.Total_New_Inventory_Units__c != 0 ? ahs.New_Cars_Missing_Photos_Qty__c / ahs.Total_New_Inventory_Units__c : 0;
    ahs.Cars_Missing_Price__c = ahs.Total_New_Inventory_Units__c != 0 ? ahs.New_Cars_Missing_Price_Qty__c / ahs.Total_New_Inventory_Units__c : 0;
    ahs.Cars_Missing_Trim_Options_New__c = ahs.Total_New_Inventory_Units__c != 0 ? ahs.New_Cars_Missing_Trim_Opts_Qty__c / ahs.Total_New_Inventory_Units__c : 0;
    ahs.Cars_Missing_Trim__c = ahs.Total_New_Inventory_Units__c != 0 ? ahs.New_Cars_Missing_Trim_Qty__c / ahs.Total_New_Inventory_Units__c : 0;
    ahs.No_Price_Analysis__c = ahs.Total_New_Inventory_Units__c != 0 ? ahs.New_Cars_No_Analysis_Qty__c / ahs.Total_New_Inventory_Units__c : 0;
    ahs.Overpriced__c = ahs.Total_New_Inventory_Units__c != 0 ? ahs.New_Cars_Overpriced_Qty__c / ahs.Total_New_Inventory_Units__c : 0;
    ahs.with_Photos_Used__c = ahs.Total_Used_Inventory_Units__c != 0 ? (ahs.Total_Used_Inventory_Units__c - ahs.Used_Cars_Missing_Photos_Qty__c) / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.with_Pricing_Used__c = ahs.Total_Used_Inventory_Units__c != 0 ? (ahs.Total_Used_Inventory_Units__c - ahs.Used_Cars_Missing_Price_Qty__c) / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.with_Trim_Options_Used__c = ahs.Total_Used_Inventory_Units__c != 0 ? (ahs.Total_Used_Inventory_Units__c - ahs.Used_Cars_Missing_Trim_Opts_Qty__c) / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.with_Trims_Used__c = ahs.Total_Used_Inventory_Units__c != 0 ? (ahs.Total_Used_Inventory_Units__c - ahs.Used_Cars_Missing_Trim_Qty__c) / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Used_Car_Pricing_Fair__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_Fair_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Used_Car_Pricing_Good__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_Good_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Used_Car_Pricing_Great__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_Great_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Used_Car_Pricing_High__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_High_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Cars_Missing_Photos_Used__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_Missing_Photos_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Cars_Missing_Price_Used__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_Missing_Price_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Cars_Missing_Trim_Options_Used__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_Missing_Trim_Opts_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Cars_Missing_Trim_Used__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_Missing_Trim_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Used_Car_Pricing_No_Analysis__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_No_Analysis_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Used_Car_Pricing_Outlier__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_Outliers_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;
    ahs.Used_Car_Pricing_Overpriced__c = ahs.Total_Used_Inventory_Units__c != 0 ? ahs.Used_Cars_Overpriced_Qty__c / ahs.Total_Used_Inventory_Units__c : 0;

    return ahs;
  }

  public static Map<String, Listings_Performance_metrics__mdt> getPerformanceMetricsMtd(){
    Map<String, Listings_Performance_metrics__mdt> metricsMetadataMap = new Map<String, Listings_Performance_metrics__mdt>();  
    for(Listings_Performance_metrics__mdt listingPerformanceMetadata : [SELECT Id, Label, DeveloperName, 
                                                                            Include_Paying_Account_Types__c, 
                                                                            Include_Basic_Account_Types__c 
                                                                            FROM Listings_Performance_metrics__mdt]) {
                                                                                
		if(!metricsMetadataMap.containsKey(listingPerformanceMetadata.DeveloperName)){
        	metricsMetadataMap.put(listingPerformanceMetadata.DeveloperName,listingPerformanceMetadata);                                                                   
        }
    }
    return metricsMetadataMap;
  }  
  
}