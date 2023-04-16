/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*   https://cargurus.atlassian.net/browse/SA-142
*   Change Contract Account - Lightening Web Component
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Navdeep Singh
* @created        08/07/2021
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public without sharing class ChangeContractAccountLWC {
    
    static final String SUCCESS_MESSAGE = System.Label.Change_Contract_Account_Success_Msg;
    static final String INVALID_CONTRACT_MESSAGE = System.Label.Change_Contract_Account_Invalid_Contract_Msg;
    static final String INVALID_USER_MESSAGE = System.Label.Change_Contract_Account_Invalid_User_Msg;

    @AuraEnabled
    public static Map<String,Object> processAccountUpdate(String contractId,String selectedAccountId){
        
        Map<String,Object> response = new Map<String,Object>();
        response.put('success',false);

        if(validateCurrentUser()){
        
            if(String.isNotBlank(contractId) && String.isNotBlank(selectedAccountId)){

                String fields = '';
                Map<String, Schema.SObjectField> mapofFields = Schema.getGlobalDescribe().get('Contract').getDescribe().fields.getMap();
                
                for(String fieldName : mapofFields.keySet()) {
                    fields += fieldName+',';
                }
                fields = fields.removeEnd(',');
                
                String soqlQuery = 'SELECT ' + fields + ' FROM Contract WHERE Id=:contractId AND Status!=\''+ConstantsUtil.CONTRACT_STATUS_CANCELLED+'\' LIMIT 1';
                
                List<Contract> updateContracts = new List<Contract>();

                List<Contract> contracts = Database.query(soqlQuery);

                if(!contracts.isEmpty()){
                    Contract duplicateContract = contracts[0].clone(false,true,true,false);
                    duplicateContract.AccountId = selectedAccountId;
                    duplicateContract.Status = 'Draft';

                    try{
                        insert duplicateContract;

                        duplicateContract.Status = ConstantsUtil.CONTRACT_STATUS_ACTIVE;
                        contracts[0].Status = ConstantsUtil.CONTRACT_STATUS_CANCELLED;

                        updateContracts.add(contracts[0]);
                        updateContracts.add(duplicateContract);
                        update updateContracts;

                        Contract newContract = [SELECT Id,ContractNumber FROM Contract WHERE Id=:duplicateContract.Id];

                        setNewContractOnExistingRelations(contractId,duplicateContract.Id,selectedAccountId);
                        response.put('success',true);
                        response.put('message',SUCCESS_MESSAGE +' '+ newContract.ContractNumber);
                        response.put('newContractId',duplicateContract.Id);
                    }catch(Exception e){
                        response.put('exception_details',e);            
                    }
                }else{
                    response.put('success',false);
                    response.put('message',INVALID_CONTRACT_MESSAGE);
                }
            }
        }else{
            response.put('message',INVALID_USER_MESSAGE);
        }
        return response;
    }

    static Boolean validateCurrentUser(){

        Set<String> allowedProfiles = new Set<String>();

        for(Permissions_Settings__mdt profileName : [
            SELECT Label, Is_Active__c
            FROM Permissions_Settings__mdt
            WHERE Object__c = 'Contract'
            AND Permission_Type__c = 'ChangeContractAccount'
            AND Is_Active__c = true
        ]){
            allowedProfiles.add(profileName.Label);
        }
        Profile usrProfile = [SELECT Id, Name FROM Profile WHERE Id=:Userinfo.getProfileId() LIMIT 1];
        return !allowedProfiles.isEmpty() && allowedProfiles.contains(usrProfile.Name);
    }

    static void setNewContractOnExistingRelations(String contractId,String newContractId,String selectedAccountId){

        List<Order> updateOrds = new List<Order>();
        List<SBQQ__Subscription__c> updateCPQSub = new List<SBQQ__Subscription__c>();
        List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>();
        List<Attachment> insertAttList = new List<Attachment>();

        //update Contract on Orders
        for(Order ord : [SELECT Id,ContractCustom__c,ContractId 
        FROM Order 
        WHERE ContractCustom__c =:contractId]){
            ord.ContractCustom__c = newContractId;
            updateOrds.add(ord);
        }

        for(SBQQ__Subscription__c cpqSub : [SELECT Id,SBQQ__Contract__c 
        FROM SBQQ__Subscription__c 
        WHERE SBQQ__Contract__c =:contractId]){
            cpqSub.SBQQ__Account__c = selectedAccountId;
            cpqSub.SBQQ__Contract__c = newContractId;
            updateCPQSub.add(cpqSub);
        }

        for(ContentDocumentLink cdl : [
            SELECT Id, LinkedEntityId, ContentDocumentId, ShareType, Visibility 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId=:contractId
        ]){
            cdl.Id = null;
            cdl.LinkedEntityId = newContractId;
            cdlList.add(cdl);
        }
        
        for(Attachment a : [
            SELECT Id, Name, Body 
            FROM Attachment 
            WHERE ParentId =:contractId
        ]){
            Attachment att = new Attachment(Name = a.Name, Body = a.Body, Parentid = newContractId);
            insertAttList.add(att);
        }

        List<SBQQ__Quote__c> quoteList  = new List<SBQQ__Quote__c>();

        for(SBQQ__Quote__c cpqQuote : [
            SELECT Id,SBQQ__MasterContract__c  
            FROM SBQQ__Quote__c 
            WHERE SBQQ__MasterContract__c=:contractId 
        ]){
            if(cpqQuote.SBQQ__MasterContract__c!=null){
                cpqQuote.SBQQ__MasterContract__c = newContractId;
                quoteList.add(cpqQuote);
            }
        }

        List<Opportunity> oppList = new List<Opportunity>();

        for(Opportunity opp : [
            SELECT Id,Retention_Contract__c, SBQQ__AmendedContract__c, SBQQ__RenewedContract__c 
            FROM Opportunity 
            WHERE Retention_Contract__c=:contractId 
            OR SBQQ__AmendedContract__c=:contractId 
            OR SBQQ__RenewedContract__c=:contractId
        ]){

            if(opp.SBQQ__AmendedContract__c!=null){
                opp.SBQQ__AmendedContract__c = newContractId;
                oppList.add(opp);
            }else if(opp.Retention_Contract__c!=null){
                opp.Retention_Contract__c = newContractId;
                oppList.add(opp);
            }else if(opp.SBQQ__RenewedContract__c!=null){
                opp.SBQQ__RenewedContract__c = newContractId;
                oppList.add(opp);
            }
        }

        //bypassing the triggers for these objects, since we are only updating Contract 
        //on these records with the new cloned contract
        TriggerHandler.bypass('CPQ_Subscription_TriggerHandler');
        TriggerHandler.bypass('OrderTriggerHandler');
        TriggerHandler.bypass('OpportunityTriggerHandler');
        TriggerHandler.bypass('CPQQuoteTriggerHandler');

        if(!updateCPQSub.isEmpty()){
            update updateCPQSub;
        }

        if(!updateOrds.isEmpty()){
            update updateOrds;
        }

        if(!oppList.isEmpty()){
            update oppList;
        }

        if(!quoteList.isEmpty()){
            update quoteList;
        }

        if(!cdlList.isEmpty()){
            insert cdlList;
        }

        if(!insertAttList.isEmpty()){
            insert insertAttList;
        }
    }
}