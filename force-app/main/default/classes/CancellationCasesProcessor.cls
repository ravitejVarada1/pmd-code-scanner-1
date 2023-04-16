/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         ngoldy
* modifiedBy:     ralvarez
* created:        12/08/2021
* modified:       11/07/2022
* created jira:   BR-5044 / BR-9060 / SA-957
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class CancellationCasesProcessor implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {

    private List<Id> caseIdList = new List<Id>();
    private List<Opportunity> oppsToUpdate = new List<Opportunity>();
    private Map<Id, SBQQ__Quote__c> quotesToUpdate = new Map<Id, SBQQ__Quote__c>();
    private List<Case> casesToUpdate = new List<Case>();
    private Id cancellationQuoteId;

    public CancellationCasesProcessor() {}

    public CancellationCasesProcessor(Id caseId) {
        this.caseIdList = new List<Id>();
        this.caseIdList.add(caseId);
    }

    public CancellationCasesProcessor(List<Id> lst) {
        this.caseIdList = lst;
    }

    public Database.QueryLocator start(Database.BatchableContext BC){
        String query =  'SELECT Id, Cancellation_Effective_Date__c, Related_Contract__c,Cancel_Override__c, ' +
                        'Related_Contract__r.AccountId, Related_Contract__r.Account.Name, Related_Contract__r.Initial_Term_End_Date__c, Related_Contract__r.Co_Op_Program_Opt_in__c  ' +
                        'FROM Case ' +
                        'WHERE RecordType.Name = \'Cancellations\' AND Related_Contract__c != null ' +
                        'AND Id IN (\'' + String.join(caseIdList, '\', \'') + '\')';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<Case> cases) {

        // we want CPQ trigger disabled so quote & QLs insertion does not generate multiple queueables (due to quote calculation) 
        SBQQ.TriggerControl.disable();

        ContractAmender contractAmender = new ContractAmender();
        Id retentionOppRecordTypeId = Utilities.getrecordTypeId('Opportunity', 'Retention');
        Map<Id,Id> opptyContractMap = new Map<Id,Id> ();
        List<SBQQ__Quote__c> amendQuotesToDel = new List<SBQQ__Quote__c> (); //SA-957
        List<Account> turkeyAccountsToInactivate = new List<Account> (); //SA-957

        for(Case c : cases) {
            // generate amendment opp + quote
            QuoteModel quoteModel = contractAmender.amend(c.Related_Contract__c);
           
            Boolean isTurnkeyContract = c.Related_Contract__r.Co_Op_Program_Opt_in__c != null;
            // add opportunity to list, to update certain fields            
            String opptyName = !isTurnkeyContract ?
                    'Retention Opp for ' + c.Related_Contract__r.Account.Name + ' - Full Cancellation' :
                    'Turnkey Cancellation Opp for ' + c.Related_Contract__r.Account.Name;

            oppsToUpdate.add(
                new Opportunity(
                Id = quoteModel.record.SBQQ__Opportunity2__c,
                Name = opptyName,
                Cancellation_Case__c = c.Id,
                RecordTypeId = retentionOppRecordTypeId,
                StageName = 'At Risk',//SA-815 setting the stagename for Retention Opp
                Type = 'Existing Business',
                CloseDate = c.Cancellation_Effective_Date__c + 57,
                Auto_Close_Date__c = c.Cancellation_Effective_Date__c + 57
                )
            );

            // Populate Opportunity Contract Id Map
            opptyContractMap.put(quoteModel.record.SBQQ__Opportunity2__c, c.Related_Contract__c);

            // add amendment quote to list, to update certain fields
            
                
            /*Date  startDate;
                if(c.Cancel_Override__c != null){
                startDate = c.Cancellation_Effective_Date__c.adddays(1);  
                }else{
                startDate = c.Related_Contract__r.Initial_Term_End_Date__c.daysBetween(c.Cancellation_Effective_Date__c) >= 30 ? c.Cancellation_Effective_Date__c.addDays(1) : c.Cancellation_Effective_Date__c;
                }*/
            
            Approval.UnlockResult ur = Approval.unlock(quoteModel.record.Id);
            System.debug(ur.isSuccess());
            System.debug(ur.getErrors());
            
            quotesToUpdate.put(quoteModel.record.Id,
                new SBQQ__Quote__c(
                Id = quoteModel.record.Id,
                SBQQ__StartDate__c = c.Cancellation_Effective_Date__c,
                SBQQ__ExpirationDate__c = null
                )
            );

            // add cancellation case to list, to update certain fields
            casesToUpdate.add(
                new Case(
                Id = c.Id,
                Related_Opportunity__c = quoteModel.record.SBQQ__Opportunity2__c,
                Related_Dealer_Account__c = c.Related_Contract__r.AccountId,
                Case_Resolution__c = 'Full Cancellation',
                Status = 'Closed',
                Sub_Status__c= 'Complete'   
                )
            );

            // Add Turnkey Amendment Quote to the list in order to be deleted and set Account Enrollment Status to Inactive
            if (isTurnkeyContract) {
                amendQuotesToDel.add(new SBQQ__Quote__c(Id = quoteModel.record.Id));
                quotesToUpdate.remove(quoteModel.record.Id);
                turkeyAccountsToInactivate.add(new Account (Id = c.Related_Contract__r.AccountId, Enrollment_Status__c = 'Inactive'));
            }
        }

        // update opps
        if(!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }

        // update cases
        if(!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }

        //Remove amendment quote if it's Turnkey Deal
        if (!amendQuotesToDel.isEmpty()) {
            delete amendQuotesToDel;
        }
        // If it is a Turnkey cancellation, set the Account Enrollment_Status__c to Inactive
        if (!turkeyAccountsToInactivate.isEmpty()) {
            update turkeyAccountsToInactivate;
        }

        if(!opptyContractMap.isEmpty()) {
            // BR-9060 Create Opportunity Line Items with negative lines        
            createNegativeLinesRetentionOpp(opptyContractMap);
        }

        // query newly cloned Cancellation quotes upon case closure
        List<SBQQ__Quote__c> cancellationQuotes = [
        SELECT Id, SBQQ__StartDate__c, SBQQ__Opportunity2__r.Cancellation_Case__r.Cancellation_Effective_Date__c
        FROM SBQQ__Quote__c
        WHERE SBQQ__Type__c = 'Cancellation'
            AND SBQQ__Opportunity2__r.Cancellation_Case__c IN :caseIdList
           // AND SBQQ__StartDate__c = TODAY
        ];

        //Quote Ids to unlock
        Set<Id> qIds = new Set<Id>();
        // update quote start date to force quote calculation
        for(SBQQ__Quote__c quote : cancellationQuotes) {
            quote.SBQQ__StartDate__c = quote.SBQQ__Opportunity2__r.Cancellation_Case__r.Cancellation_Effective_Date__c;
            quote.Cancellation_Quote__c = true;
            quote.Initial_Term_End_Date__c = null;
            quotesToUpdate.put(quote.Id, quote);
            qIds.add(quote.Id);

            cancellationQuoteId = quote.Id;
        }

        List<Approval.UnlockResult> more_ur = Approval.unlock(new List<Id>(qIds));
        for(Approval.UnlockResult aur : more_ur) {
            System.debug(aur.isSuccess());
            System.debug(aur.getErrors());
        }

        if(!quotesToUpdate.isEmpty() && !Test.isRunningTest()) {
            update quotesToUpdate.values();
        }
        
        // reenable CPQ triggers
        SBQQ.TriggerControl.enable();
    }

    public void finish(Database.BatchableContext BC) {
        if (!Test.isRunningTest()) {
            //BR-8810 custom quote calculation
            if(cancellationQuoteId!=null){
                System.enqueueJob(new QuoteCalculatorOperation(cancellationQuoteId));
            }
        }
    }

    @InvocableMethod(label='processCancellationCase')
    public static void execute(List<Id> caseIds) {
        Database.executeBatch(new CancellationCasesProcessor(caseIds), 1);
    }

    /**
    * BR-9060 Bring over Negative Line Items for Existing Products on the Retention Opportunity
    * @author   Ramiro Alvarez
    * @date     05/09/2022
    * @param    Map<Id,Id> - opptyContractIdMap
    * @return   void
    */

    private static void createNegativeLinesRetentionOpp(Map<Id,Id> opptyContractIdMap) {
    
        // Map to store contract Id and list of cancelled subs
        Map<Id, List<SBQQ__Subscription__c>> cancelled_cpq_subs = new Map<Id, List<SBQQ__Subscription__c>>();
        // List to store Opportunity Lines Items to be inserted
        List<OpportunityLineItem> delta_oli_insert = new List<OpportunityLineItem>();

        // Loop through cpq subs on related contracts
        for(SBQQ__Subscription__c sub : [SELECT Id, SBQQ__Contract__c, SBQQ__ProductId__c, SBQQ__Quantity__c,
            SBQQ__SubscriptionType__c, SBQQ__NetPrice__c, CurrencyIsoCode,SBQQ__Product__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__NetPrice__c > 0
            AND SBQQ__Quantity__c > 0
            AND SBQQ__TerminatedDate__c = NULL
            AND SBQQ__Contract__c IN :opptyContractIdMap.values()])
        {
            if(!cancelled_cpq_subs.containsKey(sub.SBQQ__Contract__c)) {
                cancelled_cpq_subs.put(sub.SBQQ__Contract__c, new List<SBQQ__Subscription__c>());
            } 
            cancelled_cpq_subs.get(sub.SBQQ__Contract__c).add(sub);
        }

        Set<Id> productIds = new Set<Id> ();
        Set<String> currencyCodes = new Set<String> ();
        for (Id contractId : cancelled_cpq_subs.keySet()) {
            for(SBQQ__Subscription__c sub : cancelled_cpq_subs.get(contractId)) {
                productIds.add(sub.SBQQ__Product__c);
                currencyCodes.add(sub.CurrencyIsoCode);
            }
        }

        // Query for PriceBook Entries
        List<PricebookEntry> pbeList = [
            SELECT Id, Product2Id,CurrencyIsoCode
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
            AND CurrencyIsoCode IN :currencyCodes
            AND IsActive = true];

        // Prepare a map with following key: Product2Id + CurrencyIsoCode and PBE Id as value
        Map<String,Id> pricebookEntryMap = new Map<String,Id>();
        for (PricebookEntry pbe : pbeList) {
            pricebookEntryMap.put(pbe.Product2Id + pbe.CurrencyIsoCode, pbe.Id);
        }

        // Map to collect Opportunity Id and the Original Contract Spend
        Map<Id,Decimal> opptyOriginalSpendMap = new Map<Id,Decimal> ();
        for(Id opp_id : opptyContractIdMap.keySet()) {
            
            Id cancelledContractId = opptyContractIdMap.get(opp_id);
            List<SBQQ__Subscription__c> cpq_subs = cancelled_cpq_subs.get(cancelledContractId);
            if(cpq_subs == null) { continue; }

            //Initiate map with 0 amount
            opptyOriginalSpendMap.put(opp_id, 0);

            for(SBQQ__Subscription__c cpq_sub : cpq_subs) {

                Id priceBookEntryId = pricebookEntryMap.get(cpq_sub.SBQQ__Product__c + cpq_sub.CurrencyIsoCode);
                OpportunityLineItem delta_oli = createOppLineItemForSub(opp_id, cpq_sub, priceBookEntryId);
                delta_oli_insert.add(delta_oli);
                
                Decimal netPrice = opptyOriginalSpendMap.get(opp_id);
                opptyOriginalSpendMap.put(opp_id, cpq_sub.SBQQ__NetPrice__c + netPrice);
            }
        }    

        if(!delta_oli_insert.isEmpty()) {
            insert delta_oli_insert;
        }
        
        // Loop through opptyOriginalSpendMap and prepare Opp List to update Original_Contract_Spend__c
        List<Opportunity> oppsToUpd = new List<Opportunity> ();
        for (Id opp_id : opptyOriginalSpendMap.keySet()) {
            oppsToUpd.add(new Opportunity (Id = opp_id, Original_Contract_Spend__c = opptyOriginalSpendMap.get(opp_id)));
        }
        if (!oppsToUpd.isEmpty()) {
            update oppsToUpd;
        }
    }

    private static OpportunityLineItem createOppLineItemForSub(Id opportunityId, SBQQ__Subscription__c cpq_sub, Id pbeId) {
        return new OpportunityLineItem(
          OpportunityId = opportunityId,
          Product2Id = cpq_sub.SBQQ__ProductId__c,
          Quantity = (-cpq_sub.SBQQ__Quantity__c),
          UnitPrice = cpq_sub.SBQQ__NetPrice__c,
          PricebookEntryId = pbeId
        );
    }

}