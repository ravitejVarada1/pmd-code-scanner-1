/**
 * Ad-hoc batch job to send account data to PH Admin Centre.
 * 
 * @author: Adam LaPlante
 * @jira: BR-5593
 * @created: 02/10/2022
 * @modified: 
 *   06/29/2022 (SA-211) Adam LaPlante
 */


public class Batch_TransferDataToPHAdminCentre implements Database.Batchable<sObject>, Schedulable {

	public Database.QueryLocator start(Database.BatchableContext bc){

        String query;
        // for testing, run query without date criterion
        if (Test.isRunningTest()) {
            query = 	
                'SELECT ' +
                    'Id, ' +
                    'Product_Code__c, ' +
                    'SBQQ__ProductId__c, ' +
                    'Fulfillment_Account__r.Id, ' +
                    'Fulfillment_Account__r.PH_Admin_Centre_Id__c ' +
                'FROM ' +
                    'SBQQ__Subscription__c ' +
                'WHERE ' +
                    'Fulfillment_Account__c IN (SELECT Id FROM Account WHERE PH_Admin_Centre_Id__c != null) AND ' +
                    'Activation_Status__c = \'Activated\' AND ' + 
                    'Provisioning_Status__c = \'Activated\' AND ' +
                    '(' +
                        'SBQQ__Product__r.Provisioning_Platform__c = \'PistonHeads\' OR '+
                    '(' +
                        'Product_Code__c = \'ENH-BUND\' OR ' +
                        'Product_Code__c = \'FEAT_BUND\' OR ' +
                        'Product_Code__c = \'FEAT_PRI_BUND\'' +
                    '))';

        } else {

            // query to pass to execute function
            query = 	
                'SELECT ' +
                    'Id, ' +
                    'Product_Code__c, ' +
                    'SBQQ__ProductId__c, ' +
                    'Fulfillment_Account__r.Id, ' +
                    'Fulfillment_Account__r.PH_Admin_Centre_Id__c ' +
                'FROM ' +
                    'SBQQ__Subscription__c ' +
                'WHERE ' +
                    'Fulfillment_Account__c IN (SELECT Id FROM Account WHERE PH_Admin_Centre_Id__c != null) AND ' +
                    'CreatedDate <= 2022-12-16T12:00:00Z AND ' +
                    'Activation_Status__c = \'Activated\' AND ' + 
                    'Provisioning_Status__c = \'Activated\' AND ' +
                    '(' +
                        'SBQQ__Product__r.Provisioning_Platform__c = \'PistonHeads\' OR '+
                    '(' +
                        'Product_Code__c = \'ENH-BUND\' OR ' +
                        'Product_Code__c = \'FEAT_BUND\' OR ' +
                        'Product_Code__c = \'FEAT_PRI_BUND\'' +
                    '))';

        }


		return Database.getQueryLocator(query);
	}
    
	public void execute(Database.BatchableContext bc, List<SBQQ__Subscription__c> phSubscriptions) {

        // maps necessary to construct integration messages
        Map<Id, Boolean> accountIdMap = new Map<Id, Boolean>();
        Map<Id, Id> accountProductIdMap = new Map<Id, Id>();


        // loop through subs, setting up maps for integration messages
        for (SBQQ__Subscription__c sub : phSubscriptions) {
            // gather account Id + boolean if featured product
            accountIdMap.put(
                sub.Fulfillment_Account__r.Id, 
                sub.Product_Code__c.contains('FEAT') ? true : false
            );

            // gather account Id + product Id
            accountProductIdMap.put(
                sub.Fulfillment_Account__r.Id,
                sub.SBQQ__ProductId__c
            );
        }

        // using constructed maps, create and send all integration messages immediately
        PHIntegration_AccountHelper.createAndSendPHAccountMessages(
            accountIdMap, 
            accountProductIdMap,
            true,
            true
        );

    }

	public void finish(Database.BatchableContext bc){
	}

	public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_TransferDataToPHAdminCentre());
	}

}