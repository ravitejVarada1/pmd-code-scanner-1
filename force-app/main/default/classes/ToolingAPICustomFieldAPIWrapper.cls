public class ToolingAPICustomFieldAPIWrapper {
    
		public Attributes attributes;    
        public String Id;
        public String TableEnumOrId;
        public String DeveloperName;
        public String Description;
        public String Length;
        public String Precision;
        public String Scale;
        public String DefaultValue;
        public String RelationshipLabel;
        public String SummaryOperation;
        public String InlineHelpText;
        public String MaskType;
        public String MaskChar;
        public String NamespacePrefix;
        public String ManageableState;
        public String CreatedDate;
        public String CreatedById;
        public String LastModifiedDate;
        public String LastModifiedById;
        public String EntityDefinitionId;
		public String FullName;    
		public CustomFieldMetadata metadata;
    
        public class Attributes {
               public String fieldType;
               public String url;
		}    
    
      	public class CustomFieldMetadata {
            public String businessOwnerGroup;
			public String businessOwnerUser;
			public String businessStatus;
			public Boolean caseSensitive;
			public String customDataType;
			public String defaultValue;
			public String deleteConstraint;
			public Boolean deprecated;
			public String description;
			public String displayFormat;
			public String displayLocatio1nInDecimal;
			public String encrypted;
			public Boolean escapeMarkup;
			public String externalDeveloperName;
			public Boolean externalId;
			public String formula;
			public String formulaTreatBlanksAs;
			public String inlineHelpText;
			public Boolean isCaseInsensitiveDeterministicEncryptionEnabled;
			public Boolean isCaseSensitiveDeterministicEncryptionEnabled;
			public Boolean isConvertLeadDisabled;
			public Boolean isFilteringDisabled;
			public Boolean isNameField;
			public Boolean isSortingDisabled;
			public String label;
			public Integer length;
			public LookupFilter lookupFilter;
			public String maskChar;
			public String maskType;
			public String metadataRelationshipControllingField;
			public Boolean populateExistingRows;
			public String precision;
			public String readOnlyProxy;
			public String referenceTargetField;
			public String referenceTo;
			public String relationshipLabel;
			public String relationshipName;
			public String relationshipOrder;
			public Boolean reparentableMasterDetail;
			public Boolean required;
			public Boolean restrictedAdminField;
			public String scale;
			public String securityClassification;
			public String startingNumber;
			public Boolean stripMarkup;
			public String summarizedField;
			public String summaryForeignKey;
			public String summaryOperation;
			public Boolean trackFeedHistory;
			public Boolean trackHistory;
			public Boolean trackTrending;
			public String type;
			public Boolean unique;
			public String urls;
            public ValueSet valueSet;
            public String visibleLines;
            public Boolean writeRequiresMasterRead;
        }           
    
      	public class ValueSet {
            public String controllingField;
            public String restricted;
            public ValueSetDefinition valueSetDefinition;
            public String valueSetName;
            public List<valueSettings> valueSettings;
        }
    
      	public class ValueSetDefinition {
            public Boolean isSorted;
            public List<Value> value;
        }     
            
      	public class Value {
            public String color;
            public Boolean isDefault;
            public String description;
            public Boolean isActive;
            public String label;
            public String urls;
            public String valueName;
        }    
    
        public class lookupFilter {
         	public Boolean booleanFilter;
			public List<filterItems> filterItems;
            public Boolean active;
            public String description;
         	public String errorMessage;
         	public String infoMessage;
         	public Boolean isOptional;
        }

        public class filterItems {
            public String field;
            public String operation;
            public String value;
            public String valueField;
        }

        public class valueSettings {
            public List<String> controllingFieldValue;
            public String valueName;
        }
    
        public static ToolingAPICustomFieldAPIWrapper parse(String json_response) {
            return (ToolingAPICustomFieldAPIWrapper) System.JSON.deserialize(json_response, ToolingAPICustomFieldAPIWrapper.class);
        }

}