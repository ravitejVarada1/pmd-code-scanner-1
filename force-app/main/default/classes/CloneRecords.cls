public class CloneRecords {
    @InvocableMethod(label='Clone Records')
    public static List<sObject> cloneSObjects(List<sObject> records) {
        List<sObject> returnList = new List<sObject>();
        for(sObject obj : records) {
            sObject o = obj.clone(false,true,false,false);
            returnList.add(o);
        }
        return returnList;
    }
}
