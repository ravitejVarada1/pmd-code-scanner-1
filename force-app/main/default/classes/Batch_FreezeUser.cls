/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         amitul
* modifiedBy:     amitul
* created:        04/05/2021
* modified:       04/05/2021
* created jira:   BR-864
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
global class Batch_FreezeUser implements Database.Batchable<sObject>,Schedulable{
 
    String query = '';
    private final Date currentTime = System.Today();
    global Batch_FreezeUser() {
     query = 'SELECT Id,Name FROM User WHERE Termination_Date__c <=: currentTime AND IsActive = True';
        }   

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
        }

    global void execute(Database.BatchableContext BC, List<User> userList) {
  		Map<Id, User> userMap = new Map<Id, User>(userList);

    
        //Freeze User
        List<UserLogin> userLoginList = [SELECT Id, IsFrozen 
                         FROM UserLogin 
                         WHERE UserId IN: userMap.keySet()];
        
    	for(UserLogin ulogin : userLoginList){
       		ulogin.IsFrozen = true; 
        }
     
    	if(!userLoginList.isEmpty()){
       		update userLoginList;
        }
    }
    global void execute(SchedulableContext SC) {
        Database.executeBatch(new Batch_FreezeUser());
    }
    global void finish(Database.BatchableContext BC) {}
 
}