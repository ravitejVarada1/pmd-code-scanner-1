global class QuoteApprovalPage_Submit {
    //- Jira: BR-782
    //PSubmits quote records to the Order Management approval process
    @InvocableMethod(label='submitForOMApproval')
    global static void submitForOMApproval(List<ID> quoteIds){
        
        String OM_APPROVAL_PROCESS_NAME = 'Order_Management_Approval';
        
        List<Approval.ProcessSubmitRequest> requestList = new List<Approval.ProcessSubmitRequest>();
        
        for (ID quoteId : quoteIds){
            // Create an approval request for the quote
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setComments('Docusign Complete - Submitting Request For OM Approval');
            req.setObjectId(quoteId);
            req.setProcessDefinitionNameOrId(OM_APPROVAL_PROCESS_NAME);
            
            requestList.add(req);
        }
        
        Approval.process(requestList);
    }
}