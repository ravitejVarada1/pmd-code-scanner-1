@IsTest
public class Test_Batch_Populate_DataDictionary {

    
    private static String testFldMetaDataResponse = 
        
           '{'+
              '"attributes":{' +
              '"type":"CustomField",'+
              '"url":"/services/data/v29.0/tooling/sobjects/CustomField/00NG0000009Y0I9MAK"'+ 
           '},'+
           '"Id":"00NG0000009Y0I9MAK",'+
           '"TableEnumOrId":"Account",'+
           '"DeveloperName":"A_Number",'+
           '"Description":"This is a sample description for a test class",'+
           '"Length":null,'+
           '"Precision":null,'+
           '"Scale":null,'+
           '"DefaultValue":null,'+
           '"RelationshipLabel":null,'+
           '"SummaryOperation":null,'+
           '"InlineHelpText":"Sample Inline help text",'+
           '"MaskType":null,'+
           '"MaskChar":null,'+
           '"NamespacePrefix":null,'+
           '"ManageableState":"unmanaged",'+
           '"CreatedDate":"2021-04-15T16:03:46.000+0000",'+
           '"CreatedById":"00511010101nB1UAAA",'+
           '"LastModifiedDate":"2021-04-15T16:03:46.000+0000",'+
           '"LastModifiedById":"00511010101nB1UAAA",'+
           '"EntityDefinitionId":"Account",'+
           '"Metadata":{'+
              '"businessOwnerGroup":null,'+
              '"businessOwnerUser":null,'+
              '"businessStatus":null,'+
              '"caseSensitive":null,'+
              '"customDataType":null,'+
              '"defaultValue":null,'+
              '"deleteConstraint":null,'+
              '"deprecated":null,'+
              '"description":"This is a sample description for a test class",'+
              '"displayFormat":null,'+
              '"displayLocationInDecimal":null,'+
              '"encrypted":null,'+
              '"escapeMarkup":null,'+
              '"externalDeveloperName":null,'+
              '"externalId":false,'+
              '"formula":null,'+
              '"formulaTreatBlanksAs":null,'+
              '"inlineHelpText":"This is a sample inline text",'+
              '"isCaseInsensitiveDeterministicEncryptionEnabled":null,'+
              '"isCaseSensitiveDeterministicEncryptionEnabled":null,'+
              '"isConvertLeadDisabled":null,'+
              '"isFilteringDisabled":null,'+
              '"isNameField":null,'+
              '"isSortingDisabled":null,'+
              '"label":"Dealer Type",'+
              '"length":null,'+
              '"lookupFilter":null,'+
              '"maskChar":null,'+
              '"maskType":null,'+
              '"metadataRelationshipControllingField":null,'+
              '"populateExistingRows":null,'+
              '"precision":null,'+
              '"readOnlyProxy":null,'+
              '"referenceTargetField":null,'+
              '"referenceTo":null,'+
              '"relationshipLabel":null,'+
              '"relationshipName":null,'+
              '"relationshipOrder":null,'+
              '"reparentableMasterDetail":null,'+
              '"required":false,'+
              '"restrictedAdminField":null,'+
              '"scale":null,'+
              '"securityClassification":null,'+
              '"startingNumber":null,'+
              '"stripMarkup":null,'+
              '"summarizedField":null,'+
              '"summaryFilterItems":null,'+
              '"summaryForeignKey":null,'+
              '"summaryOperation":null,'+
              '"trackFeedHistory":false,'+
              '"trackHistory":true,'+
              '"trackTrending":null,'+
              '"type":"Picklist",'+
              '"unique":null,'+
              '"urls":null,'+
              '"valueSet":{'+
                 '"controllingField":null,'+
                 '"restricted":null,'+
                 '"valueSetDefinition":{'+
                    '"sorted":false,'+
                    '"value":['+
                       '{'+
                          '"color":null,'+
                          '"default":false,'+
                          '"description":null,'+
                          '"isActive":null,'+
                          '"label":"Nothing",'+
                          '"urls":null,'+
                          '"valueName":"Value1"'+
                       '},'+
                       '{'+
                          '"color":null,'+
                          '"default":false,'+
                          '"description":null,'+
                          '"isActive":null,'+
                          '"label":"Used",'+
                          '"urls":null,'+
                          '"valueName":"Value2"'+
                       '}'+
                    ']'+
                 '},'+
                 '"valueSetName":null,'+
                 '"valueSettings":null'+
              '},'+
              '"visibleLines":null,'+
              '"writeRequiresMasterRead":null'+
           '},'+
           '"FullName":"Account.A_Number__c"'+
        '}';

