/**
 * @description       : 
 * @author            : LZhao
 * @group             : 
 * @last modified on  : 02/10/2022
 * @last modified by  : alaplante
**/
public without sharing class CPQQuoteTriggerFunctions {


    // globals
    private static final String APPROVALSTATUS_APPROVED = ConstantsUtil.QUOTE_APPROVALSTATUS_APPROVED;
    private static final Date EXPIRATION_DATE_CONST = ConstantsUtil.STANDARD_QUOTE_EXPIRATION;
    private static final String CLONED_QUOTE_VALIDATION = 'Source Quote is already closed and ordered, and cannot be cloned.';

    // test visible globals
    @TestVisible
    private static final String DOCUSIGN_COMPLETE = ConstantsUtil.DOCUSIGN_COMPLETE;

    /**
    * Checks for delinquent accounts in entire hierarchy to ensure proper approvals occur. If found, checks off
    * 'DelinquencyInBillingHierarchy__c' on quote
    *
    * @jira: BR-5593
    * @author: Adam LaPlante
    */
    
    public static Set<Id> checkForHierarchyDelinquency(List<SBQQ__Quote__c> quoteList) {
        
        Map<Id,Id> accountToQuoteMap = new Map<Id, Id>();
        Set<Id> quotesWithDelinquency = new Set<Id>();

        // loop through quotes, for each put quote id and ult parent id in map
        for (SBQQ__Quote__c quote : quoteList) {

            System.debug('quote.SBQQ__Account__r.Is_Ultimate_Parent__c::' + quote.SBQQ__Account__r.Is_Ultimate_Parent__c);
            System.debug('quote.SBQQ__Account__r.Ultimate_Parent_Account__c::' + quote.SBQQ__Account__r.Id);
            System.debug('quote.Account_Ultimate_Parent__c::' + quote.Account_Ultimate_Parent__c);
            System.debug('quote.Account_Ultimate_Parent_Formula__c::' + quote.Account_Ultimate_Parent_Formula__c);

            Id accountId = 
                quote.Account_Ultimate_Parent_Formula__c == null
                ? quote.SBQQ__Account__c
                : quote.Account_Ultimate_Parent_Formula__c;

                system.debug('accountId::' + accountId);

            accountToQuoteMap.put(accountId, quote.Id);
        }

        for (Account acc: 
                [
                    SELECT Id, Is_Ultimate_Parent__c, Ultimate_Parent_Account__c FROM Account
                    WHERE (
                        Ultimate_Parent_Account__c IN :accountToQuoteMap.keySet() OR
                        Id IN :accountToQuoteMap.keySet()
                    ) AND (
                        HasDelinquentSubscription__c = true OR ZuoraWriteOffBalance__c > 0
                    ) LIMIT 1
                ]
        ) {
            // get ult parent id
            Id ultimateId = acc.Is_Ultimate_Parent__c == true ? acc.Id : acc.Ultimate_Parent_Account__c;
            // add quote to list to update
            quotesWithDelinquency.add(accountToQuoteMap.get(ultimateId));
        }
        return quotesWithDelinquency;

    }

    // BR-1144 - check if quote is newly approved, and if so process zuora account creation
    public static void processZAccountCreation(List<SBQQ__Quote__c> quoteList, Map<Id,SBQQ__Quote__c> oldQuoteMap) {
        Set<Id> quoteIdsToProcess = new Set<Id>();
        
        for (SBQQ__Quote__c q : quoteList) {
            Id quoteId = q.Id;

            if (q.ApprovalStatus__c == APPROVALSTATUS_APPROVED 
                    && oldQuoteMap.get(quoteId).ApprovalStatus__c != APPROVALSTATUS_APPROVED) {
                quoteIdsToProcess.add(quoteId);
            }
        }
        
        if (!quoteIdsToProcess.isEmpty()) {
            ZuoraIntegration_AccountHelper.createAndSendZAccountMessages(quoteIdsToProcess);
        }
    }    



    //Added for BR-780 by Justin Chang on 4/5/21
    //Purpose: set default fields on Quote insert
    public static void initializeForInsert(SBQQ__Quote__c[] newList) {

        Map<Id,SBQQ__Quote__c> cloneSourceQuoteToNewQuote = new Map<Id,SBQQ__Quote__c>();

        //default to 10th of next month on insert, except for Cancellation quotes
        for (SBQQ__Quote__c q : newList) {

            //SA-223, check if quote is cloned, and reset Approved Quote record type
            if((q.isClone() || q.SBQQ__Source__c != null)
            && q.RecordTypeId == SObjectDescribeUtils.getRecordTypeIdByName('Quote','Approved Quote')){
                q.SBQQ__StartDate__c = System.today();
                q.Last_Docusign_Sent_Date__c = null;
                q.RecordTypeId = SObjectDescribeUtils.getRecordTypeIdByName('Quote','Standard Quote');
                
                Id parentQuoteId = q.isClone() ? q.getCloneSourceId() : q.SBQQ__Source__c;
                //to validate if Parent Quote is not already Ordered
                cloneSourceQuoteToNewQuote.put(parentQuoteId,q);
            }

            if (q.SBQQ__Type__c != 'Cancellation') {
              q.SBQQ__ExpirationDate__c = EXPIRATION_DATE_CONST;
              //add any other fields that need to be set here
            }
            
            //DSS-453 Expiration Date will be the 10th day of the next month from the Quote StartDate (renewal period)
            if (q.SBQQ__Type__c == 'Renewal') {
                q.SBQQ__ExpirationDate__c = q.SBQQ__StartDate__c.toStartOfMonth().addMonths(1).addDays(9);
            }
        }

        //query Parent/Clone Source Quote and validate if Cloned Quote was not already Ordered
        if(!cloneSourceQuoteToNewQuote.isEmpty()){
            for(SBQQ__Quote__c pQuote : [
                SELECT Id 
                FROM SBQQ__Quote__c 
                WHERE SBQQ__Ordered__c=true 
                AND Id IN:cloneSourceQuoteToNewQuote.keyset()
            ]){
                if(cloneSourceQuoteToNewQuote.containskey(pQuote.Id)){
                    cloneSourceQuoteToNewQuote.get(pQuote.Id).addError(CLONED_QUOTE_VALIDATION);
                }
            }
        }
    }

    /**
     * Sets quote status to expired
     */

    public static void setQuoteExpired(SBQQ__Quote__c[] quoteList) {
        for (SBQQ__Quote__c q : quoteList) {
            q.SBQQ__Status__c = 'Expired';
        }

        update quoteList;
    }

    // SA-615
    // This will only check set approvals on quotes with positive quote line items
    public static void checkQuoteForApprovals(List<SBQQ__Quote__c> quoteList) {

        Set<Id> quotesWithGraceDates = new Set<Id>();
        Set<Id> accountsWithGraceDate = new Set<Id>();
        Set<Id> quotesWithDelinquencies = checkForHierarchyDelinquency(quoteList);
        
        // Get all quote lines from all quotes
        List<SBQQ__QuoteLine__c> quoteLines = [SELECT Id, Fulfillment_Account__c, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Status__c, SBQQ__Quantity__c
                                               FROM SBQQ__QuoteLine__c 
                                               WHERE SBQQ__Quote__c IN :quoteList AND SBQQ__Quantity__c > 0 AND SBQQ__Quote__r.SBQQ__Status__c != 'Expired'];

        if(quoteLines.isEmpty()) {
            return;
        }

        // Get all fullfillment accs associated with all quotes
        Set<Id> ffAccIds = CPQQuoteLineTriggerFunctions.getFulfillmentAccountsFromQuoteLines(quoteLines);
        
        // Get accounts with future grace dates and keep track of them
        for(Account a : [SELECT Id FROM Account WHERE Id IN :ffAccIds AND Grace_Date_Formula__c > TODAY]) {
            accountsWithGraceDate.add(a.Id);
        }

        // Go through the quote lines to cross reference fulfillment account and create sets to keep track of approvals
        for(SBQQ__QuoteLine__c ql : quoteLines) {
            // Check quote line to see if it has a grace date
            if(accountsWithGraceDate.contains(ql.Fulfillment_Account__c)) {
                quotesWithGraceDates.add(ql.SBQQ__Quote__c);
            }
        }

        // Loop through quotes and check for approvals to tag the quotes
        for(SBQQ__Quote__c quote : quoteList) {
            // Tag quote field
            quote.Has_Account_With_Grace_Date__c = quotesWithGraceDates.contains(quote.Id);
            if(quotesWithDelinquencies.contains(quote.Id)) {
                quote.Delinquent_Account_In_Billing_Hierarchy__c = true;
            }
        }
    }

    
    //Use this query on beforeUpdate context to get list of amendment quote lines
    public static List<SBQQ__Quoteline__c> quoteLinesInQuote;    
    public static List<SBQQ__Quoteline__c> getQuoteLinesInQuote(Set<Id> quoteIds) {
        if (quoteLinesInQuote == null) {
            quoteLinesInQuote = [
                SELECT Id,SBQQ__Quote__c, Intro_Discount_Percentage__c,
                 Intro_Discount_Period__c, Retain_Current_Net_Total__c, Fulfillment_Account__c
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c IN :quoteIds
                ORDER BY SBQQ__Quote__c, Intro_Discount_Period__c DESC
            ];
        }
        return quoteLinesInQuote;
    }


    // BR-1265 Lawrence Zhao
    // BR-2811
    // Calculates the Committed Term End Date based on the Docusign Sent Date
    // and checks for amendments to determine if there is an extension in committment term
    public static void calculateCommittedTermEndDate(Map<Id,SBQQ__Quote__c> newQuoteMap) {

        Set<Id> contractList = new Set<Id>();
        Set<Id> quoteIds = new Set<Id> ();

        for (SBQQ__Quote__c q : newQuoteMap.values()) {

             // DSS-759 Exclude Cancellation Quotes to be processed
            if (q.Cancellation_Quote__c) {
                continue;
            }

            // Add Related Master Contracts to list (amendments)
            if(q.SBQQ__MasterContract__c != null) {
                contractList.add(q.SBQQ__MasterContract__c);
            }
            // Check if quote has any lines to query related information later
            if (q.SBQQ__LineItemCount__c !=0) {
                quoteIds.add(q.Id);
            }
        }

        List<SBQQ__QuoteLine__c> allQuoteLines = new List<SBQQ__QuoteLine__c> ();
        //BR-9023 Query quote lines to get ROMF Intro discount period
        if (!quoteIds.isEmpty()) {
            allQuoteLines = getQuoteLinesInQuote(quoteIds);
        }

        List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c> ();
        for (SBQQ__Quoteline__c quoteLine : allQuoteLines) {
            if ((quoteLine.Intro_Discount_Period__c != null && quoteLine.Intro_Discount_Percentage__c == 100) ||
              quoteline.Intro_Discount_Period__c != null && quoteLine.Retain_Current_Net_Total__c == true) {

                quoteLines.add(quoteLine);
              }
        }

        // Prepare map with Quote as Key and Quote Lines with higher Intro_Discount_Period__c as a value
        Map<Id,SBQQ__QuoteLine__c> quoteMap = new Map<Id,SBQQ__QuoteLine__c> ();
        for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
            if (!quoteMap.containsKey(quoteLine.SBQQ__Quote__c)) {
                quoteMap.put(quoteLine.SBQQ__Quote__c, quoteLine);
            }
        }

        Map<Id, Contract> contractMap = new Map<Id, Contract> ();
        // Query for Initial_Term_End_Date__c on the Master Contract if processing amendment quotes
        if (!contractList.isEmpty()) {
            contractMap = new Map<Id, Contract>([SELECT Id, Initial_Term_End_Date__c FROM Contract WHERE ID IN :contractList]);
        }        

        for (SBQQ__Quote__c q : newQuoteMap.values()) {

            Date docusignDate = q.Last_Docusign_Sent_Date__c == null ? System.today() : q.Last_Docusign_Sent_Date__c.date();
            Date startDate = q.SBQQ__StartDate__c == null ? System.today() : q.SBQQ__StartDate__c;
            Date endOfCurrentMonth = System.today().addMonths(1).toStartofMonth().addDays(-1);
            Boolean isStartDateTheFirstInFuture = (startDate > endOfCurrentMonth) && startDate.day() == 1 ? TRUE : FALSE;
            Boolean startDateCheck = startDate < docusignDate;
            Date committedTermEndDate = startDateCheck ?  docusignDate : startDate;
            Integer commitmentTermMonths = q.Contract_Commitment_Term_Months__c == null ? 1 : Integer.valueOf(q.Contract_Commitment_Term_Months__c);
            if(isStartDateTheFirstInFuture) {
                commitmentTermMonths = commitmentTermMonths - 1;
            }

            // SA-442 - stop calc of the commitment term end date past the date the docusign was sent to the dealer
            if (docusignDate == System.today()) {

                // BR-9023 If quoteMap contains Quote Id, ROMF was aplied to that quote. Need to sum Intro Discount to Commitment Term Month
                if (quoteMap.containsKey(q.Id)) {
                    // If start date is first day in the future we do not substract the current month (already did it l.181)
                    commitmentTermMonths = !isStartDateTheFirstInFuture ? commitmentTermMonths + (Integer)quoteMap.get(q.Id).Intro_Discount_Period__c - 1 
                        : commitmentTermMonths + (Integer)quoteMap.get(q.Id).Intro_Discount_Period__c;
                }

                committedTermEndDate = committedTermEndDate.addMonths(commitmentTermMonths).addMonths(1).toStartofMonth().addDays(-1);

                // Check to see if current commitment term end date needs to be overridden due to amendment
                if(contractMap.containsKey(q.SBQQ__MasterContract__c)) {
                    Date contractCommittedTermEndDate = contractMap.get(q.SBQQ__MasterContract__c).Initial_Term_End_Date__c;
                    Boolean existingContractNoDiscounts = (contractCommittedTermEndDate < committedTermEndDate) && 
                                                        q.Increase_Commitment_Term_Months__c == 0 && 
                                                        commitmentTermMonths == 1;
                    Boolean existingCommitTermInPast = contractCommittedTermEndDate > committedTermEndDate;

                    if(existingContractNoDiscounts || existingCommitTermInPast) {
                        committedTermEndDate = contractCommittedTermEndDate;
                    }
                }
                q.Initial_Term_End_Date__c = q.Cancellation_Quote__c ? null : committedTermEndDate;
            }
        }
    }

    /**
     * Checks quote state, if complete sends to OM approval process, also trigger recalc for language changes
     */

    public static void checkQuoteState(List<SBQQ__Quote__c> newQuotes, Map<ID,SBQQ__Quote__c> oldQuoteMap) {
        Set<Id> quoteLanguageChanged = new Set<Id>();
        Map<ID,SBQQ__Quote__C> quotesChangedToDocusignComplete = new Map<ID,SBQQ__Quote__C>();

        for(SBQQ__Quote__c q : newQuotes) {
            SBQQ__Quote__c oldQuote = oldQuoteMap.get(q.Id);
            if (q.SBQQ__Status__c == DOCUSIGN_COMPLETE && oldQuote.SBQQ__Status__c != DOCUSIGN_COMPLETE){
                quotesChangedToDocusignComplete.put(q.Id, q);
            }
            if(Trigger.isAfter && q.SBQQ__QuoteLanguage__c != oldQuote.SBQQ__QuoteLanguage__c) { 
                quoteLanguageChanged.add(q.Id); 
            }
        }

        // Check if the Status changed to "Docusign Complete," and if so, send quote to OM approval process
        if (!quotesChangedToDocusignComplete.isEmpty()){
            switch on Trigger.operationType {
                when BEFORE_UPDATE{
                    QuoteApprovalPageHelper.updateOrderManagementEntryCriteria(quotesChangedToDocusignComplete);
                    QuoteApprovalPageHelper.updateOrderManagementApprovalReason(quotesChangedToDocusignComplete);
                }
                when AFTER_UPDATE{
                    Set<ID> quotesReadyForOM = new Set<ID>();
                    Set<ID> quotesNotReadyForOM = new Set<ID> ();
                    
                    for (ID quoteId : quotesChangedToDocusignComplete.keySet()){
                        SBQQ__Quote__c quote = quotesChangedToDocusignComplete.get(quoteId);
                        
                        if (quote.Order_Management_Entry_Criteria__c == 'NONE'){
                            quotesReadyForOM.add(quoteId);
                        }else{
                            
                            quotesNotReadyForOM.add(quoteId);
                        }
                    }
                    
                    if (!quotesReadyForOM.isEmpty()){
                        QuoteApprovalPage_Submit.submitForOMApproval(new List<ID>(quotesReadyForOM));
                    }
                    
                    if (!quotesNotReadyForOM.isEmpty()){
                        EmailTemplate notReadyOMTemplate = [SELECT Id, HtmlValue, Body, Subject
                                                            FROM EmailTemplate
                                                            WHERE name = 'OM Entry Criteria Not Met'
                                                            LIMIT 1][0];
                        
                        List<Messaging.SingleEmailMessage> notReadyOMEmails = new List<Messaging.SingleEmailMessage>();
                        
                        for (SBQQ__Quote__c quote : [SELECT Id, Name, SBQQ__Account__r.Name, OwnerId, Order_Management_Entry_Criteria__c,
                                                     SBQQ__Opportunity2__r.Name, Owner.FirstName
                                                     FROM SBQQ__Quote__c
                                                     WHERE Id IN :quotesNotReadyForOM])
                        {             
                            notReadyOMEmails.add(constructOMBlockedEmail(quote, notReadyOMTemplate));
                            sendOMBlockedNotification(quote);
                        }
                        
                        Messaging.sendEmail(notReadyOMEmails); 
                    } 
                } 
            }
        }

        // If quote language changed, query all quote lines with discounts and trigger recalculation on them
        if (!quoteLanguageChanged.isEmpty()){
            List<SBQQ__Quoteline__c> quoteLines = [SELECT ID FROM SBQQ__Quoteline__c WHERE SBQQ__Quote__c = :quoteLanguageChanged AND CongaClause__c != null];
            update quoteLines;
        }
    }


    /**
     * Constructor for OM blocked email notificaiton HTML.
     */

    public static Messaging.SingleEmailMessage constructOMBlockedEmail(SBQQ__Quote__C quote, EmailTemplate notReadyOMTemplate ){
        String entryCriteria = '(';
        for (String reason : quote.Order_Management_Entry_Criteria__c.split(';')){
            entryCriteria += reason + ', ';
        }
        entryCriteria = entryCriteria.removeEnd(', ');
        entryCriteria += ')';
        
        String quoteLink = URL.getSalesforceBaseUrl().toExternalForm() + '/' + quote.Id;

        String ownerNameOrGreeting = quote.Owner.FirstName == null
        ? 'Hello'
        : quote.Owner.FirstName;
        
        String htmlBody = notReadyOMTemplate.HtmlValue;
        htmlBody = htmlBody.replace('{{{SBQQ__Quote__c.Order_Management_Entry_Criteria__c}}}', entryCriteria);  
        htmlBody = htmlBody.replace('{{{SBQQ__Quote__c.SBQQ__Account__r.Name}}}', quote.SBQQ__Account__r.Name);
        htmlbody = htmlBody.replace('{{{SBQQ__Quote__c.Org_URL__c}}}', quoteLink);
        htmlBody = htmlBody.replace('{{{SBQQ__Quote__c.Name}}}', quote.Name);
        htmlBody = htmlBody.replace('{{{SBQQ__Quote__c.SBQQ__Opportunity2__r.Name}}}', quote.SBQQ__Opportunity2__r.Name);
        htmlBody = htmlBody.replace('{{{SBQQ__Quote__c.Owner.Name}}}', ownerNameOrGreeting);
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setHtmlBody(htmlBody);
        mail.setTargetObjectId(quote.ownerId);
        mail.saveAsActivity = false;
        mail.setSubject('A quote could not be submitted for OM Review - ' + quote.Name);
        mail.setOrgWideEmailAddressId('0D24S0000004CQjSAM');
        
        return mail;
    }

    /**
     * Sends OM blocked email notification
     */

    public static void sendOMBlockedNotification(SBQQ__Quote__c quote){
        ID approvalNotificationId = 
            [SELECT Id, DeveloperName 
             FROM CustomNotificationType 
             WHERE DeveloperName='Approval_Notifications'
             LIMIT 1].Id;
        
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        
        notification.setTitle('Quote Blocked From OM');
        notification.setBody('A quote could not be submitted for OM Review - ' + quote.Name);
        
        notification.setNotificationTypeId(approvalNotificationId);
        notification.setTargetId(quote.ID);
        
        notification.send(new Set<String>{quote.OwnerId});
    } 

    //SA-295
    public static void defaultValuesForOEMQuotes(List<SBQQ__Quote__c> quotes) {

        Set<Id> masterContractIds = new Set<Id>();

        for(SBQQ__Quote__c quote : quotes){

            if(quote.Co_Op_Program_Opt_in__c!=null){
                quote.Prevent_Automated_Initial_Invoice__c = true;

                //Billing type from Quote trickles down to its Quote Lines via Price Rule
                quote.Billing_Type__c = ConstantsUtil.OEM_QL_BILLING_TYPE;
            }

            //SA-653, check if master contract is a Turnkey/OEM contract
            if(quote.SBQQ__MasterContract__c!=null){
                masterContractIds.add(quote.SBQQ__MasterContract__c);
            }
        }

        //SA-653, check if needed to set Co-Op Program value for amendment quote
        if(!masterContractIds.isEmpty()){

            Map<Id,Contract> contractMap = new Map<Id,Contract>();
            contractMap.putAll([
                SELECT Id,Co_Op_Program_Opt_in__c 
                FROM Contract 
                WHERE Id IN:masterContractIds 
                AND Co_Op_Program_Opt_in__c!=null
            ]);

            if(!contractMap.isEmpty()){
                for(SBQQ__Quote__c quote : quotes){
    
                    //SA-653, get Co-Op Program value for amendment quote
                    if(quote.SBQQ__MasterContract__c!=null
                    && contractMap.containsKey(quote.SBQQ__MasterContract__c)){
                        quote.Co_Op_Program_Opt_in__c = contractMap.get(quote.SBQQ__MasterContract__c).Co_Op_Program_Opt_in__c;
                    }
                }
            }
        }
    }
    
    //SA-591 Only for Amendments, set default Language getting value from the amended contract
    public static void setDefaultLanguage(List<SBQQ__Quote__c> newList) {

        Set<Id> contractIds = new Set<Id> ();
        for (SBQQ__Quote__c q : newList) {
            if (q.SBQQ__Type__c == 'Amendment' && q.SBQQ__MasterContract__c != null) {
                contractIds.add(q.SBQQ__MasterContract__c);
            }
        }
        
        // If it's not amendmet, just return
        if (contractIds.isEmpty()) {
            return;
        }

        // Query contract to get Contract Language
        Map<Id,Contract> contractMap = new Map<Id,Contract>([
            SELECT Id, ContractLanguage__c 
            FROM Contract
            WHERE Id IN : contractIds]);

        //Stamp default Quote Language
        for (SBQQ__Quote__c q : newList) {
            q.SBQQ__QuoteLanguage__c = contractMap.containsKey(q.SBQQ__MasterContract__c) ?
                contractMap.get(q.SBQQ__MasterContract__c).ContractLanguage__c : null;
        }
    }

    //SA-591 Update quote line translations if Quote Language has changed
    public static void updateQuoteLineTranslations(List<SBQQ__Quote__c> newList, Map<Id,SBQQ__Quote__c> oldQuoteMap) {

        Set<Id> quoteIds = new Set<Id> ();
        Map<Id, String> quoteIdLanguageMap = new Map<Id,String> ();

        // Check if Quote Language has been changed
        for (SBQQ__Quote__c quote : newList) {
            if (quote.SBQQ__Type__c != 'Amendment' &&
                quote.SBQQ__QuoteLanguage__c != oldQuoteMap.get(quote.Id).SBQQ__QuoteLanguage__c &&
                quote.SBQQ__QuoteLanguage__c != null) {

                    quoteIds.add(quote.Id);
                    quoteIdLanguageMap.put(quote.Id, quote.SBQQ__QuoteLanguage__c);
                }
        }

        // If no changes, return
        if (quoteIds.isEmpty()) {
            return;
        }

        //Get Map for Translated Product Name and Translated Prodocut Descriptions
        Map<String,String> productNameLangMap = Utilities.getTranslatedProductName();
        Map<String,String> productDescriptionLangMap = Utilities.getTranslatedProductDescription();
        
        // Get related quote lines to stamp translations
        List<SBQQ__Quoteline__c> quoteLines = [
            SELECT Id, SBQQ__ProductCode__c, SBQQ__Existing__c,SBQQ__Quote__c
            FROM SBQQ__Quoteline__c
            WHERE SBQQ__Quote__c IN :quoteIds
        ];

        for (SBQQ__Quoteline__c quoteLine : quoteLines) {
            if (!quoteLine.SBQQ__Existing__c) {
                String lineKey = quoteIdLanguageMap.get(quoteLine.SBQQ__Quote__c) + '-' + quoteLine.SBQQ__ProductCode__c;
                quoteLine.Translated_Product_Name__c = productNameLangMap.get(lineKey);
                quoteLine.Translated_Product_Description__c = productDescriptionLangMap.get(lineKey);
            }
        }

        if (!quoteLines.isEmpty()) {
            // Disable CPQ triggers, we don't need to kick off lines recalculation
            SBQQ.TriggerControl.disable();
            update quoteLines;
            SBQQ.TriggerControl.enable();
        }
    }

    public static void preventQuoteFromDeletion(List<SBQQ__Quote__c> quotes){
        Id profileId = UserInfo.getProfileId();
        String profileName = [SELECT Id, Name FROM Profile WHERE Id =:profileId].Name;
        Boolean isSysAdmin = false;

        if(profileName  == 'System Administrator' || profileName == 'Sales Ops'){
            isSysAdmin = true;
        }

        for(SBQQ__Quote__c quote : quotes ){
            if(!isSysAdmin){
                quote.adderror('Only System Administrator or Sales Ops can delete this Quote');
            }
        }  
    }

    //DSS-392 Prevent updates on Amendment Quote Start Date if there are pending activations Subs in the future
    public static void checkStartDateOnAmendments(List<SBQQ__Quote__c> newList, Map<Id,SBQQ__Quote__c> oldQuoteMap) {

        Map<Id,SBQQ__Quote__c> quoteToProcess = new Map<Id,SBQQ__Quote__c> ();
        for (SBQQ__Quote__c quote : newList) {
            if (quote.SBQQ__Type__c == 'Amendment' &&
                quote.SBQQ__StartDate__c != oldQuoteMap.get(quote.Id).SBQQ__StartDate__c) {
                  quoteToProcess.put(quote.Id,quote);
            }
        }
        
        if (quoteToProcess.isempty()) {
            return;
        }        
        
        //Loop through all quote lines related to amendment quote and push into the list if Quote is on quoteToProcess map.
        List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__Quoteline__c> ();        
        for (SBQQ__Quoteline__c quoteLine : quoteLinesInQuote) {
            if (quoteToProcess.containsKey(quoteLine.SBQQ__Quote__c)) {
                quoteLines.add(quoteLine);
            }
        }

        Map<Id,Set<Id>> quoteQuoteLinesMap = new Map<Id,Set<Id>> ();
        Set<Id> fulfillmentAccIds = new Set<Id> ();        
        for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
            
            fulfillmentAccIds.add(quoteLine.Fulfillment_Account__c);

            if (!quoteQuoteLinesMap.containsKey(quoteLine.SBQQ__Quote__c)) {
                quoteQuoteLinesMap.put(quoteLine.SBQQ__Quote__c, new Set<Id>());
            }
            quoteQuoteLinesMap.get(quoteLine.SBQQ__Quote__c).add(quoteLine.Fulfillment_Account__c);
        }

        if (fulfillmentAccIds.isEmpty()) {
            return;
        }

        // Query for Subs related to fulfillment accounts to check if there are some in Pending Activation status
        Map<Id,Account> accWithRelatedSubs = new Map<Id,Account>([
            SELECT Id, (
                SELECT Id, Provisioning_Status__c, SBQQ__StartDate__c, SBQQ__Quantity__c, Fulfillment_Account__r.Name
                FROM CPQ_Subscriptions_Fulfillment__r                
                WHERE Provisioning_Status__c = 'Pending Activation'
                AND SBQQ__Product__r.ProductCode = 'CG-BASE'
                AND SBQQ__StartDate__c > TODAY
                ORDER BY SBQQ__StartDate__c DESC)
            FROM Account
            WHERE Id IN :fulfillmentAccIds
        ]);
        
        for (SBQQ__Quote__c quote : quoteToProcess.values()) {

            for (Id fulAcc : quoteQuoteLinesMap.get(quote.Id)) {

                if (accWithRelatedSubs.containsKey(fulAcc)) {

                    List<SBQQ__Subscription__c> subs = accWithRelatedSubs.get(fulAcc).CPQ_Subscriptions_Fulfillment__r;
                    if (subs == null || subs.isEmpty()) {
                        continue;
                    }
                    String cannotAmendErrorMsg = subs[0].Fulfillment_Account__r.Name +
                        ' has future Pending Activation Subscriptions starting on ' + subs[0].SBQQ__StartDate__c.format() +
                        ', it cannot be amended';
                    
                    if (subs[0].SBQQ__Quantity__c > 0 ||
                       (subs[0].SBQQ__Quantity__c < 0 && subs[0].SBQQ__StartDate__c > quote.SBQQ__StartDate__c)) {                        
                        
                        // If there Pending Activation subs or Pending cancel subs with starting after quote start date, throw an error
                        quote.addError(cannotAmendErrorMsg);
                    }
                }
            }
        }
    }
    public static void updateRenewalOpportunity(Map<ID,SBQQ__Quote__c> quotes){
        Map<Id,Id> quoteOppMap = new Map<Id,Id>();
        for (Id quoteId : quotes.keyset()) {
            SBQQ__Quote__c q = quotes.get(quoteId);
            if (q.SBQQ__Type__c == 'Renewal') {
                quoteOppMap.put(quoteId,q.SBQQ__Opportunity2__c); //collect quote ids and put them in a map of Quote Ids to Opp Ids
            }
        }
        if(quoteOppMap.isEmpty()){
            return;
        }  
        Map<Id,Opportunity> oppMap = new Map<Id,Opportunity>(
        [SELECT Id, Name, Auto_Close_Date__c, AccountName__c FROM Opportunity WHERE ID IN: quoteOppMap.values()]);

        List<Opportunity> oppList = new List<Opportunity>();
        for (Id quoteId : quoteOppMap.keySet()) {
            SBQQ__Quote__c q = quotes.get(quoteId);
            Opportunity o = oppMap.get(quoteOppMap.get(quoteId));
            
            Date renewalDate = q.SBQQ__StartDate__c; 
            Integer y = renewalDate.year();
            Integer m = renewalDate.month();
            Integer day = renewalDate.day(); 
            DateTime dt = DateTime.newInstance(y,m,day); 
            String renewalPlusOneMonth = dt.format('MMMM'); 
            Integer renewalYear = dt.year(); 
            String sRenewalYear = String.valueOf(renewalYear);

            o.Auto_Close_Date__c = renewalDate.addDays(57);
            //autoclose date = renewal period + 58 days. start date is renewal period +1 day
            String OppName = o.AccountName__c + ' - Annual Business Review - ' + renewalPlusOneMonth + ' 1 '+sRenewalYear;
            o.Name = oppName;
            oppList.add(o);
        }
        update oppList;
    }
}