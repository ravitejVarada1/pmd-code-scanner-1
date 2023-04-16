public without sharing class QuoteVal_QuoteValidator {

    public static final String BASE_BUNDLE_PROD_CODE = 'CG-BASE';

    // error constants for errors evaluted by apex logic
    static final String ERROR_ALREADY_SUBSCRIBED = 'ALREADY_SUBSCRIBED';

    // maps to capture data from quote validation custom metadata into a usable format
    static final Map<Id, Quote_Validation_Settings_Product__mdt> VALIDATION_PROD_MAP = QuoteVal_ErrorObject.VALIDATION_PROD_MAP;
    static final Map<String, QuoteVal_ErrorObject> VALIDATION_ERROR_MAP = QuoteVal_ErrorObject.VALIDATION_ERROR_MAP;
    
    static final String VPRODTYPE_SELECTED = QuoteVal_ErrorObject.VPRODTYPE_SELECTED;
    static final String VPRODTYPE_REQUIRED = QuoteVal_ErrorObject.VPRODTYPE_REQUIRED;
    static final String VPRODTYPE_EXCLUDED = QuoteVal_ErrorObject.VPRODTYPE_EXCLUDED;

    static final String CPQ_SUB = 'CpqSub';
    static final String QUOTE_EXISTING = 'Existing';
    static final String QUOTE_ADDED = 'Added';
    static final String QUOTE_REMOVED = 'Removed';

    // **************************************************** MAIN METHOD ********************************************************* //
    // Called by quote handler to return an error string for each quote with validation errors
    public static Map<Id,String> getQuoteErrorMap(Set<Id> quoteIds) {
        Map<Id,String> quoteErrorMap = new Map<Id,String>();

        if(quoteIds.isEmpty()) {
            return quoteErrorMap;
        }

        // getQuoteDataList() both compiles quote information and checks quote-level validation
        for(QuoteVal_QuoteDataObject quoteData : getQuoteDataList(quoteIds)) {

            List<String> locationErrors = new List<String>();

            // add string for any quote level errors
            if(!quoteData.quoteErrorSet.isEmpty()) {
                locationErrors.add('Quote Level Errors:\n-- '+String.join((Iterable<String>)quoteData.quoteErrorSet, '\n-- ')+'\n');
            }

            // add string for any location level errors
            for(QuoteVal_LocationDataObject locationData : quoteData.locationDataMap.values()) {
                System.debug('QV::// add string for any location level errors');                
                locationData.locationErrorSet = addLocationErrors(locationData, quoteData);
                System.debug('QV::loc errorset : ' + locationData.locationErrorSet);
                if(!locationData.locationErrorSet.isEmpty()) {
                    locationErrors.add('Account: '+locationData.accountName+'\n> '+
                        String.join((Iterable<String>)locationData.locationErrorSet, '\n> '));
                }
            }

            // concatenate all errors into a single string for the quote
            if(!locationErrors.isEmpty()) {
                quoteErrorMap.put(quoteData.quote.Id, String.join(locationErrors, '\n')+'\n');
            }
        }

        return quoteErrorMap;
    }

    // compile quote information and check quote-level validations
    // this will populate an instance of QuoteDataObject for each quote and QuoteVal_LocationDataObject for each location
    static List<QuoteVal_QuoteDataObject> getQuoteDataList(Set<Id> quoteIds) {
        
        Map<Id,QuoteVal_QuoteDataObject> quoteDataObjectByQuoteId = new Map<Id,QuoteVal_QuoteDataObject>();

        if(quoteIds.isEmpty()) {
            return quoteDataObjectByQuoteId.values();
        }

        Set<Id> ffAccIds = new Set<Id>();
        Set<Id> skipSubscriptionIds = new Set<Id>();

        for(SBQQ__Quote__c quote : QuoteSelector.getQuotesWithQuoteLines(quoteIds)) {
            // Initialize a new quote data object
            Id quoteId = quote.Id;
            QuoteVal_QuoteDataObject quoteData = new QuoteVal_QuoteDataObject();
            quoteData.quote = quote;

            // Loop through quote lines of the quote to categorize the lines by action type within the quote data object
            for(SBQQ__QuoteLine__c quoteLine : quote.SBQQ__LineItems__r) {
                Id ffAccountId = quoteLine.Fulfillment_Account__c;
                if(ffAccountId == null) { continue; }
                ffAccIds.add(ffAccountId);

                // Initialize variables to store relevent quote line data points
                Id productId = quoteLine.SBQQ__Product__c;
                String productCode = quoteLine.SBQQ__ProductCode__c;
                String productName = quoteLine.SBQQ__ProductName__c;
                Id upgradedSubId = quoteLine.SBQQ__UpgradedSubscription__c;
                Id renewedSubId = quoteLine.SBQQ__RenewedSubscription__c;
                Double qty = quoteLine.SBQQ__Quantity__c;

                Boolean isBaseBundle = (productCode == BASE_BUNDLE_PROD_CODE);
                Boolean hasExistingSub = (upgradedSubId != null || renewedSubId != null);
                Boolean isRemoval = (qty == 0 && hasExistingSub);
                Boolean isAmendmentRemoval = (isRemoval && upgradedSubId != null);

                // Get the location data object within the quote data object
                QuoteVal_LocationDataObject locationData = quoteData.getLocationData(ffAccountId);
                
                skipSubscriptionIds.addAll(new Set<Id>{upgradedSubId,renewedSubId});

                // Skip data capturing for base bundles or 0 quantity additions
                if( (qty == 0 && !isRemoval) || isBaseBundle) {
                    continue;
                }

                if(isRemoval) {
                    locationData.addLine(quoteLine, QUOTE_REMOVED);
                } else if (hasExistingSub) {
                    locationData.addLine(quoteLine, QUOTE_EXISTING);
                } else {
                    locationData.addLine(quoteLine, QUOTE_ADDED);
                }
            }
            quoteDataObjectByQuoteId.put(quoteId, quoteData);
            System.debug('QV::quoteDataObjectByQuoteId ' +quoteDataObjectByQuoteId);
        }

        // add location data for cpq subscriptions for entire hierarchy
        Map<Id, Account> ffAccountsAndSubsById = getLocationWithSubscriptionsMap(ffAccIds, skipSubscriptionIds);

        // Loop through the quote data objects 
        for(Id quoteId : quoteDataObjectByQuoteId.keySet()) {
            QuoteVal_QuoteDataObject quoteData = quoteDataObjectByQuoteId.get(quoteId);
            Id ultimateParentId;

            for(Id ffAccount : quoteData.locationDataMap.keySet()) {
                QuoteVal_LocationDataObject locationData = quoteData.getLocationData(ffAccount);

                if(!ffAccountsAndSubsById.containsKey(ffAccount)) { continue; }
                Account location = ffAccountsAndSubsById.get(ffAccount);
                locationData.accountName = location.Name;
                // Assign ultimateParentId. If the location ult parent isn't null, then assign ult parent acc otherwise the location is ult parent
                if(ultimateParentId == null && location.Ultimate_Parent_Account__c != null) {
                    ultimateParentId = location.Ultimate_Parent_Account__c;
                } else {
                    ultimateParentId = location.Id;
                }
                System.debug('QV::cpq subs here: '+location.CPQ_Subscriptions_Fulfillment__r);
                // Record the cpq subs at this location within the quote data object
                for(SBQQ__Subscription__c cpqSub : location.CPQ_Subscriptions_Fulfillment__r) {
                    locationData.addLine(cpqSub);
                }
            }

            QuoteVal_LocationDataObject locationGroupData = quoteData.locationGroupData;
            Set<Id> groupCPQSubVProdIds = locationGroupData.validationSettingsProductIdsByAction.get(CPQ_SUB);

            // Loop through the accounts in the hierarchy then go through the subscriptions of each account and check for null terminated date
            for(Account location : ffAccountsAndSubsById.values()) {
                if(location.id == ultimateParentId || location.Ultimate_Parent_Account__c == ultimateParentId) {
                    for(SBQQ__Subscription__c cpqSub : location.CPQ_Subscriptions_Fulfillment__r) {
                        if(cpqSub.SBQQ__TerminatedDate__c == null) {
                            groupCPQSubVProdIds.addAll(QuoteVal_ValidationHelper.getMatchingValidationProductIds(cpqSub));
                        }
                    }
                }
            }
        }

        return quoteDataObjectByQuoteId.values();
    }

    // add location-specific errors, based on configuration metadata
    static Set<String> addLocationErrors(QuoteVal_LocationDataObject locationData, QuoteVal_QuoteDataObject quoteData) {

        Set<String> returnSet = new Set<String>();
        String locationName = locationData.accountName;
        System.debug('QV::inside addLocationErrors '+locationName);
        // check each active, configured validation error
        for(QuoteVal_ErrorObject vErrorData : VALIDATION_ERROR_MAP.values()) {
            String vErrorType = vErrorData.vErrorType;
            String vErrorName = vErrorData.vErrorName;
            String errorMessage = vErrorData.vErrorMessage;
            Set<String> errorProdNames = new Set<String>();
            Set<Id> errorVProdIds = new Set<Id>();
            System.debug('QV::looping through : '+vErrorName);

            if(vErrorData.vErrorType == 'Apex Logic') {
                System.debug('QV::Apex Logic');
                if(vErrorName == ERROR_ALREADY_SUBSCRIBED) {
                    System.debug('QV::dup prod names = ' + locationData.duplicateProductNames);
                    errorProdNames.addAll(locationData.duplicateProductNames);
                }
                
                for(String prodName : errorProdNames) {
                    returnSet.add(errorMessage.replaceAll('<SELECTED>', prodName));
                }

                continue;
            }

            // get all location validation product ids
            // these are products associated to the loation that correspond to configured validation products
            Set<Id> locationVProdIds = locationData.getHasValidationProductIds();

            if (vErrorType == 'Separate Contract') {
                System.debug('QV::is Separate Contract');
                // for 'Separate Contract' check, only look at products on the quote, not all cpq subscriptions
                locationVProdIds = locationData.getValidationSettingsProductIdsInQuote();
                System.debug('locationVProdIds change to == ' + locationVProdIds);
            }

            // get the set of validation products for this location that match the current error we are checking
            Set<Id> matchedVProdIds = Utilities.getCommonIds(locationVProdIds, vErrorData.getVProdIdsByType(VPRODTYPE_SELECTED));
            System.debug('matchedVProdIds == ' + matchedVProdIds);
            
            if(matchedVProdIds.isEmpty()) {
                continue;
            }

            switch on vErrorType {
                when 'Product Dependency' {
                    System.debug('Product Dependency');
                    Set<Id> excludedVProdIds = Utilities.getCommonIds(locationVProdIds, vErrorData.getVProdIdsByType(VPRODTYPE_EXCLUDED));
                    Set<Id> requiredVProdIds = Utilities.getCommonIds(locationVProdIds, vErrorData.getVProdIdsByType(VPRODTYPE_REQUIRED));
                    // Add error if fulfillment account meets either of the following criteria:
                    // 1) Required products don't exist for this particular error
                    // 2) Excluded products exist for this particular error
                    if(requiredVProdIds.isEmpty() || !excludedVProdIds.isEmpty()) {
                        errorVProdIds.addAll(matchedVProdIds);
                        System.debug('errorVProdIds === '+errorVProdIds);
                    }
                }
                when 'One Per Location' {
                    System.debug('QV::One Per Location = '+locationData.duplicateValidationProdIds);
                    errorVProdIds.addAll(Utilities.getCommonIds(matchedVProdIds, locationData.duplicateValidationProdIds));
                }
                when 'Separate Contract' {
                    Boolean isError = matchedVProdIds.size() > 1;
                    System.debug('isError == ' + isError);
                    if(!isError) {
                        for(Id vProdId : matchedVProdIds) {
                            for(SBQQ__QuoteLine__c quoteLine : locationData.getHasQuoteLines()) {
                                if(!QuoteVal_ValidationHelper.getMatchingValidationProductIds(quoteLine).contains(vProdId)) {
                                    isError = true;
                                    break;
                                }
                            }
                            if(isError) {
                                break;
                            }
                        }
                    }

                    if(isError) {
                        errorVProdIds.addAll(matchedVProdIds);
                        System.debug('errorVProdIds == ' + errorVProdIds);
                    }
                }
                when 'Group Product Dependency' {
                    System.debug('QV::Group Product Dependency');
                    Set<Id> locationGroupVProdIds = quoteData.getHasGroupValidationProductIds();

                    Set<Id> requiredVProdIds = Utilities.getCommonIds(locationGroupVProdIds, vErrorData.getVProdIdsByType(VPRODTYPE_REQUIRED));

                    if(requiredVProdIds.isEmpty()) {
                        errorVProdIds.addAll(matchedVProdIds);
                    }
                }
            }

            for(Id vProdId : errorVProdIds) {
                returnSet.add(errorMessage.replaceAll('<SELECTED>', VALIDATION_PROD_MAP.get(vProdId).MasterLabel));
            }
        }

        return returnSet;
    }

    // get a map of locations with all active or pending cpq subscriptions
    static Map<Id,Account> getLocationWithSubscriptionsMap(Set<Id> ffAccIds, Set<Id> skipSubscriptionIds) {
        if (ffAccIds.isEmpty()) {
            return new Map<Id,Account>();
        }

        Set<String> cpqSubStatuses = new Set<String>{'Activated','Pending Activation'};
        Set<Id> upIds = new Set<Id>();

        //compile ultimate parents, if no ultimate parent marked on the account, just add the account id
        for (Account ffAccount : [SELECT Id, Ultimate_Parent_Account__c FROM Account WHERE Id IN : ffAccIds]) {
            if (ffAccount.Ultimate_Parent_Account__c != null) {
                upIds.add(ffAccount.Ultimate_Parent_Account__c);
            } else  {
                upIds.add(ffAccount.Id);
            }
        }

        return new Map<Id,Account>(
            [SELECT Id, Name, Ultimate_Parent_Account__c, 
                (SELECT Id, SBQQ__Product__c, Product_Code__c, SBQQ__ProductName__c, SBQQ__Product__r.Family, SBQQ__TerminatedDate__c, SBQQ__Product__r.Product_Category__c,
                SBQQ__Product__r.Sub_Category__c FROM CPQ_Subscriptions_Fulfillment__r WHERE Activation_Status__c IN : cpqSubStatuses AND SBQQ__TerminatedDate__c = null
                AND SBQQ__Quantity__c > 0 AND Id NOT IN : skipSubscriptionIds)
            FROM Account WHERE Id IN : upIds OR Ultimate_Parent_Account__c IN : upIds]
        );
    }
}