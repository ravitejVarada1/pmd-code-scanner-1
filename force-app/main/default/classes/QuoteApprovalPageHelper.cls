global class QuoteApprovalPageHelper {
    
        
    @InvocableMethod(label='checkOMEntryCriteriaAndReasons')
    global static List<String> checkOMEntryCriteriaAndReasons(List<Id> quoteIds){
        
        ID singleQuoteId = quoteIds[0];
        
        String newEntryCriteria = updateOrderManagementEntryCriteria(new Map<ID,SBQQ__Quote__c>{singleQuoteId => new SBQQ__Quote__c(Id = singleQuoteId)});
        String newReasons       = updateOrderManagementApprovalReason(new Map<ID,SBQQ__Quote__c>{singleQuoteId => new SBQQ__Quote__c(Id = singleQuoteId)});
        
        Boolean hasNewEntryCrtieria = newEntryCriteria != null;
        Boolean hasNewReasons       = newReasons != null;
        
        if (!hasNewEntryCrtieria && !hasNewReasons){
            return new List<String>{'FALSE'};
         }
        
        String returnString;
        
        SBQQ__Quote__c quoteToUpdate = new SBQQ__Quote__c(
            Id = singleQuoteId
        );
        
        if (hasNewEntryCrtieria){
            quoteToUpdate.Order_Management_Entry_Criteria__c = newEntryCriteria;
        }
        
        if (hasNewReasons){
            quoteToUpdate.Order_Management_Approval_Reasons__c = newReasons;
        }
        
        if (hasNewEntryCrtieria && hasNewReasons){
            returnString = 'BOTH';
        }else if (hasNewEntryCrtieria){
            returnString = 'ENTRY';
        }else if (hasNewReasons){
            returnString = 'REASONS';
        }
        
        update quoteToUpdate;
        
        return new List<String>{'TRUE'};
    }

     //- Jira: BR-782
    //Populates the Order_Management_Approval_Reasons__c field on quotes. This field is the one criteria that
    //determines if a quote needs OM review. Uses Order_Approval_Criteria__mdt to dynamcially query quote and lines
    public static String updateOrderManagementApprovalReason(Map<ID,SBQQ__Quote__c> quoteMap){
        
        String returnString;
        
        Set<ID> quoteMapKeySet = quoteMap.keySet();
        
        String quoteQuery = 'SELECT Order_Management_Approval_Reasons__c, <quoteFields> (SELECT <quoteLineFields> ' +
            						 			   'FROM SBQQ__LineItems__r) ' +
            				'FROM SBQQ__Quote__c ' +
            				'WHERE Id IN :quoteMapKeySet';
        
        //All Quote Order_Approval_Criteria__mdt
        List<Order_Approval_Criteria__mdt> quoteCriteriaRecords = [SELECT Active__c, Field__c, Object__c, Operator__c, Value__c,
                                                                   Message__c
                                                                   FROM Order_Approval_Criteria__mdt
                                                                   WHERE Active__c = true
                                                                   AND Object__c = 'SBQQ__Quote__c'];
        
        //All Quote Line Order_Approval_Criteria__mdt
        List<Order_Approval_Criteria__mdt> quoteLineCriteriaRecords = [SELECT Active__c, Field__c, Object__c, Operator__c, Value__c,
                                                                       Message__c
                                                                       FROM Order_Approval_Criteria__mdt
                                                                       WHERE Active__c = true
                                                                       AND Object__c = 'SBQQ__QuoteLine__c'];
        
        //Dynamically construct the quote and quote line fields pulled into the query
        String quoteFields = '';
        String quoteLineFields = '';
        
        for (Order_Approval_Criteria__mdt criteria : quoteCriteriaRecords){
            quoteFields += criteria.Field__c + ', ';
        }

        Integer i=0;
        for (Order_Approval_Criteria__mdt criteria : quoteLineCriteriaRecords){
            if (i != 0){
                quoteLineFields += ', ';
            }
            
            quoteLineFields += criteria.Field__c;
            
            i++;
        }
        
        //Query for the quotes and lines with just the fields we need
       Map<ID,SBQQ__Quote__c> quoteMapClone = new Map<ID,SBQQ__Quote__c>(
            (List<SBQQ__Quote__c>)
            Database.query(
                quoteQuery.replace('<quoteFields>', quoteFields)
                .replace('<quoteLineFields>', quoteLineFields)
            )
        );
    
        //For each quote, and for each quote line, check if it meets each of the order management criteria,
        //and if so, update the Order_Management_Approval_Reasons__c field on the quote
        for (SBQQ__Quote__c q : quoteMapClone.values()){

            Set<String> orderMgmtApprovalReasonsSet = new Set<String>();
            
            for (Order_Approval_Criteria__mdt criteria : quoteCriteriaRecords){
                
                Object qFieldValue = Utilities.getValue(q, criteria.Field__c);
                
                if (Utilities.compareDynamically(
                    String.valueOf(qFieldValue),
                    criteria.Value__c, 
                    criteria.Operator__c,
                    Utilities.getType(qFieldValue))
                   )
                {
                    orderMgmtApprovalReasonsSet.add(criteria.Message__c);
                }
            }
            
            for (SBQQ__QuoteLine__c ql : q.SBQQ__LineItems__r){
                
                
                
                for (Order_Approval_Criteria__mdt criteria : quoteLineCriteriaRecords){
                    Object qlFieldValue = Utilities.getValue(ql, criteria.Field__c);
                    
                    if (Utilities.compareDynamically(
                        String.valueOf(qlFieldValue),
                        criteria.Value__c, 
                        criteria.Operator__c,
                        Utilities.getType(qlFieldValue))
                       )
                    {
                        orderMgmtApprovalReasonsSet.add(criteria.Message__c);
                    }
                }
                
            }
            
            String orderMgmtApprovalReasons = !orderMgmtApprovalReasonsSet.isEmpty()
            ? String.join(new List<String>(orderMgmtApprovalReasonsSet), ';')
            : 'NONE';
            
            if (q.Order_Management_Approval_Reasons__c != orderMgmtApprovalReasons){
                quoteMap.get(q.Id).Order_Management_Approval_Reasons__c = orderMgmtApprovalReasons;
                
                if (returnString == null){
                    returnString = orderMgmtApprovalReasons;
                }
            }
        }
        
        return returnString;
    }
    

    public static String updateOrderManagementEntryCriteria(Map<ID,SBQQ__Quote__c> quoteMap){
String returnString;
        
        Set<ID> quoteMapKeySet = quoteMap.keySet();
        
        String quoteQuery = 'SELECT Order_Management_Entry_Criteria__c, <quoteFields> (SELECT Id <quoteLineFields> ' +
            						 			   'FROM SBQQ__LineItems__r) ' +
            				'FROM SBQQ__Quote__c ' +
            				'WHERE Id IN :quoteMapKeySet';
        
        //All Quote Order_Mgmt_Approval_Entry_Criteria__mdt	
        List<Order_Mgmt_Approval_Entry_Criteria__mdt> quoteCriteriaRecords = [SELECT Active__c, Field__c, Object__c, Operator__c, Value__c,
                                                                   Message__c
                                                                   FROM Order_Mgmt_Approval_Entry_Criteria__mdt
                                                                   WHERE Active__c = true
                                                                   AND Object__c = 'SBQQ__Quote__c'];
        
        //All Quote Line Order_Mgmt_Approval_Entry_Criteria__mdt	
        List<Order_Mgmt_Approval_Entry_Criteria__mdt> quoteLineCriteriaRecords = [SELECT Active__c, Field__c, Object__c, Operator__c, Value__c,
                                                                       Message__c
                                                                       FROM Order_Mgmt_Approval_Entry_Criteria__mdt
                                                                       WHERE Active__c = true
                                                                       AND Object__c = 'SBQQ__QuoteLine__c'];
        
        //Dynamically construct the quote and quote line fields pulled into the query
        String quoteFields = '';
        String quoteLineFields = '';
        
        for (Order_Mgmt_Approval_Entry_Criteria__mdt criteria : quoteCriteriaRecords){
            quoteFields += criteria.Field__c + ', ';
        }


        for (Order_Mgmt_Approval_Entry_Criteria__mdt criteria : quoteLineCriteriaRecords){
            quoteLineFields += ', ' + criteria.Field__c;
        }
        
        //Query for the quotes and lines with just the fields we need
        Map<ID,SBQQ__Quote__c> quoteMapCloned = new Map<ID,SBQQ__Quote__c>(
            (List<SBQQ__Quote__c>)
            Database.query(
                quoteQuery.replace('<quoteFields>', quoteFields)
                .replace('<quoteLineFields>', quoteLineFields)
            )
        );
    
        //For each quote, and for each quote line, check if it meets each of the order management criteria,
        //and if so, update the Order_Management_Approval_Reasons__c field on the quote
        for (SBQQ__Quote__c q : quoteMapCloned.values()){

            Set<String> orderMgmtEntryCriteriaSet = new Set<String>();
            
            for (Order_Mgmt_Approval_Entry_Criteria__mdt criteria : quoteCriteriaRecords){
                Object qFieldValue = Utilities.getValue(q, criteria.Field__c);
                
                if (Utilities.compareDynamically(
                    String.valueOf(qFieldValue), 
                    criteria.Value__c, 
                    criteria.Operator__c,
                    Utilities.getType(qFieldValue))
                   )
                {
                    orderMgmtEntryCriteriaSet.add(criteria.Message__c);
                }
            }
            
            for (SBQQ__QuoteLine__c ql : q.SBQQ__LineItems__r){
                for (Order_Mgmt_Approval_Entry_Criteria__mdt criteria : quoteLineCriteriaRecords){
                    Object qlFieldValue = Utilities.getValue(ql, criteria.Field__c);

                    if (Utilities.compareDynamically(
                        String.valueOf(qlFieldValue),
                        criteria.Value__c, 
                        criteria.Operator__c,
                        Utilities.getType(qlFieldValue))
                       )
                    {
                        orderMgmtEntryCriteriaSet.add(criteria.Message__c);
                    }
                }
                
            }
            
            String orderMgmtEntryCriteria = !orderMgmtEntryCriteriaSet.isEmpty()
            ? String.join(new List<String>(orderMgmtEntryCriteriaSet), ';')
            : 'NONE';

            if (q.Order_Management_Entry_Criteria__c != orderMgmtEntryCriteria){
                

                
                quoteMap.get(q.Id).Order_Management_Entry_Criteria__c = orderMgmtEntryCriteria;
                                
                if (returnString == null){
                    returnString = orderMgmtEntryCriteria;
                }
            }
        }
        
        return returnString;
    }
    
}