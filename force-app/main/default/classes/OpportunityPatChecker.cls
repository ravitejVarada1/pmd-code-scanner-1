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

public class OpportunityPatChecker {
    
    // grab todays date,
    public static Date todaysDate = Date.today();

    /**
    * jira: BR-878
    * purpose: method that takes a set of Opportunity Ids and calculates all values for the
    *           related Opportunity Tracker, then updates as needed.
    *
    * THIS METHOD IS BULKIFIED!
    */

    public static checkOppsWrapper checkOpps(Set<ID> oppIds){
        Map<Id,checkOppsWrapper> oppToCheckWrapper = new Map<Id,checkOppsWrapper>();
        Map<Id,SBQQ__Quote__c> quotesWithLines = new Map<ID,SBQQ__Quote__c>();

        Map<Id,Opportunity_Tracker__c> trackers = new  Map<Id, Opportunity_Tracker__c>(
            [SELECT Id, Quote_Final__c, Quote_Approved__c, Quote_Approved_Override__c, Quote_StartDate__c, Quote_StartDate_Override__c, 
             Quote_AreaBoostInformation__c, Quote_AreaBoostInformation_Override__c, Quote_hasAreaBoostProduct__c,
             Complete__c, DocusignComplete__c, DocusignComplete_Final__c, DocusignComplete_Override__c, 
             Spid_Final__c, Spid_HasInventory__c, Spid_HasInventory_Override__c, Zuora_ActiveBillingAccounts__c, 
             Zuora_ActiveBillingAccounts_Override__c, Zuora_Final__c, Zuora_QuotePaymentMethod__c, 
             Zuora_QuotePaymentMethod_Override__c, Zuora_ActivePaymentMethodMatch__c,
             Zuora_ActivePaymentMethodMatch_Override__c, Spid_CDA__c, Spid_CDA_Override__c,
             Spid_DealerEmail__c, Spid_DealerEmail_Override__c, QuoteOrderingErrors__c,
             Spid_InventoryAvailableFeedNotRun__c,Spid_InventoryAvailableFeed_Override__c,
             Granular_Territory_Assigned__c, Granular_Territory_Assigned_Override__c
             FROM Opportunity_Tracker__c
             WHERE Id IN (SELECT Opportunity_Tracker__c
                          FROM Opportunity WHERE Id IN :oppIds)]);

        //Create a map of Opportunity Id to an checkOppsWrapper object - this contains
        //an opportunity, a quote, and a tracker
        Map<Id,Id> oppAccIdMap = new Map<Id,Id> ();

        for(Opportunity opp : [SELECT Id,IsClosed, Opportunity_Tracker__c, AreaBoost_Field_Validation__c, AccountId, (SELECT Id
                                FROM SBQQ__Quotes2__r
                                WHERE SBQQ__Primary__c = true
                                LIMIT 1)
                               FROM Opportunity
                               WHERE Id in :oppIds])
        {
            oppAccIdMap.put(opp.Id,opp.AccountId);

            Opportunity_Tracker__c oppTracker = trackers.get(opp.Opportunity_Tracker__c);

            Id quoteId = opp.SBQQ__Quotes2__r.isEmpty()
                ? null
                : opp.SBQQ__Quotes2__r[0].Id;

            quotesWithLines.put(quoteId, null);
            
            oppToCheckWrapper.put(opp.Id, new checkOppsWrapper(
                opp,
                oppTracker,
                new SBQQ__Quote__c(Id = quoteId),false)
            );
        }
        quotesWithLines.remove(null);

        //Query for Territory Assignments
        AggregateResult[] otaGrouped = [
            SELECT ObjectId, COUNT(Id)
            FROM ObjectTerritory2Association
            WHERE Territory2.Is_Granular__c = TRUE
            AND Territory2.Territory2Model.State != 'Archived'
            AND ObjectId IN :oppAccIdMap.values()
            GROUP BY ObjectId];

        Map<String,Integer> accountTerritoryCount = new Map<String,Integer> ();
        for (AggregateResult sp : otaGrouped) {
            accountTerritoryCount.put(String.valueOf(sp.get('ObjectId')), Integer.valueOf(sp.get('expr0')));
        }
        
        //Get all the quote lines related to each quote - to be used in loop below
        quotesWithLines = new Map<Id,SBQQ__Quote__c>([SELECT Payment_Method__c, SBQQ__Status__c, SBQQ__StartDate__c, SBQQ__Ordered__c,
                                                      (SELECT Fulfillment_Account__c, Fulfillment_Account__r.Billing_Account_Zuora__r.Zuora__Status__c,
                                                       Billing_Account__r.Billing_Account_Zuora__r.Zuora__Status__c,
                                                       Billing_Account__r.Billing_Account_Zuora__r.Zuora__PaymentMethod_Type__c,
                                                       Billing_Account__r.Billing_Account_Zuora__r.Zuora__Default_Payment_Method__r.Zuora__PaymentMethodStatus__c,
                                                       Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c,	
                                                       Fulfillment_Account__r.Used_Inventory_Avg__c, SBQQ__Quantity__c, SBQQ__Existing__c,
                                                       SBQQ__ProductOption__c, SBQQ__Product__r.Sub_Category__c, SBQQ__Product__r.ProductCode
                                                       FROM SBQQ__LineItems__r),
                                                      (SELECT Id
                                                       FROM DocuSign_Status__r
                                                       WHERE dsfs__Envelope_Status__c = 'Completed'
                                                       AND Id IN(SELECT dsfs__Parent_Status_Record__c
                                                       FROM dsfs__DocuSign_Recipient_Status__c
                                                       WHERE dsfs__Date_Signed__c!=null)
                                                       LIMIT 1)
                                                      FROM SBQQ__Quote__c
                                                      WHERE Id IN :quotesWithLines.keySet()]);
        
        //Get all the spids related to each fulfillment account - to be used in loop below
        Map<Id,Account> fullfillmentAccountsWithSpids = new Map<Id,Account>();
        Map<Id,Account> fullfillmentAccountsWithSpidsPositiveLines = new Map<Id,Account>();
        
        Boolean hasAreaBoostProduct = false;
        
        for (SBQQ__Quote__c quote : quotesWithLines.values()){
            for (SBQQ__QuoteLine__c ql : quote.SBQQ__LineItems__r){
                
                Id fulfillmentAccount = ql.Fulfillment_Account__c;
                fullfillmentAccountsWithSpids.put(fulfillmentAccount, null);
                
                //BR-3959 Filter fullfilment acount with new map (quote lines Qty > 0)
                if (ql.SBQQ__Quantity__c >= 0) { //DSS-91 Need to consider amendments where all lines has Qty 0
                    fullfillmentAccountsWithSpidsPositiveLines.put(fulfillmentAccount, null);
                }
            }
        }
        
        // logic to check if opp hasAreaBoostProduct = true
        for (SBQQ__Quote__c quote : quotesWithLines.values()){
            for (SBQQ__QuoteLine__c ql : quote.SBQQ__LineItems__r){
                if 
                  ((ql.SBQQ__Product__r.Sub_Category__c == 'Area Boost'||ql.SBQQ__Product__r.Sub_Category__c == 'Digital Retail')
                    && ql.SBQQ__Quantity__c > 0 && ql.SBQQ__Existing__c != true && ql.SBQQ__Product__r.ProductCode  != 'CG-DIG-DEAL') 
                    {
                   hasAreaBoostProduct = true;
                break;
               }
            }
        }

        List<Opportunity> oppListTemp = new List<Opportunity>([
            SELECT Opportunity_Tracker__c,IsClosed FROM Opportunity WHERE Id IN :oppIds
        ]);
        Id oppTrackerId = !oppListTemp[0].IsClosed && oppListTemp[0].Opportunity_Tracker__c!=null ? oppListTemp[0].Opportunity_Tracker__c : null;

        if(String.isNotBlank(oppTrackerId)){
            Opportunity_Tracker__c opphasAreaBoost = trackers.get(oppTrackerId);
            opphasAreaBoost.Quote_hasAreaBoostProduct__c = hasAreaBoostProduct;
            update opphasAreaBoost;
        }

        // logic to set the hasAreaBoostProduct boolean property of wrapper class 
        for (Id oppId : oppToCheckWrapper.keySet()){   
            checkOppsWrapper wrapper = oppToCheckWrapper.get(oppId);
            wrapper.hasAreaBoostProduct = hasAreaBoostProduct; 
            oppToCheckWrapper.put(oppId,wrapper);
        }

        fullfillmentAccountsWithSpids = new Map<Id,Account>([SELECT Id, (SELECT Id,Name, Can_host_inventory__c, Inventory_Source__c,
                                                                        Dashboard_Admin_Exist__c, Dealer_Email_Exist__c,
                                                                        Inventory_Available_Feed_Not_Run__c
                                                                         FROM Service_Provider__r
                                                                         WHERE reviewStatus__c	!= 'DENIED')  
                                                             FROM Account
                                                             WHERE Id IN :fullfillmentAccountsWithSpids.keySet()]);

        //Populate new map with the fullfillment account value
        for (Id accountId : fullfillmentAccountsWithSpidsPositiveLines.keySet()) {
            fullfillmentAccountsWithSpidsPositiveLines.put(accountId,fullfillmentAccountsWithSpids.get(accountId));
        }
        
        List<Opportunity_Tracker__c> oppTrackersToUpdate = new List<Opportunity_Tracker__c>();
        
        //Loop through all Opportunity Ids int he oppToCheckWrapper keyset, and check every boolean value
        for (Id oppId : oppToCheckWrapper.keySet()){
            checkOppsWrapper wrapper = oppToCheckWrapper.get(oppId);
            
            Opportunity opp = wrapper.opp;

            if(opp.IsClosed){
                continue;
            }

            wrapper.quote = wrapper.quote.Id == null
                ? null
                : quotesWithLines.get(wrapper.quote.Id);
            
            SBQQ__Quote__c quote = wrapper.quote;
            
            Opportunity_Tracker__c oppTracker = wrapper.oppTracker;
            Opportunity_Tracker__c oppTrackerClone = oppTracker.clone(true,false,false,false);
            
            //Booleans that contain all the accurate values for each tracker field - to be populated below
            Boolean fullfillmentAccountsHaveInventory = false;
            Boolean cdaDone = false;
            Boolean dealerEmailDone = false;
            Boolean InventoryAvailableFeedNotRun = true;
            
            Boolean quotePaymentMethodDone = false;
            Boolean zuoraAccountsSet = false;
            Boolean zuoraPaymentMethodMatch = false;
            
            Boolean omApprovedQuote = false;
            Boolean quoteStartDateNotInPast = false;
            Boolean areaBoostInformationDone = false;
            
            Boolean docusignCompleted = false;

            Boolean accountTerritoryAssigned = false;
            
            if (quote != null){
                //Quote level validations
                String quotePaymentMethod = quote.Payment_Method__c;
                
                quotePaymentMethodDone  = quotePaymentMethod != null;
                omApprovedQuote         = quote.SBQQ__Status__c == ConstantsUtil.QUOTE_STATUS_APPROVED || quote.SBQQ__Status__c == ConstantsUtil.QUOTE_STATUS_ORDER_GENERATED;
                docusignCompleted       = !quote.DocuSign_Status__r.isEmpty();
                quoteStartDateNotInPast = (quote.SBQQ__StartDate__c >= todaysDate) || quote.SBQQ__Ordered__c;
                areaBoostInformationDone=  opp.AreaBoost_Field_Validation__c == true;
                
                Integer numServiceProviders = 0;
                Integer numServiceProvidersPositiveLines = 0;
                
                Integer numServiceProvidersWithInventory = 0;
                Integer numServiceProvidersCantHostInventory = 0;
                Integer numServiceProvidersWithCdaDone = 0;
                Integer numServiceProvidersWithDealerEmailDone = 0;
                Integer numInventoryAvailableFeedNotRun = 0;
                
                Integer numLines = 0;
                Integer numLinesWithActivatedBillingAccounts = 0;
                Integer numLinesWithConfiguredPaymentMethod = 0;

                //BR-9131
                Map<Id,Map<Integer,WeighServiceProvider>> fullfillmentAccIdToSPs = new Map<Id,Map<Integer,WeighServiceProvider>>();
                Map<Id,WeighServiceProvider> fullfillmentAccIdToFilteredSP = new Map<Id,WeighServiceProvider>();

                //Quote line level validations
                for (SBQQ__QuoteLine__c ql : quote.SBQQ__LineItems__r){
                    if (ql.SBQQ__ProductOption__c != null){
                        continue;
                    }

                    numLines++;
                    
                    if (ql.Fulfillment_Account__c != null) {
                        //numServiceProviders += fullfillmentAccountsWithSpids.get(ql.Fulfillment_Account__c).Service_Provider__r.size();
                        
                        if (!fullfillmentAccIdToSPs.containsKey(ql.Fulfillment_Account__c)) { //DSS-91
                            fullfillmentAccIdToSPs.put(ql.Fulfillment_Account__c,new Map<Integer,WeighServiceProvider>());
                        }

                        if (fullfillmentAccountsWithSpidsPositiveLines.containsKey(ql.Fulfillment_Account__c)) {

                            numServiceProvidersPositiveLines += fullfillmentAccountsWithSpidsPositiveLines.get(ql.Fulfillment_Account__c).Service_Provider__r.size();
                            
                            for (Service_Provider__c spid : fullfillmentAccountsWithSpidsPositiveLines.get(ql.Fulfillment_Account__c).Service_Provider__r) {
                                
                                WeighServiceProvider spInfo = new WeighServiceProvider();
                                Integer spWeight = 0;

                                if (spid.Inventory_Source__c != null && spid.Can_host_inventory__c != 'No'){

                                    spInfo.fullfillmentAccountsHaveInventory = true;
                                    spWeight++;
                                }
                                
                                if (spid.Dashboard_Admin_Exist__c){
                                    
                                    spInfo.cdaDone = true;
                                    spWeight++;
                                }
                                
                                if (spid.Dealer_Email_Exist__c){

                                    spInfo.dealerEmailDone = true;
                                    spWeight++;
                                }

                                if (!spid.Inventory_Available_Feed_Not_Run__c){
                                    spInfo.InventoryAvailableFeedNotRun = true;
                                    spWeight++;
                                }

                                spInfo.serviceProviderName = spid.Name;
                                spInfo.serviceProviderId = spid.Id;
                                spInfo.fullfillmentAccountId = ql.Fulfillment_Account__c;
                                spInfo.weightage = spWeight;

                                if(fullfillmentAccIdToSPs.get(ql.Fulfillment_Account__c).isEmpty()){
                                    fullfillmentAccIdToSPs.put(ql.Fulfillment_Account__c,new Map<Integer,WeighServiceProvider>{spInfo.weightage => spInfo});
                                }else{
                                    Map<Integer,WeighServiceProvider> temp = fullfillmentAccIdToSPs.get(ql.Fulfillment_Account__c);
                                    temp.put(spInfo.weightage,spInfo);
                                    fullfillmentAccIdToSPs.put(ql.Fulfillment_Account__c,temp);
                                }
                            }
                        }

                        if (ql.Billing_Account__c != null){
                            if (ql.Fulfillment_Account__r.Billing_Account_Zuora__r.Zuora__Status__c == 'Active'
                                && ql.Billing_Account__r.Billing_Account_Zuora__r.Zuora__Status__c == 'Active')
                            {
                                numLinesWithActivatedBillingAccounts ++;
                            }
                        }
                        
                        switch on quotePaymentMethod{
                            when 'Check'{
                                if (ql.Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c == 'Check'){
                                    numLinesWithConfiguredPaymentMethod ++;
                                }
                            }when else{
                                
                                if (ql.Billing_Account__r.Billing_Account_Zuora__r.Zuora__Default_Payment_Method__r.Zuora__PaymentMethodStatus__c == 'Active'
                                    && (ql.Billing_Account__r.Billing_Account_Zuora__r.Zuora__PaymentMethod_Type__c	
                                        == quotePaymentMethod))
                                {
                                    numLinesWithConfiguredPaymentMethod ++;
                                }
                            } 
                        }
                    }
                }

                if(!fullfillmentAccIdToSPs.isEmpty()){
                    
                    Map<Integer,Id> weightToFullfillmentAccId = new Map<Integer,Id>();

                    for(Id fullfillmentAccId : fullfillmentAccIdToSPs.keyset()){

                        Map<Integer,WeighServiceProvider> spInfoMap = fullfillmentAccIdToSPs.get(fullfillmentAccId);

                        if(!spInfoMap.isEmpty()){
                            List<Integer> spInfoMapKeys = new List<Integer>(spInfoMap.keyset());
                            spInfoMapKeys.sort();
                            Integer highestWeightedSP = spInfoMapKeys.get(spInfoMapKeys.size() - 1);

                            if(spInfoMap.containsKey(highestWeightedSP)){
                                fullfillmentAccIdToFilteredSP.put(fullfillmentAccId,spInfoMap.get(highestWeightedSP));
                                weightToFullfillmentAccId.put(spInfoMap.get(highestWeightedSP).weightage,fullfillmentAccId);
                            }
                        }
                    }

                    if(!weightToFullfillmentAccId.isEmpty()){
                        List<Integer> filterSPWeights = new List<Integer>(weightToFullfillmentAccId.keyset());
                        filterSPWeights.sort();
                        //get least weight SP out of filtered highest weighted SPs wrt their Fulfillment Accounts
                        //to display this on the PAT UI
                        Integer leastWeightedSP = filterSPWeights.get(0);
                        WeighServiceProvider selectedSPForUI = fullfillmentAccIdToFilteredSP.get(weightToFullfillmentAccId.get(leastWeightedSP));
                        fullfillmentAccountsHaveInventory = selectedSPForUI.fullfillmentAccountsHaveInventory;
                        cdaDone = selectedSPForUI.cdaDone;
                        dealerEmailDone = selectedSPForUI.dealerEmailDone;
                        InventoryAvailableFeedNotRun = selectedSPForUI.InventoryAvailableFeedNotRun;

                        wrapper.displayedSP = new Service_Provider__c(
                            Id=selectedSPForUI.serviceProviderId,Name=selectedSPForUI.serviceProviderName
                        );

                        if(fullfillmentAccIdToFilteredSP.containsKey(selectedSPForUI.fullfillmentAccountId)){
                            fullfillmentAccIdToFilteredSP.remove(selectedSPForUI.fullfillmentAccountId);
                        }

                        if(!fullfillmentAccIdToFilteredSP.isEmpty()){

                            List<Service_Provider__c> spItems = new List<Service_Provider__c>();

                            for(WeighServiceProvider wrapRec : fullfillmentAccIdToFilteredSP.values()){
                                spItems.add(new Service_Provider__c(
                                    Id=wrapRec.serviceProviderId,Name=wrapRec.serviceProviderName
                                ));
                            }
                            wrapper.additionalSP = spItems;
                        }

                        oppToCheckWrapper.put(oppId,wrapper);
                    }   
                }

                
                if (numLines != 0){
                    if (numLines == numLinesWithActivatedBillingAccounts){
                        zuoraAccountsSet = true;
                    }
                    
                    if (numLines == numLinesWithConfiguredPaymentMethod){
                        zuoraPaymentMethodMatch = true;
                    }
                }
            }            
            
            // EA-410: If opp account has only one granular assigned territory, verified.
            accountTerritoryAssigned = accountTerritoryCount.get(opp.AccountId) == 1 ? true : false;
            
            if(oppTracker.Spid_HasInventory__c != fullfillmentAccountsHaveInventory){
                oppTracker.Spid_HasInventory__c = fullfillmentAccountsHaveInventory;
            }
            
            
            if (oppTracker.Spid_CDA__c != cdaDone){
                oppTracker.Spid_CDA__c = cdaDone;
            }
            
            if (oppTracker.Spid_DealerEmail__c != dealerEmailDone){
                oppTracker.Spid_DealerEmail__c = dealerEmailDone;
            }

            if (oppTracker.Spid_InventoryAvailableFeedNotRun__c != InventoryAvailableFeedNotRun){
                oppTracker.Spid_InventoryAvailableFeedNotRun__c = InventoryAvailableFeedNotRun;
            }
            

            //Update all tracker fields that have a mis-match with the boolean created above
            if (oppTracker.Zuora_ActivePaymentMethodMatch__c != zuoraPaymentMethodMatch){
                oppTracker.Zuora_ActivePaymentMethodMatch__c = zuoraPaymentMethodMatch;
            }
            
            if (oppTracker.Zuora_QuotePaymentMethod__c != quotePaymentMethodDone){
                oppTracker.Zuora_QuotePaymentMethod__c = quotePaymentMethodDone;
            }
            
            if(oppTracker.Zuora_ActiveBillingAccounts__c != zuoraAccountsSet){
                oppTracker.Zuora_ActiveBillingAccounts__c = zuoraAccountsSet;
            }
            
            if (oppTracker.Quote_Approved__c != omApprovedQuote){
                oppTracker.Quote_Approved__c = omApprovedQuote;
            }
            
            if (oppTracker.Quote_StartDate__c != quoteStartDateNotInPast){
                oppTracker.Quote_StartDate__c = quoteStartDateNotInPast;
            }
            
            if (oppTracker.Quote_AreaBoostInformation__c != areaBoostInformationDone){
               oppTracker.Quote_AreaBoostInformation__c = areaBoostInformationDone;
           }

            if (oppTracker.DocusignComplete__c != docusignCompleted){
                oppTracker.DocusignComplete__c = docusignCompleted;
            }

            if (oppTracker.Granular_Territory_Assigned__c != accountTerritoryAssigned){
                oppTracker.Granular_Territory_Assigned__c = accountTerritoryAssigned;
            }

            //Check if opp tracker needs an update, and pass in a new version (with the Id) - just
            //so we don't update the override fields - only the true done fields
            if (oppTracker != oppTrackerClone){
                oppTrackersToUpdate.add(new Opportunity_Tracker__c(
                    Id = oppTracker.Id,
                    Zuora_ActivePaymentMethodMatch__c = oppTracker.Zuora_ActivePaymentMethodMatch__c,
                    Zuora_QuotePaymentMethod__c = oppTracker.Zuora_QuotePaymentMethod__c,
                    Zuora_ActiveBillingAccounts__c = oppTracker.Zuora_ActiveBillingAccounts__c,
                    
                    
                    Quote_Approved__c = oppTracker.Quote_Approved__c,
                    Quote_StartDate__c = oppTracker.Quote_StartDate__c,
                    Quote_AreaBoostInformation__c = oppTracker.Quote_AreaBoostInformation__c,
                    
                    Spid_HasInventory__c = oppTracker.Spid_HasInventory__c,
                    DocusignComplete__c = oppTracker.DocusignComplete__c,
                    Spid_CDA__c = oppTracker.Spid_CDA__c,
                    Spid_DealerEmail__c = oppTracker.Spid_DealerEmail__c ,
                    Spid_InventoryAvailableFeedNotRun__c = oppTracker.Spid_InventoryAvailableFeedNotRun__c,

                    Granular_Territory_Assigned__c = oppTracker.Granular_Territory_Assigned__c
                ));
            }

        }
        
        
        //Update the opp tracker in a future method
        if (!oppTrackersToUpdate.isEmpty()){
            update oppTrackersToUpdate;
        }

        //Return the first value in the oppToCheckWrapper - this is utilized by the LWC controller that can 
        //use the object's values to calculate variables
        return oppToCheckWrapper.values()[0];
    }

