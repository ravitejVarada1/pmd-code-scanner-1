/**
 * @author Adam LaPlante
 * @module BR-1200
 * @created 07/01/2021
 * @modified 10/13/2021
 */
public class Batch_CancelDelinquentContracts implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

    //BR-9607 - in addition to delinquent days, also query the status since we do not
    //want to process the same cancellation twice, if previosuly processed the provisioning
    //status will be de-activated so we should only query 'Delinquent' subscriptions
    public static final String SUB_DELINQUENT_STATUS = ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_DELINQUENT;

	/**
	* Run SOQL query to return active contracts with sub delinquent at least 57 days
	*/
	public Database.QueryLocator start(Database.BatchableContext bc){
		Date todayDate = System.today();
        Double delinquencyDays = [SELECT Days_Until_Cancellation__c FROM Delinquency_Cancellation_Rules__mdt limit 1].Days_Until_Cancellation__c;
		string query = 'SELECT  Id, Name, Auto_Renewal_Disable_Date__c, EndDate, Status  ' +
                       'FROM Contract '+
					   'WHERE Status = \'Activated\' AND Id IN (SELECT SBQQ__Contract__c FROM SBQQ__Subscription__c '+
                       'WHERE Delinquent_Days__c >= :delinquencyDays AND Provisioning_Status__c = :SUB_DELINQUENT_STATUS)';

		return Database.getQueryLocator(query);
	}

	/**
	 * Loop through found contracts, set to cancel, send to create cancellation quote
	 * class to generate cancellation quote.
	 */

	public void execute(Database.BatchableContext bc, List<Contract> contracts) {
        // try creating cancellation quotes, if error, send error email to crm@cargurus.com
        // We must not mass amend contracts sicne we'll most likely hit a limit before we through even 2
        Contract ct = contracts[0];
        CancelDelinquentContractsHelper.cancelDelinquentSubscriptions(ct);
	}

	public void finish(Database.BatchableContext bc) {
        //BR-9607 - chain the cancellation quotes processor so it processes
        //the cancellation into Orders and cancels the contract
        if(!Test.isRunningTest()) {
            Database.executeBatch(new CancellationQuotesProcessor(), 1);
        }
	}

	public void execute(SchedulableContext sc){

        //BR-9607 - set batch size to 1 since we might end up mass amending
        //contracts and the batch will run into a time limit exception
		Database.executeBatch(new Batch_CancelDelinquentContracts(), 1);
	}
}                                      