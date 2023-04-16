// Jira: BR-1220
public class BatchUpdateFinalApprover implements Database.Batchable<sObject>, Schedulable {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String testClause = 'AND Username = \'testFinalApprover@gmail.com\'';
        
        String query = 'SELECT Id, Is_Final_Approver__c, Final_Approver_Id_Text__c, '+
            'ManagerId '+
            'FROM User WHERE IsActive = true';
        
        query += Test.isRunningTest() ? ' '+testClause : '';

        return Database.getQueryLocator(query);
    }
    
    public void execute(SchedulableContext SC) {
        Database.executeBatch(new BatchUpdateFinalApprover());
    }
    
    public void execute(Database.BatchableContext bc, List<User> users){
        Map<Id, User> allUsersMap = new Map<Id, User>(users);
        
        List<User> usersToUpdate = new List<User>();
        for(User u : users) {
            if(u.ManagerId == null) {
                continue;
            }
            User finalApproverUser = findFinalApprover(u, allUsersMap);
            if(finalApproverUser == null) {
                u.Final_Approver_Id_Text__c = null;
                usersToUpdate.add(u);
            }
            
            if(finalApproverUser != null && u.Final_Approver_Id_Text__c != finalApproverUser.Id) {
            	u.Final_Approver_Id_Text__c = finalApproverUser.Id;
                usersToUpdate.add(u);
            }
        }
        
        if(! usersToUpdate.isEmpty()) {
        	update usersToUpdate;
		}
    }
    
    public static User findFinalApprover(User u, Map<Id, User> allUsersMap) {
        if(u.ManagerId == null) {
            return null;
        }
        
        User manager = allUsersMap.get(u.ManagerId);
        if(manager == null) {
            return null;
        }
        
        if(manager.Is_Final_Approver__c) {
            return manager;
        } else {
            findFinalApprover(manager, allUsersMap);
        }

        return null;
    }
            

    public void finish(Database.BatchableContext bc){

    }
}