    public class ToolingAPIMock implements HttpCalloutMock {
        private String testResponse;
        private Integer testStatusCode;
        
        public ToolingAPIMock(String testResponse, Integer testStatusCode){
            this.testResponse = testResponse;
            this.testStatusCode = testStatusCode;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setBody(testResponse);
            res.setStatusCode(testStatusCode);
            return res;
        }
    }
    
	@IsTest
    static void testQueryCustomFields(){
        Test.setMock(HttpCalloutMock.class, new ToolingAPIMock(testFldMetaDataResponse, 200));
        
        Data_Dictionary__c ddObject = new Data_Dictionary__c();
        ddObject.Tooling_API_Custom_Field_URL__c = '/services/data/v29.0/tooling/sobjects/CustomField/00NG0000009Y0I9MAK';
        insert ddObject;
        
        Test.startTest();
            Batch_Populate_DataDictionary batch_populate_tooling = new Batch_Populate_DataDictionary();
            database.executeBatch(batch_populate_tooling,1);
        Test.stopTest();
        
        List<Data_Dictionary__c> ddList = [SELECT Id, Object_Name__c FROM Data_Dictionary__c LIMIT 1];
        system.assertEquals(ddList[0].Object_Name__c == 'Account', true);
    }   
    
	@IsTest
    static void testQueryCustomFieldsSingleRecConstructor(){
        Test.setMock(HttpCalloutMock.class, new ToolingAPIMock(testFldMetaDataResponse, 200));
        
        Data_Dictionary__c ddObject = new Data_Dictionary__c();
        ddObject.Tooling_API_Custom_Field_URL__c = '/services/data/v29.0/tooling/sobjects/CustomField/00NG0000009Y0I9MAK';
        insert ddObject;

        List<Data_Dictionary__c> ddListToGetIdList = [SELECT Id, Object_Name__c FROM Data_Dictionary__c LIMIT 1];
        
        Id ddRecId = ddListToGetIdList[0].Id;
        
        Test.startTest();
            Batch_Populate_DataDictionary batch_populate_tooling = new Batch_Populate_DataDictionary(ddRecId);
            database.executeBatch(batch_populate_tooling,1);
        Test.stopTest();
        
        List<Data_Dictionary__c> ddList = [SELECT Id, Object_Name__c FROM Data_Dictionary__c LIMIT 1];
        system.assertEquals(ddList[0].Object_Name__c == 'Account', true);
    }       
    
	@IsTest
    static void testQueryCustomFieldsSetOfRecsConstructor(){
        Test.setMock(HttpCalloutMock.class, new ToolingAPIMock(testFldMetaDataResponse, 200));
        
        Data_Dictionary__c ddObject = new Data_Dictionary__c();
        ddObject.Tooling_API_Custom_Field_URL__c = '/services/data/v29.0/tooling/sobjects/CustomField/00NG0000009Y0I9MAK';
        insert ddObject;

        Set<Id> ddRecordIdSet = new Set<Id>();
        List<Data_Dictionary__c> ddListToGetIdList = [SELECT Id, Object_Name__c FROM Data_Dictionary__c LIMIT 1];
        
        for(Data_Dictionary__c ddRec : ddListToGetIdList){
			ddRecordIdSet.add(ddRec.Id);            
        }
        
        Test.startTest();
            Batch_Populate_DataDictionary batch_populate_tooling = new Batch_Populate_DataDictionary(ddRecordIdSet);
            database.executeBatch(batch_populate_tooling,1);
        Test.stopTest();
        
        List<Data_Dictionary__c> ddList = [SELECT Id, Object_Name__c FROM Data_Dictionary__c LIMIT 1];
        system.assertEquals(ddList[0].Object_Name__c == 'Account', true);
    }           
    
}