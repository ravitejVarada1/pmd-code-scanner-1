/**
 * @author  Adam LaPlante
 * @date    12/23/21
 * @module  BR-3884
 */

public without sharing class PHIntegration_AccountHelper {

    /**
     * Global Vars
     */
    
    static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;

    static final Datetime SEND_ON_DELAY = Datetime.now().addMinutes(10); // used to send on delay
    static final Datetime SEND_IMMEDIATELY = Datetime.now().addMinutes(-10);// used to send immediately

    static final String PROCESS_PHACCOUNT = Integrations.PROCESS_PHACCOUNT;
    static final String REQUEST_STATUS_NEW = Integrations.REQUEST_STATUS_NEW;
    static final String APPROVALSTATUS_APPROVED = ConstantsUtil.QUOTE_APPROVALSTATUS_APPROVED;
    static final Set<String> PH_PRODUCT_CODES = ConstantsUtil.PH_PRODUCT_CODES;
    static Set<Id> accountIdsInProgress;

    /**
     * For supplied quote ids, create PH account messages for accounts that need creating in PH
     */

    public static void createAndSendPHAccountMessages(Set<Id> orderIds, Boolean sendImmediately) {

        // check if PH Integration is enabled in env
        if (!INTEGRATION_CONTROLS.Enable_PH_Integration__c || orderIds.isEmpty()) {
            return;
        }

        // if not in async context, kick to future method
        if (!System.isBatch() && !System.isFuture() && !Test.isRunningTest()) {
            createAndSendPHAccountMessagesFuture(orderIds, sendImmediately);
            return;
        }

        // generate integration messages
        List<Integration_Message__c> phAccountMessages = getPHAccountMessages(orderIds, sendImmediately);

        // if account messages are created, insert and send
        if (!phAccountMessages.isEmpty()) {
            insert phAccountMessages;
            Integrations.sendMessageIdsToBoomi(phAccountMessages);
        }

    }


    @future // round trip back to main method in a future context
    static void createAndSendPHAccountMessagesFuture(Set<Id> orderIds, Boolean sendImmediately) {
        createAndSendPHAccountMessages(orderIds, sendImmediately);
    }

    /**
     * For supplied quote ids, create PH account messages for accounts that need creating in PH
     */

    public static void createAndSendPHAccountMessages(Map<Id, Boolean> accountIdMap, Map<Id, Id> accountProductIdMap, Boolean activateAccount, Boolean sendImmediately) {

        // check if PH Integration is enabled in env
        if (!INTEGRATION_CONTROLS.Enable_PH_Integration__c) {
            return;
        }

        // if not in async context, kick to future method
        if (!System.isBatch() && !System.isFuture() && !Test.isRunningTest()) {
            createAndSendPHAccountMessagesFuture(accountIdMap, accountProductIdMap, activateAccount, sendImmediately);
            return;
        }

        // generate integration messages
        List<Integration_Message__c> phAccountMessages = getPHAccountMessages(accountIdMap, accountProductIdMap, activateAccount, sendImmediately);

        // if account messages are created, insert and send
        if (!phAccountMessages.isEmpty()) {
            insert phAccountMessages;
            Integrations.sendMessageIdsToBoomi(phAccountMessages);
        }

    }

    @future // round trip back to main method in a future context
    static void createAndSendPHAccountMessagesFuture(Map<Id, Boolean> accountIdMap, Map<Id, Id> accountProductIdMap, Boolean activateAccount, Boolean sendImmediately) {
        createAndSendPHAccountMessages(accountIdMap, accountProductIdMap, activateAccount, sendImmediately);
    }

    /**
     * Construct integration messages for accounts that need creating in PH
     */

    public static List<Integration_Message__c> getPHAccountMessages(Set<Id> orderIds, Boolean sendImmediately) {
        
        List<Integration_Message__c> returnMessages = new List<Integration_Message__c>();
        Map<Id,Id> accountIdQuoteIdMap = new Map<Id,Id>();
        Map<Id, Order> quoteIdToOrderMap = new Map<Id, Order>();
        List<Id> quoteIds = new List<Id>();
        sendImmediately = sendImmediately == false ? false  : true;

        Map<Id, Order> orders = new Map<Id, Order>([SELECT Id, SBQQ__Quote__c FROM Order WHERE Id IN :orderIds]);
        List<Order> ordersToUpdate = new List<Order>();

        for (Order o : orders.values())  {
            quoteIdToOrderMap.put(o.SBQQ__Quote__c, o);
        }

        // go through quote lines to find all related billing and fulfillment accounts
        for (SBQQ__QuoteLine__c ql : getAccountQuoteLines(quoteIdToOrderMap.keySet())) {
            // gather Id vars
            Id quoteId = ql.SBQQ__Quote__c;
            Id fAccountId = ql.Fulfillment_Account__c;

            // put billing account in account to quote map
            accountIdQuoteIdMap.put(fAccountId, quoteId);
        }

        quoteIds = accountIdQuoteIdMap.values();
        
        // query for accounts with all fields needed to construct PH account messages
        Map<Id,Account> accountMap = getAccountMap(accountIdQuoteIdMap.keySet());

        // loop through accounts in account map
        for (Account a : accountMap.values()) {
            // if the account already exists in PH skip
            if (a.PH_Admin_Centre_Id__c != null) {
                // remove quote id from quote ids
                quoteIds.remove(
                    quoteIds.indexOf(
                        accountIdQuoteIdMap.get(a.Id)
                    )
                );

                // if no ph activation is needed, put order in queue for update
                if (quoteIds.indexOf(accountIdQuoteIdMap.get(a.Id)) == -1) {
                    ordersToUpdate.add(quoteIdToOrderMap.get(accountIdQuoteIdMap.get(a.Id)));
                }
                accountIdQuoteIdMap.remove(a.Id);
            }
        }

        // query for all related quote info needed to construct PH account messages
        Map<Id,SBQQ__Quote__c> quoteMap = getQuoteMap(accountIdQuoteIdMap.values());

        // remove any accounts from map which are already have a sync in progress
        //accountIdQuoteIdMap.keySet().removeAll(getAccountIdsInProgress());
        
        // create an integration message for each eligible account
        for (Id accountId : accountIdQuoteIdMap.keySet()) {
            Id quoteId = accountIdQuoteIdMap.get(accountId);
            // create message and add to return messages
            returnMessages.add(
                createIntegrationMessage(
                    accountMap.get(accountId), 
                    quoteMap.get(quoteId),
                    quoteIdToOrderMap.get(quoteId),
                    sendImmediately
                )
            );
        }

        if (!ordersToUpdate.isEmpty()){
            for (Order o : ordersToUpdate) {
                o.Activation_PH_Admin_Centre__c = '';
            }

            try {
                update ordersToUpdate;
            } catch (DMLException e){
                system.debug('Error updating orders::' + e.getMessage());
            }
        }

        return returnMessages;
    }

    /**
     * Construct integration messages for accounts that need creating in PH
     */

    public static List<Integration_Message__c> getPHAccountMessages(Map<Id, Boolean> accountIdMap, Map<Id, Id> accountProductIdMap, Boolean activateAccount, Boolean sendImmediately) {
        
        List<Integration_Message__c> returnMessages = new List<Integration_Message__c>();
        sendImmediately = sendImmediately == false ? false  : true;

        // query for accounts with all fields needed to construct PH account messages
        Map<Id,Account> accountMap = getAccountMap(accountIdMap.keySet());

        /* 
        
        Logic in block below seems incorrect, commenting out 01/27/2023

        // loop through accounts in account map
        for (Account a : accountMap.values()) {
            // if the account already exists in PH skip
            if (a.PH_Admin_Centre_Id__c == null) {
                accountIdMap.remove(a.Id);
            }
        }
        

        // remove any accounts from map which are already have a sync in progress
        //accountIdMap.keySet().removeAll(getAccountIdsInProgress());

        */
        
        // create an integration message for each eligible account
        for (Id accountId : accountIdMap.keySet()) {
            // create message and add to return messages
            returnMessages.add(
                createIntegrationMessage(
                    accountMap.get(accountId), 
                    accountProductIdMap.get(accountId),
                    activateAccount,
                    sendImmediately,
                    accountIdMap.get(accountId)
                )
            );
        }

        return returnMessages;
    }


    /**
     * Create integration message for supplied account / quote
     */

    public static Integration_Message__c createIntegrationMessage(Account a, SBQQ__Quote__c q, Order o, Boolean sendImmediately) {
        // return integration message
        return new Integration_Message__c(
            Account__c = a.Id,
            CPQ_Quote__c = q.Id,
            CPQ_Order__c = o.Id,
            Service_Provider__c = !a.Service_Provider__r.isEmpty() ? a.Service_Provider__r[0].Id : null, 
            Request_Body__c = PHIntegration_Account.serializeJSON(a, q, PH_PRODUCT_CODES),
            Request_Status__c = REQUEST_STATUS_NEW,
            Process__c = PROCESS_PHACCOUNT,
            Send_After__c = (!sendImmediately ? SEND_ON_DELAY : SEND_IMMEDIATELY)
        );
    }

    /**
     * Create integration message for supplied account / quote
     */

    public static Integration_Message__c createIntegrationMessage(Account a, Id productId, Boolean activateAccount, Boolean sendImmediately, Boolean isFeatured) {
        // return integration message
        return new Integration_Message__c(
            Account__c = a.Id,
            Service_Provider__c = !a.Service_Provider__r.isEmpty() ? a.Service_Provider__r[0].Id : null, 
            Request_Body__c = PHIntegration_Account_Activation.serializeJSON(a, productId, activateAccount, isFeatured),
            Request_Status__c = REQUEST_STATUS_NEW,
            Process__c = PROCESS_PHACCOUNT,
            Send_After__c = (!sendImmediately ? SEND_ON_DELAY : SEND_IMMEDIATELY)
        );
    }

    /**
     * Query for quote lines related to supplied quote ids
     */

    public static List<SBQQ__QuoteLine__c> getAccountQuoteLines(Set<Id> quoteIds) {
        // get accounts with integration messages in progress
        Set<Id> excludeAccountIds = getAccountIdsInProgress();

        // return SOQL results
        return [
            SELECT 
                Id, 
                SBQQ__Quote__c, 
                Billing_Account__c, 
                Fulfillment_Account__c 
            FROM SBQQ__QuoteLine__c 
            WHERE SBQQ__Quote__c 
            IN :quoteIds 
            AND SBQQ__ProductOption__c = null 
            AND Fulfillment_Account__c != null
        ];
    }

    /**
     * Query account info needed for PH account messages
     */

    public static Map<Id,Account> getAccountMap(Set<Id> accountIds) {
        // return Map w/ SOQL query results
        return new Map<Id,Account>(
            [
                SELECT 
                    Id, 
                    Account_Category_Formula__c,
                    BillingStreet, 
                    BillingCity, 
                    BillingStateCode, 
                    BillingPostalCode, 
                    BillingCountryCode, 
                    Name, 
                    PH_Admin_Centre_Id__c,
                    Phone,
                    Website,
                    (SELECT 
                        Id, Service_Provider_Id__c, Dealer_Type__c 
                    FROM Service_Provider__r 
                    ORDER BY Dealer_Type__c 
                    DESC NULLS LAST LIMIT 1)
                FROM Account 
                WHERE Id 
                IN :accountIds
            ]
        );
    }

    /**
     * Query quote info needed for PH account messages
     */

    public static Map<Id,SBQQ__Quote__c> getQuoteMap(List<Id> quoteIds) {
        // return MAP w/ SOQL query results
        return new Map<Id,SBQQ__Quote__c>(
            [
                SELECT 
                    Id, 
                    Payment_Method__c, 
                    SBQQ__PrimaryContact__r.FirstName, 
                    SBQQ__PrimaryContact__r.LastName, 
                    SBQQ__PrimaryContact__r.Email,
                    (   
                        SELECT
                            Id, 
                            SBQQ__ProductCode__c,
                            SBQQ__Product__c,
                            Used_Inventory_Cap__c
                        FROM SBQQ__LineItems__r
                        WHERE SBQQ__Quantity__c > 0
                    )
                FROM SBQQ__Quote__c 
                WHERE Id 
                IN :quoteIds
            ]
        );
    }

    /**
     * Check for accounts with related integration messages in progress
     */

    public static Set<Id> getAccountIdsInProgress() {
        // iff acountIdsInProgress holder is null
        if (accountIdsInProgress == null) {
            accountIdsInProgress = new Set<Id>();
            // loop through integration messages returned from SOQL query
            for (Integration_Message__c im : 
                [
                    SELECT 
                        Id, 
                        Account__c 
                    FROM Integration_Message__c
                    WHERE Account__c != null 
                    AND Process__c = :Integrations.PROCESS_PHACCOUNT
                    AND Request_Status__c 
                    IN :Integrations.REQUEST_STATUSES_TO_PROCESS
                ]
            ) {
                // add account to global accountIdsInProgress
                accountIdsInProgress.add(im.Account__c);
            }
        }
        return accountIdsInProgress;
    }
}
