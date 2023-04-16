public without sharing class CPQ_Subscription_TriggerFunctions {

    private static final Set<String> ACTIVE_CPQ_PROVISIONING_STATUSES = new Set<String>{'Activated','Pending Activation','Delinquent'};
    private static final String CGBASE_PRODUCTCODE = ConstantsUtil.PRODUCT_PRODUCTCODE_CGBASE;
    private static final String CUSTOMER_TYPE = 'Customer';

    // set holding active sub statuses
    private static final Set<String> SUB_ACTIVATED_STATUSES = new Set<String>{
        ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE
    };

    // set holding deactive sub statuses
    private static final Set<String> SUB_DEACTIVATED_STATUSES = new Set<String>{
        ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_INACTIVE,
        ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_DELINQUENT,
        ConstantsUtil.SUBSCRIPTION_PROVISIONINGSTATUS_PENDING
    };

    /**
     * When a subs status changes, checks if a message is needed to update PH
     */

    public static void processPHIntegrationUpdates(SBQQ__Subscription__c[] subList, Map<Id,SBQQ__Subscription__c> oldMap) {

        List<SBQQ__Subscription__c> updatedSubs = new List<SBQQ__Subscription__c>();
        String oldStatus;
        String newStatus;
        Set<String> phProductCodes = ConstantsUtil.PH_PRODUCT_CODES;

        // check subs for status change to see if we should continue, prevent unecessary SOQL
        for (SBQQ__Subscription__c sub : subList) {
            oldStatus = oldMap.size() > 0 ? oldMap.get(sub.Id).Provisioning_Status__c : null;
            newStatus = sub.Provisioning_Status__c;
            
            if (oldStatus != null && newStatus != oldStatus) {
                updatedSubs.add(sub);
            }
        }

        // only continue if necessary
        if (updatedSubs.size() > 0) {
            // sets to hold messages
            Map<Id, Boolean> activationMessageIds = new Map<Id,Boolean>();
            Map<Id, Id> activationMessageProductIds = new Map<Id,Id>();
            Map<Id, Boolean> deactivationMessageIds = new Map<Id,Boolean>();
            Map<Id, Id> deactivationMessageProductIds = new Map<Id, Id>();

            // get piston heads product codes
            //phProductCodes = ConstantUtils.PH_PRODUCT_CODES;


            // loop through subs in scope
            for (SBQQ__Subscription__c sub : updatedSubs) {
                // set provision statuses to vars
                oldStatus = oldMap.size() > 0 ? oldMap.get(sub.Id).Provisioning_Status__c : null;
                newStatus = sub.Provisioning_Status__c;
                String productCode = sub.Product_Code__c;
                Id productId = sub.SBQQ__ProductId__c;
                
                if (phProductCodes.contains(productCode)) {
                    // check productcode for isfeatured boolean
                    Boolean isFeatured = productCode.contains('FEAT');

                    // sub has changed from delinquent / deactivated to activated
                    if (
                        SUB_ACTIVATED_STATUSES.contains(newStatus) && 
                        SUB_DEACTIVATED_STATUSES.contains(oldStatus)
                    ) {
                        activationMessageIds.put(sub.Fulfillment_Account__c, isFeatured);
                        activationMessageProductIds.put(sub.Fulfillment_Account__c, productId);
                    // sub has changed from actived to delinquent / deactivated
                    }  else if (
                        SUB_ACTIVATED_STATUSES.contains(oldStatus) && 
                        SUB_DEACTIVATED_STATUSES.contains(newStatus)
                    ) {
                        deactivationMessageIds.put(sub.Fulfillment_Account__c, isFeatured);
                        deactivationMessageProductIds.put(sub.Fulfillment_Account__c, productId);
                    }
                }
            }

            // if there are deactivation messages to send, send them
            if (!deactivationMessageIds.isEmpty()) {
                PHIntegration_AccountHelper.createAndSendPHAccountMessages(deactivationMessageIds, deactivationMessageProductIds, false, true);
            }

            // if there are activation messages to send, send them
            if (!activationMessageIds.isEmpty()) {
                PHIntegration_AccountHelper.createAndSendPHAccountMessages(activationMessageIds, activationMessageProductIds, true, false);
            }
        }

    }
    
    // BR-894 - for all related orders, check that the order items all have related cpq subscriptions
    // BR-3884 - added in functionality for ph integration, changed name of method
    // if so, set the activation status field for zuora subscription to 'pending' to kick off order integration
    public static void setOrdersPending(List<SBQQ__Subscription__c> cpqSubs) {
        Set<Id> orderItemIds = new Set<Id>();
        Set<Id> phOrderItemIds = new Set<Id>();
        Set<Id> phOrderIds = new Set<Id>();
        Set<String> phProductCodes = ConstantsUtil.PH_PRODUCT_CODES;

        for (SBQQ__Subscription__c cpqSub : cpqSubs) {
            orderItemIds.add(cpqSub.SBQQ__OrderProduct__c);

            // BR-3884 - PH Integraiton
            if (phProductCodes.contains(cpqSub.Product_Code__c))  {
                phOrderItemIds.add(cpqSub.SBQQ__OrderProduct__c);
            }
        }

        orderItemIds.remove(null);

        if (orderItemIds.isEmpty()) {
            return;
        }

        Map<Id,Order> updateOrderMap = new Map<Id,Order>(
            [SELECT Id, 
                (SELECT Id FROM OrderItems WHERE Product2.ProductCode = :CGBASE_PRODUCTCODE
                AND Quantity < 0) FROM Order WHERE Activation_Zuora_Subscription__c = null AND Id IN 
                (SELECT OrderId FROM OrderItem WHERE Id IN :orderItemIds)]
        );

        if (phOrderItemIds.size() > 0) {
            List<OrderItem> phOrderItems = new List<OrderItem>([SELECT Id, OrderId FROM OrderItem WHERE Id IN: phOrderItemIds]);
            
            for (OrderItem oItem : phOrderItems) {
                phOrderIds.add(oItem.OrderId);
            }
        } 

        for (OrderItem noSubOrderItem : [SELECT Id, OrderId FROM OrderItem 
                WHERE OrderId IN :updateOrderMap.keySet() 
                AND Id NOT IN (SELECT SBQQ__OrderProduct__c FROM SBQQ__Subscription__c
                    WHERE SBQQ__OrderProduct__r.OrderId IN :updateOrderMap.keySet())]) 
        {
            updateOrderMap.remove(noSubOrderItem.OrderId);
        }

        if (updateOrderMap.isEmpty()) {
            return;
        }

        for (Order o : updateOrderMap.values()) {
            List<OrderItem> oItems = o.OrderItems;
            if(oItems.size() > 0) {
                o.Activation_Status_Renew_Prior__c = ConstantsUtil.ACTIVATION_STATUS_PENDING;
            } else {
                o.Activation_Status_Renew_Prior__c = ConstantsUtil.ACTIVATION_STATUS_NA;
                o.Activation_Zuora_Subscription__c = ConstantsUtil.ACTIVATION_STATUS_PENDING;
            }

            // if order also needs ph update, set field remove from PH map
            if (phOrderIds.contains(o.Id)) {
                o.Activation_PH_Admin_Centre__c = ConstantsUtil.ACTIVATION_STATUS_PENDING;
            }
        }


        if (!updateOrderMap.isEmpty()) {
            try{
                update updateOrderMap.values();
            } catch (DMLException e) {
                throw e;
            }
           
        }
    }
    
    public static void initialSetup(SBQQ__Subscription__c[] subList) {

        for (SBQQ__Subscription__c sub : subList) {
            sub.Provisioning_Status__c = 'Pending Activation';
            sub.SBQQ__SubscriptionEndDate__c = null;
        }

    }

    //For BR-1470
    //Update Account Type based on active CPQ Subs
    public static void updateAccountType(SBQQ__Subscription__c[] subList, Map<Id,SBQQ__Subscription__c> oldMap) {

        Map<Id,Integer> fulfillmentAcctIds = new Map<Id,Integer>();

        for (SBQQ__Subscription__c sub : subList) {

            if (!fulfillmentAcctIds.containsKey(sub.Fulfillment_Account__c)) {
                fulfillmentAcctIds.put(sub.Fulfillment_Account__c,0);
            }

            if(!fulfillmentAcctIds.containsKey(sub.Billing_Account__c)) {
                fulfillmentAcctIds.put(sub.Billing_Account__c, 0);
            }

            if (oldMap != null) {

                SBQQ__Subscription__c oldSub = oldMap.get(sub.Id);

                if ((!ACTIVE_CPQ_PROVISIONING_STATUSES.contains(oldSub.Provisioning_Status__c)
                        && ACTIVE_CPQ_PROVISIONING_STATUSES.contains(sub.Provisioning_Status__c))) {
                    Integer count = fulfillmentAcctIds.get(sub.Fulfillment_Account__c);
                    fulfillmentAcctIds.put(sub.Fulfillment_Account__c,count+1);
                }

            } else {    //all new CPQ Subs should pending activation, so should auto 
                Integer count = fulfillmentAcctIds.get(sub.Fulfillment_Account__c);
                fulfillmentAcctIds.put(sub.Fulfillment_Account__c,count+1);
            }
        }
        checkAccountCPQSubs(fulfillmentAcctIds);
    }

    public static void checkAccountCPQSubs(Map<Id,Integer> accountIds) {
        
        Map<Id,Account> acctMap = new Map<Id,Account>([SELECT Id, Type, 
                    (SELECT Id, Fulfillment_Account__c FROM CPQ_Subscriptions_Fulfillment__r
                    WHERE Provisioning_Status__c IN: ACTIVE_CPQ_PROVISIONING_STATUSES),
                    (SELECT Id, Billing_Account__c FROM CPQ_Subscription_Billing__r
                    WHERE Provisioning_Status__c IN: ACTIVE_CPQ_PROVISIONING_STATUSES),
                    (SELECT Id, AccountId FROM Contracts 
                    WHERE Status IN: ACTIVE_CPQ_PROVISIONING_STATUSES)
                FROM Account WHERE Id IN: accountIds.keySet()]);
                
        Account[] updateList = new List<Account>();

        for (Id acctId : acctMap.keySet()) {

            Account a = acctMap.get(acctId);
            String currentType = a.Type;
            SBQQ__Subscription__c[] relatedActiveSubs = a.CPQ_Subscriptions_Fulfillment__r;
            SBQQ__Subscription__c[] relatedActiveBillingSubs = a.CPQ_Subscription_Billing__r;
            Contract[] relatedActiveContracts = a.Contracts;
            System.debug('Found ' + relatedActiveSubs.size() + ' Active/Pending Subs');
            Boolean updated = false;
            Integer count = accountIds.get(acctId);
            count += relatedActiveSubs.size();
            count += relatedActiveBillingSubs.size();
            count += relatedActiveContracts.size();


            if (currentType == CUSTOMER_TYPE && count == 0) {
                a.Type = 'Former Customer';
                updated = true;
            } else if (currentType != CUSTOMER_TYPE && count > 0) {
                a.Type = 'Customer';
                updated = true;
            }

            if (updated) { updateList.add(a); }
        }

        if (!updateList.isEmpty()) { update updateList; }

    }

    //BR-1452 - Test method - Batch_SubscriptionProvisionStatusTest - testMismatchBatchUpdate
    public static void setProvisioningStatusOnMismatch(List<SBQQ__Subscription__c> subList) {
        for (SBQQ__Subscription__c sub : subList) {
            
            if (sub.Provisioning_Status_Mismatch__c) {
                sub.Provisioning_Status__c = sub.Provisioning_Status_Formula__c;
            }
        }
    }

    public static void evaluateCancellingBundles(Map<Id,SBQQ__Subscription__c> oldMap, Map<Id,SBQQ__Subscription__c> newMap) {
      
        Set<Id> fulfillmentAccountsIds = new Set<Id>();
        Set<Id> contractsIds = new Set<Id>();
        Set<SBQQ__Subscription__c> negativeQtyBaseBundles = new Set<SBQQ__Subscription__c>();

        Set<Id> contractIds = new Set<Id>();

        for(SBQQ__Subscription__c sub : newMap.values()) {
            if(sub.SBQQ__Quantity__c == -1 && sub.SBQQ__ProductName__c == 'CG Base Bundle') {
                fulfillmentAccountsIds.add(sub.Fulfillment_Account__c);
                contractsIds.add(sub.SBQQ__Contract__c);
                negativeQtyBaseBundles.add(sub);
            }
        }

        if(fulfillmentAccountsIds.isEmpty()) {
            return;
        }

        Map<Id, Contract> contractsMap = new Map<Id, Contract>([SELECT Id, Cancellation_Effective_Date__c FROM
            Contract WHERE Id IN :contractsIds]);    

        Set<Id> bundlesWithCoreListingsIds = new Set<Id>();
        for(SBQQ__Subscription__c sub : [
            SELECT Id, Fulfillment_Account__c, SBQQ__Contract__c, SBQQ__ProductName__c, 
            SBQQ__Quantity__c, SBQQ__TerminatedDate__c, SBQQ__RequiredById__c, 
            SBQQ__Product__r.Family, SBQQ__Product__r.product_category__c, SBQQ__Product__r.Sub_Category__c 
            FROM SBQQ__Subscription__c 
            WHERE Fulfillment_Account__c IN :fulfillmentAccountsIds
            AND SBQQ__Quantity__c > 0
            AND SBQQ__ProductName__c != 'CG Base Bundle'
            AND SBQQ__Product__r.Family = 'Listings'
            AND SBQQ__Product__r.product_category__c = 'Core Products'
        ]) {
            bundlesWithCoreListingsIds.add(sub.SBQQ__RequiredById__c);
        }

        Set<String> trulyRemovedBundlesByFulfillmentAccountIds = new Set<String>();
        for(AggregateResult ar: [
            SELECT Fulfillment_Account__c, SBQQ__Contract__c, SUM(SBQQ__Quantity__c)
            FROM SBQQ__Subscription__c
            WHERE SBQQ__Contract__c IN :contractsIds
            AND Fulfillment_Account__c IN :fulfillmentAccountsIds
            AND SBQQ__ProductName__c = 'CG Base Bundle'
            GROUP BY Fulfillment_Account__c, SBQQ__Contract__c
            HAVING SUM(SBQQ__Quantity__c) = 0
        ]) {
            String key = (Id)ar.get('Fulfillment_Account__c') + '|' + (Id)ar.get('SBQQ__Contract__c');
            trulyRemovedBundlesByFulfillmentAccountIds.add(key);
        }

        if(trulyRemovedBundlesByFulfillmentAccountIds.isEmpty()) {
            return;
        }

        List<Account> accountsToUpdate = new List<Account>();

        // iterate over the potentially removed base bundles
        for(SBQQ__Subscription__c sub : negativeQtyBaseBundles) {

            // if the bundle does not contain core listings products, omit
            if(!bundlesWithCoreListingsIds.contains(sub.SBQQ__RevisedSubscription__c)) {
            continue;
            }

            String key = sub.Fulfillment_Account__c + '|' + sub.SBQQ__Contract__c;
            // if the bundle was not truly removed (ie Rate Reduction), omit
            if(!trulyRemovedBundlesByFulfillmentAccountIds.contains(key)) {
                continue;
            }

            //BR-8618 - check cancellation effective date before changing
            //product activation status
            Contract ct = contractsMap.get(sub.SBQQ__Contract__c);
            Date ced = ct.Cancellation_Effective_Date__c;

            if(ced != null && ced <= Date.today()) {
                accountsToUpdate.add(
                new Account(
                    Id = sub.Fulfillment_Account__c,
                    Cancellation_Effective_Date__c = ced,
                    Last_Cancellation_Effective_Date__c = ced,
                    Product_Activation_Status__c = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_CANCELING57DAYS
                ));
            }
        }
        
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }


    //SA-943
    public static void aggregateNetPrice(List<SBQQ__Subscription__c> newList) {
        
		Map<Id, Decimal> listingsMRRByAccount = new Map<Id, Decimal>();
        Set<Id> ffAccIds = new Set<Id>();
        
        // Get all fullfillment accounts from subscriptions
        for(SBQQ__Subscription__c sub : newList) {
            listingsMRRByAccount.put(sub.Fulfillment_Account__c, 0); 
        }
        
        // Query for all activated subscriptions using the fulfillment accounts and create a map of listings MRR by account id
        List<SBQQ__Subscription__c> activatedSubs = [SELECT Id, Product_Code__c, SBQQ__Product__c, SBQQ__Product__r.Family, SBQQ__NetPrice__c, Fulfillment_Account__c
                                                    FROM SBQQ__Subscription__c 
                                                    WHERE SBQQ__Quantity__c > 0 AND Provisioning_Status__c = 'Activated' 
                                                        AND Fulfillment_Account__c IN :listingsMRRByAccount.keySet()];
        if(!activatedSubs.isEmpty()) {
        	for(SBQQ__Subscription__c sub : activatedSubs) { 
                Id ffAccId = sub.Fulfillment_Account__c;
                if(sub.SBQQ__Product__r.Family == 'Listings') {
                	if(!listingsMRRByAccount.containsKey(ffAccId)) {
                    	listingsMRRByAccount.put(ffAccId, 0);
                	}
                    Decimal netPrice = sub.SBQQ__NetPrice__c == null ? 0 : sub.SBQQ__NetPrice__c;
                	listingsMRRByAccount.put(ffAccId, listingsMRRByAccount.get(ffAccId) + netPrice);                          
                }                         
        	}    
        }
        
        List<Account> accountsToUpdate = new List<Account>();

        // Create a list of accounts to update
        for(Id accId : listingsMRRByAccount.keySet()) {
            Account acc = new Account(Id = accId);
            acc.Listings_CMRR_Without_Cancellations__c = listingsMRRByAccount.get(accId);
            accountsToUpdate.add(acc);
        }

        update accountsToUpdate;
    }


    /**
    * Validate if the Subscription Billing Account has been changed. Inform errors or set the proper Invoice Change Status
    * @author   Ramiro A.
    * @date     11/03/21
    * @module   BR-3733 : Change Invoice Owner in Salesforce
    */
    public static void validateChangeOnBillingAccount(Map<Id,SBQQ__Subscription__c> oldMap, List<SBQQ__Subscription__c> newList) {

        Set<Id> updatedAccountIds = new Set<Id>();
        Set<Id> contractIds = new Set<Id>();
        Map<SBQQ__Subscription__c,Id> subBillingAccountMap = new Map<SBQQ__Subscription__c,Id> ();
        Map<Id,Id> subBillingAccountIdOldMap = new Map<Id,Id> ();

        for (SBQQ__Subscription__c sub : newList) {
            //Check if the Billing Account has been changed. If yes, populate subBillingAccountMap map
            if (sub.Billing_Account__c != null &&
            oldMap.get(sub.Id).Billing_Account__c != sub.Billing_Account__c &&
            sub.Zuora_Subscription__c != null &&
            sub.Product_Code__c == 'CG-BASE') {
                subBillingAccountMap.put(sub, sub.Billing_Account__c);
                contractIds.add(sub.SBQQ__Contract__c);
                subBillingAccountIdOldMap.put(sub.Id, oldMap.get(sub.Id).Billing_Account__c);
            }
        }

        // If no updates, return
        if (subBillingAccountMap.isEmpty()) {
            return;
        }

        // Query for the related Billing Account data
        Map<Id, Account> billingAccountWithRelatedMap = new Map<Id,Account> ([SELECT Id, Name, Billing_Account_Zuora__c,
            Billing_Account_Zuora__r.Zuora__AutoPay__c,
            Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c
            FROM Account
            WHERE Id IN :subBillingAccountMap.values()
            OR Id IN :subBillingAccountIdOldMap.values()]);

        // Query the related Contract to get Quote Payment Method
        Map<Id,Contract> contractPaymentMethodMap = new Map<Id,Contract> ([SELECT Id, SBQQ__Quote__r.Payment_Method__c
            FROM Contract
            WHERE Id IN :contractIds]);
        
        Set<Id> subAutoPayValidationsIds = new Set<Id> ();
        Set<Id> subNoPayMethodMatchValidationsIds = new Set<Id> ();
        for (SBQQ__Subscription__c sub : subBillingAccountMap.keySet()) {
            
            // Default Payment Method on the related Zuora Account
            String zuoraPaymentMethod = billingAccountWithRelatedMap.get(sub.Billing_Account__c).Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c;
            
            //Is auto pay customer
            Boolean autoPay = billingAccountWithRelatedMap.get(sub.Billing_Account__c).Billing_Account_Zuora__r.Zuora__AutoPay__c;

            // Default Payment Method on the related Quote
            String defaultPaymentMethod;
            if (contractPaymentMethodMap.get(sub.SBQQ__Contract__c).SBQQ__Quote__r != null) {
                defaultPaymentMethod = contractPaymentMethodMap.get(sub.SBQQ__Contract__c).SBQQ__Quote__r.Payment_Method__c == 'Credit Card' ? 'CreditCard' :
                    contractPaymentMethodMap.get(sub.SBQQ__Contract__c).SBQQ__Quote__r.Payment_Method__c;
            } else {
                // If it is no quote, it's a migrated contract. The Default Payment Method is get from the old Zuora Billing Account
                defaultPaymentMethod =  billingAccountWithRelatedMap.get(oldMap.get(sub.Id).Billing_Account__c).Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c;
            }

            //Validation #1 - Autopay customers require a credit card
            if (autoPay && zuoraPaymentMethod != 'CreditCard') {
                subAutoPayValidationsIds.add(sub.Id);
            }

            //Validation #2 - Check customers must be approved by collections.
            else if (zuoraPaymentMethod == 'Check') {
                sub.Invoice_Change_Status__c  = 'Pending Collections Approval'; //Trigger Approval Process

            //Validation #3 - If it is not a check customer, must match quote Payment Method
            } else if(zuoraPaymentMethod != defaultPaymentMethod) {
                subNoPayMethodMatchValidationsIds.add(sub.Id);
            } else {
                sub.Invoice_Change_Status__c = 'Completed';
            }
        }

        for (SBQQ__Subscription__c sub : newList) {
            if (subAutoPayValidationsIds.contains(sub.Id)) {
                sub.addError('The Account: ' + billingAccountWithRelatedMap.get(sub.Billing_Account__c).Name +
                 ' is Auto Pay customer. Credit Card is required');
            } else {
                if (subNoPayMethodMatchValidationsIds.contains(sub.Id)) {
                    sub.addError('The Account: ' + billingAccountWithRelatedMap.get(sub.Billing_Account__c).Name +
                     ' default Payment Method does not match the Quote Payment Method');
                }
            }
        }
    }

    /**
    * Send for Collections Approval if Invoice Change Status is 'Pending Collections Approval'
    * @author   Ramiro A.
    * @date     11/03/21
    * @module   BR-3733 : Change Invoice Owner in Salesforce
    */
    public static void changeOwnerSendCollectionsApproval(Map<Id,SBQQ__Subscription__c> oldMap, List<SBQQ__Subscription__c> newList) {

        Map<Id,SBQQ__Subscription__c> subMap = new Map<Id,SBQQ__Subscription__c> ();        
        for (SBQQ__Subscription__c sub : newList) {
            if (oldMap.get(sub.Id).Invoice_Change_Status__c != sub.Invoice_Change_Status__c &&
                sub.Invoice_Change_Status__c == 'Pending Collections Approval' &&
                sub.Billing_Account__c != null)
            {
                subMap.put(sub.Id,sub);
            }
        }

        // If Invoice Owner has been changed to 'Pending Collections Approval', submit Subcription for Approval
        if (!subMap.isEmpty()) {
            for (SBQQ__Subscription__c sub : subMap.values()) {
                submitSubOwnerChangeForApproval(sub);
            }
        }
    }

    /**
    * Send to Zuora the update for the Subscription Billing Account (Invoice Change Status = Completed)
    * @author   Ramiro A.
    * @date     11/03/21
    * @module   BR-3733 : Change Invoice Owner in Salesforce
    */

    public static void changeZuoraOwner(Map<Id,SBQQ__Subscription__c> oldMap, List<SBQQ__Subscription__c> newList) {

        Set<Id> subIds = new Set<Id> ();
        for (SBQQ__Subscription__c sub : newList) {
            if (oldMap.get(sub.Id).Invoice_Change_Status__c != sub.Invoice_Change_Status__c &&
                sub.Invoice_Change_Status__c == 'Completed' &&
                sub.Billing_Account__c != null &&
                sub.Zuora_Subscription__c != null) {
                subIds.add(sub.Id);
            }
        }

        List<SBQQ__Subscription__c> subsToUpd = new List<SBQQ__Subscription__c>();
        if (!subIds.isEmpty()) {
            //Call Zuora API to perform subscription owner transfer
            if (!Test.isRunningTest()) {
                ZuoraIntegration_SupplementOrderHelper.sendAmendTransferOwnerMessages(subIds, true);
            }
        
            for(Id subId : subIds) {
                //Refresh 'Invoice Change Status' field to null
                subsToUpd.add(new SBQQ__Subscription__c(Id = subId, Invoice_Change_Status__c = null));
            }
            if (!subsToUpd.isEmpty()) {
                update subsToUpd;
            }
        }
    }

    /**
    * Submit Subscription Owner Change for Collections Approval
    * @author   Ramiro A.
    * @date     11/03/21
    * @module   BR-3733 : Change Invoice Owner in Salesforce
    */
    @TestVisible
    private static void submitSubOwnerChangeForApproval(SBQQ__Subscription__c sub) {         
        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();          
        req.setComments('Submitting approval request using Trigger');        
        req.setObjectId(sub.Id);       
        Approval.ProcessResult result = Approval.process(req);        
        System.debug('Account submitted for approval successfully: '+result.isSuccess());
     }

    /**
    * Update Billing Account on child Subs based on the related CG-BASE parent sub
    * @author   Ramiro A.
    * @date     12/13/21
    * @module   BR-3733 : Change Invoice Owner in Salesforce
    */
    public static void updateBillingAccountOnChildSubs(Map<Id,SBQQ__Subscription__c> oldMap, List<SBQQ__Subscription__c> newList) {                
        
        Map<Id,Id> subBillingAccMap = new Map<Id,Id> ();
        Set<Id> contractIds = new Set<Id> ();
        List<SBQQ__Subscription__c> subToBeUpd = new List<SBQQ__Subscription__c> ();
        for (SBQQ__Subscription__c sub : newList) {

            //Check if the Billing Account has been changed. If yes, populate subBillingAccountMap map
            if (sub.Billing_Account__c != null &&
            oldMap.get(sub.Id).Billing_Account__c != sub.Billing_Account__c &&
            sub.Zuora_Subscription__c != null &&
            sub.Product_Code__c == 'CG-BASE') {
                
                subBillingAccMap.put(sub.Id, sub.Billing_Account__c);
                contractIds.add(sub.SBQQ__Contract__c);
            }
        }

        // If no updates, return
        if (subBillingAccMap.isEmpty()) {
            return;
        }

        for (SBQQ__Subscription__c childSub : [SELECT Id,SBQQ__RequiredById__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__RequiredById__c IN :subBillingAccMap.keySet()
            AND SBQQ__Contract__c IN :contractIds
            AND Product_Code__c != 'CG-BASE'])
        {
            subToBeUpd.add(new SBQQ__Subscription__c(Id = childSub.Id, Billing_Account__c = subBillingAccMap.get(childSub.SBQQ__RequiredById__c)));
        }

        if (!subToBeUpd.isEmpty()) {
            update subToBeUpd;
        }
    }

}