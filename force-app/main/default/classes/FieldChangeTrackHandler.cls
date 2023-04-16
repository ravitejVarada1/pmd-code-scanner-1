public class FieldChangeTrackHandler {
    
    public static void TrackTransactions(Map<id,SObject> oldMap,List<SObject> newList){
        
        Schema.SObjectType sot = newList.getSObjectType();
        String Sobjname = sot.getDescribe().getName();	//find and get the Sobject name
        
        //Get List of Source Fields
        Set<String> strSourceFields1 = new Set<String>();
        Set<String> strRecordType1 = new Set<String>();
        
        for(Date_Time_Tracking_Matrix__mdt custmetadata:[Select Id, Source_Field__c,
                                                         Source_Field_Value__c,Source_Object__c,
                                                         Source_Object_Record_Type__c,Target_Field__c,Target_Object__c
                                                         from Date_Time_Tracking_Matrix__mdt where
                                                         Source_Object__c=:Sobjname])
        {
            if(custmetadata.Source_Object__c==custmetadata.Target_Object__c){
                strSourceFields1.add(custmetadata.Source_Object_Record_Type__c+'-'+custmetadata.Source_Field__c);               
            }          
        }
        
        //Get Custom Meta Data Records
        Map<String,Date_Time_Tracking_Matrix__mdt> custMetadataMap = new Map<String,Date_Time_Tracking_Matrix__mdt>();
        for(Date_Time_Tracking_Matrix__mdt custmetadata:[Select Id, Source_Field__c,Source_Field_Value__c,
                                                         Source_Object__c,Source_Object_Record_Type__c,
                                                         Target_Field__c,Target_Object__c from 
                                                         Date_Time_Tracking_Matrix__mdt where Source_Object__c=:Sobjname])
        {
            custMetadataMap.put(custmetadata.Source_Object__c+custmetadata.Source_Object_Record_Type__c+'-'+custmetadata.Source_Field__c+custmetadata.Source_Field_Value__c, custmetadata); 
        }
        
        
        if (Trigger.isUpdate && Trigger.isBefore && strSourceFields1.size()>0) {
            
            for(String str:strSourceFields1){           
                String keySourceFieldRecordType = str;
                String keySourceField = str.substringAfter('-');
                
                for(SObject sObj: newList){
                    String mapKey = Sobjname+keySourceFieldRecordType+(String)sObj.get(keySourceField);
                    if(custMetadataMap.containskey(mapKey)){                       
                        if((String)sObj.get(custMetadataMap.get(mapKey).Source_Field__c)!= oldMap.get(sObj.Id).get(custMetadataMap.get(mapKey).Source_Field__c) 
                           && String.ValueOf((String)sObj.get(custMetadataMap.get(mapKey).Source_Field__c)).toLowerCase()==custMetadataMap.get(mapKey).Source_Field_Value__c.toLowerCase()
                           && custMetadataMap.get(mapKey).Source_Object__c==custMetadataMap.get(mapKey).Target_Object__c)
                        {
                            sObj.put(custMetadataMap.get(mapKey).Target_Field__c, System.now());
                        }
                    }                    
                }
            }
        }        
    }
}