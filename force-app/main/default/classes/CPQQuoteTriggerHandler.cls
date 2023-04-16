public class CPQQuoteTriggerHandler extends TriggerHandler {

    private List<SBQQ__Quote__c> newList;
    private Map<ID,SBQQ__Quote__c> newMap;
    private List<SBQQ__Quote__c> oldList;
    private Map<ID,SBQQ__Quote__c> oldMap;

    public CPQQuoteTriggerHandler(){
        this.newList= (List<SBQQ__Quote__c>) Trigger.new;
        this.newMap = (Map<Id,SBQQ__Quote__c>) Trigger.newMap;
        this.oldList = (List<SBQQ__Quote__c>) Trigger.old;
        this.oldMap = (Map<Id,SBQQ__Quote__c>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        CPQQuoteTriggerFunctions.initializeForInsert(newList);
        CPQQuoteTriggerFunctions.defaultValuesForOEMQuotes(newList);//SA-295 Turnkey Quotes
        CPQQuoteTriggerFunctions.setDefaultLanguage(newList); //SA-591
        CPQQuoteTriggerFunctions.checkQuoteForApprovals(newList);
    }

    public override void beforeUpdate() {
        CPQQuoteTriggerFunctions.checkQuoteState(newList, oldMap);
        CPQQuoteTriggerFunctions.calculateCommittedTermEndDate(newMap);
        CPQQuoteTriggerFunctions.defaultValuesForOEMQuotes(newList);//SA-295 Turnkey Quotes
        CPQQuoteTriggerFunctions.checkQuoteForApprovals(newList);
        CPQQuoteTriggerFunctions.checkStartDateOnAmendments(newList, oldMap); //SA-392
    }

    public override void beforeDelete() {
        CPQQuoteTriggerFunctions.preventQuoteFromDeletion(oldList);


    }

    public override void afterInsert() {
        CPQQuoteTriggerFunctions.updateRenewalOpportunity(newMap);//DSS-450
    }

    public override void afterUpdate() {
        CPQQuoteTriggerFunctions.processZAccountCreation(newList, oldMap);   // BR-1144
        CPQQuoteTriggerFunctions.checkQuoteState(newList, oldMap);
        CPQQuoteTriggerFunctions.updateQuoteLineTranslations(newList, oldMap); //SA-591
    }

    public override void afterDelete() {

    }

}