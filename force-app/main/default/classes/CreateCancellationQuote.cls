/**
 * @author Adam LaPlante
 * @module BR-1200
 * @created 07/01/2021
 * @modified 10/13/2021
 */

 public class CreateCancellationQuote {

    public final static Date firstDayOfNextMonth = System.today().addMonths(1).toStartOfMonth();
    public final static Date lastDayOfNextMonth = firstDayOfNextMonth.addDays(Date.daysInMonth(firstDayOfNextMonth.year(), firstDayOfNextMonth.month())-1);

    /**
    * Function creates amendment quotes for contract cancellations and saves them.
    */

    public static void createCancellationQuotes(List<Contract> contractsToCancel, String context) {
        // list of quotes to insert and subscriptions to update
        List<QuoteModel> cancellationQuotes = new List<QuoteModel>();
        Set<Id> quoteIds = new Set<Id>();

        ContractAmender contractAmender = new ContractAmender();
        //List<SBQQ__Subscriptions__c> subsToUpdate = new List<SBQQ__Subscriptions__c>();

        // loop through contracts to create cancellation quote,
        // loop through subscriptions to update field values, 
        // add quote to cancellation quotes list,
        for (Contract contract : contractsToCancel) {
            // returns quote model of amendment quote
            cancellationQuotes.add(contractAmender.amend(contract.Id));
        }

        // loop through create cancellation quote models
        for (QuoteModel quote : cancellationQuotes) {
            // grab quote record from model
            SBQQ__Quote__c quoteRec = quote.record;
            quoteIds.add(quoteRec.Id);
        }

        if (!quoteIds.isEmpty()){
            updateCancellationQuotes(quoteIds, context);
        }

    }

    // future method for asynchronous processing
    public static void updateCancellationQuotes(Set<Id> quoteIds, String context) {

        List<SBQQ__QuoteLine__c> quoteLinesToUpdate = new List<SBQQ__QuoteLine__c>();
        List<SBQQ__Quote__c> quotesToUpdate = new List<SBQQ__Quote__c>();

        for (SBQQ__Quote__c quoteRec : 
            [
                SELECT Id, SBQQ__LineItemCount__c , (SELECT Id FROM SBQQ__LineItems__r) FROM SBQQ__Quote__c WHERE Id IN :quoteIds
            ]
        ) {

            // set cancellation quote to true, type to cancellation, note on quote
            quoteRec.Cancellation_Quote__c = true;
            quoteRec.SBQQ__Type__c = 'Cancellation';
            quoteRec.SBQQ__Notes__c = context == 'DELINQUENT' 
                ? 'Quote automatically created on ' + formatDate(System.today()) + ' for delinquency cancellation.'
                : 'Quote automatically created on ' + formatDate(System.today()) + ' for contract end date cancellation.';
            if(context == 'EXPIRED') {
                quoteRec.SBQQ__StartDate__c = firstDayOfNextMonth; 
                quoteRec.SBQQ__EndDate__c = lastDayOfNextMonth;
            }
                
            // set amendment quote line quantities to 0
          	for (SBQQ__QuoteLine__c quoteline : quoteRec.SBQQ__LineItems__r) {
                quoteline.SBQQ__Quantity__c = 0;
                quoteLinesToUpdate.add(quoteline);
            }

            // add quote to list
            quotesToUpdate.add(quoteRec);
        }
			
        // disable sbqq trigger control, commit quote to SF, enable trigger control
        try {
            //disable SBQQ Triggers
            SBQQ.TriggerControl.disable();       

            // save quote
            update quotesToUpdate;
            update quoteLinesToUpdate;

            //re-enable SBQQ Triggers
            SBQQ.TriggerControl.enable();
        } catch (DMLException e) {
            Utilities.sendSimpleErrorEmail('CreateCancellationQuote', e.getMessage());
        } 
    }

    /**
     * Function returns formatted date for field setting purposes.
     */
    private static String formatDate(Date d) {
        return d.year() + '-' + d.month() + '-' + d.day();
    }
}