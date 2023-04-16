// https://cargurus.atlassian.net/browse/CRM-4804
// class to create an instance of a single account to feature
// test coverage in CG_FeatureFramework_Test
public class CG_AccountFeature {

    public Id sfFeatureId  { get; private set; }
    public Integer cgFeatureId { get; private set; }
    public String featureName { get; private set; }
    @TestVisible public String featureStatus { get; private set; }
    public String featureMetadataString { get; private set; }
    public Id accountId { get; private set; }
    public Id overrideRecordId { get; private set; }
    @TestVisible public Boolean statusOverride { get; set; }
    @TestVisible public Boolean metadataOverride { get; set; }
    public Datetime cgLastUpdatedDatetime {get; private set;}
    public String cgLastUpdatedBy {get; private set;}

    // constructor takes sf feature id and account id and sets up generic status and metadata
    public CG_AccountFeature(Id sfFeatureId, Account a, String featureStatus) {
        this.sfFeatureId = sfFeatureId;
        this.accountId = a.Id;
        this.featureStatus = featureStatus;
        statusOverride = false;
        metadataOverride = false;
        setCGFeatureVars();
        setFeatureMetadataString(CG_AccountFeatureMapHelper.generateFeatureMetadataString(sfFeatureId, a));
    }

    // constructor takes account feature record
    public CG_AccountFeature(CG_Account_Feature__c cgaf) {
        sfFeatureId = cgaf.CG_Feature__c;
        accountId = cgaf.Account__c;
        overrideRecordId = cgaf.Id;
        statusOverride = cgaf.Status_Override__c;
        metadataOverride = cgaf.Metadata_Override__c;
        featureStatus = cgaf.Status__c;
        setCGFeatureVars();
        setFeatureMetadataString(cgaf.Metadata__c);
    }

    // constructor takes cg feature id, status, and metadata string (or error string), last modified date and person
    // this constructor is used when pulling feature data from cg
    public CG_AccountFeature(Integer cgFeatureId, String featureStatus, String featureMetadataString, 
            Datetime cgLastUpdatedDatetime, String cgLastUpdatedBy) {
        
        this.cgFeatureId = cgFeatureId;
        this.featureStatus = featureStatus;
        this.featureMetadataString = featureMetadataString;
        this.cgLastUpdatedDatetime = cgLastUpdatedDatetime;
        this.cgLastUpdatedBy = cgLastUpdatedBy;
    }

    // get cg feature id and name instance variables from cg feature record
    void setCGFeatureVars() {
        CG_Feature__c cgf = CG_FeatureHelper.getFeatureSFIdMap().get(sfFeatureId);
        cgFeatureId = (Integer)cgf.CG_Feature_Id__c;
        featureName = cgf.Name;
    }

    // set supplied feature metadata string in current feature instance as formatted json
    public void setFeatureMetadataString(String featureMetadataString) {
        System.debug('featureMetadataString: '+featureMetadataString);
        if (!String.isBlank(featureMetadataString)) {
            featureMetadataString = JSON.serializePretty(JSON.deserializeUntyped(featureMetadataString));
        }
        this.featureMetadataString = featureMetadataString;
    }

    // return json metadata string for current feature instance as a generic string / object map
    // if string cannot be deserialized, return map with error
    public Map<String,Object> getFeatureMetadataMap() {
        if (!String.isBlank(featureMetadataString)) {
            try {
                return (Map<String,Object>)JSON.deserializeUntyped(featureMetadataString);
            } catch (Exception e) {
                return new Map<String,Object>{
                    'Metadata Error' => featureMetadataString
                };
            }
        }
        return null;
    }

    // update the status of the current feature instance
    public void setFeatureStatus(String featureStatus) {
        this.featureStatus = featureStatus;
    }

}