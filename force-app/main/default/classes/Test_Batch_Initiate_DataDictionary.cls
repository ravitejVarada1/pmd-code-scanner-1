@isTest
public class Test_Batch_Initiate_DataDictionary {

	private static String testFieldResponse =
        '{' +
          '"totalSize" : 1,' +
          '"done" : true,' +
          '"records" : [{' +
            '"attributes" : {' +
              '"type" : "CustomField",' +
              '"url" : "/services/data/v29.0/tooling/sobjects/CustomField/00NG0000009Y0I9MAK"' +
            '},' +
            '"DeveloperName" : "A_Number"' +
          '}]' +
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
        Test.setMock(HttpCalloutMock.class, new ToolingAPIMock(testFieldResponse, 200));
        Test.startTest();
            Batch_Initiate_DataDictionary batch_initiate_tooling = new Batch_Initiate_DataDictionary();
            database.executeBatch(batch_initiate_tooling,1);
        Test.stopTest();
        
        List<Data_Dictionary__c> ddList = [SELECT Id FROM Data_Dictionary__c];
        system.assertEquals(ddList.size() > 0, true);
    }    
}