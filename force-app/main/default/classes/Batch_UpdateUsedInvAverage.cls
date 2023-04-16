// Jira: BR-725 
public class Batch_UpdateUsedInvAverage implements Database.Batchable<sObject>, Schedulable {
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
    	String query =  'SELECT Id, Used_Inventory_Avg_Last_Updated__c, Total_Used_Inventory_Units__c, ' + 
                            'Used_Inventory_Avg_Daily_Numbers__c, Used_Inventory_Avg__c ' +
                            'FROM Service_Provider__c WHERE reviewStatus__c != \'DENIED\'AND Can_host_inventory__c = \'Yes\'';
    	return Database.getQueryLocator(query);
    }
   
    public void execute(Database.BatchableContext BC, List<Service_Provider__c> spList) {
        // calling updateAverageInventory method of ServiceProviderFunctions to update Used Inventory Avg Daily Numbers
    	ServiceProviderFunctions.updateAverageInventory(spList);
    }
   
    public void finish(Database.BatchableContext BC) {}
    

    public void execute (SchedulableContext sc) {
        database.executeBatch(new Batch_UpdateUsedInvAverage());
    }
}