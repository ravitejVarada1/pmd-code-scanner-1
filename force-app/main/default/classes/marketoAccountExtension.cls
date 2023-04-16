//https://cargurus.atlassian.net/browse/B2BM-168 migrated from CRM-965 Wrap Marketo page for access control
public class marketoAccountExtension{
    private final Account acc;
    
    public string recordID {get{return ApexPages.currentPage().getParameters().get('id');} set;}
    public boolean userAccess {get{return marketoController.isUserAuthorised();} set;}
    
    public marketoAccountExtension(ApexPages.StandardController stdController){
        this.acc = (Account)stdController.getRecord();
    }
}