/**
* Helper class to clone & deep-clone records, replicating OOB managed-package functionality (not available on APIs)
* @author 	Nahuel Goldy
* @date 	  06/04/2021
* @module   BR-2169
*/
public without sharing class ObjectCloner {

  /**
  * Method to clone the quotes received as parameter, including their quotelines (expected to be embedded)
  * @author 	Nahuel Goldy
  * @date 	  06/04/2021
  * @param    List<SBQQ__Quote__c>: list of quotes to be cloned
  * @return 	Map<SBQQ__Quote__c,List<SBQQ__QuoteLine__c>>: map of cloned quotes (map keys) with their respective quotelines (map values)
  */
  public static Map<SBQQ__Quote__c,List<SBQQ__QuoteLine__c>> cloneQuotesWithRelatedQuoteLines(List<SBQQ__Quote__c> quotesToClone) {

    // map to store original quote ID + newly cloned quote
    Map<Id, SBQQ__Quote__c> quotesMap = new Map<Id, SBQQ__Quote__c>();
    // map to store original quote ID + newly cloned quotelines
    Map<Id,List<SBQQ__QuoteLine__c>> quoteLinesMap = new Map<Id,List<SBQQ__QuoteLine__c>>();
    // map to store old and new quote IDs
    Map<Id,Id> originalToClonedQuoteIdsMap = new Map<Id,Id>();
    // map to store old and new Base Bundle quoteline IDs
    Map<Id,Id> originalToClonedBaseBundleQLIdsMap = new Map<Id,Id>();

    for (SBQQ__Quote__c quote : quotesToClone) {
      SBQQ__Quote__c clonedQuote = quote.clone(false, true, false, false);
      // set Primary as false
      clonedQuote.SBQQ__Primary__c = false;
      clonedQuote.SBQQ__Source__c = quote.Id;
      clonedQuote.SBQQ__ExpirationDate__c = null;
      clonedQuote.SBQQ__StartDate__c = quote.SBQQ__Opportunity2__r.Cancellation_Case__r.Cancellation_Effective_Date__c;
      clonedQuote.SBQQ__EndDate__c = null;
      clonedQuote.SBQQ__Type__c = 'Cancellation';

      // put the cloned quote in the map
      quotesMap.put(quote.Id, clonedQuote);

      List<SBQQ__QuoteLine__c> clonedQuoteLines = new List<SBQQ__QuoteLine__c>();

      // process and build quote lines
      for(SBQQ__Quoteline__c ql : quote.SBQQ__LineItems__r) {
        SBQQ__Quoteline__c clonedQL = ql.clone(false, true, false, false);
        // notice the cloned QL remains linked to the previous quote at this point. This is changed after quotes are inserted below
        clonedQL.SBQQ__Source__c = ql.Id;
        clonedQL.Intro_Discount_Percentage__c = null;
        clonedQL.SBQQ__Quantity__c = 0;

        clonedQuoteLines.add(clonedQL);
      }

      // put the cloned quolines in the map
      quoteLinesMap.put(quote.Id, clonedQuoteLines);
    }

    List<SBQQ__Quote__c> clonedQuotesToInsert = new List<SBQQ__Quote__c>(quotesMap.values());
    List<SBQQ__QuoteLine__c> qlsToInsert = new List<SBQQ__QuoteLine__c>();

    // if there are cloned records, insert them
    if (!clonedQuotesToInsert.isEmpty()) {
      insert clonedQuotesToInsert;

      // build the ID translation map (original quote ID to cloned quote ID)
      for(SBQQ__Quote__c q : clonedQuotesToInsert) {
        originalToClonedQuoteIdsMap.put(q.SBQQ__Source__c, q.Id);
      }

      // update cloned QL's quote IDs
      for(Id originalQuoteId : quoteLinesMap.keyset()) {
        List<SBQQ__QuoteLine__c> qls = quoteLinesMap.get(originalQuoteId);
        for(SBQQ__QuoteLine__c ql : qls) {
          ql.SBQQ__Quote__c = originalToClonedQuoteIdsMap.get(originalQuoteId);
          qlsToInsert.add(ql);
        }
      }

      if (!qlsToInsert.isEmpty()) {
        insert qlsToInsert;
      }

      // build map of old-to-new quoteline IDs for Base Bundle lines
      for(SBQQ__QuoteLine__c ql : qlsToInsert) {
        if(ql.SBQQ__Product__r.Name == 'CG Base Bundle') {
          originalToClonedBaseBundleQLIdsMap.put(ql.SBQQ__Source__c, ql.Id);
        }
      }

      // build list and update requiredBy for non-base bundle quote lines
      List<SBQQ__QuoteLine__c> qlsToUpdateRequiredBy = new List<SBQQ__QuoteLine__c>();
      for(SBQQ__QuoteLine__c ql : qlsToInsert) {
        if(ql.SBQQ__Product__r.Name != 'CG Base Bundle') {
          ql.SBQQ__RequiredBy__c = originalToClonedBaseBundleQLIdsMap.get(ql.SBQQ__RequiredBy__c);
          qlsToUpdateRequiredBy.add(ql);
        }
      }

      if (!qlsToUpdateRequiredBy.isEmpty()) {
        update qlsToUpdateRequiredBy;
      }
      
    }

    return buildResultMap(clonedQuotesToInsert, qlsToInsert);

  }

  // helper method to build a map out of the lists of cloned quotes and quotelines, to return them all in the same data structure
  private static Map<SBQQ__Quote__c,List<SBQQ__QuoteLine__c>> buildResultMap(List<SBQQ__Quote__c> quotes, List<SBQQ__QuoteLine__c> quotelines) {
    Map<Id,SBQQ__Quote__c> quotesMap = new Map<Id,SBQQ__Quote__c>();
    Map<SBQQ__Quote__c,List<SBQQ__QuoteLine__c>> clonedResultsMap = new Map<SBQQ__Quote__c,List<SBQQ__QuoteLine__c>>();
    
    for(SBQQ__Quote__c quote : quotes) {
      quotesMap.put(quote.Id, quote);
      clonedResultsMap.put(quote, new List<SBQQ__QuoteLine__c>());
    }

    for(SBQQ__QuoteLine__c ql : quotelines) {
      List<SBQQ__QuoteLine__c> qls = clonedResultsMap.get(quotesMap.get(ql.SBQQ__Quote__c));
      qls.add(ql);
    }

    return clonedResultsMap;
  }

}