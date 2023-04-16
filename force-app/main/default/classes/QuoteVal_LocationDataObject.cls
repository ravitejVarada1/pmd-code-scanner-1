// class to represent location-specific data
// each instance carries subscription and quote data relevant to the quote data object this corresponds to
// we are capturing removed quote line data even though we don't currently use it in case of future enhancement

public class QuoteVal_LocationDataObject {

    static final String CPQ_SUB = 'CpqSub';
    static final String QUOTE_EXISTING = 'Existing';
    static final String QUOTE_ADDED = 'Added';
    static final String QUOTE_REMOVED = 'Removed';

    public String accountName;
    public Set<String> locationErrorSet = new Set<String>();

    public List<SBQQ__Subscription__c> cpqSubList = new List<SBQQ__Subscription__c>();

    // Categorize the quote lines into a map of existing, additions, and removals
    public Map<String,List<SBQQ__QuoteLine__c>> quoteLinesByAction = new Map<String,List<SBQQ__QuoteLine__c>>{
        QUOTE_EXISTING => new List<SBQQ__QuoteLine__c>(),
        QUOTE_ADDED => new List<SBQQ__QuoteLine__c>(),
        QUOTE_REMOVED => new List<SBQQ__QuoteLine__c>()
    };

    // Map of product ids that this current location has categorized by subs/existing/additions/removals
    public Map<String,Set<Id>> productIdsByAction = new Map<String,Set<Id>>{
        CPQ_SUB => new Set<Id>(),
        QUOTE_EXISTING => new Set<Id>(),
        QUOTE_ADDED => new Set<Id>(),
        QUOTE_REMOVED => new Set<Id>()
    };

    // Map of product ids that require validating
    public Map<String,Set<Id>> validationSettingsProductIdsByAction = new Map<String,Set<Id>>{
        CPQ_SUB => new Set<Id>(),
        QUOTE_EXISTING => new Set<Id>(),
        QUOTE_ADDED => new Set<Id>(),
        QUOTE_REMOVED => new Set<Id>()
    };

    public Set<String> duplicateProductNames = new Set<String>();
    public Set<Id> duplicateValidationProdIds = new Set<Id>();

    
    public void addLine(SBQQ__QuoteLine__c quoteLine, String quoteLineAction) {
        Id productId = quoteLine.SBQQ__Product__c;

        quoteLinesByAction.get(quoteLineAction).add(quoteLine);

        Set<Id> validationSettingsProductIds = QuoteVal_ValidationHelper.getMatchingValidationProductIds(quoteLine);

        if (quoteLineAction != QUOTE_REMOVED) {
            if (getHasProductIds().contains(productId)) {
                System.debug('Add product to duplicateProductNames : '+quoteLine.SBQQ__ProductName__c);
                duplicateProductNames.add(quoteLine.SBQQ__ProductName__c);
            }
            Set<Id> dupeValSettingsProdIds = Utilities.getCommonIds(getHasValidationProductIds(), validationSettingsProductIds);
            duplicateValidationProdIds.addAll(dupeValSettingsProdIds);
        }
        validationSettingsProductIdsByAction.get(quoteLineAction).addAll(validationSettingsProductIds);
        productIdsByAction.get(quoteLineAction).add(productId);
    }

    public void addLine(SBQQ__Subscription__c cpqSub) {
        Id productId = cpqSub.SBQQ__Product__c;

        cpqSubList.add(cpqSub);
        System.debug('Adding cpqSub = '+cpqSub.Product_Code__c);
        if (getHasProductIds().contains(productId) && cpqSub.Product_Code__c != 'CG-BASE') {
            duplicateProductNames.add(cpqSub.SBQQ__ProductName__c);
        }
        Set<Id> validationSettingsProductIds = QuoteVal_ValidationHelper.getMatchingValidationProductIds(cpqSub);
        duplicateValidationProdIds.addAll(Utilities.getCommonIds(getHasValidationProductIds(), validationSettingsProductIds));
        
        productIdsByAction.get(CPQ_SUB).add(productId);
        validationSettingsProductIdsByAction.get(CPQ_SUB).addAll(validationSettingsProductIds);
    }
    
    /*
    Gets the product ids that this location has based on existing and added quote lines along with cpq subs
    */
    public Set<Id> getHasProductIds() {
        Set<Id> returnSet = new Set<Id>(productIdsByAction.get(CPQ_SUB));
        returnSet.addAll(productIdsByAction.get(QUOTE_EXISTING));
        returnSet.addAll(productIdsByAction.get(QUOTE_ADDED));
        System.debug('returning from getHasProductIds method: '+returnSet);
        return returnSet;
    }

    /*
    Gets the validation settings product ids that this location has based on existing and added quote lines along with cpq subs
    */
    public Set<Id> getHasValidationProductIds() {
        Set<Id> returnSet = new Set<Id>(validationSettingsProductIdsByAction.get(CPQ_SUB));
        returnSet.addAll(validationSettingsProductIdsByAction.get(QUOTE_EXISTING));
        returnSet.addAll(validationSettingsProductIdsByAction.get(QUOTE_ADDED));
        return returnSet;
    }

    /*
    Gets the validation settings product ids that this location has based on existing and added quote lines
    */
    public Set<Id> getValidationSettingsProductIdsInQuote() {
        Set<Id> returnSet = new Set<Id>(validationSettingsProductIdsByAction.get(QUOTE_EXISTING));
        returnSet.addAll(validationSettingsProductIdsByAction.get(QUOTE_ADDED));
        return returnSet;
    }

    /*
    Gets the quote line ids that this location has using existing and added quote lines
    */
    public List<SBQQ__QuoteLine__c> getHasQuoteLines() {
        List<SBQQ__QuoteLine__c> returnList = new List<SBQQ__QuoteLine__c>(quoteLinesByAction.get(QUOTE_ADDED));
        returnList.addAll(quoteLinesByAction.get(QUOTE_EXISTING));
        return returnList;
    }
}