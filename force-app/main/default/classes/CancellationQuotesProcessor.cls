/**
* Schedulable class to process cancellations, starting from the quote and effectively cancelling the related contract
* @author 	Nahuel Goldy
* @date 	  06/06/2021
* @module   BR-1037
*/
global class CancellationQuotesProcessor implements Database.Batchable<sObject>, Schedulable {

    private List<Id> accountIds;

    private Boolean compareThirtyOne;

    public CancellationQuotesProcessor() {}

    public CancellationQuotesProcessor(Id accountId) {
        this.accountIds = new List<Id>();
        this.accountIds.add(accountId);

        this.compareThirtyOne = false;
    }

    public CancellationQuotesProcessor(List<Id> accIds) {
        this.accountIds = accIds;
        this.compareThirtyOne = false;
    }

    public CancellationQuotesProcessor(Id accountId, Boolean compareThirtyOne) {
        this.accountIds = new List<Id>();
        this.accountIds.add(accountId);

        this.compareThirtyOne = compareThirtyOne;
    }

    /**
     * Entry-point method. Queries all cancellation quotes with start date = today or prior,
    *   where the retention opp hasn't been closed and the related contract hasn't been cancelled
    * @author 	Nahuel Goldy
    * @date 	  06/06/2021
    * @return 	void
    */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String accountCondition = accountIds != null && !accountIds.isEmpty() ? 'AND SBQQ__Account__c IN :accountIds ' : '';
        Integer numDays = 30;
        if(compareThirtyOne != null && compareThirtyOne) {
            numDays = 31;
        }
        Date dateComparison = Date.today().addDays(numDays);

        String query = 'SELECT Id, SBQQ__Opportunity2__c, SBQQ__Primary__c, SBQQ__Type__c, ' +
            'SBQQ__Opportunity2__r.Cancellation_Case__c, ApprovalStatus__c, SBQQ__Status__c, ' + 
            'SBQQ__Ordered__c, SBQQ__Source__c, SBQQ__Source__r.SBQQ__Primary__c, ' + 
            'SBQQ__Source__r.SBQQ__Status__c, SBQQ__Source__r.ApprovalStatus__c, ' + 
            'SBQQ__MasterContract__r.Status, SBQQ__MasterContract__c, ' +
            'SBQQ__MasterContract__r.Cancellation_Effective_Date__c, ' +
            'SBQQ__Opportunity2__r.SBQQ__PrimaryQuote__c, SBQQ__StartDate__c ' + 
            'FROM SBQQ__Quote__c ' +
            'WHERE SBQQ__Type__c = \'Cancellation\' ' +
                'AND SBQQ__StartDate__c <=: dateComparison ' + //changed to dateComparison from TODAY
                'AND SBQQ__Opportunity2__r.IsWon = FALSE ' + 
                'AND ('+
                '(SBQQ__Opportunity2__r.RecordType.Name = \'Retention\' AND SBQQ__MasterContract__r.Status != \'Cancelled\') ' + 
                'OR Cancellation_Quote__c = TRUE'+
                ') ' +
                accountCondition +
                'ORDER BY SBQQ__StartDate__c ASC';
        return Database.getQueryLocator(query);
    }

    /**
     * Method that processes the quotes. Makes the cancellation quote primary & approved, 
    *   the related retention quote is unchecked as primary, expired and locked,
    *   and the cancellation quotes are Ordered (CPQ)
    * @author 	Nahuel Goldy
    * @date 	  06/06/2021
    * @param    List<SBQQ__Quote__c>: list of cancellation quotes to be processed
    * @return 	void
    */
    public void execute(Database.BatchableContext bc, List<SBQQ__Quote__c> cancelQuotes) {

        String STATUS_APPROVED = 'Approved';
        String STATUS_COMPLETED = 'Completed';
        String STATUS_EXPIRED = 'Expired';
        String STATUS_CANCELLED = 'Cancelled';

        List<SBQQ__Quote__c> quotesToUpdate = new List<SBQQ__Quote__c>();
        List<SBQQ__Quote__c> cancellationQuotes = new List<SBQQ__Quote__c>();
        List<Contract> contracts = new List<Contract>();
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (SBQQ__Quote__c cancellationQuote : cancelQuotes) {

            //BR-9607 - since delinquency cancellation may be full or partial, we
            //rely on the quote start date.
            Date quoteStartDate = cancellationQuote.SBQQ__StartDate__c;
            Date cancelEffectiveDate = cancellationQuote.SBQQ__MasterContract__r.Cancellation_Effective_Date__c;

            Date amendmentSendDate = quoteStartDate.addDays(-30); 
            if (date.today() < amendmentSendDate) {
                continue;
            }

            cancellationQuote.SBQQ__Primary__c = true;
            cancellationQuote.SBQQ__Status__c = STATUS_APPROVED;
            cancellationQuote.SBQQ__Type__c = 'Amendment';
            quotesToUpdate.add(cancellationQuote);
            cancellationQuotes.add(cancellationQuote);

            // customer cancellation quotes will have a regular retention quote;
            // delinquency-related cancellations will not
            if(cancellationQuote.SBQQ__Source__c != null) {
                SBQQ__Quote__c retentionQuote = new SBQQ__Quote__c(Id=cancellationQuote.SBQQ__Source__c);
                retentionQuote.SBQQ__Primary__c = false;
                quotesToUpdate.add(retentionQuote);

                // we need to also update any other quote apart from these that could be 
                if(cancellationQuote.SBQQ__Source__c != cancellationQuote.SBQQ__Opportunity2__r.SBQQ__PrimaryQuote__c) {
                    SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=cancellationQuote.SBQQ__Opportunity2__r.SBQQ__PrimaryQuote__c);
                    quote.SBQQ__Primary__c = false;
                    quotesToUpdate.add(quote);
                }
            }        

            if(cancelEffectiveDate != null) {
                Contract contractToCancel = new Contract(Id=cancellationQuote.SBQQ__MasterContract__c);
                contractToCancel.Status = STATUS_CANCELLED;
                contracts.add(contractToCancel);
            }

            Opportunity oppToUpdate = new Opportunity(Id=cancellationQuote.SBQQ__Opportunity2__c);
            oppToUpdate.SBQQ__PrimaryQuote__c = cancellationQuote.Id;
            oppToUpdate.Retention_Contract__c = cancellationQuote.SBQQ__Source__c != null ? cancellationQuote.SBQQ__MasterContract__c : null;
            oppsToUpdate.add(oppToUpdate);
        }

        // unlock the quotes
        Approval.UnlockResult[] lrList = Approval.unlock(cancellationQuotes);

        // update both quotes and retention opportunity
        // SBQQ triggers off to avoid CPQ generating a queueable from the calculation
        SBQQ.TriggerControl.disable();
        {
            update quotesToUpdate;
            update oppsToUpdate;
            SBQQ.TriggerControl.enable();

            for (SBQQ__Quote__c quote : cancellationQuotes) {
                quote.SBQQ__Ordered__c = true;
            }

            if(!Test.isRunningTest()) {
                update cancellationQuotes;
            }

            SBQQ.TriggerControl.disable();

            // update retention opportunities: clear amended contract & primary quote lookups
            List<Id> oppsIds = new List<Id>();
            for(Opportunity opp: oppsToUpdate) {
                opp.SBQQ__AmendedContract__c = null;
                opp.SBQQ__PrimaryQuote__c = null;
                oppsIds.add(opp.Id);
            }
            update oppsToUpdate;


            //all quotes to update
            List<SBQQ__Quote__c> quotesUpdate = new List<SBQQ__Quote__c>();
            List<Opportunity> oppsUpdate = new List<Opportunity>();

            // update cancellation quotes: clear primary checkbox
            for (SBQQ__Quote__c quote : cancellationQuotes) {
                quote.SBQQ__Primary__c = false;

                SBQQ__Quote__c retentionQuote = null;
                if(quote.SBQQ__Source__c != null) {
                    retentionQuote = new SBQQ__Quote__c(Id=quote.SBQQ__Source__c);
                    retentionQuote.SBQQ__Primary__c = true;
                    quotesUpdate.add(retentionQuote);
                }

                if(retentionQuote != null) {
                    Opportunity oppToUpdate = new Opportunity(Id=quote.SBQQ__Opportunity2__c);
                    oppToUpdate.SBQQ__PrimaryQuote__c = retentionQuote.Id;
                    oppsUpdate.add(oppToUpdate);
                }
            } 
            quotesUpdate.addAll(cancellationQuotes);

            //update quotes
            update quotesUpdate;

            //updating opportunity with the new primary quote reference
            update oppsUpdate; 

            // update contract status if canceling contract
            if(!contracts.isEmpty()) {
                update contracts;
            }
        }

        //re-enable CPQ Triggers
        SBQQ.TriggerControl.enable();

    }

    public void finish(Database.BatchableContext bc) {
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CancellationQuotesProcessor(), 1);
    }

}