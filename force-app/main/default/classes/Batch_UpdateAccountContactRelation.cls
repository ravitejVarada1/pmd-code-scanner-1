public class Batch_UpdateAccountContactRelation implements Database.Batchable<sObject>, Schedulable{ 
    private Set<Id> queryIds;
    private DateTime cutoffTime = DateTime.now().addHours(-5);
    private DateTime startDate;
	public static Map<String, String> objectFieldTypeMap = new Map<String, String>(); 
    public static Set<String> cpqStatusesToQuery = new Set<String>();
    public static Map<String, Set<String>> prodFamilyGrpToACRFldMap = new Map<String, Set<String>>();    
    public static Map<String, Set<String>> acrToACRFldMap = new Map<String, Set<String>>();        
    public static Map<string,String> prodSubCategoryToACRFieldGroupMap = new Map<String,String>();
    public static Map<string,String> teamMemberRoleToACRFieldMap = new Map<String,String>();    
    public static Set<String> acrFieldSet = new Set<String>();
    public static Set<String> atmACRFieldSet = new Set<String>();    
	public static Set<String> prodSubCategoriesSet = new Set<String>();    
	public static List<String> acrAllProdSubCategoryFlds = new List<String>();    

    static String strACRRegions    				= System.Label.Account_Contact_Relation_Regions;
    static String strObjects					= System.Label.ACR_Fields_Mtd_Describe; 
    static String strCPQCancelledStatuses   	= System.Label.CPQ_Cancelled_Statuses;
    static String strCPQActiveStatuses      	= System.Label.CPQ_Active_Statuses;  
    static Integer intBatchSize                 = Integer.valueof(System.Label.ACR_Batch_Size);

    static Set<String> acrRegionSet 			= new Set<String>(new List<String>(strACRRegions.split(',')));     
    static Set<String> objectSet 				= new Set<String>(new List<String>(strObjects.split(',')));
    static Set<String> cpqCancelledStatusesSet 	= new Set<String>(new List<String>(strCPQCancelledStatuses.split(','))); 
    static Set<String> cpqActiveStatusesSet 	= new Set<String>(new List<String>(strCPQActiveStatuses.split(',')));  

	public static Map<String,String> acrProductFieldsToProductSubCategoryMap = new Map<String,String>();
    
    static {
        for(String sObjectName : objectSet){
            SObjectType SobjType = ((SObject)(Type.forName('Schema.'+sObjectName).newInstance())).getSObjectType();
            Schema.DescribeSObjectResult objectDescribe = SobjType.getDescribe(); 
            Map<String, Schema.SObjectField> fields = objectDescribe.fields.getMap();
            for(String fieldName : fields.keySet()) {
                Schema.SObjectField field = fields.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                if (!objectFieldTypeMap.containsKey(fieldName)) {
                    objectFieldTypeMap.put(fieldDescribe.getName(), string.valueOf(fieldDescribe.getType()));
                }
            }
        }

        cpqStatusesToQuery.addAll(cpqCancelledStatusesSet);
        cpqStatusesToQuery.addAll(cpqActiveStatusesSet);      
        
        for(ACR_to_Prod_Sub_Categories_Mappings__mdt acrToProdSubCategoriesMdt : [SELECT Id, DeveloperName, MasterLabel, 
                                                                                  ACR_Product_Field__c, ACR_Product_Field_Set__c, 
                                                                                  ACR_Product_Sub_Category__c  
                                                                                  FROM ACR_to_Prod_Sub_Categories_Mappings__mdt]) {
           
            String prodFamilyGrpToACRFldMapKey = acrToProdSubCategoriesMdt.ACR_Product_Field__c;
            String strACRFieldSet = acrToProdSubCategoriesMdt.ACR_Product_Field_Set__c;  
			String strProdSubCategories = acrToProdSubCategoriesMdt.ACR_Product_Sub_Category__c;                                                                                        
            acrFieldSet = new Set<String>(new List<String>(strACRFieldSet.split(',')));
            for(String acrField : acrFieldSet) {
                acrField = acrField.trim();
            }                                                                         
			prodSubCategoriesSet = new Set<String>(new List<String>(strProdSubCategories.split(',')));          
                                                                                      
            if(!prodFamilyGrpToACRFldMap.containsKey(prodFamilyGrpToACRFldMapKey)){
                prodFamilyGrpToACRFldMap.put(prodFamilyGrpToACRFldMapKey, acrFieldSet);
            }    
			
            ACRAllProdSubCategoryFlds.addAll(acrFieldSet);
                                                                                      
            for(String prodSubCategory : prodSubCategoriesSet){
                if(!prodSubCategoryToACRFieldGroupMap.containsKey(prodSubCategory)){
                    prodSubCategoryToACRFieldGroupMap.put(prodSubCategory, prodFamilyGrpToACRFldMapKey);
                }
            }                                                                                      
        }

        for(ATM_To_ACR_Field_Mappings__mdt  atmToACRFieldMappingsMdt : [SELECT Id, DeveloperName, MasterLabel, 
                                                                                  ATM_Team_Role__c, ATM_Team_Field__c, 
                                                                                  ATM_Team_Field_Set__c   
                                                                                  FROM ATM_To_ACR_Field_Mappings__mdt]) {
           
            String atmTeamMemberRole = atmToACRFieldMappingsMdt.ATM_Team_Role__c;
            String strATMField = atmToACRFieldMappingsMdt.ATM_Team_Field__c;  
			String strATMFieldSet = atmToACRFieldMappingsMdt.ATM_Team_Field_Set__c;                                                                                        
            atmACRFieldSet = new Set<String>(new List<String>(strATMFieldSet.split(',')));
            for(String atmACRField : atmACRFieldSet) {
                atmACRField = atmACRField.trim();
            }                                                                         
                                                                                      
            if(!acrToACRFldMap.containsKey(strATMField)){
                acrToACRFldMap.put(strATMField, atmACRFieldSet);
            }    
			acrAllProdSubCategoryFlds.addAll(atmACRFieldSet);

            if(!teamMemberRoleToACRFieldMap.containsKey(atmTeamMemberRole)){
				teamMemberRoleToACRFieldMap.put(atmTeamMemberRole,strATMField);
            }
        }
    }

    private static final Map<String,String> acctToACRFieldMap = new Map<String,String>{  
        'CurrencyIsoCode'							=> 'CurrencyIsoCode',
        'BillingCity'								=> 'Account_Billing_City__c', 
        'BillingCountry'							=> 'Account_Billing_Country__c',
        'BillingState'								=> 'Account_Billing_State__c',
        'BillingStreet'        						=> 'Account_Billing_Street__c',
        'BillingPostalCode'							=> 'Account_Billing_Zip_Code__c',
        'Account_Category__c'						=> 'Account_Category__c',
        'Name'										=> 'Account_Name__c',
        'OwnerId'									=> 'Account_Owner_ID__c',
        'Owner.Email'								=> 'Account_Owner_Email__c',
        'Owner.Name'								=> 'Account_Owner_Full_Name__c',
        'RecordType.DeveloperName'					=> 'Account_Record_Type__c',
        'Type'										=> 'Account_Type__c',
        'Account_Status__c'							=> 'Account_Status__c',
        'Product_Activation_Status__c'				=> 'Product_Activation_Status__c',
        'Account_Saturation_Formula__c'				=> 'Account_Saturation_Formula__c',
        'Account_Saturation_Percentage__c'			=> 'Account_Saturation_Percentage__c',
        'Account_Saturation_Percentage_Formula__c'	=> 'Account_Saturation_Percentage_Formula__c',
		'CarOffer_Id__c'							=> 'CarOffer_Id__c'            
    };  

    private static final Set<String> cpqSubscriptionFieldSet = new Set<String>{
        'SBQQ__Product__r.name',               
        'SBQQ__StartDate__c',
        'SBQQ__EndDate__c',            
        'SBQQ__NetPrice__c',
        'SBQQ__TerminatedDate__c',
        'Billing_Status__c',
        'Provisioning_Status__c'
    };   
        
    private static final Map<String,String> serviceProviderToACRFieldMap = new Map<String,String>{
        'Total_Used_Inventory_Units__c'		=> 'SP_Total_Used_Inventory_Units__c',
        'Total_New_Inventory_Units__c'		=> 'SP_Total_New_Inventory_Units__c'
    };  
        
    private static final Set<String> acctTeamMemberFieldSet = new Set<String>{
        'TeamMemberRole',    
        'User.Email',    
		'User.FirstName',
        'User.LastName',
        'User.Phone'
    };          

    public Batch_UpdateAccountContactRelation() {}
    
	public Batch_UpdateAccountContactRelation(Id queryId) { 
            this.queryIds = new Set<Id>{queryId};
    }
    
    public Batch_UpdateAccountContactRelation(Set<Id> queryIds) {
            this.queryIds = queryIds;
    }

    public Batch_UpdateAccountContactRelation(Integer numberOfDays) {
            this.startDate = DateTime.now().addDays(-Integer.valueOf(numberOfDays));
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC){
            
            String soqlQuery = 'SELECT Id FROM Account WHERE BillingCountryCode IN : acrRegionSet ' +
                			   'AND LastModifiedDate >=: ';  
                                if(startDate != null){
									soqlQuery += ' startDate' ;                                     
                                } else {
									soqlQuery += ' cutoffTime' ;                                                                         
                                }		
                                if(queryIds != null){
                                    soqlQuery += ' and Id IN : queryIds';		
                                }
	        return Database.getQueryLocator(soqlQuery); 
    }
    
    public void execute(Database.BatchableContext BC, List<Account> acctList) {
        
        Map<Id,Account> singleBatchAccountMap = new Map<Id,Account>(acctList);
        Map<String, Map<String,Object>> acctIdToACRFieldValMap = New Map<String, Map<String,Object>>();
        List<AccountContactRelation> acrUpdateList = new List<AccountContactRelation>();
        Set<Id> acctIds = new Set<Id>();
        acctIds = singleBatchAccountMap.keySet();
        
        String soqlAcctQuery = 'SELECT Id, (SELECT Id, AccountId, '+
								String.join(new List<String>(acctToACRFieldMap.values()), ', ')+ ' , '+
            					String.join(new List<String>(ACRAllProdSubCategoryFlds), ', ')+' , '+
            					String.join(new List<String>(serviceProviderToACRFieldMap.values()), ', ')+' '+            
                                'FROM AccountContactRelations WHERE Contact.Status__c = \'Active\'), '+
            					'(SELECT Id, '+ String.join(new List<String>(cpqSubscriptionFieldSet), ', ')+ ' , '+
            					'SBQQ__Product__r.Sub_Category__c ' +
            					'FROM CPQ_Subscriptions_Fulfillment__r WHERE Provisioning_Status__c IN : cpqStatusesToQuery  '+
            					'AND SBQQ__NetPrice__c > 0 ORDER BY SBQQ__TerminatedDate__c DESC), '+
								'(SELECT Id, Total_Used_Inventory_Units__c, Total_New_Inventory_Units__c '+
            					'FROM Service_Provider__r), '+ 
								'(SELECT Id, '+ String.join(new List<String>(acctTeamMemberFieldSet), ', ')+ ' , '+
            					'UserId FROM AccountTeamMembers ORDER BY TeamMemberRole ASC, CreatedDate DESC), '+ 
                                String.join(new List<String>(acctToACRFieldMap.keyset()), ', ')+' '+
                                'FROM Account WHERE Id in : acctIds';   

        Map<ID,Account> accountMap = new Map<ID,Account>(
				(List<Account>)Database.query(soqlAcctQuery)
        );

        for (Account acct : accountMap.Values()) {
            
            if (acct.AccountContactRelations.size() > 0) {
                Id acctId = acct.Id;
                Integer noOfCPQActiveSubs;      
                Set<String> processedProductGroupings = new Set<String>();
                Map<String,Object> acrFieldValueMap = new Map<String,Object>();
                List<SBQQ__Subscription__c> cpqSubsriptionsList = acct.CPQ_Subscriptions_Fulfillment__r;
                List<Service_Provider__c> serviceProviderList = acct.Service_Provider__r;
                List<AccountTeamMember> accountTeamMemberList = acct.AccountTeamMembers;

                if(!acctIdToACRFieldValMap.ContainsKey(acctId)){
                    acctIdToACRFieldValMap.put(acctId, new Map<String,Object>());
                }
                
                //Below block of code populates Account and parent object fields from account object (Ex: user)
                for (String acctFieldName : acctToACRFieldMap.keySet()) {
                    String acrFieldName = acctToACRFieldMap.get(acctFieldName);
                    Object accountFieldVal;
                    
                    accountFieldVal = getAnyObjFldValue(acct, acctFieldName);
                    
                    if (!acctIdToACRFieldValMap.get(acctId).containsKey(acrFieldName)) {
                        acctIdToACRFieldValMap.get(acctId).put(acrFieldName, accountFieldVal);
                    }
                }
                    
                //Below function process CPQ subscriptions data        
                if (acct.Type == 'Customer') {
                    processCPQSubsToACR(cpqSubsriptionsList, cpqActiveStatusesSet, acctId, acctIdToACRFieldValMap);                               
                } else if(acct.Type == 'Former Customer') {
                    system.debug('Only cancelled subscriptions');
                    processCPQSubsToACR(cpqSubsriptionsList, cpqCancelledStatusesSet, acctId, acctIdToACRFieldValMap);                                               
                }
                
                if(serviceProviderList != null) {
					processSPDataToACR(serviceProviderList, acctId, acctIdToACRFieldValMap);                    
                }
                
                if(accountTeamMemberList != null) {
                    processATMToACR (accountTeamMemberList, acctId, acctIdToACRFieldValMap); 
                }

                acrFieldValueMap = acctIdToACRFieldValMap.get(acctId);
                
                for (AccountContactRelation acr : acct.AccountContactRelations) {

                    Boolean isDifferent = false;
                    isDifferent = getIsACRDifferent(acr, acrFieldValueMap);
                    
                    if (isDifferent) {
                        acrUpdateList.add(acr);
                    }                       
                }
            }		        
        }
        
        if (!acrUpdateList.isEmpty()) {
            update acrUpdateList;

		}
       
    }

    public void execute(SchedulableContext sc) {        
        Database.executeBatch(new Batch_UpdateAccountContactRelation(), intBatchSize);
    }
    
   	public void finish(Database.BatchableContext BC) { }

	//If Account has active CPQ subscriptions process and wipe out all the cancelled data    
    private static void processCPQSubsToACR(List<SBQQ__Subscription__c> cpqSubsriptionsList, Set<String> cpqStatusSet,
                                            Id acctId, Map<String,Map<String,Object>> acctIdToACRFieldValMap) {
	    Set<String> processedProductSubCategories = new Set<String>();
    	for (SBQQ__Subscription__c cpqSub : cpqSubsriptionsList) { 	

        	String cpqProvisioningStatus	= cpqSub.Provisioning_Status__c;
            String prodSubCategory 			= cpqSub.SBQQ__Product__r.Sub_Category__c;
            Date terminatedDate				= cpqSub.SBQQ__TerminatedDate__c;

            if (cpqStatusSet.contains(cpqProvisioningStatus) && prodSubCategoryToACRFieldGroupMap.containsKey(prodSubCategory)) {          
            	for (string cpqSubscriptionFieldName : cpqSubscriptionFieldSet) {
					Object cpqSubscriptionFieldVal;
                    if (cpqSubscriptionFieldName.contains('.')) {
                        cpqSubscriptionFieldVal = getAnyObjFldValue (cpqSub, cpqSubscriptionFieldName);
                    } else {
	                    cpqSubscriptionFieldVal = cpqSub.get(cpqSubscriptionFieldName);                        
                    }                   

                    processedProductSubCategories.add(prodSubCategory);
                    Set<String> acrFldSet = prodFamilyGrpToACRFldMap.get(prodSubCategoryToACRFieldGroupMap.get(prodSubCategory));
                        
                    for (String acrFieldName : acrFldSet) {
                    	if (!acctIdToACRFieldValMap.get(acctId).containsKey(acrFieldName)) {                       
                        	acctIdToACRFieldValMap.get(acctId).put(acrFieldName, cpqSubscriptionFieldVal);
                            break;
                        }                                
                    }
                } 
            }
        }

        for(String prodSubCategory : prodFamilyGrpToACRFldMap.keySet()){
    	    if(!processedProductSubCategories.contains(prodSubCategory)){
    	       	Set<String> acrFieldSet = prodFamilyGrpToACRFldMap.get(prodSubCategory);
        		for (String acrFieldName : acrFieldSet) {
                	if (!acctIdToACRFieldValMap.get(acctId).containsKey(acrFieldName)) {
                    	acctIdToACRFieldValMap.get(acctId).put(acrFieldName, null);
                    }              
                }               
            }
        }                                                     
	}
    
    private static void processSPDataToACR(List<Service_Provider__c> sericeProviderList, Id acctId, 
                                           Map<String,Map<String,Object>> acctIdToACRFieldValMap) {

		Decimal totalUsedInventory = 0;
		Decimal totalNewInventory  = 0;   
        Object spFieldVal;                                       
                                               
		for(Service_Provider__c sp : sericeProviderList) {
            if(sp.Total_Used_Inventory_Units__c != null){
                totalUsedInventory = totalUsedInventory + sp.Total_Used_Inventory_Units__c;
            }
            
            if(sp.Total_New_Inventory_Units__c != null){
                totalNewInventory  = totalNewInventory + sp.Total_New_Inventory_Units__c;
            }                
        }     
                                               
		for (String acrFieldName : serviceProviderToACRFieldMap.values()) {
			if (!acctIdToACRFieldValMap.get(acctId).containsKey(acrFieldName)) {
                if(acrFieldName == 'SP_Total_Used_Inventory_Units__c'){
					acctIdToACRFieldValMap.get(acctId).put(acrFieldName, totalUsedInventory);					                    
                }
                if(acrFieldName == 'SP_Total_New_Inventory_Units__c'){
					acctIdToACRFieldValMap.get(acctId).put(acrFieldName, totalNewInventory);					                    
                }                
			}                                
		}                                               
    }
    
	//If Account has active CPQ subscriptions process and wipe out all the cancelled data    
    private static void processATMToACR(List<AccountTeamMember> atmList, Id acctId, 
                                        Map<String,Map<String,Object>> acctIdToACRFieldValMap) {
		String teamMemberRole;	
		String previousTeamMemberRole;
                                             
    	for (AccountTeamMember atm : atmList) { 
            teamMemberRole = atm.TeamMemberRole;
            if((teamMemberRoleToACRFieldMap.containsKey(teamMemberRole)) && (teamMemberRole != previousTeamMemberRole)){
                for (string acctTeamMemberFieldName : acctTeamMemberFieldSet) {
                    Object acctTeamMemberFieldVal;
                    if (acctTeamMemberFieldName.contains('.')) {
                        acctTeamMemberFieldVal = getAnyObjFldValue (atm, acctTeamMemberFieldName);
                    } else {
                        acctTeamMemberFieldVal = atm.get(acctTeamMemberFieldName);                        
                    }

                    Set<String> acrFldSet = acrToACRFldMap.get(teamMemberRoleToACRFieldMap.get(teamMemberRole));
                    
                    for (String acrFieldName : acrFldSet) {
                        if (!acctIdToACRFieldValMap.get(acctId).containsKey(acrFieldName)) {                       
                            acctIdToACRFieldValMap.get(acctId).put(acrFieldName, acctTeamMemberFieldVal);
                            break;
                        }                                
                    }
                }
                previousTeamMemberRole = atm.TeamMemberRole;                    
            }
        }
	}    
    
    public static Object getAnyObjFldValue (SObject sObjectType, String objfieldName) {
        Object fieldVal;
        SObject sObjectName = sObjectType;
        
        if (objfieldName.contains('.')) {
            List<String> refObjectFields = new List<String>(objfieldName.split('\\.'));
            String parentObjName 	= refObjectFields[0];
            String parentObjField 	= refObjectFields[1];
            if (parentObjName.contains('__r')) {
                //This block is to deal with custom relationships.
                String parentObjAPIName = parentObjName.replace('__r','__c');
                if(sobjectName.get(parentObjAPIName) != null && sobjectName.getSObject(parentObjName).get(parentObjField) != null){
                    fieldVal = sobjectName.getSObject(parentObjName).get(parentObjField);                            
                }                                
                
            } else {
                //This block is to deal with standard relationships.
                if(sobjectName.getSObject(parentObjName).get(parentObjField) != null){
                    fieldVal = sobjectName.getSObject(parentObjName).get(parentObjField);                            
                }                                   
            }
        } else {
            fieldVal = sObjectName.get(objfieldName);
        }
        
        return fieldVal;        
    }

    private static Boolean getIsACRDifferent (AccountContactRelation acr, Map<String,Object> acrFieldValueMap){

        Boolean isDifferent = false;
        for(String acrFieldName : acrFieldValueMap.keySet()){
            String acrFieldType = objectFieldTypeMap.get(acrFieldName);

            if (acrFieldType == 'STRING' || acrFieldType == 'EMAIL' || acrFieldType == 'PICKLIST' || acrFieldType == 'PHONE') {
                String acrFieldValue = (String)acr.get(acrFieldName);
                String newACRFieldValue = (String)acrFieldValueMap.get(acrFieldName);                            
                
                if (String.isBlank(string.valueof(acrFieldValue))) {
                    acrFieldValue = null;
                }
                
                if (String.isBlank(string.valueof(newACRFieldValue))) {
                    newACRFieldValue = null;
                }
                
                if (acrFieldValue != newACRFieldValue) {
                    acr.put(acrFieldName, newACRFieldValue);
                    isDifferent = true;
                }                              
                
            } else if (acrFieldType == 'DATE') {
                
                Date acrFieldValue = (Date)acr.get(acrFieldName);                                  
                Date newACRFieldValue = (Date)acrFieldValueMap.get(acrFieldName);                                        
                if (acrFieldValue != newACRFieldValue) {
                    acr.put(acrFieldName, newACRFieldValue);
                    isDifferent = true;
                }                              
                
            } else { 
                
                Double acrFieldValue = (Double)acr.get(acrFieldName);            
                Double newACRFieldValue = (Double)acrFieldValueMap.get(acrFieldName);                              
                if (acrFieldValue != newACRFieldValue) {
                    acr.put(acrFieldName, newACRFieldValue);
                    isDifferent = true;
                }                              
            }
        }

        return isDifferent;
    }
    
}