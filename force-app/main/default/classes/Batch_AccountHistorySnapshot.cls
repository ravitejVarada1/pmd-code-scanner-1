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
global class Batch_AccountHistorySnapshot implements Database.Batchable<sObject>, Schedulable {
  private Id dealerRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
  
  private Set<Id> acctIds;
  global Batch_AccountHistorySnapshot() {}
    
  global Batch_AccountHistorySnapshot(Id acctId) {
	  this.acctIds = new Set<Id>{acctId};
  }
    
  global Batch_AccountHistorySnapshot(Set<Id> acctIds) {
	  this.acctIds = acctIds;
  }
  
  global Database.QueryLocator start(Database.BatchableContext BC) {
    List<String> spQueryFields = new List<String>(Service_Provider__c.SObjectType.getDescribe().fields.getMap().keySet());

    String query = 'SELECT '+ String.join(spQueryFields, ', ') + ', Account__r.OwnerId, Account__r.Owner.Email, ' +
                      'Account__r.Name, Account__r.Account_Category_Formula__c, Account__r.BillingCountryCode, ' +
                      'Account__r.CurrencyIsoCode, Account__r.Owner.Title, Account__r.Product_Activation_Status__c ' +
                    'FROM Service_Provider__c ' +
                    'WHERE Include_for_Snapshot__c = true '+
                      'AND Account__r.recordTypeId = : dealerRecordTypeId ' +
                      'AND Account__c NOT IN ('+
                        'SELECT Account__c FROM Account_History_Snapshot__c '+
                        'WHERE Snapshot_Date__c = THIS_MONTH'+
                      ')';
    
    if (acctIds != null) {
      query += ' and Account__c in : acctIds';		
    }
    
    System.debug('Batch_AccountHistorySnapshot Query: '+query);
    return Database.getQueryLocator(query);
  }

  global void execute(Database.BatchableContext BC, List<Service_Provider__c> spList) {
    try {
      List<Account_History_Snapshot__c> ahs = Batch_AccountHistorySnapshotHelper.createAccountHistorySnapshotsFromSPs(spList, true);
    } catch (Exception e) {
      System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
      throw e;
    }
  }
  
  global void finish(Database.BatchableContext BC) {
    Date myDate = system.today();
    Date cutOffdate = myDate.addDays(-1);

    List<AsyncApexJob> failedBatchList = [SELECT Id, Status, NumberOfErrors
                                            FROM AsyncApexJob WHERE ApexClass.name = 'Batch_AccountHistorySnapshot' 
                                            AND CompletedDate >= : cutOffdate order by CompletedDate desc];

    //there might be more accounts to process because of ROW LOCK ERRORS so go ahead and send them to Batch again
    if(failedBatchList.size() > 0 && !Test.isRunningTest() && 
        failedBatchList[0].Status == 'Completed' && failedBatchList[0].NumberOfErrors > 0) {
          Database.executeBatch(new Batch_AccountHistorySnapshot(), 50);
    }
  }

  public void execute(SchedulableContext sc) {
    Database.executeBatch(new Batch_AccountHistorySnapshot(), 200);
  }
  
}