public without sharing class ContractTriggerFunctions {

    private static final Set<String> ACTIVE_CPQ_PROVISIONING_STATUSES = new Set<String>{'Activated','Pending Activation','Delinquent'};
    private static final String CUSTOMER_TYPE = 'Customer';

    public static void initialSetup(Contract[] cList) {
        Map<Id, SBQQ__Quote__c> quoteMap = new Map<Id, SBQQ__Quote__c>(); 

        for (Contract c : cList) {
            if(c.SBQQ__Quote__c != null) {
                quoteMap.put(c.SBQQ__Quote__c,null);
            }
        }

        quoteMap.putAll([SELECT Id, Initial_Term_End_Date__c, SBQQ__PrimaryContact__c, Co_Op_Program_Opt_in__c, SBQQ__QuoteLanguage__c FROM SBQQ__Quote__c WHERE ID in : quoteMap.keySet()]);

        for (Contract c : cList) {
            if(quoteMap.containsKey(c.SBQQ__Quote__c)) {
                Date d = quoteMap.get(c.SBQQ__Quote__c).Initial_Term_End_Date__c;
                c.Initial_Term_End_Date__c = d;
                c.EndDate = d;

                //BR-1338 Stamp Primary Contact from the quote on the Contract
                c.QuotePrimaryContact__c = quoteMap.get(c.SBQQ__Quote__c).SBQQ__PrimaryContact__c;

                //SA-653 set co-op program on Contract if it is present on the related Quote
                c.Co_Op_Program_Opt_in__c = quoteMap.get(c.SBQQ__Quote__c).Co_Op_Program_Opt_in__c!=null ? quoteMap.get(c.SBQQ__Quote__c).Co_Op_Program_Opt_in__c : null;
                //SA-591 Stamp Contract Language based on Quote Language
                c.ContractLanguage__c = quoteMap.get(c.SBQQ__Quote__c).SBQQ__QuoteLanguage__c;
            }

            c.Status = 'Pending Activation';
            c.SBQQ__PreserveBundleStructureUponRenewals__c = true; //BR-4556
        }

    }

    public static void updateAccountType(Contract[] contractList, Map<Id,Contract> oldMap) {

        Map<Id,Integer> acctIds = new Map<Id,Integer>();

        for (Contract con : contractList) {

            if (!acctIds.containsKey(con.AccountId)) {
                acctIds.put(con.AccountId,0); //count initialized to 0
            }

            if (oldMap != null) {

                Contract oldCon = oldMap.get(con.Id);
                //Example:
                //new.status = 'Cancelled';
                //old.Status = 'Activated';
                if (ACTIVE_CPQ_PROVISIONING_STATUSES.contains(con.Status)  
                        && !ACTIVE_CPQ_PROVISIONING_STATUSES.contains(oldCon.Status)) {
                    Integer count = acctIds.get(con.AccountId);
                    acctIds.put(con.AccountId,count+1);
                }

            } else {    //all new CPQ Subs should pending activation, so should auto 
                Integer count = acctIds.get(con.AccountId);
                acctIds.put(con.AccountId,count+1);
            }
        }
        CPQ_Subscription_TriggerFunctions.checkAccountCPQSubs(acctIds);
    }

    //BR-4265 Attach pdf file (from quote to contract)
    public static void getContractPDF(List<Contract> contractList) {

        // Loop new contracts and populate quote map
        Map<Id,Id> quoteContractMap = new Map<Id,Id> ();
        for (Contract contract : contractList) {
            quoteContractMap.put(contract.SBQQ__Quote__c, contract.Id);
        }

        // Query existing attachment files for relted quotes
        List<Attachment> attachmentList = [SELECT Id,
            Body,
            Name,
            Description,
            ParentId,
            BodyLength
            FROM Attachment
            WHERE ParentId IN :quoteContractMap.keySet()
            AND Name LIKE '%.pdf'
            ORDER BY CreatedDate DESC];

        Map<Id,Attachment> fileAttachmentMap = new Map<Id,Attachment> ();
        // Loop through attachmnet list and populate map. If more than one per quote, get the latest
        for (Attachment attach : attachmentList) {            
            if (!fileAttachmentMap.containsKey(attach.ParentId)) {
                fileAttachmentMap.put(attach.ParentId, attach);
            }
        }
        
        // Clone existing file attachments and create for contract record
        List<Attachment> fileAttachmentToIns = new List<Attachment> ();
        for (Id quoteId : fileAttachmentMap.keySet()) {

            Attachment newFile = fileAttachmentMap.get(quoteId).clone();
            newFile.ParentId = quoteContractMap.get(quoteId);
            
            fileAttachmentToIns.add(newFile);
        }

        // Insert net new quote pdf files attachments on related contract
        if (!fileAttachmentMap.isEmpty()) {
            insert fileAttachmentToIns;
        }
    }

    // BR-4265 Attach pdf file (from amendment quote to contract)
    public static void getAmendContractPDF(List<Contract> contractList, Map<Id,Contract> oldMap) {

        // Loop new contracts and populate quote map
        Set<Id> contractIds = new Set<Id> ();
        for (Contract contract : contractList) {
            if (contract.SBQQ__Order__c != null && oldMap.get(contract.Id).SBQQ__Order__c != contract.SBQQ__Order__c) {
                contractIds.add(contract.Id); // only get contracts if was a change on the related order (amendment)
            }
        }

        if (contractIds.isEmpty()) {
            return;
        }

        // Insert new PDF attachments based on set of Contract Ids
        insertNewPDFonContracts(contractIds);
        
    }

    @TestVisible
    private static void insertNewPDFonContracts(Set<Id> contractIds) {

        // Query for amendment quotes related to the amendment contracts
        List<SBQQ__Quote__c> quotes = [SELECT Id, SBQQ__MasterContract__c 
            FROM SBQQ__Quote__c
            WHERE SBQQ__Type__c = 'Amendment'
            AND SBQQ__MasterContract__c IN :contractIds
            AND SBQQ__Ordered__c = TRUE];
        
        if (quotes.isEmpty()) {
            return;
        }

        // Populate Map with Amendment Quote as key and related Contract as value
        Map<Id,Id> quoteContractIdMap = new Map<Id,Id> ();
        for (SBQQ__Quote__c quote : quotes) {
            if (!quoteContractIdMap.containsKey(quote.Id)) {
                quoteContractIdMap.put(quote.Id, quote.SBQQ__MasterContract__c);
            }
        }

        // Query existing attachment files for relted quotes and contracts (already added)
        List<Attachment> attachmentList = [SELECT Id,
            Body,
            Name,
            Description,
            ParentId,
            Parent.Type,
            BodyLength
            FROM Attachment
            WHERE (ParentId IN :quoteContractIdMap.keySet()
                OR ParentId IN :contractIds)
            AND Name LIKE '%.pdf'
            ORDER BY CreatedDate DESC];

        // Map to store existing pdf attachments on Contract obj
        Map<String,Attachment> existingAttachmentMap = new Map<String,Attachment> ();
        // Map to store new pdf attachments that needs to go Contract (amendment quotes)
        Map<String,Attachment> newQuoteAttachmentMap = new Map<String,Attachment> ();

        for (Attachment attachment : attachmentList) {
            if (attachment.Parent.Type == 'Contract') {
                if (!existingAttachmentMap.containsKey(attachment.Name)) {
                    existingAttachmentMap.put(attachment.Name + '-' + attachment.BodyLength, attachment);
                }
            }
            if (attachment.Parent.Type == 'SBQQ__Quote__c') {
                if (!newQuoteAttachmentMap.containsKey(attachment.Name)) {
                    newQuoteAttachmentMap.put(attachment.Name + '-' + attachment.BodyLength, attachment);
                }
            }
        }        
        
        // Clone existing file attachments and create for contract record
        List<Attachment> fileAttachmentToIns = new List<Attachment> ();
        for (Attachment attachment : newQuoteAttachmentMap.values()) {

            if (!existingAttachmentMap.containsKey(attachment.Name + '-' + attachment.BodyLength) &&
                quoteContractIdMap.containsKey(attachment.ParentId)) {

                    Attachment newFile = attachment.clone();
                    newFile.ParentId = quoteContractIdMap.get(attachment.ParentId); //Get related contract
                    
                    fileAttachmentToIns.add(newFile);
                    existingAttachmentMap.put(attachment.Name + '-' + attachment.BodyLength, attachment); //add attachment to the existing value map
            }
        }

        if (!fileAttachmentToIns.isEmpty()) {
            insert fileAttachmentToIns;
        }

    }

}