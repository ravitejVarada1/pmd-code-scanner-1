global class CustomAmendSkuidHelper {
    
    webservice static List<String> amendContract(Id contractIds, Id oppId) {

        ContractAmender contractAmender = new ContractAmender();
        QuoteModel quoteModel = contractAmender.amend(contractIds);
        
        Id newOpportunityId = quoteModel.record.SBQQ__Opportunity2__c;
        Opportunity opp = [SELECT Id,Name,SBQQ__PrimaryQuote__c,SBQQ__AmendedContract__c FROM Opportunity
        WHERE Id =:oppId];

        if(string.isBlank(opp.SBQQ__AmendedContract__c)  && string.isBlank( opp.SBQQ__PrimaryQuote__c)){
            opp.SBQQ__AmendedContract__c =  quoteModel.record.SBQQ__MasterContract__c;
            update opp;
        }
 
       // SBQQ__Quote__c oldquote = [SELECT Id FROM SBQQ__Quote__c WHERE SBQQ__Opportunity2__c =:opp.Id AND SBQQ__Primary__c = true LIMIT 1];
       // oldquote.SBQQ__Primary__c = false;
       // Update oldquote;
 
        SBQQ__Quote__c newQuote = new SBQQ__Quote__c (Id = quoteModel.record.Id, SBQQ__Opportunity2__c = opp.Id, SBQQ__Primary__c = true);
        Update newQuote;
 
        opp.SBQQ__PrimaryQuote__c = quoteModel.record.Id;
        Update opp;
 
        Opportunity newOpp = new Opportunity(Id = newOpportunityId);
        delete newOpp;
 
        system.debug('quoteModelId'+new List <String> {quoteModel.record.Id});

        return new List <String> {quoteModel.record.Id};
 
     }
}