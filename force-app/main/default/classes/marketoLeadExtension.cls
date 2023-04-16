//https://cargurus.atlassian.net/browse/B2BM-168 migrated from CRM-965 Wrap Marketo page for access control
public class marketoLeadExtension{
    private final Lead ld;
    
    public string recordID {get{return ApexPages.currentPage().getParameters().get('id');} set;}
    public boolean userAccess {get{return marketoController.isUserAuthorised();} set;}
    
    public marketoLeadExtension(ApexPages.StandardController stdController){
        this.ld = (Lead)stdController.getRecord();
    }
}