global class OfferSupportEmailHandler implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailresult();
        String myPlainText = email.plainTextBody;
        String FromEmail = email.FromAddress;
        List<Contact> ConList = new List<Contact>();
   
       List<Account> AccList= new List<Account>([select id,PersonEmail from account where IsPersonAccount =true and PersonEmail = : FromEmail 
                      order by CreatedDate desc limit 1]);

        
        if(AccList.size()>0){
        ConList = [select id from contact where accountid = : AccList[0].id and email = : FromEmail
                       order by CreatedDate desc limit 1];
            
        } 

        Id consumerSupportRTId = CaseTriggerFunctions.caseRTNameIdMap.get('Consumer Support');
        
        //With Queue name getting Queue ID
        Group Grp = [select Id,DeveloperName from Group where DeveloperName='Consumer_Support_CarOffer'];
        
        List<EmailTemplate> EMTemplate = new List<EmailTemplate>([SELECT Id,Name,Subject,Body,HtmlValue,FolderName
                        FROM EmailTemplate Where DeveloperName=:'Auto_Response_Consumer_Support_Case' Limit 1]);
            
        
        
        try{
            Case objCase = new Case ( Description = myPlainText, Subject = email.Subject );
            objCase.Origin = 'Email';
            objCase.Status = 'New';
            objCase.Priority = 'Medium';
            objCase.SuppliedEmail = FromEmail;
            objCase.RecordTypeId = consumerSupportRTId;
            objCase.OwnerId = Grp.id;
            if(AccList.size()>0)
            {
                objCase.AccountId = AccList[0].id;
                objCase.ContactId = ConList[0].id;
            }

            objCase.OfferSupport_Email__c = true;
            insert objCase;
            
                    If(email.textAttachments != NUll)
            {
                for (Messaging.Inboundemail.TextAttachment tAttachment : email.textAttachments) {
                    Attachment attachment = new Attachment();
                    attachment.Name = tAttachment.fileName;
                    attachment.Body = Blob.valueOf(tAttachment.body);
                    attachment.ParentId = objCase.Id;
                    insert attachment;
                    
                }
            }
            If(email.binaryAttachments != NUll)
            {
                //Save any Binary Attachment
                for (Messaging.Inboundemail.BinaryAttachment bAttachment : email.binaryAttachments) {
                    Attachment attachment = new Attachment();
                    attachment.Name = bAttachment.fileName;
                    attachment.Body = bAttachment.body;
                    attachment.ParentId = objCase.Id;
                    insert attachment;
                    
                }             
            }  
            
			EmailMessage emailMessage = new EmailMessage();  
            emailMessage.Status = '0'; // email is New
            emailMessage.FromAddress = email.FromAddress;
            if ( email.toAddresses != null && email.toAddresses.size() > 0 )
                emailMessage.ToAddress = String.join( email.toAddresses, ';' );
            if ( email.ccAddresses != null && email.ccAddresses.size() > 0 )
                emailMessage.CcAddress = String.join( email.ccAddresses, ';' );
            emailMessage.FromName = email.FromName; // from name  
            emailMessage.Subject = email.Subject; // email subject  
            emailMessage.TextBody = myPlainText; // email body  
            emailMessage.RelatedToId = objCase.Id;
            insert emailMessage; // insert 
            
            case c = [select id, casenumber from case where id = :objCase.Id];
            String Sub = 'New CarGurus Support Case! Case #: '+c.casenumber;
             // Send email notifcation
            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage(); 
            message.setSenderDisplayName('CarGurus-noreply'); 
            message.setReplyTo('noreply@cargurus.com');
            message.setUseSignature(false); 
            message.setBccSender(false); 
            message.setSaveAsActivity(false); 
            message.toAddresses = new String[] {fromEmail};
            message.setWhatId(objCase.Id); 
            message.setSubject(Sub);
        	message.setHTMLBody(EMTemplate[0].HtmlValue);
            Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
            Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
            
            
            //Auto response mail
            EmailMessage emailMessagereply = new EmailMessage();  
            emailMessagereply.Status = '3'; // email is sent
            emailMessagereply.FromAddress = 'noreply@cargurus.com';
            emailMessagereply.ToAddress = email.FromAddress;
            if ( email.ccAddresses != null && email.ccAddresses.size() > 0 )
                emailMessagereply.CcAddress = String.join( email.ccAddresses, ';' );
            emailMessagereply.FromName = 'CarGurus-noreply'; // from name
            emailMessagereply.Subject = Sub; // email subject 
            emailMessagereply.TextBody = EMTemplate[0].Body; // email body  
            emailMessagereply.RelatedToId = objCase.Id;
            insert emailMessagereply; // insert
            result.success = true;
        }
        catch ( Exception e ) {
            
            System.debug( 'Error is: ' + e.getMessage());  
            result.success = false;   
            
        }     
        
        return result;
    }
}