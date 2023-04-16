/**
 * An apex page controlledddr that exposes the change password functionality
 */
public with sharing class ChangePasswordController {
    public String oldPassword {get; set;}
    public String newpassword {get; set;}
    public string verifyNewPassword {get; set;}        
    
    public PageReference changePassword() {
        System.debug(true);//change 344565
        return Site.changePassword(newpassword, verifyNewPassword, oldpassword);    
    }     
    
   	public ChangePasswordController() {}
}