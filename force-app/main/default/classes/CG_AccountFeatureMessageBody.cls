// https://cargurus.atlassian.net/browse/CRM-5021
// class to create an instance of account feature message body for the cg message to be sent to cg
// test coverage in CG_FeatureFramework_Test
public class CG_AccountFeatureMessageBody {
    
    public static final Map<String,String> COUNTRYCODE_REGION_MAP = CG_FeatureHelper.getCountryRegionMap();

    public String objectType = 'SP';
    public String source = 'SF';
    public String destination = 'CG';
    public String direction = 'OUTBOUND';
    public String modifiedBy = System.UserInfo.getUserName();
    public Datetime modifiedDate = System.now();

    public Integer objectId;
    public String region;
    public String accountId;
    public String accountStatus;
    public List<CG_Feature> features;

    // inner class to represent data for an individual feature for the service provider
    public class CG_Feature {
        Integer id;
        String status;
        Map<String,String> metadata;
        
        // constructor takes metadata string and constructs a string/string key/value map
        public CG_Feature(Integer cgFeatureId, String featureStatus, String featureMetadataString) {
            id = cgFeatureId;
            status = featureStatus;

            if (!String.isEmpty(featureMetadataString)) {
                metadata = new Map<String,String>();
                Map<String,Object> mdMap = (Map<String,Object>)JSON.deserializeUntyped(featureMetadataString);
                for (String mdKey : mdMap.keySet()) {
                    metadata.put(mdKey, (String)mdMap.get(mdKey));
                }
            }
        }
    }

    // constructor to use when setting up a feature framework message to push to cg
    public CG_AccountFeatureMessageBody(Account a, Map<Integer,CG_AccountFeature> accountFeatureMap, Integer spId) {
        this.objectId = spId;
        this.region = COUNTRYCODE_REGION_MAP.get(a.BillingCountryCode);
        this.accountId = a.Id;
        this.accountStatus = a.Product_Activation_Status__c;
        this.features = setupCGFeatureList(accountFeatureMap);
    }

    // use supplied feature map to generate sorted list of features to send to cg
    static List<CG_Feature> setupCGFeatureList(Map<Integer,CG_AccountFeature> accountFeatureMap) {
        List<CG_Feature> returnCGFeatureList = new List<CG_Feature>();

        List<Integer> featureIdList = new List<Integer>(accountFeatureMap.keySet());
        featureIdList.sort();

        for (Integer featureId : featureIdList) {
            CG_AccountFeature af = accountFeatureMap.get(featureId);
            returnCGFeatureList.add(new CG_Feature(featureId, af.featureStatus, af.featureMetadataString));
        }

        return returnCGFeatureList;
    }
    
}