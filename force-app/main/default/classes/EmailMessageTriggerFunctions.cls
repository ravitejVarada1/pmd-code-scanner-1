public class EmailMessageTriggerFunctions {
    
    public static void updateCaseStatus(List<EmailMessage> newEmailMessageList) {
        Set<ID> caseId = new Set<ID>();
        for(EmailMessage emsg : newEmailMessageList){
            if(emsg.Incoming == True && emsg.ParentId != null){
               caseId.add(emsg.ParentId) ;
            }
        }
        if(!caseID.isEmpty()){ 
          checkAndUpdateCaseStatus(caseId);  
        }
	}
    
    private static void checkAndUpdateCaseStatus(Set<ID> caseID) {
        Id billingRTID = SObjectDescribeUtils.getRecordTypeIdByName('Case', 'Billing');
        Id supportRTID = SObjectDescribeUtils.getRecordTypeIdByName('Case', 'Support');
        Id caseCSRTID = SObjectDescribeUtils.getRecordTypeIdByName('Case', 'Consumer Support');
        Map<Id, Case> caseStatusToUpdate = new Map<Id, Case>();
        List<Case> caseNeedToCreate = new List<Case>();
        for(case c : [SELECT Id,status,recordtypeId,isclosed,closedDate,OwnerId,AccountId,ContactId,
                      Description,Subject,CaseNumber FROM Case WHERE ID IN:caseID]){
            if(c.Isclosed && c.RecordTypeId == supportRTID){
                integer Days = Integer.valueOf((datetime.now().getTime() - c.closeddate.getTime())/(1000*60*60*24));
                if(days > 14)
                {
                   c.status = 'Closed';
				   Case newCase = new Case();
				   newCase.ParentId = c.Id;
                   newCase.OwnerId = c.OwnerId;
                   newCase.RecordTypeId = c.RecordTypeId;
                   newCase.AccountId = c.AccountId;
                   newCase.ContactId = c.ContactId;
                   newCase.Description = c.Description;
                   newCase.Subject = 'This case was reopend due to an email reply, Please refer to the parent case'  + c.CaseNumber;
				   caseNeedToCreate.add(newCase);
                }
                else 
				{
					c.status = 'Reopen';
				}

               caseStatusToUpdate.put(c.Id,c);   
            }
            else if(c.Isclosed && c.RecordTypeId == billingRTID){
                c.status = 'Reopen';
                caseStatusToUpdate.put(c.Id,c); 
            }
            else if(c.Isclosed && c.RecordTypeId == caseCSRTID){
               c.Status = 'In Progress';
               caseStatusToUpdate.put(c.Id,c);   
            }
        }
        if(!caseStatusToUpdate.isEmpty()){
            update caseStatusToUpdate.values();
        }   
        if(!caseNeedToCreate.isEmpty()){
            insert caseNeedToCreate;
            sendEmailNotification(caseNeedToCreate);
        }   
    }
    
    private static void sendEmailNotification(List<case> caseID) {
        List<Case> newCaseList = [SELECT Id, ParentId, Parent.SuppliedEmail FROM CASE WHERE ID IN :caseID];
		List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
		For(Case c: newCaseList)
		{
			If(c.ParentId != null && c.Parent.SuppliedEmail != null)
			{
				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				List<String> sendTo = new List<String>();
				sendTo.add(c.parent.SuppliedEmail);
				mail.setToAddresses(sendTo);
				mail.setSubject('Request received');
				String body = 'Your case '+ URL.getSalesforceBaseUrl().toExternalForm() + '/' + c.ParentId + ' was closed more than 14 days. \n';
				body += 'A new case '+ URL.getSalesforceBaseUrl().toExternalForm() + '/' + c.Id +' has been created and will be reviewed by our Billing Team.';
				mail.setHtmlBody(body);
				mails.add(mail);
			}
		}
		if(!mails.isEmpty())
		{
			Messaging.sendEmail(mails);
        }
    }
}