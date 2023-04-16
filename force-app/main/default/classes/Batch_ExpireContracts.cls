public class Batch_ExpireContracts implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {
	
	public final static Date firstDayOfMonth = System.today().toStartOfMonth();
    public final static Date lastDayOfMonth = firstDayOfMonth.addDays(Date.daysInMonth(firstDayOfMonth.year(), firstDayOfMonth.month())-1);
	public final static Date firstDayOfNextMonth = System.today().addMonths(1).toStartOfMonth();
	
	public Database.QueryLocator start(Database.BatchableContext bc){
		Date todayDate = System.today();
		string query = 'SELECT Id,Name,Auto_Renewal_Disable_Date__c,EndDate,Status,' +
					'(SELECT Auto_Renewal_Flag__c ' +
					'FROM  SBQQ__Subscriptions__r ' +
					'WHERE SBQQ__Product__r.ProductCode = \'CG-BASE\' AND Auto_Renewal_Flag__c = true) ' +
					'FROM Contract '+
					'WHERE EndDate =:lastDayOfMonth ' + 
					'AND Status = \'Activated\' ' + 
					'AND Auto_Renewal_Disable_Date__c <= :todayDate';
		return Database.getQueryLocator(query);
	}
	public void execute(Database.BatchableContext bc, List<Contract> Contracts){
		List<Contract> contractsToBeCancelled= new List<Contract>();
		for (Contract con : contracts){

			//Since we only want to process contracts that have 0 subscriptions 
			//set to auto renew, we'll omit processing contracts that do have 
			//atleast 1 subscriptions that is set to auto renew.
			List<SBQQ__Subscription__c> cpqSubs = con.SBQQ__Subscriptions__r;
			if(cpqSubs.size() > 0) {
				continue;
			}
				con.Cancellation_Effective_Date__c = firstDayOfNextMonth;
				con.SBQQ__AmendmentStartDate__c = firstDayOfNextMonth;
				contractsToBeCancelled.add(con);
			}
        
        try {
			if(contractsToBeCancelled.size() > 0){
				CreateCancellationQuote.createCancellationQuotes(contractsToBeCancelled, 'EXPIRED');
				update contractsToBeCancelled;
			}
        } catch (Exception e) {
            System.debug('Error creating cancellation quotes : ' + e.getMessage());
			throw e;
        }
	}
	public void finish(Database.BatchableContext bc){
	}
	public void execute(SchedulableContext sc){
		Database.executeBatch(new Batch_ExpireContracts(), 1);
	}
}