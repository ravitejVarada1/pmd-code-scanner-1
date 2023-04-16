// class to represent location-specific data
// each instance carries subscription and quote data relevant to the quote data object this corresponds to
// we are capturing removed quote line data even though we don't currently use it in case of future enhancement

public class LocationDataObject {

    static final String CPQ_SUB = 'CpqSub';
    static final String QUOTE_EXISTING = 'Existing';
    static final String QUOTE_ADDED = 'Added';
    static final String QUOTE_REMOVED = 'Removed';

    public String accountName;
    public Set<String> locationErrorSet = new Set<String>();

    public List<SBQQ__Subscription__c> cpqSubList = new List<SBQQ__Subscription__c>();

    // Categorize the quote lines into a map of existing, additions, and removals
    public Map<String,List<SBQQ__QuoteLine__c>> quoteLineListMap = new Map<String,List<SBQQ__QuoteLine__c>>{
        QUOTE_EXISTING => new List<SBQQ__QuoteLine__c>(),
        QUOTE_ADDED => new List<SBQQ__QuoteLine__c>(),
        QUOTE_REMOVED => new List<SBQQ__QuoteLine__c>()
    };

    // Map of product ids that this current location has categorized by subs/existing/additions/removals
    public Map<String,Set<Id>> productIdSetMap = new Map<String,Set<Id>>{
        CPQ_SUB => new Set<Id>(),
        QUOTE_EXISTING => new Set<Id>(),
        QUOTE_ADDED => new Set<Id>(),
        QUOTE_REMOVED => new Set<Id>()
    };

    // Map of product ids that require validating
    public Map<String,Set<Id>> validationProdIdSetMap = new Map<String,Set<Id>>{
        CPQ_SUB => new Set<Id>(),
        QUOTE_EXISTING => new Set<Id>(),
        QUOTE_ADDED => new Set<Id>(),
        QUOTE_REMOVED => new Set<Id>()
    };

    public Set<String> duplicateProductNames = new Set<String>();
    public Set<Id> duplicateValidationProdIds = new Set<Id>();


    
    public void addLine(SBQQ__QuoteLine__c quoteLine, String quoteType) {
        Id productId = quoteLine.SBQQ__Product__c;

        quoteLineListMap.get(quoteType).add(quoteLine);

        Set<Id> matchingValidationProdIds = QuoteValidationHelper.getMatchingValidationProductIds(quoteLine);

        if (quoteType != QUOTE_REMOVED) {
            if (getHasProductIds().contains(productId)) {
                System.debug('Add product to duplicateProductNames : '+quoteLine.SBQQ__ProductName__c);
                duplicateProductNames.add(quoteLine.SBQQ__ProductName__c);
            }
            Set<Id> dupeVProdIds = Utilities.getCommonIds(getHasValidationProductIds(), matchingValidationProdIds);
            duplicateValidationProdIds.addAll(dupeVProdIds);
        }
        validationProdIdSetMap.get(quoteType).addAll(matchingValidationProdIds);
        productIdSetMap.get(quoteType).add(productId);
    }

    public void addLine(SBQQ__Subscription__c cpqSub) {
        Id productId = cpqSub.SBQQ__Product__c;

        cpqSubList.add(cpqSub);
        System.debug('Adding cpqSub = '+cpqSub);
        if (getHasProductIds().contains(productId) && cpqSub.Product_Code__c != 'CG-BASE') {
            System.debug('Adding to duplicatePRoductNames : '+cpqSub.Product_Code__c);
            duplicateProductNames.add(cpqSub.SBQQ__ProductName__c);
        }
        Set<Id> matchingValidationProdIds = QuoteValidationHelper.getMatchingValidationProductIds(cpqSub);
        duplicateValidationProdIds.addAll(Utilities.getCommonIds(getHasValidationProductIds(), matchingValidationProdIds));
        
        productIdSetMap.get(CPQ_SUB).add(productId);
        validationProdIdSetMap.get(CPQ_SUB).addAll(matchingValidationProdIds);
    }

    public Set<Id> getHasProductIds() {
        System.debug('Firing getHasProductIds method');
        Set<Id> returnSet = new Set<Id>(productIdSetMap.get(CPQ_SUB));
        returnSet.addAll(productIdSetMap.get(QUOTE_EXISTING));
        returnSet.addAll(productIdSetMap.get(QUOTE_ADDED));
        System.debug('returning from getHasProductIds method: '+returnSet);
        return returnSet;
    }

    public Set<Id> getHasValidationProductIds() {
        Set<Id> returnSet = new Set<Id>(validationProdIdSetMap.get(CPQ_SUB));
        returnSet.addAll(validationProdIdSetMap.get(QUOTE_EXISTING));
        returnSet.addAll(validationProdIdSetMap.get(QUOTE_ADDED));
        return returnSet;
    }

    public Set<Id> getHasValidationProductIdsInQuote() {
        Set<Id> returnSet = new Set<Id>(validationProdIdSetMap.get(QUOTE_EXISTING));
        returnSet.addAll(validationProdIdSetMap.get(QUOTE_ADDED));
        return returnSet;
    }

    public List<SBQQ__QuoteLine__c> getHasQuoteLines() {
        List<SBQQ__QuoteLine__c> returnList = new List<SBQQ__QuoteLine__c>(quoteLineListMap.get(QUOTE_ADDED));
        returnList.addAll(quoteLineListMap.get(QUOTE_EXISTING));
        return returnList;
    }
}