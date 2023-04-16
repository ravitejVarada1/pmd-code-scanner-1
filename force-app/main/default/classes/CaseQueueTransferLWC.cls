/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*   https://cargurus.atlassian.net/browse/BR-8364
*   Case Queue Transfer - Lightening Web Component
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Navdeep Singh
* @created        04/18/2021
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public without sharing class CaseQueueTransferLWC {
    
    public static final String CASE_OWNER_NOT_QUEUE = 'This case record doesn\'t belong to a queue.';
    public static final String CURRENT_USER_NOT_QUEUE_MEMBER = 'Your user is not a member of the case owner queue, so you won\'t be able to use this feature for this case record.';
    
    public static final String SSD_RECORDTYPE_NAME = 'Sales Support Desk';
    public static final String SSD_DEFAULT_COUNTRY_CODE = 'US';

    @AuraEnabled
    public static Map<String,Object> getInitialSetup(String recordId){
        
        Map<String,Object> response = new Map<String,Object>();
        response.put('validOperation',false);

        if(String.isNotBlank(recordId)){

            String objectName = 'Case';
            Map<String, List<Object>> fieldToPicklistMap = new Map<String, List<Object>>();
            //SA-1492 - KS - Added LogisticPartners__c to the list to get picklist values
            List<String> fieldNameList = new List<String>{'CountryCode__c', 'LogisticPartners__c'};
            for(String fieldName: fieldNameList){
                List<Object> tempList = new List<object>();
                for(Schema.PicklistEntry pickListVal : SObjectDescribeUtils.getPicklistValuesByField(objectName, fieldName)){
                    Map<String,Object> temp = new Map<String,Object>();
                    temp.put('label',pickListVal.getLabel());
                    temp.put('value',pickListVal.getValue());
                    tempList.add(temp);
                }
                if(!tempList.isEmpty()){
                    fieldToPicklistMap.put(fieldName, tempList);
                }
            }
            response.put('fieldToPicklistMap', fieldToPicklistMap);
            //SA-1492 - KS - Added LogisticPartners__c in the query
            List<Case> cs = new List<Case>([
                SELECT Id,OwnerId,Owner.Name, CountryCode__c, LogisticPartners__c
                FROM Case
                WHERE Id=:recordId
            ]);
            
            if(!cs.isEmpty()){
                
                response = checkValidOperation(cs[0].OwnerId,response);
                
                if(response!=null && response.containskey('validOperation') && (Boolean)response.get('validOperation')){
                    
                    List<CG_Case_Queue_Mapping__mdt> queueRecordTypeConfig = new List<CG_Case_Queue_Mapping__mdt>([
                        SELECT Id,Order__c , Queue_Label__c, Mapped_RecordType__c,Run_with_Assignment_Rules__c
                        FROM CG_Case_Queue_Mapping__mdt
                        WHERE Active__c = true
                        ORDER BY Order__c asc
                    ]);
                    
                    //SA-1492 - KS - Pass current value of the LogisticPartners__c field as a response
                    response.put('caseOwnerName',cs[0].Owner.Name); 
                    response.put('caseQueueMappingConfig',queueRecordTypeConfig);
                    response.put('countryCode', cs[0].CountryCode__c);
                    response.put('logisticsProvider', cs[0].LogisticPartners__c);
                }    
            }
        }
        return response;
    }
    
    public static Map<String,Object> checkValidOperation(String groupId,Map<String,Object> response){
        
        String currentUsrId = UserInfo.getUserId();

        if(groupId.startsWith('00G')){
            
            //check if current user is case owner queue member
            List<GroupMember> groupMembrList = new List<GroupMember>([
                SELECT Id, GroupId, UserOrGroupId 
                FROM GroupMember 
                WHERE GroupId =:groupId 
                AND UserOrGroupId =:currentUsrId
            ]);
            
            if(groupMembrList.isEmpty()){
                response.put('validOperation',false);
                response.put('operationMsg',CURRENT_USER_NOT_QUEUE_MEMBER);    
            }else{
                //case owner is a queue, with current user being a member of the queue
                response.put('validOperation',true);
            }
            
        }else if(groupId == currentUsrId){
            //current user is case owner
            response.put('validOperation',true);
        }
        else{
            response.put('validOperation',false);
            response.put('operationMsg',CASE_OWNER_NOT_QUEUE);
        }
        
        return response;
    }

    @AuraEnabled
    //SA-1492 - KS - Accept logisticsProvider as a parameter when called from the caseQueueTransfers.js
    public static Map<String,Object> processCaseSwitch(String recordId,String recordTypeId,String caseReason,String caseTransferExcerpt, String countryCode, String logisticsProvider){

        Map<String,Object> response = new Map<String,Object>();
        response.put('success',false);

        if(String.isNotBlank(recordId)
        && String.isNotBlank(recordTypeId)
        && String.isNotBlank(caseReason)
        && String.isNotBlank(caseTransferExcerpt)){

            String recordTypeName = getRecordTypeNameById('Case',recordTypeId);

            Boolean runWithAssignmentRules = true;
            runWithAssignmentRules = setAssignmentRulesFlag(runWithAssignmentRules,recordTypeName);

            List<Case> cs = new List<Case>([
                SELECT Id,Description,Reason,CountryCode__c, LogisticPartners__c,
                RecordTypeId,Force_Run_Assignment_Rules__c
                FROM Case
                WHERE Id=:recordId
            ]);

            if(!cs.isEmpty()){
                Case csObj = cs[0];
                csObj.Reason = caseReason;
                csObj.RecordTypeId = recordTypeId;
                csObj.Description = 'Queue Switch Reason(' + Datetime.now().format('MMM dd,yyyy') +'):\n'+ caseTransferExcerpt + '\n\n' +csObj.Description;
                csObj.Force_Run_Assignment_Rules__c = true;
                csObj.CountryCode__c = countryCode;
                csObj.LogisticPartners__c = logisticsProvider;

                //Sales Support Desk use case, set CountryCode is NULL
                csObj.CountryCode__c = recordTypeName.equalsIgnoreCase(SSD_RECORDTYPE_NAME) && csObj.CountryCode__c==null  ? SSD_DEFAULT_COUNTRY_CODE : csObj.CountryCode__c;

                //Run Case assignment rule from apex
                Database.DMLOptions dmlOption = new Database.DMLOptions();
                dmlOption.assignmentRuleHeader.useDefaultRule = runWithAssignmentRules;

                try{

                    csObj.setOptions(dmlOption);
                    update csObj;

                    csObj.Force_Run_Assignment_Rules__c = false;
                    //Not running Case assignment rules, updating flag back to false
                    dmlOption = new Database.DMLOptions();
                    dmlOption.assignmentRuleHeader.useDefaultRule = false;

                    csObj.setOptions(dmlOption);

                    update csObj;
                    response.put('success',true);

                }catch(Exception ex){
                    response.put('success',false);
                    response.put('exceptionMsg',ex.getMessage());
                }
            }

        }

        return response;
    }

    public static Boolean setAssignmentRulesFlag(Boolean runWithAssignmentRules,String recordTypeName){

        List<CG_Case_Queue_Mapping__mdt> queueRecordTypeConfig = new List<CG_Case_Queue_Mapping__mdt>([
            SELECT Mapped_RecordType__c,Run_with_Assignment_Rules__c
            FROM CG_Case_Queue_Mapping__mdt
            WHERE Active__c = true AND Mapped_RecordType__c =:recordTypeName LIMIT 1
        ]);

        if(!queueRecordTypeConfig.isEmpty()){
            runWithAssignmentRules = queueRecordTypeConfig[0].Run_with_Assignment_Rules__c;
        }
        return runWithAssignmentRules;
    }

    public static String getRecordTypeNameById(String objectName, Id strRecordTypeId){
        return Schema.getGlobalDescribe().get(objectName).getDescribe().getRecordTypeInfosById().get(strRecordTypeId).getName();
    }
}