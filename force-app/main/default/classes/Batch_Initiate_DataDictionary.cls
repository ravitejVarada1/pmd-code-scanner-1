public class Batch_Initiate_DataDictionary implements Database.Batchable<String>, Database.AllowsCallouts {
    
	  	public List<String> start(Database.BatchableContext context) {
            String result = DataDictionaryFunctions.getHTTP('/services/data/v42.0/tooling/query/?q=SELECT+DeveloperName+FROM+CustomField');	
    		List<String> httpResponseString = new List<String>();
            httpResponseString.add(result);
            return httpResponseString;            
		}

    	public void execute(Database.BatchableContext BC, List<String> responseStringList) {
            List<Data_Dictionary__c> ddObjectList = new List<Data_Dictionary__c>();
            String result = responseStringList[0];
            
            ToolingAPICustomFieldWrapper completeWrapper 	= ToolingAPICustomFieldWrapper.parse(result);
            Integer totalSize 					= completeWrapper.totalSize;
            Integer size 						= completeWrapper.records.size();
            String nextRecordsUrl 				= completeWrapper.nextRecordsUrl;
            Integer counter 					= 0; 
            Double totalScopes 					= Math.floor((Integer)totalSize /(Integer)size);
            
			ddObjectList = saveToDatabase(completeWrapper.records);   
            
            while(counter < totalScopes) {
				result			= DataDictionaryFunctions.getHTTP(nextRecordsUrl);		
                completeWrapper = ToolingAPICustomFieldWrapper.parse(result);
                nextRecordsUrl	= completeWrapper.nextRecordsUrl;                
                ddObjectList.addall(saveToDatabase(completeWrapper.records));                
				counter++;                
            }

            if(!ddObjectList.isEmpty()){
                insert ddObjectList;
            }
        }
        
        public void finish(Database.BatchableContext BC) {    
            if(!Test.isRunningTest()){            
                Batch_Populate_DataDictionary batch_populate_datadictionary = new Batch_Populate_DataDictionary();
                database.executeBatch(batch_populate_datadictionary,1);
            }
        }
    
        public static List<Data_Dictionary__c> saveToDatabase(List<ToolingAPICustomFieldWrapper.records> customFieldRecordsList){
            
            List<Data_Dictionary__c> ddObjectList = new List<Data_Dictionary__c>();
            map<string,string> customFieldAttrMap = new Map<String,String>();          

            for(ToolingAPICustomFieldWrapper.records record : customFieldRecordsList){
                Data_Dictionary__c  ddObject = new Data_Dictionary__c();       
                ddObject.Full_Name__c = record.DeveloperName;
                customFieldAttrMap = record.attributes;
                for(string customFldAttribute : customFieldAttrMap.KeySet()){
                    if(customFldAttribute == 'url'){
                        ddObject.Tooling_API_Custom_Field_URL__c  = customFieldAttrMap.get(customFldAttribute);
                    }
                }
                ddObjectList.add(ddObject);                
            }
            return ddObjectList;
        }
}