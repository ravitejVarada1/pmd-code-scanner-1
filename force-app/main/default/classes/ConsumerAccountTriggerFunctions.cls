/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         prabhu
* modifiedBy:     prabhu
* created:        05/27/2027
* modified:       05/27/2027
* created jira:   CA-611
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class ConsumerAccountTriggerFunctions {
    //Updating phone format based on the phone insert SA-944
    
     public static void checkPhoneField(List<Account> accList, Map<Id, Account> oldAMap) {
         
        for (Account a : accList) {
            Account oldAccount = oldAMap?.get(a.ID); 
             if(a.Phone != null && a.IsPersonAccount && (oldAccount == null || a.Phone != oldAccount.Phone)){
                  a.Unformatted_Phone_Numer__c = a.phone.replaceAll('[^0-9]','');        
             }		
       }
   }
    
    //If Phone Number is updated in Personal Account, Update the related Dialpad Phone field in offer
    public static void updatePhoneNumberOnRelatedOffer(Map<Id, Account> newAccountMap, Map<Id, Account> oldAMap){
        Map<id,string> accPhoneMap = new Map<id,string>();
        
        for(Account acc : newAccountMap.values()) {
            //add record if phone is changed
            if(acc.Phone != oldAMap.get(acc.Id).Phone){
                accPhoneMap.put(acc.Id,acc.Phone);           
                
            }
        }
        
        if(accPhoneMap.size()>0){
            
            List<offer__c> offerUpdate = new List<offer__c>();
            List<offer__c> OfferList = [select id,Person_Account__c,Dialpad_Phone__c from offer__c where Person_Account__c in : accPhoneMap.keyset() ]; 
            
            if(OfferList.size()>0){
                
                for(offer__c off : OfferList){
                    //Assign the Phone Number from the Personal Account
                    off.Dialpad_Phone__c = accPhoneMap.get(off.Person_Account__c);
                    offerUpdate.add(off);
                }
                
                if(offerUpdate.size()>0){
                    update offerUpdate;
                }
            }
            
        }
        
    }
    
    //Added under SA-618
    public static void preventAccountDelete(List<Account> oldAList){

        String currentUserId = UserInfo.getUserId();

        //Check if current user has the AccountMerge permission set assigned.
        List<PermissionSetAssignment> accountMergeUser = [SELECT Id, AssigneeId FROM PermissionSetAssignment WHERE PermissionSet.Name =: ConsumerConstantsUtil.PS_ACCOUNT_MERGE AND AssigneeId =: currentUserId];
        Boolean mergeUser = accountMergeUser.size() > 0;

        if(!mergeUser){
            return;
        }

        String dealerErrorMessage = 'You do not have permissions to delete dealer accounts. Contact your administrator for help.';
        String csErrorMessage = 'You do not have permissions to delete person accounts. Please use the Merge functionality if this is a duplicate person account.';
        
        for(Account a: oldAList){
            Boolean manualDelete = a.MasterRecordId == null;
            if(a.IsPersonAccount && manualDelete){ //Execute only if this is a delete as a result of a manual delete, not a merge.
                    Trigger.oldMap.get(a.Id).addError(csErrorMessage);
            } else if (!a.IsPersonAccount){
                Trigger.oldMap.get(a.Id).addError(dealerErrorMessage);
            }
        }
        
    }


}