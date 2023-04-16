/**
 * @description       : 
 * @author            : LZhao
 * @group             : 
 * @last modified on  : 11/3/22
 * @last modified by  : Nik Finn
**/
public without sharing class CPQQuoteLineTriggerFunctions {

  public static final String QUOTE_TYPE_CANCELLATION = 'Cancellation';

  public static final String CGBASEBUNDLE_PRODCODE = 'CG-BASE';
  public static Date expirationDateConst = ConstantsUtil.STANDARD_QUOTE_EXPIRATION;
  public static final String BATCH_NUMBER_9 = 'Batch9';

  public static Set<String> quoteTypeRetainCurrentTotal = new Set<String>{'Amendment'};
  public static Map<Id, Product2> productMap = new Map<Id, Product2>([SELECT Id, Name, Product_Category__c, Description,
      Sub_Category__c FROM Product2]);

  //Map from Zuora Default Payment Method to Quote Payment Method
  public static Map<String, String> defaultPaymentMethodValueMap = new Map<String, String> {
        'CreditCard' => 'Credit Card',
        'Check' => 'Check',
        'ACH' => 'ACH',
        'BankTransfer' => 'Bank Transfer'
  };

    public static void setFieldValues(SBQQ__Quoteline__c[] qLines) {
        for (SBQQ__Quoteline__c qL : qLines) {
            qL.Contract_Total_Price__c = calculateTotalPrice(qL);
            if(qL.SBQQ__UpgradedSubscription__c != null) {
                qL.SBQQ__EndDate__c = null;
                if(qL.SBQQ__Existing__c) {
                    qL.Intro_Discount_Percentage__c = null;
                    qL.Intro_Discount_Period__c = null;
                }
            }
            if (Trigger.IsInsert) {
                if(qL.SBQQ__RenewedSubscription__c != null) {   
                    qL.SBQQ__Discount__c  = null;
                    qL.SBQQ__AdditionalDiscountAmount__c  = null;

                    //DSS-385 nulling values on renewals line inserts (avoid CPQ twin fields)
                    ql.Intro_Discount_Percentage__c = null;
                    ql.Intro_Discount_Period__c = null;
                }
            }

            if(!Test.isRunningTest()) {
                String desct = productMap.get(qL.SBQQ__Product__c).Description;
                
                if(desct != null && qL.SBQQ__ProductCode__c != 'CG-BASE'){
                    if(qL.SBQQ__Existing__c && qL.SBQQ__Quantity__c > 0) {
                        desct = desct.replace('Includes:', '<br/> Includes:'); 
                        desct = desct.replace('-', '<br/> -');
                        desct = desct.remove('- LeadAI (applicable to services starting 8/18/2022 and later)');
                        desct = desct.remove('- Onsite Ads (applicable to services starting 8/18/2022 and later)');
                        qL.SBQQ__Description__c = desct;
                        
                    } else if(qL.SBQQ__Existing__c && qL.SBQQ__Quantity__c == 0) {
                        qL.SBQQ__Description__c = desct.substringBefore('Includes');
                        
                    } else {
                        desct = desct.replace('Includes:', '<br/> Includes:'); 
                        desct = desct.replace('-', '<br/> -');
                        qL.SBQQ__Description__c = desct;
                    }
                } 
            }
        }
    }

    private static Decimal calculateTotalPrice(SBQQ__Quoteline__c ql) {

        Decimal netPrice = ql.SBQQ__NetPrice__c == null ? 0 : ql.SBQQ__NetPrice__c;
        Decimal qty = qL.SBQQ__Quantity__c == null ? 0 : ql.SBQQ__Quantity__c;

        if(ql.SBQQ__ProductCode__c != 'CG-BASE') {
            return netPrice * qty;
        } else {
            return 0;
        }
    }

    public static void applyBaseBundleDiscount(Map<Id,SBQQ__QuoteLine__c> qLineMap, Map<Id,SBQQ__QuoteLine__c> oldqLineMap) {

        Boolean isInsert = false;
        Set<Id> fulfillmentAcctIds = new Set<Id>();
        Set<Id> accountsNeedingBillingUpdate = new Set<Id>();
        Set<Id> quoteIds = new Set<Id>();
        Map<Id,SBQQ__QuoteLine__c> baseBundleMap = new Map<Id,SBQQ__QuoteLine__c>();
        //only add QLs to this map if they need to be updated to match base bundle
        Map<Id,SBQQ__QuoteLine__c[]> accountToQLMap = new Map<Id,SBQQ__QuoteLine__c[]>();
        SBQQ__QuoteLine__c[] updateQLs = new List<SBQQ__QuoteLine__c>();
        

        if (oldqLineMap == null) {
            isInsert = true;
        }

        for (Id qlId : qLineMap.keySet()) {

            SBQQ__QuoteLine__c ql = qLineMap.get(qlId);

            if (isInsert) {

                fulfillmentAcctIds.add(ql.Fulfillment_Account__c);
                quoteIds.add(ql.SBQQ__Quote__c);

            } else {

                SBQQ__QuoteLine__c oldQl = oldqLineMap.get(qlId);

                if (
                    ql.Intro_Discount_Percentage__c != oldQl.Intro_Discount_Percentage__c ||
                    ql.Intro_Discount_Period__c != oldQl.Intro_Discount_Period__c ||
                    ql.Billing_Account__c != oldQl.Billing_Account__c
                ) {
                    fulfillmentAcctIds.add(ql.Fulfillment_Account__c);
                    quoteIds.add(ql.SBQQ__Quote__c);

                    // BR-7795, used to determine if component lines need billing account from base trickled
                    if (ql.Billing_Account__c != oldQl.Billing_Account__c) {
                        accountsNeedingBillingUpdate.add(ql.Fulfillment_Account__c);
                    }
                }
            }
        }

        if (!quoteIds.isEmpty()) {
        //requery for all Quote lines for the fulfillment accounts and quotes from the quote lines in the trigger
        SBQQ__QuoteLine__c[] allQLs = [SELECT Id, SBQQ__Quote__c, Fulfillment_Account__c, Billing_Account__c,
                Intro_Discount_Percentage__c, Intro_Discount_Period__c, SBQQ__ProductCode__c FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c in: quoteIds AND Fulfillment_Account__c in: fulfillmentAcctIds];

        
            for (SBQQ__QuoteLine__c ql : allQLs) {
                //determine whether we need to process specific quote lines for fulfillment accounts based on CG base bundle discount
                if (
                    ql.SBQQ__ProductCode__c == CGBASEBUNDLE_PRODCODE && 
                    (
                        (
                            ql.Intro_Discount_Percentage__c != null &&
                            ql.Intro_Discount_Percentage__c != 0
                        ) ||
                        accountsNeedingBillingUpdate.contains(ql.FulFillment_Account__c)
                    )
                ) {
                    baseBundleMap.put(ql.Fulfillment_Account__c,ql);
                //add all non base bundle products into regular map for trickle down
                } else {
                    if (ql.SBQQ__ProductCode__c != CGBASEBUNDLE_PRODCODE) {
                        if (!accountToQLMap.containsKey(ql.Fulfillment_Account__c)) {
                            accountToQLMap.put(ql.Fulfillment_Account__c,new List<SBQQ__QuoteLine__c>());
                        }
                        accountToQLMap.get(ql.Fulfillment_Account__c).add(ql);
                    }
                }
            }

            for (Id fulfillmentId : baseBundleMap.keySet()) {
                SBQQ__QuoteLine__c baseBundle = baseBundleMap.get(fulfillmentId);

                Decimal introPercent = baseBundle.Intro_Discount_Percentage__c;
                Integer introPeriod = Integer.valueOf(baseBundle.Intro_Discount_Period__c);
                Id baseBundleBillingAccountId = baseBundle.Billing_Account__c;

                if (!accountToQLMap.containsKey(fulfillmentId)) { continue; }

                for (SBQQ__QuoteLine__c subLines : accountToQLMap.get(fulfillmentId)) {
                    if (introPercent != null) {
                        subLines.Intro_Discount_Percentage__c = introPercent;
                    }

                    if (introPeriod != null) {
                        subLines.Intro_Discount_Period__c = introPeriod;
                    }
                    
                    if (accountsNeedingBillingUpdate.contains(fulfillmentId)) {
                        subLines.Billing_Account__c = baseBundleBillingAccountId;
                    }

                    updateQLs.add(subLines);
                }
            }
        }
        
        if (!updateQLs.isEmpty()) { update updateQLs; }

    }

    public static void updateExpirationDate(SBQQ__QuoteLine__c[] qlList, Map<Id,SBQQ__QuoteLine__c> oldQLMap) {

        Boolean isInsert = false;
        Set<Id> quoteIds = new Set<Id>();
        SBQQ__Quote__c[] updateQuotes = new List<SBQQ__Quote__c>();

        //determine insert/update
        if (oldQLMap == null) { isInsert = true; }

        if (isInsert) {
            //process if we add a line with 100% discount where quote expiration is still next month
            for (SBQQ__QuoteLine__c ql : qlList) {
                if ( (ql.Intro_Discount_Percentage__c == 100 || ql.Retain_Current_Net_Total__c)
                        && ((ql.Quote_Expiration_Date__c != null 
                            && ql.Quote_Expiration_Date__c.Month() != ql.Quote_Creation_Date__c.Month())
                            || ql.Quote_Expiration_Date__c == null)) 
                {
                    quoteIds.add(ql.SBQQ__Quote__c);
                }
            }

        } else {

            for (SBQQ__QuoteLine__c ql : qlList) {
                Id qlId = ql.Id;
                SBQQ__QuoteLine__c oldQL = oldQLMap.get(qlId);
                if ( ((ql.Intro_Discount_Percentage__c == 100 && oldQL.Intro_Discount_Percentage__c != 100) ||
                    (ql.Retain_Current_Net_Total__c && !oldQL.Retain_Current_Net_Total__c)
                )
                    && (( ql.Quote_Expiration_Date__c != null 
                        && ql.Quote_Expiration_Date__c.Month() != ql.Quote_Creation_Date__c.Month()) 
                        || ql.Quote_Expiration_Date__c == null) ) 
                {
                    quoteIds.add(ql.SBQQ__Quote__c);
                } else if ((ql.Intro_Discount_Percentage__c != 100 && oldQL.Intro_Discount_Percentage__c == 100) ||
                    (!ql.Retain_Current_Net_Total__c && oldQL.Retain_Current_Net_Total__c) ) {
                    quoteIds.add(ql.SBQQ__Quote__c);
                }
            }
        }

        if (!quoteIds.isEmpty()) {
            for (SBQQ__Quote__c q : [SELECT Id, SBQQ__ExpirationDate__c, CreatedDate, SBQQ__StartDate__c,
                (SELECT Id, Intro_Discount_Percentage__c, Intro_Discount_Period__c FROM SBQQ__LineItems__r WHERE Intro_Discount_Percentage__c = 100 OR Retain_Current_Net_Total__c = true ) FROM SBQQ__Quote__c
                WHERE Id IN: quoteIds]) {

                if(q.SBQQ__ExpirationDate__c == null) {
                    q.SBQQ__ExpirationDate__c = expirationDateConst;
                }

                if (q.SBQQ__LineItems__r.isEmpty() && q.CreatedDate.Month() == q.SBQQ__ExpirationDate__c.Month()) {
                    q.SBQQ__ExpirationDate__c = expirationDateConst;
                } else if (!q.SBQQ__LineItems__r.isEmpty() && q.CreatedDate.Month() != q.SBQQ__ExpirationDate__c.Month() && q.SBQQ__StartDate__c.Month() == q.CreatedDate.Month()) {
                    q.SBQQ__ExpirationDate__c = q.SBQQ__ExpirationDate__c.toStartofMonth().addDays(-1);
                }
                updateQuotes.add(q);
            }
        }

        if (!updateQuotes.isEmpty()) {
            TriggerHandler.bypass('CPQQuoteTriggerHandler');
            update updateQuotes;
            TriggerHandler.clearBypass('CPQQuoteTriggerHandler');
        }

    }

    //- Jira: BR-495
    //Set Default Payment Method for Amendment and Renewal Quotes
    public static void setDefaultPaymentMethod(List<SBQQ__QuoteLine__c> newQuoteLines) {

        Map<Id,String> quotePaymentMethodMap = new Map<Id,String> ();
        Map<Id, List<SBQQ__QuoteLine__c>> quoteQuoteLineMap = new Map<Id, List<SBQQ__QuoteLine__c>> ();
        List<SBQQ__Quote__c> quotesToUpd = new List<SBQQ__Quote__c>();

        //Query Quote Lines with related fields
        List<SBQQ__QuoteLine__c> quoteLines = [SELECT Id, SBQQ__Quote__r.SBQQ__Type__c,
            SBQQ__Quote__r.Payment_Method__c, Billing_Account__r.Billing_Account_Zuora__c,
            Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c,
            SBQQ__Quote__c
            FROM SBQQ__QuoteLine__c
            WHERE Id IN :newQuoteLines
            ORDER BY SBQQ__Quote__c ASC];

        
        for (SBQQ__QuoteLine__c quoteLine : quoteLines) {        
            if (!quoteQuoteLineMap.containsKey(quoteLine.SBQQ__Quote__c)) {
                quoteQuoteLineMap.put(quoteLine.SBQQ__Quote__c, new List<SBQQ__QuoteLine__c>());
            }
            quoteQuoteLineMap.get(quoteLine.SBQQ__Quote__c).add(quoteLine);
        }

        for (Id quoteId : quoteQuoteLineMap.keySet()) {

            for (SBQQ__QuoteLine__c quoteLine : quoteQuoteLineMap.get(quoteId)) {

                if ((quoteLine.SBQQ__Quote__r.SBQQ__Type__c == ConstantsUtil.QUOTE_TYPE_AMENDMENT ||
                    quoteLine.SBQQ__Quote__r.SBQQ__Type__c == ConstantsUtil.QUOTE_TYPE_RENEWAL) &&
                    quoteLine.SBQQ__Quote__r.Payment_Method__c == null &&
                    quoteline.Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c != null) {

                    String defaultPaymentMethod =
                        defaultPaymentMethodValueMap.containsKey(quoteline.Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c) ?
                        defaultPaymentMethodValueMap.get(quoteline.Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c) : '' ;

                    quotePaymentMethodMap.put(quoteLine.SBQQ__Quote__c, defaultPaymentMethod);
                    break;
                }
            }
        }
        
        for (Id quoteId : quotePaymentMethodMap.keySet()) {
            quotesToUpd.add(new SBQQ__Quote__c(Id = quoteId, Payment_Method__c = quotePaymentMethodMap.get(quoteId)));
        }

        if (!quotesToUpd.isEmpty()) {
            TriggerHandler.bypass('CPQQuoteTriggerHandler');
            update quotesToUpd;
            TriggerHandler.clearBypass('CPQQuoteTriggerHandler');
        }
    }

    //- Jira: BR-782
    //Sends related quote Ids into methods that run when a new quote line is added or deleted
    public static void checkQuoteNumFulfillmentAccounts(List<SBQQ__QuoteLine__c> newQuoteLines){
        Set<ID> quoteIds = new Set<ID>();
        
        for (SBQQ__QuoteLine__c ql : newQuoteLines){
            if (ql.SBQQ__ProductOption__c == null){
                quoteIds.add(ql.SBQQ__Quote__c);
            }
        }
        
        updateNumFullfilmentAccount(quoteIds);
    }
    
    //- Jira: BR-782
    //Sends related quote Ids into methods that run when a a quote's fulfillment accout chages
    public static void checkFulfillmentAccountChange(List<SBQQ__QuoteLine__c> newQuoteLines, 
                                                    Map<ID,SBQQ__QuoteLine__c> oldQuoteLineMap)
    {
        Set<ID> quoteIds = new Set<ID>();
        for (SBQQ__QuoteLine__c ql : newQuoteLines){
            SBQQ__QuoteLine__c oldQl = oldQuoteLineMap.get(ql.Id);
            
            if (ql.Fulfillment_Account__c != oldQl.Fulfillment_Account__c
                && ql.SBQQ__ProductOption__c == null){
                quoteIds.add(ql.SBQQ__Quote__c);
            }
        }
        
        if (!quoteIds.isEmpty()){
            updateNumFullfilmentAccount(quoteIds);
        }
        
    }
    
    //- Jira: BR-782
    //Future method for updateNumFullfilmentAccount
    @future
    public static void updateNumFullfilmentAccountFuture(Set<ID> quoteIds){
        updateNumFullfilmentAccount(quoteIds);
    }
    
    //- Jira: BR-782
    //Queries quote ines and calculates the number of distinct fulfillment accounts on the quote
    public static void updateNumFullfilmentAccount(Set<ID> quoteIds){

        if (!System.isBatch() && !System.isFuture()){
            updateNumFullfilmentAccountFuture(quoteIds);
            return;
        }
        
        List<SBQQ__Quote__c> allQuotes = [SELECT Id, NumFulfillmentAccounts__c, (SELECT Fulfillment_Account__c
                                                                FROM SBQQ__LineItems__r
                                                                                WHERE SBQQ__ProductOption__c = null)
                                FROM SBQQ__Quote__c
                                WHERE Id in :quoteIds];
        
        List<SBQQ__Quote__c> quotesToUpdate = new List<SBQQ__Quote__c>();

        for (SBQQ__Quote__c q : allQuotes){
            Set<ID> fulfillmentAccounts = new Set<ID>();
            
            for (SBQQ__QuoteLine__c ql : q.SBQQ__LineItems__r){
                fulfillmentAccounts.add(ql.Fulfillment_Account__c);
            }
            
            Integer numFulfilmentAccountsReal = fulfillmentAccounts.size();
            
            if (q.NumFulfillmentAccounts__c != numFulfilmentAccountsReal){
                q.NumFulfillmentAccounts__c = numFulfilmentAccountsReal;
                quotesToUpdate.add(q);
            }
        }
        TriggerHandler.bypass('CPQQuoteTriggerHandler');
        update quotesToUpdate;
        TriggerHandler.clearBypass('CPQQuoteTriggerHandler');
    }
    
    //1542
    public static void nullBaseBundleQuantity(List<SBQQ__QuoteLine__c> qls, 
                                                    Map<Id, SBQQ__QuoteLine__c> qloldMap) {
        Set<Id> qlBaseBundleIds = new Set<Id>();  
        Set<Id> quoteIds = new Set<Id> ();                                           
        for (SBQQ__QuoteLine__c ql : qls) {
            if (((qloldMap == null) || (qloldMap.get(ql.Id).SBQQ__Quantity__c  != ql.SBQQ__Quantity__c ))
                    && (ql.SBQQ__RequiredBy__c == null && ql.SBQQ__Quantity__c != 0)) {
            
                qlBaseBundleIds.add(ql.Id);
                quoteIds.add(ql.SBQQ__Quote__c);
            }
            if (((qloldMap == null) || (qloldMap.get(ql.Id).SBQQ__Quantity__c  != ql.SBQQ__Quantity__c ))
                    && (ql.SBQQ__RequiredBy__c != null && ql.SBQQ__Quantity__c == 0.00)) {
                    
                qlBaseBundleIds.add(ql.SBQQ__RequiredBy__c);
                quoteIds.add(ql.SBQQ__Quote__c);
            }
        }

        if (!qlBaseBundleIds.isEmpty() && !quoteIds.isEmpty()){
            if(!System.isFuture() && !System.isBatch() &&
                        !System.isScheduled() && !System.isQueueable())
                updateQuoteLineItemQuantity(qlBaseBundleIds, quoteIds);
        }                                      
    }
    
    //Nulls the CG Base Bundle if all the consituent products on th quote are set to quantity = 0.
    public static void quoteLineItemQuantity(List<SBQQ__QuoteLine__c> newQuoteLines,
                                            Map<Id,SBQQ__QuoteLine__c> oldMap) {
        Set<Id> qlIds = new Set<Id>();
        Set<Id> quoteIds = new Set<Id> ();
        for (SBQQ__QuoteLine__c ql : newQuoteLines) {
            if (ql.SBQQ__RequiredBy__c != null && ql.SBQQ__Quantity__c != oldMap.get(ql.Id).SBQQ__Quantity__c) {
                qlIds.add(ql.SBQQ__RequiredBy__c);
                quoteIds.add(ql.SBQQ__Quote__c);
            }
        }

        if (!qlIds.isEmpty() && !quoteIds.isEmpty()) {
                if(!System.isFuture() && !System.isBatch() &&
                    !System.isScheduled() && !System.isQueueable())
                    updateQuoteLineItemQuantity(qlIds, quoteIds);
        }
    }

    @future
    public static void updateQuoteLineItemQuantity(Set<Id> qlIds, Set<Id> quoteIds) {
        List<SBQQ__QuoteLine__c> qlToBeUpdatedList = new List<SBQQ__QuoteLine__c>();
        Map<String, Decimal> qlMap = new Map<String, Decimal>();
        for (SBQQ__QuoteLine__c ql : [SELECT Id, SBQQ__Quantity__c,SBQQ__RequiredBy__c
                                        FROM SBQQ__QuoteLine__c
                                        WHERE SBQQ__RequiredBy__c IN :qlIds
                                        AND SBQQ__Quote__c IN :quoteIds]) {

            Decimal quantity = ql.SBQQ__Quantity__c == null ? 0.00 : ql.SBQQ__Quantity__c;
            if (qlMap.containsKey(ql.SBQQ__RequiredBy__c)) {
                qlMap.put(ql.SBQQ__RequiredBy__c, qlMap.get(ql.SBQQ__RequiredBy__c)+quantity);
            }else{
                qlMap.put(ql.SBQQ__RequiredBy__c,quantity);
            }
        }

        // checking if all the  add on prodouct quantity is zero then update the base bundle with 0 quantity.
        for (String recordID : qlMap.keyset()) {
            if (recordID != null && qlMap.get(recordID) == 0.00) {
                SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c();
                ql.Id = recordID;
                ql.SBQQ__Quantity__c = 0.00;
                qlToBeUpdatedList.add(ql);
            }
        }
        if (!qlToBeUpdatedList.isempty()) {
            update qlToBeUpdatedList;
        }
    }

    // BR-2870, BR-3292
    // This will populate what discount language to use per quote line. 
    // The field CongaClause__c will determine which clause to use from the Clause object (APXT_Redlining__Clause__c)
    public static void populateDiscountLanguage(List<SBQQ__Quoteline__c> quoteLines) {
        Set<Id> quoteIds = new Set<Id>();
        List<SBQQ__Quoteline__c> processLines = new List<SBQQ__QuoteLine__c>();
        for(SBQQ__Quoteline__c ql : quoteLines) {
            if(ql.CongaClause__c != null && ql.SBQQ__Quantity__c > 0) {
                quoteIds.add(ql.SBQQ__Quote__c);
                processLines.add(ql);
            }  else { 
                ql.Contract_Discount_Language__c = null; 
            }
        }

        if (!quoteIds.isEmpty()) {
            Map<Id,SBQQ__Quote__c> quoteMap = new Map<Id,SBQQ__Quote__c>([SELECT Id, SBQQ__StartDate__c, SBQQ__QuoteLanguage__c FROM SBQQ__Quote__c WHERE Id = :quoteIds]);
            Map<String,String> clauseMap = Test.isRunningTest() ? createTestClauseMap() : getClauseMap();
            for(SBQQ__Quoteline__c ql : processLines) {
                
                String clauseKey = 'OrderForm_'+quoteMap.get(ql.SBQQ__Quote__c).SBQQ__QuoteLanguage__c+ql.CongaClause__c;
                Date startDate = quoteMap.get(ql.SBQQ__Quote__c).SBQQ__StartDate__c;
                String formattedStartDate = Utilities.formatDate(datetime.newInstance(startDate.year(),startDate.month(),startDate.day()));
                String contractLanguage = clauseMap.get(clauseKey);

                if(contractLanguage.contains('[STARTDATE]')) {
                    contractLanguage = contractLanguage.replace('[STARTDATE]', formattedStartDate);
                }

                if(ql.Intro_Discount_Percentage__c != null && ql.Intro_Discount_Period__c != null) {
                    contractLanguage = contractLanguage.replace('[DISCOUNT_PERCENT]', String.valueOf(ql.Intro_Discount_Percentage__c.setScale(2, RoundingMode.HALF_UP)));
                    contractLanguage = contractLanguage.replace('[DISCOUNT_PERIOD]', String.valueOf((ql.Intro_Discount_Period__c-1).intValue()));
                }

                ql.Contract_Discount_Language__c = contractLanguage;
            }
        }
    }    

    // Gets all the clauses related to discounting. They are in the Clauses object and are all prefixed with 'Discount_'. Clause Type determines the language of the text.
    public static Map<String,String> getClauseMap() {
        Map<String,String> clauseMap = new Map<String,String>();
        for(APXT_Redlining__Clause__c c : [SELECT Name,APXT_Redlining__Text__c, APXT_Redlining__Clause_Type__r.Name
                                            FROM APXT_Redlining__Clause__c 
                                            WHERE Name LIKE 'Discount_%' AND APXT_Redlining__Clause_Type__r.Name LIKE 'OrderForm_%']) {
            String clauseKey = c.APXT_Redlining__Clause_Type__r.Name+c.Name;
            clauseMap.put(clauseKey,c.APXT_Redlining__Text__c);                          
        }
        return clauseMap;
    }

    public static Map<String,String> createTestClauseMap() {
        Map<String,String> clauseMap = new Map<String,String>{
            'OrderForm_EnglishDiscount_FutureDateIntroRateEqualTwoMonths'   => 'Anticipated Service Start Date: [STARTDATE]. [DISCOUNT_PERCENT]% off calendar month of Anticipated Service Start Date and of the following [DISCOUNT_PERIOD] calendar month',
            'OrderForm_EnglishDiscount_FutureDateIntroRateGreaterTwoMonths' => 'Anticipated Service Start Date: [STARTDATE]. [DISCOUNT_PERCENT]% off calendar month of Anticipated Service Start Date and of the following [DISCOUNT_PERIOD] calendar months',
            'OrderForm_EnglishDiscount_FutureDateIntroRateOneMonth'         => 'Anticipated Service Start Date: [STARTDATE]. [DISCOUNT_PERCENT]% off calendar month of Anticipated Service Start Date',
            'OrderForm_EnglishDiscount_FutureDateROMF'                      => 'Anticipated Service Start Date: [STARTDATE]. 100% off calendar month of Anticipated Service Start Date',
            'OrderForm_EnglishDiscount_FutureDateROMFPlus'                  => 'Anticipated Service Start Date: [STARTDATE]. 100% off calendar month of Anticipated Service Start Date and of the following 1 calendar month',
            'OrderForm_EnglishDiscount_IntroRateEqualTwoMonths'             => '[DISCOUNT_PERCENT]% off current calendar month and the following [DISCOUNT_PERIOD] month',
            'OrderForm_EnglishDiscount_IntroRateGreaterTwoMonths'           => '[DISCOUNT_PERCENT]% off current calendar month and the following [DISCOUNT_PERIOD] months',
            'OrderForm_EnglishDiscount_IntroRateOneMonth'                   => '[DISCOUNT_PERCENT]% off current calendar month',
            'OrderForm_EnglishDiscount_RetainCurrentTotal'                  => 'Rest of current calendar month at no additional charge',
            'OrderForm_EnglishDiscount_ROMF'                                => 'Rest of current calendar month free',
            'OrderForm_EnglishDiscount_ROMFPLUS'                            => 'Rest of current calendar month and next calendar month free'
        };
        return clauseMap;
    }

    //Get Fulfillment Accounts with related data
    private static Map<Id,Account> fulfillmentAccounts;
    public static Map<Id,Account> getfulfillmentAcccountsWithRelated(Set<Id> accIds) {
        if (fulfillmentAccounts == null) {
            fulfillmentAccounts = new Map<Id,Account>([
                SELECT Id, Name, Account_Status__c, (
                    SELECT Id, Provisioning_Status__c, SBQQ__StartDate__c, SBQQ__Quantity__c
                    FROM CPQ_Subscriptions_Fulfillment__r
                    ORDER BY SBQQ__StartDate__c DESC)
                FROM Account
                WHERE Id IN :accIds]);
        }
        return fulfillmentAccounts;
    }

    public static Set<Id> getFulfillmentAccountsFromQuoteLines(List<SBQQ__Quoteline__c> quotelines) {
        Set<Id> accList = new Set<Id>();
        for(SBQQ__Quoteline__c ql : quotelines) {
            accList.add(ql.Fulfillment_Account__c);
        }
        return accList;
    }
    
    // BR-4762 - Gets the account status and copies the value onto the quote line
    public static void getAccountStatus(List<SBQQ__Quoteline__c> quoteLines) {
        Set<Id> accIds = getFulfillmentAccountsFromQuoteLines(quoteLines);

        Map<Id,Account> accMap = new Map<Id, Account>();
        for(Account a : getfulfillmentAcccountsWithRelated(accIds).values()) {
            accMap.put(a.Id, a);
        }
        for(SBQQ__Quoteline__c ql : quoteLines) {
            if(qL.SBQQ__Quantity__c > 0 && qL.SBQQ__ProductOption__c == null) {
                if (accMap.containsKey(ql.Fulfillment_Account__c)) {
                    ql.Account_Status__c = accMap.get(ql.Fulfillment_Account__c).Account_Status__c;
                }
            }
        }
    }

    // SA-350 - Prevent moving foward on Amendments Quotes if there is at least one fulfillment account with future Pending Activations Subs associated.
    public static void validateFuturePendingSubs(List<SBQQ__Quoteline__c> quoteLines, Map<Id,SBQQ__Quoteline__c> oldMap) {    
        Set<Id> accIds = new Set<Id> ();
        for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
            if (quoteLine.Quote_Type__c == 'Amendment') {
                accIds.add(quoteLine.FulFillment_Account__c);
            }
        }
        // If no amendment lines, just return.
        if (accIds.isEmpty()) {
            return;
        }

        //Get Account Map with Related Subs
        Map<Id,Account> fulfillmentAccountMap = getfulfillmentAcccountsWithRelated(accIds);

        // Map of Fulfillment Account as key and Greatest Start Date of a Pending Activation CPQ Sub as value
        Map<Id,SBQQ__Subscription__c> futureSubsMap = new Map<Id,SBQQ__Subscription__c> ();
        for (Account  acc : fulfillmentAccountMap.values()) {
            List<SBQQ__Subscription__c> subList = fulfillmentAccountMap.get(acc.Id).CPQ_Subscriptions_Fulfillment__r;
            
            // If not related Subs, just continue
            if (subList == null || subList.isEmpty()) {
                continue;
            }
            for (SBQQ__Subscription__c sub : acc.CPQ_Subscriptions_Fulfillment__r) {
                if (sub.Provisioning_Status__c == 'Pending Activation' &&
                    sub.SBQQ__StartDate__c > System.today()) {
                        // Populate Map with the first Pending Sub in the List (notice it's orderded by Start Date DESC)
                        futureSubsMap.put(acc.Id, sub);
                        break;
                    }
            }
        }

        // loop through amendment lines and check if we need to prevent insertion or updates
        for (SBQQ__QuoteLine__c quoteLine : quoteLines) {

            if (!futureSubsMap.containsKey(quoteLine.FulFillment_Account__c)){
                continue;
            }

            SBQQ__Subscription__c sub = futureSubsMap.get(quoteLine.FulFillment_Account__c);
            String cannotAmendErrorMsg = fulfillmentAccountMap.get(quoteLine.FulFillment_Account__c).Name +
             ' has future Pending Activation Subscriptions starting on ' + futureSubsMap.get(quoteLine.FulFillment_Account__c).SBQQ__StartDate__c.format() +
             ', it cannot be amended';

            // Validation on Insertion (new lines)
            if (oldMap == null && !quoteLine.SBQQ__Existing__c) {
                    //SA-1224 Do not consider Pending Subs related to cancellations
                    if (sub.SBQQ__Quantity__c > 0 || (sub.SBQQ__Quantity__c < 0 && sub.SBQQ__StartDate__c > quoteLine.SBQQ__EffectiveStartDate__c)) {                        
                        // throw error
                        quoteLine.addError(cannotAmendErrorMsg);
                    }
            }
            // Validation on Updates (existing lines)
            if (oldMap != null &&
                 quoteLine.SBQQ__Quantity__c != oldMap.get(quoteLine.Id).SBQQ__Quantity__c  &&
                    !(quoteLine.SBQQ__Quantity__c == 0 && quoteLine.SBQQ__EffectiveStartDate__c == futureSubsMap.get(quoteLine.FulFillment_Account__c).SBQQ__StartDate__c) &&
                    (quoteLine.SBQQ__Quantity__c != quoteLine.SBQQ__PriorQuantity__c)) {
                        // throw error
                        quoteLine.addError(cannotAmendErrorMsg);
            }
        }
    }

    public static void checkCoopEligibility(List<SBQQ__Quoteline__c> quoteLines) {

        List<String> coopProducts = new List<String>{'Display Advertisement', 'Listings'};
        List<String> coopProgramNames = new List<String>();
        Set<Id> ffAcctIds = getFulfillmentAccountsFromQuoteLines(quoteLines);
        Set<Id> coopEligibleAccs = new Set<Id>();
        
        SObjectField picklistUsingGlobal = SObjectType.Co_op_Program__c.fields.Co_Op_OEM__c.getSObjectField();
        List<PicklistEntry> entries = picklistUsingGlobal.getDescribe().getPicklistValues();
        for(PicklistEntry pe : entries){
            coopProgramNames.add(pe.value.toLowerCase());
        }

        for(Service_Provider__c sp : [SELECT ID, Account__c, New_Makes_Sold__c FROM Service_Provider__c 
                                    WHERE Account__c IN :ffAcctIds AND New_Makes_Sold__c != null]) {
            List<String> newMakes = sp.New_Makes_Sold__c.split(', ');
            for(String s : newMakes) {
                if(coopProgramNames.contains(s.toLowerCase())) {
                    coopEligibleAccs.add(sp.Account__c);
                    break;
                }
            }                                   
        }
        
        for(SBQQ__Quoteline__c ql : quoteLines) {
            Boolean hasCoopProduct = coopProducts.contains(ql.SBQQ__ProductFamily__c);
            Boolean accCoopEligible = coopEligibleAccs.contains(ql.Fulfillment_Account__c);
            Boolean isNewLine = ql.SBQQ__Quantity__c > 0 && !ql.SBQQ__Existing__c;
            Boolean isUSAccount = ql.Billing_Country__c == 'US';
            if(hasCoopProduct && accCoopEligible && isNewLine && isUSAccount) {
                ql.Potential_Co_Op_Eligible__c = true;
            }
        }
    }

    public static void replacePlacementProductsOnRenewal(List<SBQQ__Quoteline__c> quotelines) {
        Set<Id> fulfillmentAccount = new Set<Id>();
        for(SBQQ__Quoteline__c ql : quotelines) {
            if (ql.Quote_Type__c =='Renewal') {
                fulfillmentAccount.add(ql.Fulfillment_Account__c);
            }
        }

        if (!fulfillmentAccount.isEmpty()) {
            Map<String,Double> getRenewalPricing = new Map<String,Double>();
            for(Pricing_Data__c  pd : [SELECT Id,Product_Code__c,Renewal_Price__c,Account__c FROM Pricing_Data__c 
                                        WHERE Active__c = true AND Account__c IN: fulfillmentAccount]){
                getRenewalPricing.put(pd.Product_Code__c+pd.Account__c,pd.Renewal_Price__c);
            }

            Map<String,Id> getProductId = new Map<String,Id>();
            Map<String,Id> getPriceBookId = new Map<String,Id>();
            for(Product2 p : [SELECT Id,ProductCode,Name FROM Product2]){
                getProductId.put(p.ProductCode,p.Id);
            }
            for(PricebookEntry pbe : [SELECT Id,Product2.ProductCode,Pricebook2Id,CurrencyIsoCode  FROM PricebookEntry WHERE Pricebook2.Name = 'Standard Price Book' 
                                        AND Product2Id IN: getProductId.values()]){
                getPriceBookId.put(pbe.Product2.ProductCode+pbe.CurrencyIsoCode,pbe.Id);
            }

            Map<String, String> productIDWithProcductOptionIdMap = new Map<String, String>();
            for( SBQQ__ProductOption__c prodOption : [SELECT Id, SBQQ__OptionalSKU__c FROM SBQQ__ProductOption__c WHERE 
                SBQQ__ConfiguredSKU__c IN (SELECT Id From Product2 WHERE NAME = 'CG Base Bundle')]){
                productIDWithProcductOptionIdMap.put(prodOption.SBQQ__OptionalSKU__c,prodOption.Id);
            }

            Map<String,String> mapRenewalProducts = new Map<String,String>();
            for(Renewal_Product_Map__mdt mdt : [Select Id, Account_Billing_Country__c, Existing_Product__c, Renewal_Product__c 
                                                FROM Renewal_Product_Map__mdt]){
                mapRenewalProducts.put(mdt.Existing_Product__c+mdt.Account_Billing_Country__c,mdt.Renewal_Product__c);
            }
            
            //Updating the Product, Product Option and PriceBookEntryID
            for(SBQQ__Quoteline__c ql : quotelines) {
                if(mapRenewalProducts.containsKey(ql.SBQQ__ProductCode__c+ql.Billing_Country__c)){
                    ql.SBQQ__Product__c = getProductId.get(mapRenewalProducts.get(ql.SBQQ__ProductCode__c+ql.Billing_Country__c));
                    ql.SBQQ__PricebookEntryId__c = getPriceBookId.get(mapRenewalProducts.get(ql.SBQQ__ProductCode__c+ql.Billing_Country__c)+ql.CurrencyIsoCode);
                    ql.SBQQ__ListPrice__c  = getRenewalPricing.get(mapRenewalProducts.get(ql.SBQQ__ProductCode__c+ql.Billing_Country__c)+ql.Fulfillment_Account__c);
                    ql.SBQQ__NetPrice__c = getRenewalPricing.get(mapRenewalProducts.get(ql.SBQQ__ProductCode__c+ql.Billing_Country__c)+ql.Fulfillment_Account__c);
                    if(productIDWithProcductOptionIdMap.containsKey(getProductId.get(mapRenewalProducts.get(ql.SBQQ__ProductCode__c+ql.Billing_Country__c)))){
                        ql.SBQQ__ProductOption__c =  productIDWithProcductOptionIdMap.get(getProductId.get(mapRenewalProducts.get(ql.SBQQ__ProductCode__c+ql.Billing_Country__c)));  
                    }
                }
            }
        }
    }   

    public static Set<Id> getBillingAccountsFromQuoteLines(List<SBQQ__Quoteline__c> quotelines) {
        Set<Id> accList = new Set<Id>();
        for(SBQQ__Quoteline__c ql : quotelines) {
            accList.add(ql.Billing_Account__c);
        }
        return accList;
    }

    public static Set<Id> getQuoteIdsFromQuoteLines(List<SBQQ__Quoteline__c> quotelines) {
        Set<Id> quoteIds = new Set<Id>();
        for(SBQQ__Quoteline__c ql : quotelines) {
            quoteIds.add(ql.SBQQ__Quote__c);
        }
        return quoteIds;
    }

    //BR-5351
    public static void checkBillingAccountBillingType(List<SBQQ__Quoteline__c> ql) {

        Set<Id> billingAccs = getBillingAccountsFromQuoteLines(ql);
        Set<Id> quoteIds = getQuoteIdsFromQuoteLines(ql);
        Map<Id, List<Zuora__SubscriptionProductCharge__c>> accToZspcMap = new Map<Id, List<Zuora__SubscriptionProductCharge__c>>();

        // Query Zuora Subscription Product Charge to determine billing type (Advance/Arrears)
        // Build a map of billing accounts to all the sub prod charge objects
        for(Zuora__SubscriptionProductCharge__c zspc : [SELECT ID, Zuora__BillingTiming__c, Zuora__Subscription__r.Zuora__InvoiceOwner__r.Zuora__Account__r.Id, 
                                                        Zuora__Subscription__r.Zuora__Account__r.Name, Zuora__Subscription__r.Zuora__CancelledDate__c
                                                        FROM Zuora__SubscriptionProductCharge__c 
                                                        WHERE Zuora__Model__c = 'Flat Fee Pricing' AND Zuora__Subscription__r.Zuora__Status__c = 'Active' 
                                                        AND Zuora__Subscription__r.Zuora__InvoiceOwner__r.Zuora__Account__c IN :billingAccs]) {

            Id billingAcc = zspc.Zuora__Subscription__r.Zuora__InvoiceOwner__r.Zuora__Account__r.Id;
            
            if(!accToZspcMap.containsKey(billingAcc)) {
                accToZspcMap.put(billingAcc, new List<Zuora__SubscriptionProductCharge__c>());
            }                                               
            accToZspcMap.get(billingAcc).add(zspc);
        }

        Map<Id, SBQQ__Quote__c> quoteMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Billing_Type__c, SBQQ__StartDate__c 
                                                                        FROM SBQQ__Quote__c WHERE Id IN :quoteIds]);

        for(SBQQ__Quoteline__c quoteline : ql) {
            
            String quoteBillingType = quoteMap.get(quoteline.SBQQ__Quote__c).Billing_Type__c;
            Date quoteStartDate = quoteMap.get(quoteline.SBQQ__Quote__c).SBQQ__StartDate__c;
            Id billingAcc = quoteline.Billing_Account__c;

            Boolean mismatch = false;

            if(accToZspcMap.containsKey(billingAcc)) {
                for(Zuora__SubscriptionProductCharge__c zspc : accToZspcMap.get(billingAcc)) {

                    String billingType = zspc.Zuora__BillingTiming__c == null ? 'Advance' : zspc.Zuora__BillingTiming__c.replace('In ','');
                    Date cancelDate = zspc.Zuora__Subscription__r.Zuora__CancelledDate__c;
                    Boolean checkCancelDate = (cancelDate == null || cancelDate > quoteStartDate); 

                    if(billingType != quoteBillingType && checkCancelDate) {
                        mismatch = true;
                    }                    
                }
            } else {
                if (quoteline.SBQQ__BillingType__c != quoteBillingType) {
                    mismatch = true;
                } else {
                    mismatch = false;
                }
            }
            
            if(mismatch) { 
                quoteline.Billing_Type_Mismatch__c = true;
            } else {
                quoteline.Billing_Type_MisMatch__c = false;
            }
        }
    }
    
    //BR-8270
    public static void setPreventAutomatedInvoiceToTrue(List<SBQQ__Quoteline__c> quoteLines) {
        Map<Id,Id> accIdToQuoteMap = new Map<Id,Id>();
        for(SBQQ__Quoteline__c ql : quoteLines) {
            if(ql.Billing_Account__c != null) {
                accIdToQuoteMap.put(ql.Billing_Account__c,ql.SBQQ__Quote__c);
            }
        }

        List<Account> accList = new List<Account>();        
        accList = [SELECT Id, Billing_Account_Zuora__r.Zuora__Batch__c FROM Account 
                   WHERE Id IN:accIdToQuoteMap.keySet() AND Billing_Account_Zuora__c != null];
        
        Set<Id> quoteIds = new Set<Id>();
        for(Account acc : accList){
            if(acc.Billing_Account_Zuora__r.Zuora__Batch__c == BATCH_NUMBER_9){
                quoteIds.add(accIdToQuoteMap.get(acc.Id));
            }
        }

        List<SBQQ__Quote__c> quoteList = [SELECT Id, Prevent_Automated_Initial_Invoice__c  
                                          FROM SBQQ__Quote__c WHERE Id IN:quoteIds];
        for(SBQQ__Quote__c q : quoteList){
            q.Prevent_Automated_Initial_Invoice__c = true;
        }
        TriggerHandler.bypass('CPQQuoteTriggerHandler');
        update quoteList;
        TriggerHandler.clearBypass('CPQQuoteTriggerHandler');
    }

    //BR-8810
    public static void setProrateMultiplierForCancellationQuoteLines(List<SBQQ__QuoteLine__c> newLines) {
        
        Set<Id> quoteIds = new Set<Id>();
        
        // loop on quote lines, filling up quoteToQuoteLineMap
        for (SBQQ__QuoteLine__c ql : newLines) {
            quoteIds.add(ql.SBQQ__Quote__c);
        }
        
        if(!quoteIds.isEmpty()){
            
            Map<Id,SBQQ__Quote__c> quoteMap = new Map<Id,SBQQ__Quote__c>([
                SELECT Id
                FROM SBQQ__Quote__c 
                WHERE Id IN:quoteIds
                AND SBQQ__Type__c =:QUOTE_TYPE_CANCELLATION
            ]);
            
            if(!quoteMap.isEmpty()){
                
                // loop on quote lines, to set prorate multiplier to 1 for cancellation quotes
                for (SBQQ__QuoteLine__c ql : newLines) {
                    
                    if(quoteMap.containskey(ql.SBQQ__Quote__c)){
                        //setting prorate multiplier on Quote Line to 1, for cancellation quote
                        ql.SBQQ__ProrateMultiplier__c = 1;
                    }
                }
                
            }    
            
        }
    }

    //SA-295,SA-869
    public static void validateCoOpProgramQuoteLines(List<SBQQ__Quoteline__c> quoteLines,Boolean isInsert) {
              
        Set<Id> quoteIds = new Set<Id>();
        Set<Id> qLineFulfillAcctIds = new Set<Id>();

        Map<Id,String> acctIdToCoOpPrograms = new Map<Id,String>();
        
        Map<String,Id> coOpProgramToOEMBillAcct = new Map<String,Id>();

        for(SBQQ__Quoteline__c ql : quoteLines){

            if(isInsert || (!isInsert && ql.SBQQ__Quantity__c > 0)){
                quoteIds.add(ql.SBQQ__Quote__c);
                qLineFulfillAcctIds.add(ql.Fulfillment_Account__c);
            }
        }
        
        if(quoteIds.isEmpty()){
          return;
        }

        Set<Id> cpqAmendmentQuoteIds = new Set<Id>();
        Map<Id,SBQQ__Quote__c> quoteMap = new Map<Id,SBQQ__Quote__c>();
        Set<String> quoteRelatedCoOpPrograms = new Set<String>();

        for(SBQQ__Quote__c cpqQ : [
            SELECT Id,Co_Op_Program_Opt_in__c,SBQQ__Type__c  
            FROM SBQQ__Quote__c 
            WHERE Id IN:quoteIds
            AND Co_Op_Program_Opt_in__c!=null 
            AND SBQQ__Type__c!=:QUOTE_TYPE_CANCELLATION
        ]){
            if(cpqQ.SBQQ__Type__c.equalsIgnoreCase(ConstantsUtil.QUOTE_TYPE_AMENDMENT)){
                cpqAmendmentQuoteIds.add(cpqQ.Id);
            }
            quoteMap.put(cpqQ.Id,cpqQ);
            quoteRelatedCoOpPrograms.add(cpqQ.Co_Op_Program_Opt_in__c);
        }

        if(quoteMap.isEmpty()){
            return;
        }

        List<Account> validateAccounts = new List<Account>();
        Map<Id,Account> superAccMap = new Map<Id,Account>();

        for(Account extBillAcc : [
            SELECT Id,Name,Co_Op_Program_Opt_in__c,Enrollment_Status__c,
            External_Dealer_ID__c,OEM_Billing_Account__c 
            FROM Account 
            WHERE Id IN:qLineFulfillAcctIds
        ]){
            
            superAccMap.put(extBillAcc.Id,extBillAcc);
            
            if(extBillAcc.Co_Op_Program_Opt_in__c!=null && quoteRelatedCoOpPrograms.contains(extBillAcc.Co_Op_Program_Opt_in__c)
            && extBillAcc.External_Dealer_ID__c!=null && extBillAcc.Enrollment_Status__c.equalsIgnoreCase(ConstantsUtil.EXTERNAL_BILL_ACC_ACTIVE_STATUS) 
            && extBillAcc.OEM_Billing_Account__c!=null){
                coOpProgramToOEMBillAcct.put(extBillAcc.Co_Op_Program_Opt_in__c,extBillAcc.OEM_Billing_Account__c);
                acctIdToCoOpPrograms.put(extBillAcc.Id,extBillAcc.Co_Op_Program_Opt_in__c);
                validateAccounts.add(extBillAcc);
            }
        }

        CoOpProgramUtils.processCoOpDefaultsAndValidations(isInsert,validateAccounts,quoteLines,quoteMap,
        acctIdToCoOpPrograms,coOpProgramToOEMBillAcct,superAccMap,cpqAmendmentQuoteIds);
    }

    //SA-295
    public static void setPaymentMethodOnOEMQuote(List<SBQQ__Quoteline__c> quoteLines,Map<Id,SBQQ__QuoteLine__c> oldqLineMap) {

        Map<Id,Id> quoteIdsToOEMBillingAcct = new Map<Id,Id>();

        for(SBQQ__Quoteline__c ql : quoteLines){

            if((ql.Billing_Account__c!=null && oldqLineMap == null)
            || (oldqLineMap!= null && ql.Billing_Account__c!=null && ql.Billing_Account__c!=oldqLineMap.get(ql.Id).Billing_Account__c)){
                quoteIdsToOEMBillingAcct.put(ql.SBQQ__Quote__c,ql.Billing_Account__c);
            }
        }

        if(!quoteIdsToOEMBillingAcct.isEmpty()){

            List<SBQQ__Quote__c> updateQuotes = new List<SBQQ__Quote__c>();

            Map<Id,Account> oemBillAccMap = new Map<Id,Account>([
                SELECT Id,Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c 
                FROM Account 
                WHERE Id IN:quoteIdsToOEMBillingAcct.values() 
                AND Billing_Account_Zuora__c!=null 
                AND Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c!=null
            ]);

            //only for Co-Op Program Quotes
            for(SBQQ__Quote__c cpqQ : [
                SELECT Id,Payment_Method__c 
                FROM SBQQ__Quote__c 
                WHERE Id IN:quoteIdsToOEMBillingAcct.keyset() 
                AND Co_Op_Program_Opt_in__c!=null
            ]){
                if(quoteIdsToOEMBillingAcct.containsKey(cpqQ.Id)){
                    Id billAcctId = quoteIdsToOEMBillingAcct.get(cpqQ.Id);
                    if(oemBillAccMap.containsKey(billAcctId)){

                        String payMethod = oemBillAccMap.get(billAcctId).Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c;

                        if(payMethod.equalsIgnoreCase('creditcard')){
                            payMethod = 'Credit Card';
                        }else if(payMethod.equalsIgnoreCase('banktransfer')){
                            payMethod = 'Bank Transfer';
                        }
                        cpqQ.Payment_Method__c = payMethod;
                        updateQuotes.add(cpqQ);
                    }
                }
            }

            if(!updateQuotes.isEmpty()){
                update updateQuotes;
            }
        }
    }

    //SA-591 Stamp Translated Product Name and Translated Product Description
    public static void getTranslatedValues(List<SBQQ__QuoteLine__c> newLines) { 
        Set<Id> quoteIds = new Set<Id> ();
        Set<Id> accIds = new Set<Id> ();
        for (SBQQ__Quoteline__c quoteLine : newLines) {
            if (!quoteLine.SBQQ__Existing__c) {
                quoteIds.add(quoteLine.SBQQ__Quote__c);
                accIds.add(quoteline.FulFillment_Account__c);
            }
        }

        if (!quoteIds.isEmpty()) {
            //Update translations for the non-existing product but also the other ones under same fulfillment account
            if (!Test.isRunningTest()) {
                updateQuoteLineTranslations(quoteIds, accIds);
            }
        }
    }

    @future
    public static void updateQuoteLineTranslations(Set<Id> quoteIds, Set<Id> fulAccIds) {

        //Get Map for Translated Product Name and Translated Prodocut Descriptions
        Map<String,String> productNameLangMap = Utilities.getTranslatedProductName();
        Map<String,String> productDescriptionLangMap = Utilities.getTranslatedProductDescription();
        List<SBQQ__Quoteline__c> quoteLinesToUpd = new List<SBQQ__Quoteline__c> ();

        // Query for Quote Lines where translations needs to be stamped
        for (SBQQ__Quoteline__c quoteLine : [
            SELECT Id, SBQQ__Quantity__c,Fulfillment_Account__c, SBQQ__Quote__r.SBQQ__QuoteLanguage__c,SBQQ__Quote__c,SBQQ__ProductCode__c
            FROM SBQQ__Quoteline__c
            WHERE SBQQ__Quote__c IN :quoteIds
            AND Fulfillment_Account__c IN :fulAccIds
            AND SBQQ__ProductCode__c != 'CG-BASE' ]) {

            // Build key and get Translated Product Description and Name
            String lineKey = quoteLine.SBQQ__Quote__r.SBQQ__QuoteLanguage__c + '-' + quoteLine.SBQQ__ProductCode__c;
            quoteLinesToUpd.add(new SBQQ__QuoteLine__c(Id = quoteLine.Id,
                Translated_Product_Name__c = productNameLangMap.get(lineKey),
                Translated_Product_Description__c = productDescriptionLangMap.get(lineKey)));
        }

        if (!quoteLinesToUpd.isEmpty()) {
            SBQQ.TriggerControl.disable();
            update quoteLinesToUpd;
            SBQQ.TriggerControl.enable();
        }
    }

    //DSS-385 Calculate Intro Discounts on Renewals looking at Renewed Subs
    public static void setIntroDiscountsOnRenewals(List<SBQQ__QuoteLine__c> newLines, Map<Id,SBQQ__QuoteLine__c> oldqLineMap) {

        Map<Id,SBQQ__Quoteline__c> renewedQuoteLinesMap = new Map<Id,SBQQ__Quoteline__c> ();
        Set<Id> fulAccIds = new Set<Id> ();
        for (SBQQ__QuoteLine__c quoteLine : newLines) {
            
            if (quoteLine.Quote_Type__c == 'Renewal' &&
                quoteline.Intro_Discount_Percentage__c != 100 &&
                quoteline.Intro_Discount_Percentage__c != null &&
                quoteline.Intro_Discount_Percentage__c != 0 && 
                (Trigger.isInsert || quoteline.Intro_Discount_Percentage__c != oldqLineMap.get(quoteLine.Id).Intro_Discount_Percentage__c)) {
                
                    // Only get renewal quote lines if they are not applicable for ROMF, ROMF+ (100% intro discount)
                    renewedQuoteLinesMap.put(quoteLine.Id, quoteLine);
                    fulAccIds.add(quoteLine.FulFillment_Account__c);
            }
        }
        
        if (renewedQuoteLinesMap.isEmpty()) {
            return;
        }

        // Query to get related Subscription Pricing
        List<SBQQ__Subscription__c> cpqSubList = [
            SELECT Id, Fulfillment_Account__c, Provisioning_Status__c, SBQQ__NetPrice__c, SBQQ__Product__r.Product_Category__c,
              SBQQ__Product__r.ProductCode, SBQQ__Product__r.Sub_Category__c, SBQQ__Quantity__c
            FROM SBQQ__Subscription__c
            WHERE Fulfillment_Account__c IN :fulAccIds
            AND SBQQ__Quantity__c > 0
            AND Provisioning_Status__c = 'Activated'
            AND SBQQ__Product__r.ProductCode != 'CG-BASE'
            ORDER BY Fulfillment_Account__c, SBQQ__Product__r.Product_Category__c, SBQQ__Product__r.Sub_Category__c
        ];

        if (cpqSubList.isEmpty()) {
            return;
        }

        //Build Map with product Key and Net price as value
        Map<String,Decimal> prodCategoryMap = new Map<String,Decimal> ();
        for (SBQQ__Subscription__c sub : cpqSubList) {
            String prodKey = getProductKey(sub);
            if (!prodCategoryMap.containsKey(prodKey)) {
                prodCategoryMap.put(prodKey, 0);
            }
            Decimal netPrice = prodCategoryMap.get(prodKey) + sub.SBQQ__NetPrice__c;
            prodCategoryMap.put(prodKey, netPrice);
        }


        for (SBQQ__QuoteLine__c quoteLine : renewedQuoteLinesMap.values()) {

            if (prodCategoryMap.containskey(getProductKey(quoteLine))) {
            
                Decimal renewalPrice = quoteLine.SBQQ__ListPrice__c;
                Decimal originalSubPrice = prodCategoryMap.get(getProductKey(quoteLine));

                if (renewalPrice == 0) continue;

                Decimal introDiscount = ((renewalPrice - originalSubPrice) / renewalPrice) * 100;

                // If Intro Discount is negative then null intro discount fields, othewise stamp result
                if (introDiscount <= 0) {
                    continue;
                } else {
                    quoteLine.Intro_Discount_Percentage__c = introDiscount;
                    quoteLine.Retain_Current_Net_Total__c = true;
                    
                    if (quoteLine.Product_Category__c == 'Digital Advertising') {
                        quoteLine.Retain_Current_Net_Total_Upsell__c = true;
                    }
                }
            }
        }
    }

    // DSS-428 Return product key based on product category/sub-category
    public static String getProductKey(SBQQ__Subscription__c sub) {
        
        String prodCategory = sub.SBQQ__Product__r.Product_Category__c;
        String prodSubCategory = sub.SBQQ__Product__r.Sub_Category__c;
        String fulfillmentAcc = sub.Fulfillment_Account__c;

        if (prodCategory == 'Digital Advertising' || prodCategory == 'Core Products') {
            return fulfillmentAcc + '-' + prodCategory;
        } else {
            return fulfillmentAcc + '-' + prodCategory + '-' + prodSubCategory;
        }
    }

    // DSS-428 Return product key based on product category/sub-category
    public static String getProductKey(SBQQ__QuoteLine__c quoteLine) {
        
        String prodCategory = quoteLine.Product_Category__c;
        String prodSubCategory = quoteLine.Product_Sub_Category__c;
        String fulfillmentAcc = quoteLine.Fulfillment_Account__c;

        if (prodCategory == 'Digital Advertising' || prodCategory == 'Core Products') {
            return fulfillmentAcc + '-' + prodCategory;
        } else {
            return fulfillmentAcc + '-' + prodCategory + '-' + prodSubCategory;
        }
    }

    //DSS-385 On Renewals set Retain Net Total to false if ROMF or ROMF+
    public static void setReteinNetTotalOnRenewalsToFalse(List<SBQQ__QuoteLine__c> newLines, Map<Id,SBQQ__QuoteLine__c> oldqLineMap) {

        Map<Id,SBQQ__Quoteline__c> renewedQuoteLinesMap = new Map<Id,SBQQ__Quoteline__c> ();
        for (SBQQ__QuoteLine__c quoteLine : newLines) {
            
            if (quoteLine.Quote_Type__c == 'Renewal' &&
                (quoteline.Intro_Discount_Percentage__c == 100 || quoteline.Intro_Discount_Percentage__c == null || quoteline.Intro_Discount_Percentage__c == 0) &&
                quoteLine.Retain_Current_Net_Total__c && quoteline.Intro_Discount_Percentage__c != oldqLineMap.get(quoteLine.Id).Intro_Discount_Percentage__c) {

                    renewedQuoteLinesMap.put(quoteLine.Id, quoteLine);
            }
        }
        
        if (renewedQuoteLinesMap.isEmpty()) {
            return;
        }

        //If ROMF or ROMF+, just set Retain Current Net Total to false
        for (SBQQ__QuoteLine__c quoteLine : renewedQuoteLinesMap.values()) {
            quoteLine.Retain_Current_Net_Total__c = false;            
            quoteLine.Retain_Current_Net_Total_Upsell__c = false;
        }
    }
    
    //SA-268 updates to insert event
    private static final Set<String> quoteTypesNoInsertValidation = new Set<String>{
        ConstantsUtil.QUOTE_TYPE_RENEWAL,
        ConstantsUtil.QUOTE_TYPE_CANCELLATION,
        ConstantsUtil.QUOTE_TYPE_TRIAL
    };

    public static Boolean runQuoteValidationOnInsert = false;
    
    //Check if the related quotes have any quote lines already committed to the database, if not
    //then the runQuoteValidationOnInsert Boolean becomes true, and the validation method runs in the after insert context
    //(Quote must not be an amendment or renewal and must be only quote in Trigger.New)
    public static void setRunQuoteValidationOnInsert(List<SBQQ__QuoteLine__c> quoteLineList){

        ID uniqueQuoteId;
        for (SBQQ__QuoteLine__c ql : quoteLineList){

            ID currentquoteId = ql.SBQQ__Quote__c;
            
            if (uniqueQuoteId == null){
                uniqueQuoteId = currentquoteId;
            }

            Boolean quoteIsRenewalOrAmendmentOrCancellation = quoteTypesNoInsertValidation.contains(ql.Quote_Type__c);
            Boolean multipleQuotesInTriggerNew = uniqueQuoteId != currentquoteId;
            
            if (quoteIsRenewalOrAmendmentOrCancellation || multipleQuotesInTriggerNew){
                return;
            }
        }
        
        Integer numExistingLines = [SELECT Count()
                                    FROM SBQQ__QuoteLine__c
                                    WHERE SBQQ__Quote__c = :uniqueQuoteId
                                    AND SBQQ__ProductCode__c != 'CG-BASE'
                                    LIMIT 1];
        System.debug(numExistingLines == 0);
        runQuoteValidationOnInsert = (numExistingLines == 0);
    }

    public static void setQuoteValidationErrors(List<SBQQ__QuoteLine__c> quoteLineList) {
        // Do we need some sort of skip quote validation mechanism?
        
        if(Trigger.isInsert && !runQuoteValidationOnInsert) {
            return;
        }
        System.debug('Firing setQuoteValidationErrors');

        Set<Id> quotesToValidate = (new Map<Id, SBQQ__Quote__c>([SELECT Id, SBQQ__Status__c, SBQQ__MasterContract__c, SBQQ__Type__c
                                                                FROM SBQQ__Quote__c 
                                                                WHERE Id IN : getQuoteIdsFromQuoteLines(quoteLineList) AND SBQQ__Type__c NOT IN : quoteTypesNoInsertValidation
                                                                AND SBQQ__Status__c != 'Expired'])).keySet();

        if (!Test.isRunningTest()) {    // allow test code to run on newly generated quotes
            //quoteIds.removeAll(newQuoteIds); DO WE NEED THIS?
        }

        if (quotesToValidate.isEmpty()) {
            System.debug('No Quote Ids To Validate');
            return;
        }

        // return errors by quote id from validation script
        Map<Id,String> quoteErrorMap = QuoteVal_QuoteValidator.getQuoteErrorMap(quotesToValidate);
        // add any returned errors to the relevant quote lines
        // we will only add one per quote, for formatted display on the quote line editor
        for (SBQQ__QuoteLine__c quoteLine : quoteLineList) {
            Id quoteId = quoteLine.SBQQ__Quote__c;

            if (quoteErrorMap.containsKey(quoteId)) {
                quoteLine.addError(quoteErrorMap.get(quoteId));
                quoteErrorMap.remove(quoteId);  // remove quote id from map so we only add one error per quote
            }
        }
    }
}