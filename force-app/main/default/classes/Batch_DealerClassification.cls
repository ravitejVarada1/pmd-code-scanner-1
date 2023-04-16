/**
 * @author      Adam LaPlante
 * @created     09/21/2021
 * @modified    09/28/2021
 */

public class Batch_DealerClassification implements Database.Batchable<sObject>, Schedulable {
    /**
     * Returns query to find accounts to classify
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */

	public Database.QueryLocator start(Database.BatchableContext bc){
		string query = 'SELECT Id, Name, Account_Category_Formula__c, Dealer_Classification__c, '+ 
                        'Group_Total_Locations_Formula__c, Group_Total_Used_Inventory_Avg_Formula__c ' +
                        'FROM Account ' +
                        'WHERE Group_Total_Locations_Formula__c > 0 AND Is_Ultimate_Parent__c = true';
		return Database.getQueryLocator(query);
	}

    /**
     * Iterates through accounts returned by query, calls dealer classification class
     * to classify each account, then upserts all updated accounts
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */

	public void execute(Database.BatchableContext bc, List<Account> accounts){
        // initialize dealer classification object, account lists, batch count
        DealerClassification dc = new DealerClassification();
        List<Account> accountsToUpdate = new List<Account>();
        List<Account> accountsToProcess = new List<Account>();
        Integer batchSize = 500; // flow control that determines how many accounts get passed into dc object
        Integer i = 0; // using index to monitor batch size
        

        // loop through accounts grabbed from query
        for (Account account : accounts) {
            accountsToProcess.add(account);
            i++;
            // if batch size has been reached or end of list, process accounts
            if (i == batchSize || i == accounts.size()) {
                try {
                    // add list returned from returnClassifiedDealaers to accountsToUpdate
                    accountsToUpdate.addAll(dc.returnClassifiedDealers(accountsToProcess));
                } catch(SObjectException e) {
                    System.debug('The following exception has occurred: ' + e.getMessage());
                    Utilities.sendSimpleErrorEmail('Batch_DealerClassification', e.getMessage());
                } finally {
                    // clear accountsToProcess so we don't duplicate
                    accountsToProcess.clear();
                }
            }
        }
        
        system.debug('Accounts To Update : ' + accountsToUpdate);

        // check if there are accounts available for insert, if so, insert them, clear accounts to insert
        if (accountsToUpdate.size() > 0) {
            try {
                update accountsToUpdate;
            } catch(DmlException e) {
                System.debug('The following exception has occurred while inserting accounts: ' + e.getMessage());
                Utilities.sendSimpleErrorEmail('Batch_DealerClassification', e.getMessage());
            } finally {
                accountsToUpdate.clear();
            }    
        }
	}

	public void finish(Database.BatchableContext bc){
        // send email stating that dealer classification job has finished
        // maybe capture dealers that change
        //  Utilities.sendSimpleEmail(
        //   ''
        //   );
	}

	public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_DealerClassification(), 500);
	}
}