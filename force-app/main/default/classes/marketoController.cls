//https://cargurus.atlassian.net/browse/B2BM-168 migrated from CRM-965 Wrap Marketo page for access control
public class marketoController {
	private final static string MSI_Access = 'MSI_Access';
    
    public static boolean isUserAuthorised(){
        List<PermissionSetAssignment> psa = [SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId= :UserInfo.getUserId() AND PermissionSet.Name = :MSI_Access];
        
        if(psa.size()==1){
            return true;
        } else {
            return false;
        }
    }
}