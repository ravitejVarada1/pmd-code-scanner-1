public class Batch_Populate_DataDictionary implements Database.Batchable<sObject>, Database.AllowsCallouts {
            
        private Set<Id> queryIds;
        public static Set<String> ddObjectNamesSet = new Set<String>();
        public Batch_Populate_DataDictionary() {}

        static {
            
            for(Data_Dictionary_Objects__mdt ddMtdObject : [SELECT Id, Object_Name__c
                                                            FROM Data_Dictionary_Objects__mdt ORDER BY 
                                                            Object_Name__c]) {
               if(ddMtdObject.Object_Name__c != null){
	               ddObjectNamesSet.add(ddMtdObject.Object_Name__c);
               }
			}
        }
    
        
        public Batch_Populate_DataDictionary(Id queryId) {
            this.queryIds = new Set<Id>{queryId};
        }
        
        public Batch_Populate_DataDictionary(Set<ID> queryIds) { 
            this.queryIds = queryIds;
        }    
    
        public Database.QueryLocator start (Database.BatchableContext context) {
            String query = 'SELECT Id, Tooling_API_Custom_Field_URL__c FROM Data_Dictionary__c'; 
            if (queryIds != null) {
                query += ' WHERE Id IN : queryIds';		
            }      
        	return Database.getQueryLocator(query);            
        }

    	public void execute(Database.BatchableContext BC, List<Data_Dictionary__c> ddList) {
            List<Data_Dictionary__c> ddUpdateList = new List<Data_Dictionary__c>();
			List<Data_Dictionary__c> ddDeleteList = new List<Data_Dictionary__c>();
            
            List<String> objectAndFldNameList = new List<String>();                      
            
            for(Data_Dictionary__c ddRecord : ddList){
                
                Set<String> pickListValueSet = new Set<String>();
            	String customFieldRecordURL = ddRecord.Tooling_API_Custom_Field_URL__c ;
                String result = DataDictionaryFunctions.getHTTP(customFieldRecordURL);	
	            ToolingAPICustomFieldAPIWrapper completeWrapper = ToolingAPICustomFieldAPIWrapper.parse(result);  

                String objAndFldName = completeWrapper.FullName;
                
                if(objAndFldName != null){
                    
                    objectAndFldNameList.addAll(new List<String>(objAndFldName.split('\\.')));
                    ddRecord.API_Name__c			= objectAndFldNameList[1];
                    ddRecord.Object_Name__c 		= objectAndFldNameList[0];
                }
                
                if(!ddObjectNamesSet.contains(ddRecord.Object_Name__c)){
					ddDeleteList.add(ddRecord);
					continue;                    
                }

                ddRecord.Full_Name__c			= completeWrapper.FullName;
				ddRecord.Field_Description__c 	= completeWrapper.Description;
                ddRecord.Field_Help__c			= completeWrapper.InlineHelpText;
                ddRecord.Created_Date__c		= Date.valueOf(completeWrapper.CreatedDate);
                
                ToolingAPICustomFieldAPIWrapper.CustomFieldMetadata metadata = completeWrapper.Metadata;
                
                String strFieldType = metadata.type;
                Boolean booleanTrackHistory = metadata.trackHistory;

                if (strFieldType != null) {
                    ddRecord.Field_Data_Type__c = strFieldType;
                }
				
                if (booleanTrackHistory != null && booleanTrackHistory == true) {
                    ddRecord.Field_Tracking__c = true;
                }
                
                if (metadata.formula != null) {
                    ddRecord.Field_Formula__c = metadata.formula;
                }
                
                if (strFieldType != null && strFieldType == 'Picklist') {
                    ToolingAPICustomFieldAPIWrapper.valueSet valueSet = metadata.valueSet;
                    ToolingAPICustomFieldAPIWrapper.valueSetDefinition valueSetDefinition = valueSet.valueSetDefinition;     
                    if(valueSetDefinition != null){
                        List<ToolingAPICustomFieldAPIWrapper.value> values = valueSetDefinition.value;
                        for(ToolingAPICustomFieldAPIWrapper.value value : values){
                            pickListValueSet.add(value.label);
                        }
                        
                        ddRecord.Active_Picklist_Values__c = String.join((Iterable<String>)pickListValueSet, ', ');
                    }
                }                    
				ddUpdateList.add(ddRecord);
            }   
            if(!ddUpdateList.isEmpty()){
                update ddUpdateList;
            }
            if(!ddDeleteList.isEmpty()){
                delete ddDeleteList;
            }
            
        }
        
        public void finish(Database.BatchableContext BC) {  }
                                                          
}