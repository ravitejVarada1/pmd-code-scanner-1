/**
 * @description       : 
 * @author            : LZhao
 * @group             : 
 * @last modified on  : 11-17-2021
 * @last modified by  : LZhao
**/
public class CPQQuoteLineTriggerHandler extends TriggerHandler {

    private List<SBQQ__QuoteLine__c> newList;
    private Map<ID,SBQQ__QuoteLine__c> newMap;
    private List<SBQQ__QuoteLine__c> oldList;
    private Map<ID,SBQQ__QuoteLine__c> oldMap;

    public CPQQuoteLineTriggerHandler(){
        this.newList= (List<SBQQ__QuoteLine__c>) Trigger.new;
        this.newMap = (Map<Id,SBQQ__QuoteLine__c>) Trigger.newMap;
        this.oldList = (List<SBQQ__QuoteLine__c>) Trigger.old;
        this.oldMap = (Map<Id,SBQQ__QuoteLine__c>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        CPQQuoteLineTriggerFunctions.nullBaseBundleQuantity(newList, null);
        CPQQuoteLineTriggerFunctions.setFieldValues(newList);
        CPQQuoteLineTriggerFunctions.populateDiscountLanguage(newList);
        CPQQuoteLineTriggerFunctions.getAccountStatus(newList);
        CPQQuoteLineTriggerFunctions.checkCoopEligibility(newList);
        CPQQuoteLineTriggerFunctions.replacePlacementProductsOnRenewal(newList);
        CPQQuoteLineTriggerFunctions.setProrateMultiplierForCancellationQuoteLines(newList);//BR-8810
        CPQQuoteLineTriggerFunctions.validateCoOpProgramQuoteLines(newList,true);//SA-295
        CPQQuoteLineTriggerFunctions.checkBillingAccountBillingType(newList);
        CPQQuoteLineTriggerFunctions.validateFuturePendingSubs(newList, null);
        CPQQuoteLineTriggerFunctions.setIntroDiscountsOnRenewals(newList, oldMap); //DSS-385, DSS-428
        CPQQuoteLineTriggerFunctions.setRunQuoteValidationOnInsert(newList);
    }

    public override void beforeUpdate() {
        CPQQuoteLineTriggerFunctions.nullBaseBundleQuantity(newList, oldMap);
        CPQQuoteLineTriggerFunctions.quoteLineItemQuantity(newList, oldMap);
        CPQQuoteLineTriggerFunctions.populateDiscountLanguage(newList);
        CPQQuoteLineTriggerFunctions.setFieldValues(newList);
        CPQQuoteLineTriggerFunctions.getAccountStatus(newList);
        CPQQuoteLineTriggerFunctions.checkCoopEligibility(newList);
        CPQQuoteLineTriggerFunctions.setProrateMultiplierForCancellationQuoteLines(newList);//BR-8810
        CPQQuoteLineTriggerFunctions.validateCoOpProgramQuoteLines(newList,false);//SA-295
        CPQQuoteLineTriggerFunctions.checkBillingAccountBillingType(newList);
        CPQQuoteLineTriggerFunctions.validateFuturePendingSubs(newList, oldMap);
        CPQQuoteLineTriggerFunctions.setIntroDiscountsOnRenewals(newList, oldMap); //DSS-385, DSS-428
        CPQQuoteLineTriggerFunctions.setReteinNetTotalOnRenewalsToFalse(newList, oldMap); //DSS-428

    }
    
    public override void beforeDelete() {
        
    }

    public override void afterInsert() {
        CPQQuoteLineTriggerFunctions.applyBaseBundleDiscount(newMap, null);
        CPQQuoteLineTriggerFunctions.updateExpirationDate(newList, null);
        CPQQuoteLineTriggerFunctions.checkQuoteNumFulfillmentAccounts(newList);
        CPQQuoteLineTriggerFunctions.setDefaultPaymentMethod(newList); //BR-495
        CPQQuoteLineTriggerFunctions.setPreventAutomatedInvoiceToTrue(newList);//BR-8270
        CPQQuoteLineTriggerFunctions.setPaymentMethodOnOEMQuote(newList,null);//SA-295
        CPQQuoteLineTriggerFunctions.getTranslatedValues(newList); //SA-591
        CPQQuoteLineTriggerFunctions.setQuoteValidationErrors(newList);
    }

    public override void afterUpdate() {
        CPQQuoteLineTriggerFunctions.applyBaseBundleDiscount(newMap, oldMap);
        CPQQuoteLineTriggerFunctions.updateExpirationDate(newList, oldMap);
        CPQQuoteLineTriggerFunctions.checkFulfillmentAccountChange(newList, oldMap);
        CPQQuoteLineTriggerFunctions.setPreventAutomatedInvoiceToTrue(newList); //BR-8270
        CPQQuoteLineTriggerFunctions.setPaymentMethodOnOEMQuote(newList,oldMap);//SA-295
        CPQQuoteLineTriggerFunctions.setQuoteValidationErrors(newList);
    }

    public override void afterDelete() {
        CPQQuoteLineTriggerFunctions.checkQuoteNumFulfillmentAccounts(oldList);
    }
    
    public override void afterUndelete() {
        CPQQuoteLineTriggerFunctions.checkQuoteNumFulfillmentAccounts(newList);
    }
}