    public class CheckOppsWrapper{
        public Opportunity opp;
        public Opportunity_Tracker__c oppTracker;
        public SBQQ__Quote__c quote;
        public boolean hasAreaBoostProduct;
        public Service_Provider__c displayedSP;
        public List<Service_Provider__c> additionalSP;

        public CheckOppsWrapper(Opportunity opp, Opportunity_Tracker__c oppTracker, SBQQ__Quote__c quote, boolean hasAreaBoostProduct){
            this.opp = opp;
            this.oppTracker = oppTracker;
            this.quote = quote;
            this.hasAreaBoostProduct = hasAreaBoostProduct;
        }
    }

    //BR-9131, wrapper created to be used in service provider weightage logic
    public class WeighServiceProvider{
        public Boolean fullfillmentAccountsHaveInventory;
        public Boolean cdaDone;
        public Boolean dealerEmailDone;
        public Boolean InventoryAvailableFeedNotRun;
        public Integer weightage;
        public String serviceProviderName;
        public String serviceProviderId;
        public String fullfillmentAccountId;

        public WeighServiceProvider(){
            this.fullfillmentAccountsHaveInventory = false;
            this.cdaDone = false;
            this.dealerEmailDone = false;
            this.InventoryAvailableFeedNotRun = false;
            this.weightage = 0;
            this.serviceProviderName = '';
        }
    }

}