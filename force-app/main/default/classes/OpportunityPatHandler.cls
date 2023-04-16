/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     amitul
* created:        05/06/2021
* modified:       12/21/2021
* created jira:   BR-878/BR-4606
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public without sharing class OpportunityPatHandler {
    @TestVisible
    private static final String ZUORA_CONFIG = 'Zuora Configuration';
    @TestVisible
    private static final String ZUORA_CONFIG_PAYMENT_METHOD = 'Quote has a Payment Method';
    @TestVisible
    private static final String ZUORA_CONFIG_BILLING_ACCOUNTS = 'All Fulfillment and Billing Accounts have active Zuora Billing Accounts';
    @TestVisible
    private static final String ZUORA_PAYMENT_METHOD_MATCH = 'Quote payment method matches payment methods on all Zuora Billing Accounts related to quote Billing Accounts';
    
    @TestVisible
    private static final String SPID_CHECKS = 'Service Provider Checks';
    @TestVisible
    private static final String SPID_CHECKS_INVENTORY = 'Inventory available on all service providers';
    @TestVisible
    private static final String SPID_CHECKS_CDA = 'CDA setup complete';
    @TestVisible
    private static final String SPID_CHECKS_DEALER_EMAIL = 'Dealer Email setup complete';
    @TestVisible
    private static final String SPID_CHECKS_INVENTORY_FEED_NOT_RUN = 'Inventory Available Feed Not Run';
    
    @TestVisible
    private static final String QUOTE_CHECKS = 'Quote Data and Configuration';
    @TestVisible
    private static final String QUOTE_CHECKS_APPROVED = 'Order Management approval';
    @TestVisible
    private static final String QUOTE_CHECKS_STARTDATE = 'Start Date on quote is today or later';
    @TestVisible
    private static final String QUOTE_CHECKS_AREABOOST = 'Area Boost (Geo-Expansion) Activation Information';

    @TestVisible
    private static final String DOCUSIGN_COMPLETE = 'Docusign Signed and Completed';

    @TestVisible
    private static final String ACCOUNT_TERRITORY_COMPLETE = 'Account Territory Configuration';

    @TestVisible
    private static final Boolean OVERRIDE_ADMIN = FeatureManagement.checkPermission('PO_Admin_Override');

    //Set of strings that determines which steps have an override button in the UI
    private static final Set<String> stepsCanOverride = new Set<String>{
        DOCUSIGN_COMPLETE,
        ACCOUNT_TERRITORY_COMPLETE
    };
    
    //Set of strings that determines which step details have an override button in the UI
    private static final Set<String> stepDetailsCanOverride = new Set<String>{
        SPID_CHECKS_INVENTORY,
        ZUORA_CONFIG_PAYMENT_METHOD,
        ZUORA_CONFIG_BILLING_ACCOUNTS,
        ZUORA_PAYMENT_METHOD_MATCH,
        SPID_CHECKS_CDA,
        QUOTE_CHECKS_AREABOOST,
        SPID_CHECKS_DEALER_EMAIL,
        SPID_CHECKS_INVENTORY_FEED_NOT_RUN
    };
    
    //Dynamic map of step to the wrapper containing info displayed in the UI
    private static final Map<String,patStepDetailIterator> patStepToDetailsMap;
    
    //Wrapper containing a Opportunity Tracker, Quote, and Opportunity
    private static OpportunityPatChecker.checkOppsWrapper checkWrapper;
    
    //Set used to keep the values of the override fields when a used clicks the refresh button
    private static Set<String> currentOverridesOnRefresh;
    //Boolean that tells code if it is running after a user clicked the refresh button
    private static Boolean isRefreshing = false;
    
    static{
        //
        //-- !This is the heart of the entire Opportunity Tracker process! -- \\
        //
        //Populate the map that holds each step and the info for the step 
        //(including their done status and possible details) in the UI
        patStepToDetailsMap = new Map<String,patStepDetailIterator>();

        //MULTI-STEP CHECK
        patStepToDetailsMap.put(
            SPID_CHECKS,
            new patStepDetailIterator(
                new Map<String,BooleanCompleteInfo>{
                    SPID_CHECKS_INVENTORY => new BooleanCompleteInfo(
                        'Spid_HasInventory__c',
                        'Spid_HasInventory_Override__c',
                        null
                    ),
                    SPID_CHECKS_CDA => new BooleanCompleteInfo(
                        'Spid_CDA__c',
                        'Spid_CDA_Override__c',
                        null
                    ),
                    SPID_CHECKS_DEALER_EMAIL => new BooleanCompleteInfo(
                        'Spid_DealerEmail__c',
                        'Spid_DealerEmail_Override__c',
                        null
                    ),
                    SPID_CHECKS_INVENTORY_FEED_NOT_RUN => new BooleanCompleteInfo(
                        'Spid_InventoryAvailableFeedNotRun__c',
                        'Spid_InventoryAvailableFeed_Override__c',
                        null
                    )
                },
                null,
                'Ensure all fulfillment accounts have clean service provider data'
            )
        );
        
		//MULTI-STEP CHECK
        patStepToDetailsMap.put(
            ZUORA_CONFIG,
            new patStepDetailIterator(
                new Map<String,BooleanCompleteInfo>{
                    ZUORA_CONFIG_PAYMENT_METHOD => new BooleanCompleteInfo(
                        'Zuora_QuotePaymentMethod__c',
                        'Zuora_QuotePaymentMethod_Override__c',
                        null
                    ),
                    ZUORA_CONFIG_BILLING_ACCOUNTS => new BooleanCompleteInfo(
                        'Zuora_ActiveBillingAccounts__c',
                        'Zuora_ActiveBillingAccounts_Override__c',
                        null
                    ),
                    ZUORA_PAYMENT_METHOD_MATCH => new BooleanCompleteInfo(
                        'Zuora_ActivePaymentMethodMatch__c',
                        'Zuora_ActivePaymentMethodMatch_Override__c',
                        null
                    )
                },
                null,
                'Complete the below steps to ensure this opportunity can sync with Zuora Billing appropriately'
            )
        );
    }
   
    //- Jira: BR-878
    //- Purpose: Main method called by pat LWC on connectedCallback() hook. Returns a JSON serialized patWrapper
    //object which contains all the data that the page needs
    @AuraEnabled 
    public static String getWrapper(Id oppId, List<String> currentOverrides, Boolean isRefresh){

       
        
        //This method can run when users click the refresh button. Everything will be the same, except we want
        //to preserve the values the user selected fot the override fields
        if (isRefresh){
            currentOverridesOnRefresh = new Set<String>(currentOverrides);
            isRefreshing = true;
        }
        
        //Call to the method that calculates all the Opportunity Tracker values and updates them as needed
        checkWrapper = OpportunityPatChecker.checkOpps(new Set<ID>{oppId});
        
        //MULTI-STEP CHECK
        if(checkWrapper.hasAreaBoostProduct){
        
        patStepToDetailsMap.put(
            QUOTE_CHECKS,
            new patStepDetailIterator(
                new Map<String,BooleanCompleteInfo>{
                    QUOTE_CHECKS_APPROVED => new BooleanCompleteInfo(
                        'Quote_Approved__c',
                        'Quote_Approved_Override__c',
                        null
                    ),
                    QUOTE_CHECKS_STARTDATE => new BooleanCompleteInfo(
                        'Quote_StartDate__c',
                        'Quote_StartDate_Override__c',
                        null
                    ),
                    QUOTE_CHECKS_AREABOOST => new BooleanCompleteInfo(
                        'Quote_AreaBoostInformation__c',
                        'Quote_AreaBoostInformation_Override__c',
                        null
                    )              
                    },
                null,
                'Ensure quote has all necessary approvals and data that is configured properly'
                )
            );
        } 
        else 
        {
            patStepToDetailsMap.put(
                QUOTE_CHECKS,
                new patStepDetailIterator(
                    new Map<String,BooleanCompleteInfo>{
                        QUOTE_CHECKS_APPROVED => new BooleanCompleteInfo(
                            'Quote_Approved__c',
                            'Quote_Approved_Override__c',
                            null
                        ),
                        QUOTE_CHECKS_STARTDATE => new BooleanCompleteInfo(
                            'Quote_StartDate__c',
                            'Quote_StartDate_Override__c',
                            null
                        )
                    },
                    null,
                    'Ensure quote has all necessary approvals and data that is configured properly'
                )
            );
        }   
        //SINGLE-STEP CHECK
        patStepToDetailsMap.put(
            DOCUSIGN_COMPLETE,
            new patStepDetailIterator(
				null,
                new BooleanCompleteInfo('DocusignComplete__c', 'DocusignComplete_Override__c', 'DocusignComplete_Final__c'),
                'A docusign attached to the primary quote must be signed and returned by the dealer'
            )
        );

        //EA-410 SINGLE-STEP CHECK: Only one granular territory per opportunity account
        patStepToDetailsMap.put(
            ACCOUNT_TERRITORY_COMPLETE,
            new patStepDetailIterator(
                null,
                new BooleanCompleteInfo('Granular_Territory_Assigned__c','Granular_Territory_Assigned_Override__c','Granular_Territory_Assigned_Final__c'),
                'The opportunity account should have only one granular territory assigned'
                )
            );

        //Create the patWrapper that we will be returning
        patWrapper patWrap = new patWrapper(
            [SELECT QuoteOrderingErrors__c
             FROM Opportunity_Tracker__c
             WHERE id = :checkWrapper.oppTracker.Id][0],
            oppId,
            checkWrapper.quote
        );

        Integer i = 0;
        Integer sumPercentDone = 0;
        //Loop through the string keys in the patStepToDetailsMap, and pass in the string
        //to the getPatStepWrapper in order to get the formatted wrapper class patStepWrapper
        for (String patStepName : patStepToDetailsMap.keySet()){
            patStepWrapper patStepWrap = getPatStepWrapper(patStepName);

            sumPercentDone += patStepWrap.percentDone;
                  
            patWrap.patSteps.add(patStepWrap);
            
            i++;
        }

        patWrap.percent =  sumPercentDone / patWrap.patSteps.size();
        patWrap.progressBarStyle = 'width:' + patWrap.percent + '%';
        patWrap.done = patWrap.percent == 100;

        return JSON.serialize(patWrap);
    }
    
    //Wrapper class containing the highest level details for the pat LWC - this wrapper
    //contains a bunch of booleans whose sole purpose is to conditionally render things
    //in the LWC - i.e. oppPositive
    public class patWrapper{
        public patWrapper(Opportunity_Tracker__c oppTracker, ID oppId, SBQQ__Quote__c relatedQuote){
            
            this.quote = relatedQuote;
            this.oppTrackerId = oppTracker.Id;
            
            this.opp = [SELECT Id,CurrencyIsoCode, Amount, Account.Name, CloseDate, Name
                        FROM Opportunity
                        WHERE Id = :oppId];
            
            this.oppPositive = this.opp.Amount >= 0;
            
            for (Order existingOrder : [SELECT Id,CurrencyIsoCode,TotalAmount, EffectiveDate, ContractCustom__c, Account.Name, SBQQ__Quote__c, 
                                        OrderNumber, Status, SBQQ__Contracted__c,
                                        (SELECT CurrencyIsoCode,TotalPrice, Product2.Name, SBQQ__QuotedQuantity__c, Fulfillment_Account__r.Name, Fulfillment_Account__c, 
                                         Product2.SBQQ__ProductPictureID__c
                                         FROM OrderItems
                                         WHERE Product2.ProductCode != 'CG-BASE'
                                        ORDER BY Product2.Pricing_Wizard_Sort_Order__c NULLS LAST)
                                        FROM Order
                                        WHERE OpportunityId = :oppId])
            {
                allOrders.add(
                    new OrdersWrapper(existingOrder)
                );
                
                this.orderId = existingOrder.Id;
                this.orderNameString = 'View Order: ' + existingOrder.OrderNumber;
                this.OrderNumber = existingOrder.OrderNumber;
                this.numOrders ++;
                
                if (this.contractId == null && existingOrder.ContractCustom__c != null){
                    this.contractId = existingOrder.ContractCustom__c;
                }
            }
            
            if (numOrders > 1){
                this.hasMultipleOrders = true;
                this.orderNameString = 'View ' + this.numOrders + ' Orders';
            }
            
            if (oppTracker.QuoteOrderingErrors__c != null){
                this.hasQuoteOrderingErrors = true;
       
                Integer i = 0;
                for (String s : oppTracker.QuoteOrderingErrors__c.split('<orderBrokenSpacer>')){
                    if (i == 0){
                        this.quoteOrderingErrors = s;
                    }else if (i == 1){
                        this.quoteOrderingStackTrace = s;
                    }
                    
                    i++;
                }
            }

            if(this.quote != null) {
                //BR-7299 - large quotes
                List<SBQQ__QuoteLine__c> quoteLines = [SELECT Id, Fulfillment_Account__c 
                    FROM SBQQ__QuoteLine__c 
                    WHERE SBQQ__Quote__c = :this.quote.Id];

                Set<Id> fulAccIds = new Set<Id>();
                for(SBQQ__QuoteLine__c ql : quoteLines) {
                    fulAccIds.add(ql.Fulfillment_Account__c);
                }
                
                this.largeQuote = fulAccIds.size() > 10 ? true : false;
            }
        }
        
        @AuraEnabled
        public Integer percent;
        
        @AuraEnabled
        public Boolean done;
        
        @AuraEnabled
        public String progressBarStyle;
        
        @AuraEnabled
        public Id oppTrackerId;
        
        @AuraEnabled
        public String orderId;
        
        @AuraEnabled
        public SBQQ__Quote__c quote;
        
        @AuraEnabled
        public Date startDate;

        @AuraEnabled
        public String orderNameString;
        
        @AuraEnabled
        public String orderNumber;
        
        @AuraEnabled
        public List<patStepWrapper> patSteps = new List<patStepWrapper>();
        
        @AuraEnabled
        public String quoteOrderingErrors;
        
        @AuraEnabled
        public String quoteOrderingStackTrace;
        
        @AuraEnabled
        public Boolean hasQuoteOrderingErrors;
        
        @AuraEnabled
        public Integer numOrders = 0;
        
        @AuraEnabled
        public Boolean hasMultipleOrders;
        
        @AuraEnabled
        public Opportunity opp;
        
        @AuraEnabled
        public Boolean oppPositive;
        
        @AuraEnabled
        public List<OrdersWrapper> allOrders = new List<OrdersWrapper>();
        
        @AuraEnabled
        public Id contractId;

        @AuraEnabled
        public Boolean largeQuote;
    }
    
    //Wrapper class containing the second highest level details for the pat LWC - pat steps
    public class patStepWrapper{
        
        public patStepWrapper(BooleanCompleteInfo info, String stepName, String stepDescription, List<patStepDetailWrapper> details){
            this.oppTrackerId = checkWrapper.oppTracker.Id;
            this.stepName = stepName;
            this.stepDescription = stepDescription; 
            this.details = details;
            this.hasDetails = details != null && !details.isEmpty();
            this.info = info;

            if (info != null){
                String doneField = this.info.doneField;
                Boolean hasOverridePerm = FeatureManagement.checkPermission('PO_' + doneField.remove('__c')) || OVERRIDE_ADMIN;
                
                this.info.isDone = (Boolean)checkWrapper.oppTracker.get(doneField);
                this.allowOverride = stepsCanOverride.contains(this.stepName) && hasOverridePerm;
                
                if (allowOverride && isRefreshing){
                    this.info.isOverriden = currentOverridesOnRefresh.contains(this.stepName);
                }else{
                    this.info.isOverriden = (Boolean)checkWrapper.oppTracker.get(this.info.overrideField);
                }
                
                this.info.isFinalDone = this.info.isDone || this.info.isOverriden;
            }

            if (hasDetails){
                Integer stepsDone = 0;
                for (patStepDetailWrapper patStepDetailWrap : details){
                    stepsDone += patStepDetailWrap.info.isFinalDone ? 1 : 0;
                }
                this.percentDone = (stepsDone * 100) / details.size(); 
            }else{
                this.percentDone = info.isFinalDone ? 100 : 0;
            }
            
            this.stepDone = percentDone == 100;

            //BR-9131 addition, adding related SPs on the UI
            if(String.isNotBlank(this.stepName) && this.stepName.equalsIgnoreCase(SPID_CHECKS)){

                if(checkWrapper.displayedSP!=null){
                    this.displayedSP = new patServiceProviderInfo(checkWrapper.displayedSP);
                }

                if(checkWrapper.additionalSP!=null && !checkWrapper.additionalSP.isEmpty()){

                    List<patServiceProviderInfo> additionalSPRecords = new List<patServiceProviderInfo>();

                    for(Service_Provider__c spRec : checkWrapper.additionalSP){
                        additionalSPRecords.add(new patServiceProviderInfo(spRec));
                    }

                    this.additionalSP = additionalSPRecords;
                }
            }
        }
        
        @AuraEnabled
        public Boolean stepDone;
        
        @AuraEnabled
        public Boolean allowOverride = false;
        
        @AuraEnabled
        public BooleanCompleteInfo info;
        
        @AuraEnabled
        public Id oppTrackerId;

        @AuraEnabled
        public Integer percentDone;
        
        @AuraEnabled
        public String stepName;
        
        @AuraEnabled
        public Boolean hasDetails;
        
        @AuraEnabled
        public String stepDescription;
        
        @AuraEnabled
        public List<patStepDetailWrapper> details;

        @AuraEnabled
        public patServiceProviderInfo displayedSP;

        @AuraEnabled
        public List<patServiceProviderInfo> additionalSP;
    }

    public class patServiceProviderInfo{

        @AuraEnabled
        public String serviceProviderId;

        @AuraEnabled
        public String serviceProviderName;

        public patServiceProviderInfo(Service_Provider__c spRecord){
            //added "/" to create a proper link out service provider id
            this.serviceProviderId = '/'+spRecord.Id;
            this.serviceProviderName = spRecord.Name;
        }
    }
    
    //Wrapper class containing the second highest level details for the pat LWC - pat step details
    public class patStepDetailWrapper{

        public patStepDetailWrapper(String detailName, BooleanCompleteInfo info){
            this.info = info;
            
            String doneField = this.info.doneField;
            Boolean hasOverridePerm = FeatureManagement.checkPermission('PO_' + doneField.remove('__c')) || OVERRIDE_ADMIN;
            
            this.info.isDone = (Boolean)checkWrapper.oppTracker.get(doneField);
            this.detailName = detailName;
            this.allowOverride = stepDetailsCanOverride.contains(this.detailName) && hasOverridePerm;
            
            if (allowOverride && isRefreshing){
                this.info.isOverriden = currentOverridesOnRefresh.contains(this.detailName);
            }else{
                this.info.isOverriden = (Boolean)checkWrapper.oppTracker.get(this.info.overrideField);
            }
            
            this.info.isFinalDone = this.info.isDone || this.info.isOverriden;
   
            if (this.info.isFinalDone){
                this.imageClass = 'slds-progress__item slds-is-completed';
            }else{
                this.imageClass = 'slds-progress__item';
            }
        }
        
        @AuraEnabled
        public Boolean allowOverride;

        @AuraEnabled
        public String imageClass;
        
        @AuraEnabled
        public BooleanCompleteInfo info;
        
        @AuraEnabled
        public String detailName;
    }
    
    //- Jira: BR-878
    //- Purpose: Dynamic method that constructs a patStep wrapper object (with patStepDetails if needed),
    //from a patStepDetailIterator object
    private static patStepWrapper getPatStepWrapper(String patStepName){
        patStepDetailIterator iterator = patStepToDetailsMap.get(patStepName);
        
        List<patStepDetailWrapper> patStepDetailWrap = new List<patStepDetailWrapper>();

        if (iterator.detailToInfoMap != null){
            for (String detailName : iterator.detailToInfoMap.keySet()){
                
                patStepDetailWrap.add(
                    new patStepDetailWrapper(
                        detailName,
                        iterator.detailToInfoMap.get(detailName)
                    )
                );
            }
        }
        
        patStepWrapper patStepWrap = new patStepWrapper(
            iterator.info,
            patStepName,
            iterator.description,
            patStepDetailWrap
        );

        return patStepWrap;
    }
    
    //Method that handles when a user clicks the Override switch in the UI
    @AuraEnabled 
    public static String handleOverrideChangeApex(Id trackerId, String overrideField, Boolean isOverriden, Id oppId){
        Opportunity_Tracker__c oppTracker = new Opportunity_Tracker__c(
            Id = trackerId
        );

        oppTracker.put(overrideField, isOverriden);  
        
        update oppTracker;
        
        patWrapper returnWrap = new patWrapper(
            [SELECT QuoteOrderingErrors__c
             FROM Opportunity_Tracker__c
             WHERE id = :trackerId][0],
            oppId,
            [SELECT Id, SBQQ__StartDate__c
            FROM SBQQ__Quote__c
            WHERE SBQQ__Opportunity2__c	= :oppId
            AND SBQQ__Primary__c = true]
        );
        
        return JSON.serialize(returnWrap);
    }

    //- Jira: BR-3659
    //- Purpose: Allows users to retry the ordering of a quote when there is a failure - meaning
    //when there is a value in the opp tracker's QuoteOrderingErrors__c field
    @AuraEnabled 
    public static String retryOrderingApex(Id oppTrackerId, Id oppId){
        Opportunity_Tracker__c oppTracker = new Opportunity_Tracker__c(
            Id = oppTrackerId
        );
        
        //Make the QuoteOrderingErrors__c field null so we work with a blank slate
        oppTracker.QuoteOrderingErrors__c = null;
        update oppTracker;
        
        //Run the method that orders quotes
        OpportunityTrackerTriggerFunctions.activateOppsFromTrackerIds(new Set<ID>{oppTrackerId});

        //Create a wrapper and return it back to the LWC
        patWrapper returnWrap = new patWrapper(
            [SELECT QuoteOrderingErrors__c
             FROM Opportunity_Tracker__c
             WHERE id = :oppTrackerId][0],
            oppId,
            [SELECT Id, SBQQ__StartDate__c
             FROM SBQQ__Quote__c
             WHERE SBQQ__Opportunity2__c = :oppId
             AND SBQQ__Primary__c = true]
        );
        
        return JSON.serialize(returnWrap);
    }

    private class patStepDetailIterator{   
        private patStepDetailIterator(Map<String,BooleanCompleteInfo> detailToInfoMap, BooleanCompleteInfo info, String description){
            this.detailToInfoMap = detailToInfoMap;
            this.info = info;
            this.description = description;
        }
        
        Map<String,BooleanCompleteInfo> detailToInfoMap;
        BooleanCompleteInfo info;
        String description;
    }
    
    //Wrapper class holiding the field names and boolean for each step or details three fields
    public class BooleanCompleteInfo{
        @AuraEnabled
        public String doneField;
        @AuraEnabled
        public Boolean isDone;
        
        @AuraEnabled
        public String overrideField;
        @AuraEnabled
        public Boolean isOverriden;
        
        @AuraEnabled
        public String finalField;
        @AuraEnabled
        public Boolean isFinalDone;
        
        
        public BooleanCompleteInfo(String doneField, String overrideField, String finalField){
            this.doneField = doneField;
            this.finalField = finalField;
            this.overrideField = overrideField;
        }
    }
    
    //- Jira: BR-3659
    //- Purpose: Wrapper containing an order and a bunch of other variables/booleans for each order
    public class OrdersWrapper{
        @AuraEnabled
        public Order ord;
        
        @AuraEnabled
        public Account fullfillmentAccount;
        
        @AuraEnabled
        public Boolean isActivated;
        
        @AuraEnabled
        public Boolean isContracted;
        
        @AuraEnabled
        public Boolean orderPositive;
        
        @AuraEnabled
        public String accountLink = '/lightning/r/Account/<accountId>/view';
        
        @AuraEnabled
        public List<OrderItemWrapper> positiveOrderItems = new List<OrderItemWrapper>();
        
        @AuraEnabled
        public List<OrderItemWrapper> negativeOrderItems = new List<OrderItemWrapper>();

        public OrdersWrapper(Order existingOrder){
            this.ord = existingOrder;

            this.orderPositive = existingOrder.TotalAmount >= 0;
            
            this.isContracted = existingOrder.SBQQ__Contracted__c;
            this.isActivated= this.isContracted || existingOrder.Status == 'Activated';
            
            for (OrderItem oi : existingOrder.OrderItems){
                
                if (fullfillmentAccount == null){                    
                    fullfillmentAccount = new Account(
                        Id = oi.Fulfillment_Account__c,
                    	Name = oi.Fulfillment_Account__r.Name
                    );
                }
                
                if (oi.SBQQ__QuotedQuantity__c > 0){
                    positiveOrderItems.add(
                        new OrderItemWrapper(oi)
                    );
                }else{
                    negativeOrderItems.add(
                        new OrderItemWrapper(oi)
                    );
                }
            }
            
            accountLink = accountLink.replace('<accountId>', fullfillmentAccount.Id);
        }
    }
    
    //- Jira: BR-3659
    //- Purpose: Wrapper for order items that has a link to the product's image
    public class OrderItemWrapper{
        OrderItem ordItem;
        String imageLink = 'https://carg--c.documentforce.com/servlet/servlet.ImageServer?id=<imageId>&oid=00D4S000000Go4R';
        
        public OrderItemWrapper(OrderItem ordItem){
            this.ordItem = ordItem;
            
            if (ordItem.Product2.SBQQ__ProductPictureID__c != null){
                this.imageLink = imageLink.replace('<imageId>', ordItem.Product2.SBQQ__ProductPictureID__c);
            }
        }
    }
    
}