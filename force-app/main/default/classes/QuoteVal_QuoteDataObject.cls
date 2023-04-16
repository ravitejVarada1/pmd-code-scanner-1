// class to represent quote data
// each instance corresponds to a single quote, with a map for location-specific data
public class QuoteVal_QuoteDataObject {

    public SBQQ__Quote__c quote;
    public Set<String> quoteErrorSet = new Set<String>();
    public Map<Id,QuoteVal_LocationDataObject> locationDataMap = new Map<Id,QuoteVal_LocationDataObject>();
    public QuoteVal_LocationDataObject locationGroupData = new QuoteVal_LocationDataObject();    // CRM-4694


    public QuoteVal_LocationDataObject getLocationData(Id locationId) {
        if (!locationDataMap.containsKey(locationId)) {
            locationDataMap.put(locationId, new QuoteVal_LocationDataObject());
        }
        return locationDataMap.get(locationId);
    }

    public Set<Id> getHasGroupValidationProductIds() {
        return locationGroupData.getHasValidationProductIds();
    }
}