public without sharing class SetCancellationEffectiveDateController {
    @AuraEnabled
    public static string setEffectiveDate(String contractId, Date effectiveDate) {
        Boolean runCancellationBatch = true;
        string msg ='';
        try {
            contract con = new contract();        
            if(effectiveDate < System.today()){
                return 'Date cannot be in the Past';         
            }

            if(contractId != null) {
                con =[SELECT Id, Cancellation_Effective_Date__c, status FROM contract WHERE Id =: contractId];
                if(con.status == 'Activated') {

                    //Update the contract cancellation effective date
                    con.Cancellation_Effective_Date__c=effectiveDate;            
                    List<Contract> contractList= new List<Contract>();
                    contractList.add(con);

                    //Update the Cancellation quote start date = contract cancellation effective date
                    List<SBQQ__Quote__c> existingQuote = [
                        SELECT Id,SBQQ__Account__c,SBQQ__Type__c,SBQQ__StartDate__c FROM SBQQ__Quote__c 
                        WHERE SBQQ__MasterContract__c =: contractId AND SBQQ__Type__c = 'Cancellation'
                        AND SBQQ__Status__c = 'Draft' ORDER BY CreatedDate DESC LIMIT 1
                    ];
                    
                    for(SBQQ__Quote__c q : existingQuote )  {
                        q.SBQQ__StartDate__c = effectiveDate;
                        runCancellationBatch = false;
                    }
                    if(!existingQuote.isEmpty()) {
                        update existingQuote;
                    }

                    // Execute createCancellationQuotes only if there is no cancellation quote associated to the contract
                    if(!Test.isRunningTest() && runCancellationBatch) {
                        createCancellationQuote.createCancellationQuotes(contractList,'Delinquent'); 
                        List<SBQQ__Quote__c> quote = [
                            SELECT Id,SBQQ__Account__c,SBQQ__StartDate__c
                            FROM SBQQ__Quote__c WHERE SBQQ__MasterContract__c =: contractId 
                            AND Cancellation_Quote__c = true ORDER BY CreatedDate DESC LIMIT 1];
                        quote[0].SBQQ__StartDate__c =  effectiveDate;
                        update quote;
                    }
                    
                    update con;
                    msg = 'updated successfully';

                    if(effectiveDate>System.today().addDays(30)) {
                        msg = 'Only the date will be updated';
                    }

                } else {
                    msg = 'update failed';
                }
            }        
        } catch(Exception e) {
            system.debug('error'+e);
        }
    return msg;
    }
}