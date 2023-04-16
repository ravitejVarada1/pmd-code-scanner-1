public class ToolingAPICustomFieldWrapper {
        public Integer size;
        public Integer totalSize;
        public boolean done;
        public String nextRecordsUrl;	
        public String queryLocator;	
        public String entityTypeName;	
	    public List<records> records;

    	public class records {
            public String developerName;	
            public Map<String,String> attributes ;	
		}
    
      	public class attributes {
            public Map<String,String> attributeMap ;
		}
	
        public static ToolingAPICustomFieldWrapper parse(String json_response) {
            return (ToolingAPICustomFieldWrapper) System.JSON.deserialize(json_response, ToolingAPICustomFieldWrapper.class);
        }
	
}