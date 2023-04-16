@isTest
public class OfferSupportEmailHandlerTest {
    
    static testMethod void testUnsubscribe() 
    {
        
        Messaging.InboundEmail email = new Messaging.InboundEmail() ;
        Messaging.InboundEnvelope env    = new Messaging.InboundEnvelope();
        env.fromAddress = 'test@test.com';
        env.toAddress='test@test.com';
        email.toAddresses = new String[] {'test@test.com'};
        email.fromAddress = 'test@test.com';

        List<Account> accs = TestDataFactory.createPersonalAccounts(1);
        insert accs;
        
        email.subject = 'Test Contact Email';
        email.plainTextBody = 'Test Contact Email';
        
        // add an attachment
        Messaging.InboundEmail.BinaryAttachment attachment = new Messaging.InboundEmail.BinaryAttachment();
        attachment.body = blob.valueOf('my attachment text');
        attachment.fileName = 'textfile.txt';
        attachment.mimeTypeSubType = 'text/plain';
        email.binaryAttachments = new Messaging.inboundEmail.BinaryAttachment[] { attachment };
        Messaging.InboundEmail.TextAttachment attachmenttext = new Messaging.InboundEmail.TextAttachment();
        attachmenttext.body = 'my attachment text';
        attachmenttext.fileName = 'textfiletwo3.txt';
        attachmenttext.mimeTypeSubType = 'texttwo/plain';
        email.textAttachments =   new Messaging.inboundEmail.TextAttachment[] { attachmenttext };
              
        OfferSupportEmailHandler obj= new OfferSupportEmailHandler();
        obj.handleInboundEmail(email, env );
        
        Attachment a = [select name from attachment where name ='textfile.txt' limit 1];
  		System.assertEquals(a.name,'textfile.txt');
        
    }
    
    
    
}